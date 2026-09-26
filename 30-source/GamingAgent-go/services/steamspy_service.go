// SteamSpy enrichment — free public JSON API, no key.
//
// GFN's own catalog carries sparse genre data (SWARM_AI_FEATURES.md backlog).
// SteamSpy's `appdetails` endpoint has: genre, tags (voted), publisher,
// developer, review counts, owner buckets. We only use the fields that help
// the dashboard render — genre (single string like "Action, RPG") and tags
// (dict of "Roguelike": 342, ...) — mapped into the same []string genre
// list `EnrichedGame` already exposes.
//
// SteamSpy is a small community-run service. Their published etiquette is
// ~1 request/sec plus caching for at least 24h. We keep a 24h in-memory cache
// per appid, and only enrich games that came back from GFN empty-genred.
//
// STEAMSPY_BASE_URL env overrides the endpoint (used by tests).

package services

import (
	"encoding/json"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"time"
)

const steamSpyTTL = 24 * time.Hour

type steamSpyAppDetail struct {
	AppID     int              `json:"appid"`
	Name      string           `json:"name"`
	Developer string           `json:"developer"`
	Publisher string           `json:"publisher"`
	Genre     string           `json:"genre"` // "Action, RPG, Indie"
	Tags      map[string]int   `json:"tags,omitempty"`
	Positive  int              `json:"positive"`
	Negative  int              `json:"negative"`
	Owners    string           `json:"owners"`
}

// SteamSpyEnrichment is what we return to callers.
type SteamSpyEnrichment struct {
	Genres    []string
	Developer string
	Publisher string
	// Positive rating percentage (0-100, or -1 if no reviews).
	PositivePercent int
}

type steamSpyCacheEntry struct {
	value    SteamSpyEnrichment
	fetched  time.Time
}

type SteamSpyService struct {
	mu    sync.Mutex
	cache map[int]steamSpyCacheEntry
	http  *http.Client
}

func NewSteamSpyService() *SteamSpyService {
	return &SteamSpyService{
		cache: make(map[int]steamSpyCacheEntry),
		// Small timeout — a slow SteamSpy call should never block enrichment.
		http: &http.Client{Timeout: 4 * time.Second},
	}
}

func steamSpyBaseURL() string {
	if v := os.Getenv("STEAMSPY_BASE_URL"); v != "" {
		return v
	}
	return "https://steamspy.com/api.php"
}

// Enrich returns cached-or-fetched enrichment for the given Steam appid.
// Errors and empty responses are cached briefly (as empty) so we don't retry
// hard against a rate limit.
func (s *SteamSpyService) Enrich(appid int) (SteamSpyEnrichment, bool) {
	if appid <= 0 {
		return SteamSpyEnrichment{}, false
	}
	s.mu.Lock()
	if e, ok := s.cache[appid]; ok && time.Since(e.fetched) < steamSpyTTL {
		s.mu.Unlock()
		return e.value, e.value.Developer != "" || len(e.value.Genres) > 0
	}
	s.mu.Unlock()

	url := steamSpyBaseURL() + "?request=appdetails&appid=" + itoa(appid)
	resp, err := s.http.Get(url)
	if err != nil {
		s.cacheEmpty(appid)
		return SteamSpyEnrichment{}, false
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		s.cacheEmpty(appid)
		return SteamSpyEnrichment{}, false
	}

	var raw steamSpyAppDetail
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		s.cacheEmpty(appid)
		return SteamSpyEnrichment{}, false
	}

	out := SteamSpyEnrichment{
		Developer:       strings.TrimSpace(raw.Developer),
		Publisher:       strings.TrimSpace(raw.Publisher),
		PositivePercent: -1,
	}
	if raw.Positive+raw.Negative > 0 {
		out.PositivePercent = int(float64(raw.Positive) / float64(raw.Positive+raw.Negative) * 100)
	}
	out.Genres = mergeGenresAndTopTags(raw.Genre, raw.Tags, 6)

	s.mu.Lock()
	s.cache[appid] = steamSpyCacheEntry{value: out, fetched: time.Now()}
	s.mu.Unlock()

	return out, out.Developer != "" || len(out.Genres) > 0
}

// mergeGenresAndTopTags merges the "Action, RPG, Indie" genre string with the
// top-N most-voted tags, deduped and length-capped.
func mergeGenresAndTopTags(genre string, tags map[string]int, cap int) []string {
	seen := make(map[string]bool)
	out := make([]string, 0, cap)
	for _, g := range strings.Split(genre, ",") {
		g = strings.TrimSpace(g)
		if g == "" || seen[g] {
			continue
		}
		seen[g] = true
		out = append(out, g)
		if len(out) >= cap {
			return out
		}
	}
	// Sort tags by votes desc.
	type kv struct {
		k string
		v int
	}
	sorted := make([]kv, 0, len(tags))
	for k, v := range tags {
		sorted = append(sorted, kv{k, v})
	}
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].v > sorted[j].v })
	for _, t := range sorted {
		name := strings.TrimSpace(t.k)
		if name == "" || seen[name] {
			continue
		}
		seen[name] = true
		out = append(out, name)
		if len(out) >= cap {
			break
		}
	}
	return out
}

func (s *SteamSpyService) cacheEmpty(appid int) {
	s.mu.Lock()
	// A negative response caches for a shorter window (1 hour) — SteamSpy
	// occasionally returns partial JSON while it's rebuilding its index; we
	// want to try again before the full 24h.
	s.cache[appid] = steamSpyCacheEntry{value: SteamSpyEnrichment{}, fetched: time.Now().Add(-(steamSpyTTL - time.Hour))}
	s.mu.Unlock()
}

// itoa avoids strconv import bloat for a single conversion.
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
