package services

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"swarm-os/gaming-agent/models"
)

// gfnCatalogURL was previously "https://static.nvidiagrid.net/supported-public-game-content/Games.json",
// which NVIDIA has since removed (returns 403 AccessDenied). Verified 2026-09-20 that the live,
// unauthenticated catalog now lives under supported-public-game-list/locales/.
const gfnCatalogURL = "https://static.nvidiagrid.net/supported-public-game-list/locales/gfnpc-en-US.json"

var nonAlphanumRe = regexp.MustCompile(`[^a-z0-9]`)

// steamAppIdRe pulls the numeric Steam app id out of a GFN entry's steamUrl,
// e.g. "https://store.steampowered.com/app/1358020" -> 1358020. The feed no
// longer carries a separate steamAppId field.
var steamAppIdRe = regexp.MustCompile(`/app/(\d+)`)

// subtitleRe strips ": subtitle" or " - subtitle" so "Tainted Grail: The Fall of Avalon"
// can still match a GFN entry that only lists "Tainted Grail".
var subtitleRe = regexp.MustCompile(`\s*[:\-]\s*.+$`)

type GfnService struct {
	cache  *cached[[]models.GfnGame]
	client *http.Client
}

func NewGfnService() *GfnService {
	return &GfnService{
		cache:  newCache[[]models.GfnGame](12 * time.Hour),
		client: &http.Client{Timeout: 30 * time.Second},
	}
}

func (s *GfnService) GetCatalog() ([]models.GfnGame, error) {
	if games, ok := s.cache.get(); ok {
		return games, nil
	}
	games, err := s.fetchCatalog()
	if err != nil {
		// Return stale cache rather than failing hard
		if stale, ok := s.cache.getStale(); ok && len(stale) > 0 {
			return stale, nil
		}
		return nil, err
	}
	s.cache.set(games)
	return games, nil
}

func (s *GfnService) WarmCache() {
	games, err := s.GetCatalog()
	if err != nil {
		fmt.Printf("[GFN] warm cache error: %v\n", err)
		return
	}
	fmt.Printf("[GFN] catalog warmed: %d games\n", len(games))
}

func (s *GfnService) fetchCatalog() ([]models.GfnGame, error) {
	resp, err := s.client.Get(gfnCatalogURL)
	if err != nil {
		return nil, fmt.Errorf("gfn fetch: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("gfn catalog: HTTP %d", resp.StatusCode)
	}

	var games []models.GfnGame
	if err := json.NewDecoder(resp.Body).Decode(&games); err != nil {
		return nil, fmt.Errorf("gfn decode: %w", err)
	}
	for i := range games {
		if m := steamAppIdRe.FindStringSubmatch(games[i].SteamUrl); m != nil {
			fmt.Sscanf(m[1], "%d", &games[i].SteamAppId)
		}
	}
	return games, nil
}

func NormalizeTitle(s string) string {
	return nonAlphanumRe.ReplaceAllString(strings.ToLower(strings.TrimSpace(s)), "")
}
