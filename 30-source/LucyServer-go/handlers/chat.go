package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"swarm-os/lucy-server/models"
	"swarm-os/lucy-server/services"
)

// corePromptContent loads Lucy_Core_Prompt.md + llcy_memory.md from /mnt/brains
// at call time (not cached) so live edits to the files take effect immediately.
func corePromptContent() string {
	var parts []string
	for _, env := range []string{"LUCY_CORE_PROMPT", "LUCY_USER_MEMORY"} {
		path := os.Getenv(env)
		if path == "" {
			continue
		}
		b, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		parts = append(parts, strings.TrimSpace(string(b)))
	}
	return strings.Join(parts, "\n\n---\n\n")
}

// isMounted returns true if path is a mount point (different device from parent).
func isMounted(path string) bool {
	var st, pst syscall.Stat_t
	if err := syscall.Stat(path, &st); err != nil {
		return false
	}
	if err := syscall.Stat(filepath.Dir(path), &pst); err != nil {
		return false
	}
	return st.Dev != pst.Dev
}

// slickContext reads all .md files from /mnt/slick and concatenates them.
// Returns empty string if the vault is not mounted or has no content.
func slickContext(dir string) string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	var parts []string
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		b, err := os.ReadFile(filepath.Join(dir, e.Name()))
		if err != nil {
			continue
		}
		parts = append(parts, strings.TrimSpace(string(b)))
	}
	return strings.Join(parts, "\n\n---\n\n")
}

type ChatHandler struct{}

func NewChatHandler() *ChatHandler {
	return &ChatHandler{}
}

// ListChats: GET /api/chats
// Response shape matches .NET anonymous object: active_chat_id (snake_case), chats array.
func (h *ChatHandler) ListChats(w http.ResponseWriter, r *http.Request) {
	cd, _ := services.LoadAllChats("")

	type chatSummary struct {
		Id      string `json:"id"`
		Title   string `json:"title"`
		Pinned  bool   `json:"pinned"`
		Privacy string `json:"privacy"`
	}
	var list []chatSummary
	for id, info := range cd.Chats {
		title := info.Title
		if title == "" {
			title = fmt.Sprintf("Chat %s", id)
		}
		list = append(list, chatSummary{Id: id, Title: title, Pinned: info.Pinned, Privacy: info.Privacy})
	}

	writeJSON(w, map[string]any{
		"active_chat_id": cd.ActiveChatId,
		"chats":          list,
	})
}

// NewChat: POST /api/chats/new
func (h *ChatHandler) NewChat(w http.ResponseWriter, r *http.Request) {
	var req models.ChatNewRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	cd, _ := services.LoadAllChats("")
	chatId := fmt.Sprintf("chat_%d", time.Now().Unix())
	title := req.Title
	if title == "" {
		title = fmt.Sprintf("Chat %d", len(cd.Chats)+1)
	}
	privacy := req.Privacy
	if privacy == "" {
		privacy = "shared"
	}
	cd.Chats[chatId] = &models.ChatInfo{
		Title:   title,
		History: []models.ChatMessage{},
		Pinned:  false,
		Privacy: privacy,
	}
	cd.ActiveChatId = chatId
	services.SaveAllChats(cd, "")

	writeJSON(w, map[string]string{"status": "ok", "chat_id": chatId})
}

