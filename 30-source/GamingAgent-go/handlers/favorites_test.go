package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	dbpkg "swarm-os/gaming-agent/db"
	"swarm-os/gaming-agent/models"
)

func TestFavoritesHandler_Upsert(t *testing.T) {
	tempDir := t.TempDir()
	dbPath := filepath.Join(tempDir, "fav_handler_test.db")
	t.Setenv("GAMING_DB_PATH", dbPath)

	database, err := dbpkg.Open()
	if err != nil {
		t.Fatalf("db open failed: %v", err)
	}
	defer database.Close()

	h := NewFavoritesHandler(database)

	// Valid upsert
	entry := models.FavoriteEntry{
		AppId:      570,
		IsFavorite: true,
		IsPinned:   true,
	}
	b, _ := json.Marshal(entry)
	req := httptest.NewRequest("POST", "/api/games/favorite", bytes.NewReader(b))
	rec := httptest.NewRecorder()

	h.Upsert(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rec.Code)
	}

	var res models.FavoriteEntry
	if err := json.NewDecoder(rec.Body).Decode(&res); err != nil {
		t.Fatalf("decode failed: %v", err)
	}
	if res.AppId != 570 || !res.IsFavorite || !res.IsPinned {
		t.Errorf("unexpected returned entry: %+v", res)
	}

	// Invalid body
	reqBad := httptest.NewRequest("POST", "/api/games/favorite", bytes.NewReader([]byte("{invalid-json")))
	recBad := httptest.NewRecorder()
	h.Upsert(recBad, reqBad)
	if recBad.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for bad body, got %d", recBad.Code)
	}
}
