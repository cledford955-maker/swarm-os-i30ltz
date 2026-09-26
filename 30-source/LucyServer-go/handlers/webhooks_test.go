package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

func withTempStateDir(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	t.Setenv("LUCY_STATE_DIR", dir)
	return dir
}

// Build a chi router with the URL param wired so WebhookReceive sees {source}.
func webhookRouter(t *testing.T) http.Handler {
	t.Helper()
	r := chi.NewRouter()
	r.Post("/api/webhooks/{source}", WebhookReceive)
	r.Get("/api/webhooks", WebhookList)
	return r
}

func TestWebhookReceive_HappyPathJSON(t *testing.T) {
	stateDir := withTempStateDir(t)
	handler := webhookRouter(t)

	body := []byte(`{"event":"push","ref":"refs/heads/main"}`)
	req := httptest.NewRequest(http.MethodPost, "/api/webhooks/github", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var resp map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp["ok"] != true {
		t.Errorf("ok=%v, want true", resp["ok"])
	}
	if resp["structured"] != true {
		t.Errorf("structured=%v, want true", resp["structured"])
	}

	// Verify the JSONL line landed on disk.
	logPath := filepath.Join(stateDir, "webhooks", "github.jsonl")
	data, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("log file not written: %v", err)
	}
	if !strings.Contains(string(data), `"event":"push"`) {
		t.Errorf("payload not persisted: %q", data)
	}
	if !strings.Contains(string(data), `"source":"github"`) {
		t.Errorf("source not persisted: %q", data)
	}
}

func TestWebhookReceive_NonJSONFallsBackToRaw(t *testing.T) {
	stateDir := withTempStateDir(t)
	handler := webhookRouter(t)

	req := httptest.NewRequest(http.MethodPost, "/api/webhooks/twilio", bytes.NewReader([]byte("plain text alert")))
	req.Header.Set("Content-Type", "text/plain")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var resp map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatal(err)
	}
	if resp["structured"] != false {
		t.Errorf("structured=%v, want false for text/plain", resp["structured"])
	}

	logPath := filepath.Join(stateDir, "webhooks", "twilio.jsonl")
	data, _ := os.ReadFile(logPath)
	if !strings.Contains(string(data), `"payload_raw":"plain text alert"`) {
		t.Errorf("raw payload not persisted: %q", data)
	}
}

func TestWebhookReceive_RejectsInvalidSourceName(t *testing.T) {
	withTempStateDir(t)

	// Call WebhookReceive directly with a synthetic chi.RouteContext so we
	// exercise the source-name validator without depending on how the router
	// handles path-illegal characters.
	for _, bad := range []string{"", "a.b", "with spaces", "has/slash", "..", strings.Repeat("x", 65)} {
		req := httptest.NewRequest(http.MethodPost, "/api/webhooks/x", bytes.NewReader([]byte(`{}`)))
		req.Header.Set("Content-Type", "application/json")
		rctx := chi.NewRouteContext()
		rctx.URLParams.Add("source", bad)
		req = req.WithContext(context.WithValue(req.Context(), chi.RouteCtxKey, rctx))

		rec := httptest.NewRecorder()
		WebhookReceive(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("source %q: status=%d, want 400", bad, rec.Code)
		}
	}
}

func TestWebhookReceive_RejectsOversizedBody(t *testing.T) {
	withTempStateDir(t)
	handler := webhookRouter(t)

	big := bytes.Repeat([]byte("x"), maxWebhookBodyBytes+1024)
	req := httptest.NewRequest(http.MethodPost, "/api/webhooks/big", bytes.NewReader(big))
	req.Header.Set("Content-Type", "application/octet-stream")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	// http.MaxBytesReader triggers a 400/413-family failure via io.ReadAll.
	// Our handler translates that to 413.
	if rec.Code == http.StatusOK {
		t.Errorf("oversized body should have been rejected; got %d", rec.Code)
	}
}

func TestWebhookList_ReturnsSources(t *testing.T) {
	stateDir := withTempStateDir(t)
	handler := webhookRouter(t)

	// Seed two logs.
	dir := filepath.Join(stateDir, "webhooks")
	os.MkdirAll(dir, 0o755)
	os.WriteFile(filepath.Join(dir, "github.jsonl"), []byte("{}\n"), 0o644)
	os.WriteFile(filepath.Join(dir, "ifttt.jsonl"), []byte("{}\n"), 0o644)
	// Non-jsonl junk should be ignored.
	os.WriteFile(filepath.Join(dir, "readme.md"), []byte("ignore"), 0o644)

	req := httptest.NewRequest(http.MethodGet, "/api/webhooks", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	var resp struct {
		Sources []struct {
			Source string `json:"source"`
		} `json:"sources"`
	}
	json.Unmarshal(rec.Body.Bytes(), &resp)
	names := map[string]bool{}
	for _, s := range resp.Sources {
		names[s.Source] = true
	}
	if !names["github"] || !names["ifttt"] {
		t.Errorf("expected github+ifttt in %v", names)
	}
	if names["readme"] {
		t.Errorf("non-jsonl file leaked into list")
	}
}

func TestWebhookList_EmptyWhenNoDir(t *testing.T) {
	withTempStateDir(t)
	handler := webhookRouter(t)

	req := httptest.NewRequest(http.MethodGet, "/api/webhooks", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d", rec.Code)
	}
	var resp struct {
		Sources []any `json:"sources"`
	}
	json.Unmarshal(rec.Body.Bytes(), &resp)
	if len(resp.Sources) != 0 {
		t.Errorf("expected empty sources, got %v", resp.Sources)
	}
}
