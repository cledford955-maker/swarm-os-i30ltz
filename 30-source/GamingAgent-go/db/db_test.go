package db

import (
	"path/filepath"
	"testing"

	"swarm-os/gaming-agent/models"
)

func TestOpenAndMigrate(t *testing.T) {
	tempDir := t.TempDir()
	dbPath := filepath.Join(tempDir, "test_gaming.db")
	t.Setenv("GAMING_DB_PATH", dbPath)

	database, err := Open()
	if err != nil {
		t.Fatalf("Open() failed: %v", err)
	}
	defer database.Close()

	if err := database.Ping(); err != nil {
		t.Fatalf("database.Ping() failed: %v", err)
	}

	// Verify tables exist
	var count int
	err = database.QueryRow("SELECT COUNT(*) FROM favorites").Scan(&count)
	if err != nil {
		t.Errorf("favorites table check failed: %v", err)
	}
	err = database.QueryRow("SELECT COUNT(*) FROM chat_history").Scan(&count)
	if err != nil {
		t.Errorf("chat_history table check failed: %v", err)
	}
	err = database.QueryRow("SELECT COUNT(*) FROM price_alerts").Scan(&count)
	if err != nil {
		t.Errorf("price_alerts table check failed: %v", err)
	}
}

func TestFavorites_UpsertAndGet(t *testing.T) {
	tempDir := t.TempDir()
	dbPath := filepath.Join(tempDir, "test_fav.db")
	t.Setenv("GAMING_DB_PATH", dbPath)

	database, err := Open()
	if err != nil {
		t.Fatalf("Open() failed: %v", err)
	}
	defer database.Close()

	favs, err := GetFavorites(database)
	if err != nil {
		t.Fatalf("GetFavorites() on empty db failed: %v", err)
	}
	if len(favs) != 0 {
		t.Errorf("expected 0 favorites, got %d", len(favs))
	}

	entry1 := models.FavoriteEntry{
		AppId:      440,
		IsFavorite: true,
		IsPinned:   false,
	}
	if err := UpsertFavorite(database, entry1); err != nil {
		t.Fatalf("UpsertFavorite() failed: %v", err)
	}

	favs, err = GetFavorites(database)
	if err != nil {
		t.Fatalf("GetFavorites() failed: %v", err)
	}
	if len(favs) != 1 || !favs[440].IsFavorite || favs[440].IsPinned {
		t.Errorf("unexpected favorites state: %+v", favs[440])
	}

	// Update existing favorite
	entry1Updated := models.FavoriteEntry{
		AppId:      440,
		IsFavorite: true,
		IsPinned:   true,
	}
	if err := UpsertFavorite(database, entry1Updated); err != nil {
		t.Fatalf("UpsertFavorite() update failed: %v", err)
	}

	favs, err = GetFavorites(database)
	if err != nil {
		t.Fatalf("GetFavorites() failed: %v", err)
	}
	if len(favs) != 1 || !favs[440].IsFavorite || !favs[440].IsPinned {
		t.Errorf("expected pinned favorite, got %+v", favs[440])
	}
}

func TestChatHistory_InsertAndGet(t *testing.T) {
	tempDir := t.TempDir()
	dbPath := filepath.Join(tempDir, "test_chat.db")
	t.Setenv("GAMING_DB_PATH", dbPath)

	database, err := Open()
	if err != nil {
		t.Fatalf("Open() failed: %v", err)
	}
	defer database.Close()

	sessionID := "test-session-123"

	// Empty history
	history, err := GetChatHistory(database, sessionID, 10)
	if err != nil {
		t.Fatalf("GetChatHistory() on empty db failed: %v", err)
	}
	if len(history) != 0 {
		t.Errorf("expected empty history, got %d entries", len(history))
	}

	// Insert turns
	if err := InsertChatMessage(database, sessionID, "user", "Hello Lucille"); err != nil {
		t.Fatalf("InsertChatMessage user failed: %v", err)
	}
	if err := InsertChatMessage(database, sessionID, "assistant", "Greetings, gamer."); err != nil {
		t.Fatalf("InsertChatMessage assistant failed: %v", err)
	}

	history, err = GetChatHistory(database, sessionID, 10)
	if err != nil {
		t.Fatalf("GetChatHistory() failed: %v", err)
	}
	if len(history) != 2 {
		t.Fatalf("expected 2 history entries, got %d", len(history))
	}
	// Chronological order verification
	if history[0].Role != "user" || history[0].Content != "Hello Lucille" {
		t.Errorf("entry 0 mismatch: %+v", history[0])
	}
	if history[1].Role != "assistant" || history[1].Content != "Greetings, gamer." {
		t.Errorf("entry 1 mismatch: %+v", history[1])
	}

	// Test default limit when <= 0
	historyDefault, err := GetChatHistory(database, sessionID, 0)
	if err != nil {
		t.Fatalf("GetChatHistory(limit=0) failed: %v", err)
	}
	if len(historyDefault) != 2 {
		t.Errorf("expected 2 history entries with default limit, got %d", len(historyDefault))
	}
}

func TestBoolToInt(t *testing.T) {
	if boolToInt(true) != 1 {
		t.Errorf("boolToInt(true) != 1")
	}
	if boolToInt(false) != 0 {
		t.Errorf("boolToInt(false) != 0")
	}
}
