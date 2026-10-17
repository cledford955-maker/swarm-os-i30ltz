// Package services — persistent cache for the user's Steam library.
//
// The bare GetSteamLibrary() only succeeds when STEAM_API_KEY and STEAM_ID64
// are set and Steam accepts the key. On 2026-09-20 the shipped API key was
// revoked and the dashboard went dark. A cache lets the last-known library
// keep rendering even while the key is dead — the user just sees a
// "cached from <date>" banner instead of an empty grid.
//
// Storage: one JSON file at BaseDir()/steam_library.json. No SQLite dep is
// added; the existing LucyServer state directory pattern is flat JSON.

package services

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"

	"swarm-os/lucy-server/storage"
)

// steamCache is the on-disk snapshot format. Kept small on purpose so the
// file rewrites atomically on every successful upstream call.
type steamCache struct {
	Payload  map[string]any `json:"payload"`
	CachedAt time.Time      `json:"cached_at"`
}

var (
	steamCacheMu sync.Mutex
	// Overridable in tests.
	steamCachePathFn = defaultSteamCachePath
)

func defaultSteamCachePath() string {
	return filepath.Join(storage.BaseDir(), "steam_library.json")
}

// SaveSteamLibraryCache writes `payload` to the on-disk cache file. Best-effort;
// swallows I/O errors after logging them (caller already has a valid result).
func SaveSteamLibraryCache(payload map[string]any) error {
	steamCacheMu.Lock()
	defer steamCacheMu.Unlock()

	entry := steamCache{Payload: payload, CachedAt: time.Now()}
	path := steamCachePathFn()
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	tmp, err := os.CreateTemp(dir, "steam_library.*.json.tmp")
	if err != nil {
		return err
	}
	name := tmp.Name()
	// Guard against a stale tmp on failure paths.
	defer func() {
		if _, err := os.Stat(name); err == nil {
			os.Remove(name)
		}
	}()

	if err := json.NewEncoder(tmp).Encode(entry); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(name, path)
}

// LoadSteamLibraryCache reads the cache file, if present. Returns (payload,
// cachedAt, true) on hit; (nil, zero, false) on miss / decode failure — never
// an error, because a missing cache is normal for a first boot.
func LoadSteamLibraryCache() (map[string]any, time.Time, bool) {
	steamCacheMu.Lock()
	defer steamCacheMu.Unlock()

	data, err := os.ReadFile(steamCachePathFn())
	if err != nil {
		return nil, time.Time{}, false
	}
	var entry steamCache
	if err := json.Unmarshal(data, &entry); err != nil {
		return nil, time.Time{}, false
	}
	if entry.Payload == nil {
		return nil, time.Time{}, false
	}
	return entry.Payload, entry.CachedAt, true
}

// GetSteamLibraryCached is a caching wrapper. It always calls the upstream;
// if the upstream returned a real games list, the cache is refreshed and the
// live payload is returned. If the upstream returned an error/empty list AND
// a cache file exists, the cached payload is served with `cached=true` and
// `cached_at` set so the UI can render a "stale" indicator instead of a
// dead grid.
func GetSteamLibraryCached() (map[string]any, error) {
	fresh, err := GetSteamLibrary()

	if isSteamPayloadUsable(fresh) && err == nil {
		if saveErr := SaveSteamLibraryCache(fresh); saveErr != nil {
			// Non-fatal: return the fresh data even if the write failed.
			fresh["cache_write_error"] = saveErr.Error()
		}
		return fresh, nil
	}

	cached, cachedAt, ok := LoadSteamLibraryCache()
	if !ok {
		// No cache to fall back on — return whatever the upstream gave us
		// (including its error) so the UI still sees "Steam API key or Steam
		// ID not configured" rather than a mystery empty response.
		return fresh, err
	}

	// Shallow-clone so we don't mutate the cached copy.
	out := make(map[string]any, len(cached)+3)
	for k, v := range cached {
		out[k] = v
	}
	out["cached"] = true
	out["cached_at"] = cachedAt.UTC().Format(time.RFC3339)
	if fresh != nil {
		if e, ok := fresh["error"].(string); ok && e != "" {
			out["upstream_error"] = e
		}
	}
	return out, nil
}

// isSteamPayloadUsable reports whether the payload from GetSteamLibrary looks
// like a real library rather than an error stub. A usable result has a
// non-empty "games" slice.
func isSteamPayloadUsable(payload map[string]any) bool {
	if payload == nil {
		return false
	}
	if _, hasError := payload["error"]; hasError {
		return false
	}
	games, ok := payload["games"].([]map[string]any)
	if ok && len(games) > 0 {
		return true
	}
	// Also accept the JSON-round-tripped []any form.
	if raw, ok := payload["games"].([]any); ok && len(raw) > 0 {
		return true
	}
	return false
}
