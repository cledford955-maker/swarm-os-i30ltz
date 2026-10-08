package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func setupTestApp(t *testing.T) (*App, string) {
	t.Helper()
	tmpDir, err := os.MkdirTemp("", "lucille-test-*")
	if err != nil {
		t.Fatalf("failed to create temp dir: %v", err)
	}

	st, err := openStore(tmpDir)
	if err != nil {
		t.Fatalf("failed to open store: %v", err)
	}

	cfg := defaultConfig()
	cfg.DataDir = tmpDir
	cfg.Token = "test-secret-token"

	app := &App{
		cfg:   cfg,
		store: st,
		cache: newCache(),
	}

	return app, tmpDir
}

func TestHealthEndpoint(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"ok": true, "service": "lucille-assistant", "version": version})
	})

	req := httptest.NewRequest("GET", "/health", nil)
	rr := httptest.NewRecorder()
	mux.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}

	var res map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &res); err != nil {
		t.Fatalf("invalid json: %v", err)
	}
	if res["ok"] != true || res["service"] != "lucille-assistant" {
		t.Fatalf("unexpected response: %v", res)
	}
}

func TestAuthMiddleware(t *testing.T) {
	token := "secret123"
	handler := auth(token, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))

	// 1. Loopback request (127.0.0.1) without token -> Allowed
	req := httptest.NewRequest("GET", "/api/care", nil)
	req.RemoteAddr = "127.0.0.1:54321"
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("loopback should succeed without token, got %d", rr.Code)
	}

	// 2. Remote IP without token -> 401 Unauthorized
	req = httptest.NewRequest("GET", "/api/care", nil)
	req.RemoteAddr = "100.82.1.25:54321"
	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusUnauthorized {
		t.Fatalf("remote request without token should fail with 401, got %d", rr.Code)
	}

	// 3. Remote IP with X-Swarm-Auth header -> Allowed
	req = httptest.NewRequest("GET", "/api/care", nil)
	req.RemoteAddr = "100.82.1.25:54321"
	req.Header.Set("X-Swarm-Auth", token)
	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("remote with X-Swarm-Auth should succeed, got %d", rr.Code)
	}

	// 4. Remote IP with Bearer Authorization -> Allowed
	req = httptest.NewRequest("GET", "/api/care", nil)
	req.RemoteAddr = "100.82.1.25:54321"
	req.Header.Set("Authorization", "Bearer "+token)
	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("remote with Bearer token should succeed, got %d", rr.Code)
	}

	// 5. Remote IP with ?token= query param -> Allowed
	req = httptest.NewRequest("GET", "/api/care?token="+token, nil)
	req.RemoteAddr = "100.82.1.25:54321"
	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("remote with query token should succeed, got %d", rr.Code)
	}

	// 6. Non-API static route from remote without token -> Allowed (for app shell)
	req = httptest.NewRequest("GET", "/", nil)
	req.RemoteAddr = "100.82.1.25:54321"
	rr = httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("static shell route should be public, got %d", rr.Code)
	}
}

