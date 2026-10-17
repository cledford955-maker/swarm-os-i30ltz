package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	dbpkg "swarm-os/gaming-agent/db"
)

func TestHealthHandler_NilDB(t *testing.T) {
	h := NewHealthHandler(nil)
	req := httptest.NewRequest("GET", "/health", nil)
	rec := httptest.NewRecorder()

	h.Health(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var body map[string]any
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("expected status 'ok', got %v", body["status"])
	}
}

func TestHealthHandler_HealthyDB(t *testing.T) {
	tempDir := t.TempDir()
	dbPath := filepath.Join(tempDir, "health_test.db")
	t.Setenv("GAMING_DB_PATH", dbPath)

	database, err := dbpkg.Open()
	if err != nil {
		t.Fatalf("db open failed: %v", err)
	}
	defer database.Close()

	h := NewHealthHandler(database)
	req := httptest.NewRequest("GET", "/health", nil)
	rec := httptest.NewRecorder()

	h.Health(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}

	var body map[string]any
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if body["status"] != "ok" || body["database"] != "connected" {
		t.Errorf("unexpected body: %+v", body)
	}
}

func TestHealthHandler_DegradedDB(t *testing.T) {
	tempDir := t.TempDir()
	dbPath := filepath.Join(tempDir, "health_test_closed.db")
	t.Setenv("GAMING_DB_PATH", dbPath)

	database, err := dbpkg.Open()
	if err != nil {
		t.Fatalf("db open failed: %v", err)
	}
	// Close DB to simulate failure
	database.Close()

	h := NewHealthHandler(database)
	req := httptest.NewRequest("GET", "/health", nil)
	rec := httptest.NewRecorder()

	h.Health(rec, req)

	if rec.Code != http.StatusServiceUnavailable {
		t.Errorf("expected status 503, got %d", rec.Code)
	}

	var body map[string]any
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if body["status"] != "degraded" {
		t.Errorf("expected status 'degraded', got %v", body["status"])
	}
}

func TestHealth_LegacyPackageFunction(t *testing.T) {
	req := httptest.NewRequest("GET", "/health", nil)
	rec := httptest.NewRecorder()

	Health(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", rec.Code)
	}
}
