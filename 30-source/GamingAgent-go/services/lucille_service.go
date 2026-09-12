package services

import (
	"bufio"
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	dbpkg "swarm-os/gaming-agent/db"
	"swarm-os/gaming-agent/models"
)

const (
	nemotronEndpoint = "https://integrate.api.nvidia.com/v1/chat/completions"
	nemotronModel    = "nvidia/llama-3.3-nemotron-super-49b-v1"
)

type LucilleService struct {
	gfn    *GfnService
	steam  *SteamService
	db     *sql.DB
	client *http.Client
}

func NewLucilleService(gfn *GfnService, steam *SteamService, database *sql.DB) *LucilleService {
	return &LucilleService{
		gfn:    gfn,
		steam:  steam,
		db:     database,
		client: &http.Client{Timeout: 120 * time.Second},
	}
}

// Eval builds context from real Steam + GFN data and asks Nemotron for dashboard actions.
func (s *LucilleService) Eval() (*models.LucilleEvalResult, error) {
	steamGames, _ := s.steam.GetLibrary()
	gfnGames, _ := s.gfn.GetCatalog()

	// Build condensed context (top 20 by playtime)
	top := topByPlaytime(steamGames, 20)
	gfnTitles := gfnTitleSet(gfnGames)

	var sb strings.Builder
	sb.WriteString("Steam library (top games by playtime):\n")
	for _, g := range top {
		onGfn := gfnTitles[NormalizeTitle(g.Name)]
		sb.WriteString(fmt.Sprintf("  - %s: %.1fh played, on GFN: %v\n",
			g.Name, float64(g.PlaytimeMinutes)/60, onGfn))
	}
	sb.WriteString(fmt.Sprintf("\nTotal GFN catalog size: %d games\n", len(gfnGames)))

	systemPrompt := `You are Lucille, the SWARM OS gaming AI. Analyze the user's Steam library and suggest dashboard actions.
You MUST call these tools with JSON args:
- set_genre_filter(genres: string[]) — genre chips to activate
- pin_games(titles: string[]) — up to 4 game titles to pin
- set_sort_order(by: "playtime"|"name"|"gfn") — default sort
- favorite_games(titles: string[]) — up to 3 to auto-favourite
Also provide:
- summary: one paragraph about play patterns
- system_suggestions: 2-3 SWARM OS improvement ideas based on what they play
Respond ONLY as JSON matching LucilleEvalResult schema.`

	payload := map[string]any{
		"model": nemotronModel,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": sb.String()},
		},
		"max_tokens":  1024,
		"temperature": 0.7,
	}

	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", nemotronEndpoint, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+os.Getenv("NVIDIA_API_KEY"))
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return &models.LucilleEvalResult{Error: err.Error()}, nil
	}
	defer resp.Body.Close()

	var raw struct {
		Choices []struct {
			Message struct{ Content string } `json:"message"`
		} `json:"choices"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil || len(raw.Choices) == 0 {
		return &models.LucilleEvalResult{Error: "failed to parse Nemotron response"}, nil
	}

	content := raw.Choices[0].Message.Content
	// Strip markdown fences if present
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimPrefix(content, "```")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)

	var result models.LucilleEvalResult
	if err := json.Unmarshal([]byte(content), &result); err != nil {
		result.Summary = content
		result.Error = fmt.Sprintf("parse: %v", err)
	}
	return &result, nil
}

// Chat sends a multi-turn message to Nemotron with Steam/GFN context injected.
func (s *LucilleService) Chat(req models.LucilleChatRequest) (*models.LucilleChatResponse, error) {
	sessionId := req.SessionId
	if sessionId == "" {
		sessionId = fmt.Sprintf("session-%d", time.Now().UnixMilli())
	}

	messages := s.buildContextMessages()
	messages = append(messages, req.Messages...)

	reply, err := s.callNemotron(messages, false, nil)
	if err != nil {
		return &models.LucilleChatResponse{SessionId: sessionId, Error: err.Error()}, nil
	}

	// Persist both turns
	_ = dbpkg.InsertChatMessage(s.db, sessionId, "user", req.Messages[len(req.Messages)-1].Content)
	_ = dbpkg.InsertChatMessage(s.db, sessionId, "assistant", reply)

	return &models.LucilleChatResponse{Reply: reply, SessionId: sessionId}, nil
}