func TestCareEndpoints(t *testing.T) {
	app, tmpDir := setupTestApp(t)
	defer os.RemoveAll(tmpDir)

	// Test GET /api/care initially empty
	req := httptest.NewRequest("GET", "/api/care", nil)
	rr := httptest.NewRecorder()
	app.handleCare(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleCare returned %d", rr.Code)
	}

	// Test POST /api/care/water
	waterBody := []byte(`{"ml": 500}`)
	req = httptest.NewRequest("POST", "/api/care/water", bytes.NewReader(waterBody))
	rr = httptest.NewRecorder()
	app.handleCareWater(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleCareWater returned %d: %s", rr.Code, rr.Body.String())
	}

	var careRes map[string]any
	if err := json.Unmarshal(rr.Body.Bytes(), &careRes); err != nil {
		t.Fatalf("parse care res: %v", err)
	}
	dayMap := careRes["day"].(map[string]any)
	if int(dayMap["water_ml"].(float64)) != 500 {
		t.Fatalf("expected water 500, got %v", dayMap["water_ml"])
	}

	// Test POST /api/care/med
	medBody := []byte(`{"name": "Morning meds"}`)
	req = httptest.NewRequest("POST", "/api/care/med", bytes.NewReader(medBody))
	rr = httptest.NewRecorder()
	app.handleCareMed(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleCareMed returned %d: %s", rr.Code, rr.Body.String())
	}

	// Deduplication test: re-posting same med on same day should not duplicate
	req = httptest.NewRequest("POST", "/api/care/med", bytes.NewReader(medBody))
	rr = httptest.NewRecorder()
	app.handleCareMed(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleCareMed duplicate returned %d", rr.Code)
	}

	// Test POST /api/care/meal
	mealBody := []byte(`{"label": "Lunch: Salmon & Rice"}`)
	req = httptest.NewRequest("POST", "/api/care/meal", bytes.NewReader(mealBody))
	rr = httptest.NewRecorder()
	app.handleCareMeal(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleCareMeal returned %d: %s", rr.Code, rr.Body.String())
	}

	// Test POST /api/care/sleep
	now := time.Now()
	sleepBody, _ := json.Marshal(map[string]any{
		"bed":  now.Add(-8 * time.Hour).Format(time.RFC3339),
		"wake": now.Format(time.RFC3339),
	})
	req = httptest.NewRequest("POST", "/api/care/sleep", bytes.NewReader(sleepBody))
	rr = httptest.NewRecorder()
	app.handleCareSleep(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleCareSleep returned %d: %s", rr.Code, rr.Body.String())
	}

	// Verify persistence in Care(today)
	todayCare, err := app.store.Care(day(time.Now()))
	if err != nil {
		t.Fatalf("failed to read care: %v", err)
	}
	if len(todayCare.Meds) != 1 || todayCare.Meds[0].Name != "Morning meds" {
		t.Fatalf("expected 1 med, got %v", todayCare.Meds)
	}
	if todayCare.WaterML != 500 {
		t.Fatalf("expected 500 ml, got %d", todayCare.WaterML)
	}
	if len(todayCare.Meals) != 1 || todayCare.Meals[0].Label != "Lunch: Salmon & Rice" {
		t.Fatalf("expected 1 meal, got %v", todayCare.Meals)
	}
	if todayCare.Sleep == nil || todayCare.Sleep.Hours != 8.0 {
		t.Fatalf("expected 8.0 hours sleep, got %v", todayCare.Sleep)
	}
}