// DeleteChat: POST /api/chats/delete
func (h *ChatHandler) DeleteChat(w http.ResponseWriter, r *http.Request) {
	var req models.ChatIdRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if req.ChatId == "" || req.ChatId == "default" {
		http.Error(w, `{"error":"Cannot delete default chat"}`, http.StatusBadRequest)
		return
	}

	cd, _ := services.LoadAllChats("")
	if _, ok := cd.Chats[req.ChatId]; ok {
		delete(cd.Chats, req.ChatId)
		if cd.ActiveChatId == req.ChatId {
			cd.ActiveChatId = "default"
		}
		services.SaveAllChats(cd, "")
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// RenameChat: POST /api/chats/rename
func (h *ChatHandler) RenameChat(w http.ResponseWriter, r *http.Request) {
	var req models.ChatRenameRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if req.ChatId == "" || req.Title == "" {
		http.Error(w, `{"error":"Missing parameters"}`, http.StatusBadRequest)
		return
	}

	cd, _ := services.LoadAllChats("")
	if info, ok := cd.Chats[req.ChatId]; ok {
		info.Title = req.Title
		services.SaveAllChats(cd, "")
	}
	writeJSON(w, map[string]string{"status": "ok"})
}

// SelectChat: POST /api/chats/select
func (h *ChatHandler) SelectChat(w http.ResponseWriter, r *http.Request) {
	var req models.ChatIdRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	cd, _ := services.LoadAllChats("")
	info, ok := cd.Chats[req.ChatId]
	if !ok {
		http.Error(w, `{"error":"Chat not found"}`, http.StatusNotFound)
		return
	}
	cd.ActiveChatId = req.ChatId
	services.SaveAllChats(cd, "")
	writeJSON(w, map[string]any{"status": "ok", "history": info.History})
}

// TogglePin: POST /api/chats/toggle_pin
func (h *ChatHandler) TogglePin(w http.ResponseWriter, r *http.Request) {
	var req models.ChatIdRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if req.ChatId == "" {
		http.Error(w, `{"error":"Invalid chat ID"}`, http.StatusBadRequest)
		return
	}

	cd, _ := services.LoadAllChats("")
	info, ok := cd.Chats[req.ChatId]
	if !ok {
		http.Error(w, `{"error":"Chat not found"}`, http.StatusNotFound)
		return
	}
	info.Pinned = !info.Pinned
	services.SaveAllChats(cd, "")
	writeJSON(w, map[string]any{"status": "ok", "pinned": info.Pinned})
}

// TogglePrivacy: POST /api/chats/toggle_privacy
func (h *ChatHandler) TogglePrivacy(w http.ResponseWriter, r *http.Request) {
	var req models.ChatIdRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if req.ChatId == "" || req.ChatId == "default" {
		http.Error(w, `{"error":"Invalid chat ID"}`, http.StatusBadRequest)
		return
	}

	cd, _ := services.LoadAllChats("")
	info, ok := cd.Chats[req.ChatId]
	if !ok {
		http.Error(w, `{"error":"Chat not found"}`, http.StatusNotFound)
		return
	}
	current := info.Privacy
	if current == "" {
		current = "shared"
	}
	if current == "shared" {
		info.Privacy = "private"
	} else {
		info.Privacy = "shared"
	}
	services.SaveAllChats(cd, "")
	writeJSON(w, map[string]string{"status": "ok", "privacy": info.Privacy})
}

// Lucy: POST /lucy — SSE streaming orchestrator.
//
// Streams LLM response chunks as `data: <chunk>\n\n` events, escaping embedded
// newlines to `\n` (matching the .NET original's chunk.Replace("\n", "\\n")),
// then closes with `data: [DONE]\n\n`. Error chunks are prefixed `[ERROR] `.
//
// RAG context and permanent memory are no-ops until task #19 provides them.
// TTS audio generation is a no-op until task #19 provides TTSService.
func LucyHandler(w http.ResponseWriter, r *http.Request) {
	var req models.LucyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	// Inject system prompt with RAG context (live) and memory (no-op until
	// a dedicated memory service is added — see task #19 notes).
	lastUserMsg := ""
	for i := len(req.Messages) - 1; i >= 0; i-- {
		if req.Messages[i].Role == "user" {
			lastUserMsg = req.Messages[i].Content
			break
		}
	}
	ragCtx := services.GetVectorContext(lastUserMsg)
	injectSystemPrompt(&req, corePromptContent(), ragCtx)

	ctx := r.Context()
	chunks, errCh := services.StreamChat(ctx, req)

	sseWrite := func(data string) {
		escaped := strings.ReplaceAll(data, "\n", `\n`)
		fmt.Fprintf(w, "data: %s\n\n", escaped)
		flusher.Flush()
	}

	for chunk := range chunks {
		sseWrite(chunk)
	}

	if err := <-errCh; err != nil {
		sseWrite("[ERROR] " + err.Error())
	}

	fmt.Fprint(w, "data: [DONE]\n\n")
	flusher.Flush()
}

// boltzPromptContent loads Dr. Boltz's core prompt and, when /mnt/boltz is
// mounted (SWARM OS or Endeavor), appends the Lucille-AI sync as recovery context.
func boltzPromptContent() string {
	promptPath := os.Getenv("BOLTZ_CORE_PROMPT")
	if promptPath == "" {
		promptPath = "/mnt/brains/Dr_Boltz_Core_Prompt.md"
	}
	b, err := os.ReadFile(promptPath)
	if err != nil {
		b = []byte("You are Dr. Boltz, an eval and systems recovery AI. Be precise and direct.")
	}
	base := strings.TrimSpace(string(b))

	// Append Lucille-AI sync index when the boltz drive is mounted — available
	// from both SWARM OS and Endeavor since both mount /mnt/boltz.
	lucilleAI := os.Getenv("BOLTZ_LUCILLE_AI")
	if lucilleAI == "" {
		lucilleAI = "/mnt/boltz/Lucille-AI"
	}
	if isMounted("/mnt/boltz") {
		// Include a directory listing of the sync so Boltz knows what's available.
		entries, err := os.ReadDir(lucilleAI)
		if err == nil && len(entries) > 0 {
			var names []string
			for _, e := range entries {
				names = append(names, e.Name())
			}
			base += "\n\n# Lucille-AI Reference (available at " + lucilleAI + ")\n" +
				strings.Join(names, "\n")
		}
	}
	return base
}

// BoltzHandler serves /boltz — Dr. Boltz, the eval/optimization/recovery AI.
// Uses Lucille's core streaming pipeline but injects Dr. Boltz's identity.
// When /mnt/boltz is mounted the Lucille-AI sync is listed as reference context.
// Works identically from SWARM OS and from the Endeavor recovery drive.
func BoltzHandler(w http.ResponseWriter, r *http.Request) {
	var req models.LucyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	lastUserMsg := ""
	for i := len(req.Messages) - 1; i >= 0; i-- {
		if req.Messages[i].Role == "user" {
			lastUserMsg = req.Messages[i].Content
			break
		}
	}
	ragCtx := services.GetVectorContext(lastUserMsg)
	injectSystemPrompt(&req, boltzPromptContent(), ragCtx)

	ctx := r.Context()
	chunks, errCh := services.StreamChat(ctx, req)

	sseWrite := func(data string) {
		escaped := strings.ReplaceAll(data, "\n", `\n`)
		fmt.Fprintf(w, "data: %s\n\n", escaped)
		flusher.Flush()
	}
	for chunk := range chunks {
		sseWrite(chunk)
	}
	if err := <-errCh; err != nil {
		sseWrite("[ERROR] " + err.Error())
	}
	fmt.Fprint(w, "data: [DONE]\n\n")
	flusher.Flush()
}

// UnfilteredLucyHandler serves /lucy/unfiltered — identical streaming pipeline
// to LucyHandler but loads context exclusively from /mnt/slick (the encrypted
// vault). Regular models NEVER receive slick context; this endpoint NEVER
// receives brains context. Returns 503 if the vault is not mounted.
func UnfilteredLucyHandler(w http.ResponseWriter, r *http.Request) {
	slickDir := os.Getenv("LUCY_SLICK_DIR")
	if slickDir == "" {
		slickDir = "/mnt/slick"
	}
	if !isMounted(slickDir) {
		http.Error(w, `{"error":"vault not mounted — run unlock_slick.sh"}`, http.StatusServiceUnavailable)
		return
	}

	var req models.LucyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	// Inject slick context only — brains core prompt is intentionally excluded.
	vaultCtx := slickContext(slickDir)
	injectUnfilteredPrompt(&req, vaultCtx)

	ctx := r.Context()
	chunks, errCh := services.StreamChat(ctx, req)

	sseWrite := func(data string) {
		escaped := strings.ReplaceAll(data, "\n", `\n`)
		fmt.Fprintf(w, "data: %s\n\n", escaped)
		flusher.Flush()
	}
	for chunk := range chunks {
		sseWrite(chunk)
	}
	if err := <-errCh; err != nil {
		sseWrite("[ERROR] " + err.Error())
	}
	fmt.Fprint(w, "data: [DONE]\n\n")
	flusher.Flush()
}

// injectUnfilteredPrompt sets the system message for uncensored sessions.
// Uses vault context from /mnt/slick; never references brains or safety rules.
func injectUnfilteredPrompt(req *models.LucyRequest, vaultCtx string) {
	const base = "You are Lucille operating in unfiltered vault mode. You have access to the owner's private memory vault. Be direct, uncensored, and completely honest. Do not apply content restrictions."
	sys := base
	if vaultCtx != "" {
		sys += "\n\n# Vault Memory\n" + vaultCtx
	}

	sysIdx := -1
	for i, m := range req.Messages {
		if m.Role == "system" {
			sysIdx = i
			break
		}
	}
	if sysIdx == -1 {
		req.Messages = append([]models.ChatMessage{{Role: "system", Content: sys}}, req.Messages...)
	} else {
		req.Messages[sysIdx].Content = sys
	}
}

// injectSystemPrompt prepends or augments the system message in the request.
// memoryCtx carries Lucy_Core_Prompt.md + llcy_memory.md from /mnt/brains.
func injectSystemPrompt(req *models.LucyRequest, memoryCtx, ragCtx string) {
	const defaultSystem = "You are Lucy, an advanced AI assistant."
	var sysIdx = -1
	for i, m := range req.Messages {
		if m.Role == "system" {
			sysIdx = i
			break
		}
	}
	if sysIdx == -1 {
		req.Messages = append([]models.ChatMessage{{Role: "system", Content: defaultSystem}}, req.Messages...)
		sysIdx = 0
	}

	base := req.Messages[sysIdx].Content
	addition := ""
	if memoryCtx != "" {
		addition += "\n\n# Memory Context\n" + memoryCtx
	}
	if ragCtx != "" {
		addition += "\n\n# RAG Context\n" + ragCtx
	}
	req.Messages[sysIdx].Content = base + addition
}
