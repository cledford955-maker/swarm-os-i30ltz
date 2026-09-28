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

// chatEndpoint/chatModel/chatAPIKeyEnv have deliberately provider-agnostic
// names — this has already changed provider AND model twice in one day
// (2026-09-20): NVIDIA NIM's nvidia/llama-3.3-nemotron-super-49b-v1 (retired
// by NVIDIA, HTTP 410) -> NIM's nvidia/nemotron-3.5-lightning-30b-a3b (fixed)
// -> NIM's moonshotai/kimi-k3 (user-requested swap, but NIM's hosting of it
// turned out to have severe latency: a bare direct call with no GamingAgent
// involvement took 105s for a 64-token reply) -> OpenRouter's
// moonshotai/kimi-k2.5 (this one — same model family, different host,
// dramatically faster: 8.8s for an equivalent call, verified live before
// switching). Naming this after "Nemotron" or "NIM" specifically, like the
// two rename passes before this one had to, would just mean a third rename
// next time either changes again — check these three constants for what's
// actually live, not any comment or doc elsewhere.
const (
	chatEndpoint  = "https://openrouter.ai/api/v1/chat/completions"
	chatModel     = "moonshotai/kimi-k2.5"
	chatAPIKeyEnv = "OPENROUTER_API_KEY"
)

// This and every other OpenRouter/NIM-hosted model tried for Lucille so far
// has been a reasoning model: it streams "reasoning"/"reasoning_content"
// deltas (naming varies by provider) before the real "content" delta. Both
// callChat's streaming parser and the non-streaming Message.Content read
// below only look at the content field, so the chain-of-thought is filtered
// out automatically regardless of what the provider calls its reasoning
// field — verified this holds for kimi-k2.5 on OpenRouter specifically
// before switching, not just assumed from the pattern holding before. It
// does eat into max_tokens though, which is why the budgets below are 3072
// rather than the original non-reasoning-model defaults.

