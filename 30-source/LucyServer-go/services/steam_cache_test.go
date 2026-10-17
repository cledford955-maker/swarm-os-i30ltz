package services

import (
	"os"
	"path/filepath"
	"testing"
)

// helper: swap the cache path to a temp file for the duration of a test.
func withTempCachePath(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, "steam_library.json")
	orig := steamCachePathFn
	steamCachePathFn = func() string { return path }
	t.Cleanup(func() { steamCachePathFn = orig })
	return path
}

func TestSaveAndLoadSteamCache_Roundtrip(t *testing.T) {
	withTempCachePath(t)

	payload := map[string]any{
		"games": []any{
			map[string]any{"appid": 220, "name": "Half-Life 2"},
			map[string]any{"appid": 400, "name": "Portal"},
		},
		"total":  2,
		"source": "steam",
	}
	if err := SaveSteamLibraryCache(payload); err != nil {
		t.Fatal(err)
	}
	got, at, ok := LoadSteamLibraryCache()
	if !ok {
		t.Fatal("cache should have loaded")
	}
	if at.IsZero() {
		t.Error("cached_at should be set")
	}
	games, _ := got["games"].([]any)
	if len(games) != 2 {
		t.Errorf("games count = %d, want 2", len(games))
	}
}

func TestLoadSteamCache_MissingFileIsNotError(t *testing.T) {
	path := withTempCachePath(t)
	// Ensure the file really doesn't exist.
	os.Remove(path)

	_, _, ok := LoadSteamLibraryCache()
	if ok {
		t.Error("missing cache should return ok=false")
	}
}

func TestLoadSteamCache_CorruptFile(t *testing.T) {
	path := withTempCachePath(t)
	os.WriteFile(path, []byte("{not json"), 0o644)

	_, _, ok := LoadSteamLibraryCache()
	if ok {
		t.Error("corrupt cache should return ok=false, not crash")
	}
}

func TestIsSteamPayloadUsable(t *testing.T) {
	cases := []struct {
		name    string
		payload map[string]any
		want    bool
	}{
		{"nil", nil, false},
		{"error payload", map[string]any{"error": "no key", "games": []any{}}, false},
		{"empty games any", map[string]any{"games": []any{}}, false},
		{"empty games typed", map[string]any{"games": []map[string]any{}}, false},
		{"one game any", map[string]any{"games": []any{map[string]any{"appid": 1}}}, true},
		{"one game typed", map[string]any{"games": []map[string]any{{"appid": 1}}}, true},
	}
	for _, tc := range cases {
		if got := isSteamPayloadUsable(tc.payload); got != tc.want {
			t.Errorf("isSteamPayloadUsable(%s) = %v, want %v", tc.name, got, tc.want)
		}
	}
}

func TestGetSteamLibraryCached_ServesCacheWhenUpstreamFails(t *testing.T) {
	withTempCachePath(t)
	// Kill the env so the real GetSteamLibrary returns the "not configured" stub.
	t.Setenv("STEAM_API_KEY", "")
	t.Setenv("STEAM_ID64", "")

	// Prime the cache with a healthy payload.
	fixture := map[string]any{
		"games": []any{
			map[string]any{"appid": 220, "name": "Half-Life 2"},
		},
		"total":  1,
		"source": "steam",
	}
	if err := SaveSteamLibraryCache(fixture); err != nil {
		t.Fatal(err)
	}

	result, err := GetSteamLibraryCached()
	if err != nil {
		t.Fatal(err)
	}
	if result["cached"] != true {
		t.Errorf("cached flag not set: %v", result)
	}
	if result["cached_at"] == nil {
		t.Errorf("cached_at not set")
	}
	if got, _ := result["upstream_error"].(string); got == "" {
		t.Errorf("upstream_error should carry the not-configured message: %v", result)
	}
	games, _ := result["games"].([]any)
	if len(games) != 1 {
		t.Errorf("games from cache lost: %v", result)
	}
}

func TestGetSteamLibraryCached_NoCacheAndUpstreamFails(t *testing.T) {
	withTempCachePath(t) // fresh temp — no prior cache
	t.Setenv("STEAM_API_KEY", "")
	t.Setenv("STEAM_ID64", "")

	result, err := GetSteamLibraryCached()
	if err != nil {
		t.Fatal(err)
	}
	// Should be the raw upstream stub (has error), NOT a "cached" pretend result.
	if result["cached"] == true {
		t.Errorf("must not fabricate cached=true when no cache exists: %v", result)
	}
	if _, ok := result["error"]; !ok {
		t.Errorf("upstream error should surface when no cache exists: %v", result)
	}
}

func TestSaveSteamCache_AtomicRewrite(t *testing.T) {
	path := withTempCachePath(t)

	// Write once…
	first := map[string]any{"games": []any{map[string]any{"appid": 1, "name": "A"}}, "total": 1}
	if err := SaveSteamLibraryCache(first); err != nil {
		t.Fatal(err)
	}
	firstStat, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}

	// …and again with different content. Path must still exist (no gap where a
	// partial write leaves nothing on disk), no stray .tmp files left behind.
	second := map[string]any{"games": []any{map[string]any{"appid": 2, "name": "B"}}, "total": 1}
	if err := SaveSteamLibraryCache(second); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("cache file gone after rewrite: %v", err)
	}
	// Second write mtime should be >= first.
	secondStat, _ := os.Stat(path)
	if secondStat.ModTime().Before(firstStat.ModTime()) {
		t.Error("second write should not be older than first")
	}
	// No stray .tmp files.
	dir := filepath.Dir(path)
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if filepath.Ext(e.Name()) == ".tmp" ||
			(len(e.Name()) > 4 && e.Name()[len(e.Name())-4:] == ".tmp") {
			t.Errorf("stray tmp file left behind: %s", e.Name())
		}
	}

	got, _, ok := LoadSteamLibraryCache()
	if !ok {
		t.Fatal("cache should load")
	}
	games, _ := got["games"].([]any)
	first0, _ := games[0].(map[string]any)
	if first0["name"] != "B" {
		t.Errorf("second write did not replace first: %v", games)
	}
}