// ChatStream calls Nemotron with streaming=true and writes SSE chunks to w.
func (s *LucilleService) ChatStream(req models.LucilleChatRequest, w http.ResponseWriter) {
	sessionId := req.SessionId
	if sessionId == "" {
		sessionId = fmt.Sprintf("session-%d", time.Now().UnixMilli())
	}

	// Tell the client which session this stream belongs to BEFORE any tokens.
	// Without this, a caller that omits sessionId (first turn) never learns the
	// server-generated id, so every subsequent message would mint a NEW session
	// and multi-turn context would never accumulate in chat_history.
	fmt.Fprintf(w, "event: session\ndata: %s\n\n", sessionId)
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}

	messages := s.buildContextMessages()
	messages = append(messages, req.Messages...)

	var fullReply strings.Builder
	_, _ = s.callNemotron(messages, true, func(token string) {
		fullReply.WriteString(token)
		fmt.Fprintf(w, "data: %s\n\n", token)
		if f, ok := w.(http.Flusher); ok {
			f.Flush()
		}
	})

	fmt.Fprintf(w, "data: [DONE]\n\n")
	if f, ok := w.(http.Flusher); ok {
		f.Flush()
	}

	userMsg := req.Messages[len(req.Messages)-1].Content
	_ = dbpkg.InsertChatMessage(s.db, sessionId, "user", userMsg)
	_ = dbpkg.InsertChatMessage(s.db, sessionId, "assistant", fullReply.String())
}

func (s *LucilleService) buildContextMessages() []models.ChatMessage {
	steamGames, _ := s.steam.GetLibrary()
	gfnGames, _ := s.gfn.GetCatalog()
	top := topByPlaytime(steamGames, 10)
	gfnTitles := gfnTitleSet(gfnGames)

	var sb strings.Builder
	sb.WriteString("Context: User's Steam top games:\n")
	for _, g := range top {
		sb.WriteString(fmt.Sprintf("  %s (%.1fh, GFN: %v)\n",
			g.Name, float64(g.PlaytimeMinutes)/60, gfnTitles[NormalizeTitle(g.Name)]))
	}

	return []models.ChatMessage{
		{Role: "system", Content: "You are Lucille, the SWARM OS AI. You know about the user's Steam library and NVIDIA GeForce NOW catalog. Be helpful, concise, and gaming-focused."},
		{Role: "system", Content: sb.String()},
	}
}

func (s *LucilleService) callNemotron(messages []models.ChatMessage, stream bool, onToken func(string)) (string, error) {
	msgs := make([]map[string]string, len(messages))
	for i, m := range messages {
		msgs[i] = map[string]string{"role": m.Role, "content": m.Content}
	}

	payload := map[string]any{
		"model":       nemotronModel,
		"messages":    msgs,
		"max_tokens":  2048,
		"temperature": 0.7,
		"stream":      stream,
	}

	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", nemotronEndpoint, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+os.Getenv("NVIDIA_API_KEY"))
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if !stream {
		var raw struct {
			Choices []struct {
				Message struct{ Content string } `json:"message"`
			} `json:"choices"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil || len(raw.Choices) == 0 {
			return "", fmt.Errorf("nemotron response parse failed")
		}
		return raw.Choices[0].Message.Content, nil
	}

	// SSE streaming
	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		chunk := strings.TrimPrefix(line, "data: ")
		if chunk == "[DONE]" {
			break
		}
		var raw struct {
			Choices []struct {
				Delta struct{ Content string } `json:"delta"`
			} `json:"choices"`
		}
		if err := json.Unmarshal([]byte(chunk), &raw); err == nil && len(raw.Choices) > 0 {
			token := raw.Choices[0].Delta.Content
			if token != "" && onToken != nil {
				onToken(token)
			}
		}
	}
	return "", nil
}

func topByPlaytime(games []models.SteamGame, n int) []models.SteamGame {
	sorted := make([]models.SteamGame, len(games))
	copy(sorted, games)
	for i := 1; i < len(sorted); i++ {
		for j := i; j > 0 && sorted[j].PlaytimeMinutes > sorted[j-1].PlaytimeMinutes; j-- {
			sorted[j], sorted[j-1] = sorted[j-1], sorted[j]
		}
	}
	if n > len(sorted) {
		n = len(sorted)
	}
	return sorted[:n]
}

func gfnTitleSet(games []models.GfnGame) map[string]bool {
	m := make(map[string]bool, len(games))
	for _, g := range games {
		m[NormalizeTitle(g.Title)] = true
	}
	return m
}