type LucilleService struct {
	gfn    *GfnService
	steam  *SteamService
	games  *GamesService // optional — feeds current CheapShark deals into context
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

// WithGamesService injects the CheapShark-backed price service used to enrich
// Lucille's context with current deals. Wire from main.go AFTER both services
// exist. Safe to leave unset in tests — buildContextMessages skips the deals
// block when games is nil.
func (s *LucilleService) WithGamesService(g *GamesService) *LucilleService {
	s.games = g
	return s
}

// Eval builds context from real Steam + GFN data and asks the chat model for dashboard actions.
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

	systemPrompt := `You are Lucille, the SWARM OS gaming AI. Analyze the user's Steam library.
Return ONLY one flat JSON object with exactly these fields (not tool calls or nested actions):
{"genreFilters":["Action"],"pinGames":["Exact game title"],"sortBy":"playtime","favoriteGames":["Exact game title"],"summary":"One paragraph about play patterns","systemSuggestions":["First suggestion","Second suggestion"],"topGames":[{"name":"Exact game title","hours":1.5,"onGfn":true}]}
Use actual titles and hours from the supplied library. Pin at most 4 titles, favorite at most 3.
sortBy must be playtime, name, or gfn. Provide 2-3 systemSuggestions.
Every array must be an array, never null; use [] if no applicable data.
There are no tools to call. Do not use snake_case field names or wrap this object in another object.`

	payload := map[string]any{
		"model": chatModel,
		"messages": []map[string]string{
			{"role": "system", "content": systemPrompt},
			{"role": "user", "content": sb.String()},
		},
		// 6144 not 1024/3072: reasoning models eat real budget on
		// chain-of-thought before the JSON answer even starts, and kimi-k2.5
		// specifically (2026-09-20) was observed producing a longer, more
		// deeply-nested JSON shape than the schema asks for — got cut off
		// mid-object at 3072, producing an "unexpected end of JSON input"
		// parse error.
		"max_tokens":  6144,
		"temperature": 0.7,
	}

	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", chatEndpoint, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+os.Getenv(chatAPIKeyEnv))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("HTTP-Referer", "https://github.com/i30ltz/swarm-os")
	req.Header.Set("X-Title", "SWARM OS GamingAgent")

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
		return &models.LucilleEvalResult{Error: "failed to parse chat model response"}, nil
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

// Chat sends a multi-turn message to the chat model with Steam/GFN context injected.
func (s *LucilleService) Chat(req models.LucilleChatRequest) (*models.LucilleChatResponse, error) {
	sessionId := req.SessionId
	if sessionId == "" {
		sessionId = fmt.Sprintf("session-%d", time.Now().UnixMilli())
	}

	messages := s.buildContextMessages()
	messages = append(messages, req.Messages...)

	reply, err := s.callChat(messages, false, nil)
	if err != nil {
		return &models.LucilleChatResponse{SessionId: sessionId, Error: err.Error()}, nil
	}

	// Persist both turns
	_ = dbpkg.InsertChatMessage(s.db, sessionId, "user", req.Messages[len(req.Messages)-1].Content)
	_ = dbpkg.InsertChatMessage(s.db, sessionId, "assistant", reply)

	return &models.LucilleChatResponse{Reply: reply, SessionId: sessionId}, nil
}

// ChatStream calls the chat model with streaming=true and writes SSE chunks to w.
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
	_, _ = s.callChat(messages, true, func(token string) {
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

	messages := []models.ChatMessage{
		{Role: "system", Content: "You are Lucille, the SWARM OS AI. You know about the user's Steam library, NVIDIA GeForce NOW catalog, and current deal prices. Be helpful, concise, and gaming-focused. When suggesting games, reference specific prices from the deal list below if the game is on sale."},
		{Role: "system", Content: sb.String()},
	}

	// Current deals — best effort. A network failure or throttling does not
	// block chat; Lucille just answers without price context in that case.
	if s.games != nil {
		if deals, err := s.games.GetTopDeals(8); err == nil && len(deals) > 0 {
			var db strings.Builder
			db.WriteString("Current Steam deals (from CheapShark, cheapest first):\n")
			for _, d := range deals {
				db.WriteString(fmt.Sprintf("  %s — $%s (was $%s, %s%% off)\n",
					d.Title, d.SalePrice, d.NormalPrice, d.Savings))
			}
			messages = append(messages, models.ChatMessage{Role: "system", Content: db.String()})
		}
	}

	// Calendar context from GoogleWorkspaceService (8402). Silently skipped if
	// the service is down or not authenticated — Lucille just answers without
	// scheduling awareness. Never blocks chat.
	if cal := fetchUpcomingCalendarSummary(); cal != "" {
		messages = append(messages, models.ChatMessage{Role: "system", Content: cal})
	}

	// Local weather via wttr.in — no API key, no rate-limit gate (fair-use
	// public service). Cached ~15 min so a chatty Lucille doesn't hammer it.
	if wx := fetchWeatherSummary(); wx != "" {
		messages = append(messages, models.ChatMessage{Role: "system", Content: wx})
	}

	messages = append(messages, models.ChatMessage{Role: "system", Content: lucilleActionProtocol})
	return messages
}

// googleWorkspaceCalendarBase is overridable in tests.
var googleWorkspaceCalendarBase = func() string {
	if v := os.Getenv("GOOGLE_WORKSPACE_URL"); v != "" {
		return v
	}
	return "http://127.0.0.1:8402"
}

var calendarHTTPClient = &http.Client{Timeout: 3 * time.Second}

// fetchUpcomingCalendarSummary returns a short "next few calendar events" block
// suitable for Lucille's system context. Returns "" (empty) if:
//   - the service is unreachable / returns non-2xx (not authenticated, offline);
//   - no events are returned;
//   - decode fails.
// Never returns an error — a broken calendar must not break chat.
func fetchUpcomingCalendarSummary() string {
	base := googleWorkspaceCalendarBase()
	// Fetch the primary calendar, next 7 days, up to 6 events.
	url := fmt.Sprintf("%s/cal/events?maxResults=6&daysAhead=7&calendarId=primary", base)
	resp, err := calendarHTTPClient.Get(url)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return ""
	}

	var raw struct {
		OK     bool `json:"ok"`
		Events []struct {
			Summary string `json:"summary"`
			Start   struct {
				DateTime string `json:"dateTime"`
				Date     string `json:"date"`
			} `json:"start"`
		} `json:"events"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return ""
	}
	if len(raw.Events) == 0 {
		return ""
	}

	var sb strings.Builder
	sb.WriteString("Upcoming calendar events (next 7 days — use to avoid suggesting a long gaming session before something scheduled):\n")
	for _, e := range raw.Events {
		when := e.Start.DateTime
		if when == "" {
			when = e.Start.Date
		}
		if when == "" {
			continue
		}
		sb.WriteString(fmt.Sprintf("  %s — %s\n", when, e.Summary))
	}
	return sb.String()
}

// lucilleActionProtocol lets Lucille actually do things from the gaming
// overlay's chat panel instead of only answering questions about them. The
// overlay's dashboard.html parses a trailing "ACTION: verb [arg]" line out
// of the reply text via regex and dispatches it locally (media control,
// opening a browser widget, launching an app) — this system message is the
// other half of that contract, so the exact verb spelling here must match
// what dashboard.html's dispatchAction() recognizes.
const lucilleActionProtocol = `If, and only if, the user is asking you to DO something (not just answer a question), end your reply with exactly one extra line in this exact format, after your normal reply text:
ACTION: <verb> [arg]

Valid verbs:
  media_play, media_pause, media_play_pause, media_next, media_previous, media_stop — control whatever's currently playing (no arg)
  open_browser <url or search text> — open a walkthrough/web page in a new window
  open_app <chrome|opera-gx> — launch an installed browser app

Only ever use these exact verbs. Never invent a new verb. If the user is just chatting or asking a question, do not include an ACTION line at all.`

func (s *LucilleService) callChat(messages []models.ChatMessage, stream bool, onToken func(string)) (string, error) {
	msgs := make([]map[string]string, len(messages))
	for i, m := range messages {
		msgs[i] = map[string]string{"role": m.Role, "content": m.Content}
	}

	payload := map[string]any{
		"model":    chatModel,
		"messages": msgs,
		// Same reasoning-overhead reasoning as Eval's 3072 above.
		"max_tokens":  3072,
		"temperature": 0.7,
		"stream":      stream,
	}

	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", chatEndpoint, bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+os.Getenv(chatAPIKeyEnv))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("HTTP-Referer", "https://github.com/i30ltz/swarm-os")
	req.Header.Set("X-Title", "SWARM OS GamingAgent")

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
			return "", fmt.Errorf("chat model response parse failed")
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