func TestSessionTracking(t *testing.T) {
	app, tmpDir := setupTestApp(t)
	defer os.RemoveAll(tmpDir)

	// Start project session
	startBody := []byte(`{"project": "SWARM OS ISO", "kind": "project"}`)
	req := httptest.NewRequest("POST", "/api/sessions/start", bytes.NewReader(startBody))
	rr := httptest.NewRecorder()
	app.handleSessionStart(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleSessionStart returned %d: %s", rr.Code, rr.Body.String())
	}

	var startRes struct {
		OK      bool `json:"ok"`
		Summary struct {
			Active []struct {
				ID      string `json:"id"`
				Project string `json:"project"`
			} `json:"Active"`
		} `json:"summary"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &startRes); err != nil {
		t.Fatalf("unmarshal start res: %v", err)
	}
	if len(startRes.Summary.Active) == 0 {
		t.Fatalf("expected active session in summary, got %+v", startRes)
	}
	sessID := startRes.Summary.Active[0].ID

	// Stop session
	stopBody := []byte(`{"id": "` + sessID + `"}`)
	req = httptest.NewRequest("POST", "/api/sessions/stop", bytes.NewReader(stopBody))
	rr = httptest.NewRecorder()
	app.handleSessionStop(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleSessionStop returned %d: %s", rr.Code, rr.Body.String())
	}

	// Verify session summary via handleSessions
	req = httptest.NewRequest("GET", "/api/sessions", nil)
	rr = httptest.NewRecorder()
	app.handleSessions(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("handleSessions returned %d", rr.Code)
	}
}

func TestNewsBlocklist(t *testing.T) {
	cfg := defaultConfig()
	items := []NewsItem{
		{Title: "Arch Linux packages Linux kernel 6.12", Source: "Arch", Tag: "arch"},
		{Title: "Election debate updates from the president", Source: "News", Tag: "news"},
		{Title: "Steam Deck Proton experimental fixes released", Source: "Steam", Tag: "gaming"},
		{Title: "Senate votes on military budget in congress", Source: "Politics", Tag: "news"},
		{Title: "CachyOS drops October ISO update with BORE scheduler", Source: "CachyOS", Tag: "distro"},
	}

	var filtered []NewsItem
	for _, it := range items {
		hay := strings.ToLower(it.Title + " " + it.Summary)
		blocked := false
		for _, b := range cfg.NewsBlock {
			if strings.Contains(hay, b) {
				blocked = true
				break
			}
		}
		if !blocked {
			filtered = append(filtered, it)
		}
	}

	if len(filtered) != 3 {
		t.Fatalf("expected 3 non-political items, got %d", len(filtered))
	}
	if filtered[0].Title != "Arch Linux packages Linux kernel 6.12" ||
		filtered[1].Title != "Steam Deck Proton experimental fixes released" ||
		filtered[2].Title != "CachyOS drops October ISO update with BORE scheduler" {
		t.Fatalf("unexpected items remaining: %+v", filtered)
	}
}

func TestHeadlineGeneration(t *testing.T) {
	app, tmpDir := setupTestApp(t)
	defer os.RemoveAll(tmpDir)

	mockBrief := map[string]any{
		"nudges": []Nudge{{Text: "Drink some water — you're 400 mL behind pace."}},
		"git": []RepoStatus{
			{Path: "/mnt/swarmbuild", Dirty: 2, Untracked: 3},
		},
		"drives": []DriveUsage{
			{Mount: "/mnt/swarmbuild", Mounted: true, UsedPct: 29},
		},
	}

	now := time.Date(2026, 10, 7, 10, 0, 0, 0, time.Local) // 10 AM morning
	headline := app.headline(mockBrief, now)

	if !strings.Contains(headline, "Morning.") {
		t.Errorf("expected headline to start with Morning., got: %s", headline)
	}
	if !strings.Contains(headline, "Drink some water") {
		t.Errorf("expected headline to mention water nudge, got: %s", headline)
	}
	if !strings.Contains(headline, "swarmbuild has 5 uncommitted changes.") {
		t.Errorf("expected headline to mention git changes, got: %s", headline)
	}
}

func TestChatEndpoint(t *testing.T) {
	app, tmpDir := setupTestApp(t)
	defer os.RemoveAll(tmpDir)

	// Bad request (empty message)
	req := httptest.NewRequest("POST", "/api/chat", bytes.NewReader([]byte(`{"message": ""}`)))
	rr := httptest.NewRecorder()
	app.handleChat(rr, req)
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for empty message, got %d", rr.Code)
	}

	// Valid chat request (will use fallback when API keys are not provided in test)
	chatBody := []byte(`{"message": "Hello Lucille, I need a drink of water"}`)
	req = httptest.NewRequest("POST", "/api/chat", bytes.NewReader(chatBody))
	rr = httptest.NewRecorder()
	app.handleChat(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var chatRes ChatResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &chatRes); err != nil {
		t.Fatalf("failed to decode chat response: %v", err)
	}
	if !chatRes.OK {
		t.Fatalf("chat response ok is false")
	}
	if chatRes.Text == "" {
		t.Fatalf("chat response text is empty")
	}
	if !strings.Contains(chatRes.Text, "water") {
		t.Logf("got reply: %s", chatRes.Text)
	}
}
