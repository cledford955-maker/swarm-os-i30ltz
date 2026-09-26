package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"swarm-os/gaming-agent/db"
	"swarm-os/gaming-agent/models"
)

type GamesService struct {
	gfn      *GfnService
	steam    *SteamService
	db       *sql.DB
	cs       *http.Client
	steamSpy *SteamSpyService
}

func NewGamesService(gfn *GfnService, steam *SteamService, database *sql.DB) *GamesService {
	return &GamesService{
		gfn:      gfn,
		steam:    steam,
		db:       database,
		cs:       &http.Client{Timeout: 10 * time.Second},
		steamSpy: NewSteamSpyService(),
	}
}

func (s *GamesService) GetIntersection() ([]models.EnrichedGame, error) {
	steamGames, err := s.steam.GetLibrary()
	if err != nil {
		return nil, fmt.Errorf("steam library: %w", err)
	}
	gfnGames, err := s.gfn.GetCatalog()
	if err != nil {
		return nil, fmt.Errorf("gfn catalog: %w", err)
	}
	favs, err := db.GetFavorites(s.db)
	if err != nil {
		return nil, fmt.Errorf("favorites: %w", err)
	}

	// Build GFN lookup by steamAppId + normalised title + normalised bare title (no subtitle)
	bySteamId := make(map[int]*models.GfnGame, len(gfnGames))
	byTitle := make(map[string]*models.GfnGame, len(gfnGames))
	byBareTitle := make(map[string]*models.GfnGame, len(gfnGames))
	for i := range gfnGames {
		g := &gfnGames[i]
		if g.SteamAppId != 0 {
			bySteamId[g.SteamAppId] = g
		}
		norm := NormalizeTitle(g.Title)
		byTitle[norm] = g
		bare := NormalizeTitle(subtitleRe.ReplaceAllString(g.Title, ""))
		if bare != norm {
			byBareTitle[bare] = g
		}
	}

	result := make([]models.EnrichedGame, 0, len(steamGames))
	for _, sg := range steamGames {
		var gfn *models.GfnGame
		if g, ok := bySteamId[sg.AppId]; ok {
			gfn = g
		} else if g, ok := byTitle[NormalizeTitle(sg.Name)]; ok {
			gfn = g
		} else {
			// Subtitle-strip fallback: "Tainted Grail: The Fall of Avalon" → "Tainted Grail"
			bare := NormalizeTitle(subtitleRe.ReplaceAllString(sg.Name, ""))
			if g, ok := byTitle[bare]; ok {
				gfn = g
			} else if g, ok := byBareTitle[bare]; ok {
				gfn = g
			}
		}

		fav := favs[sg.AppId]

		eg := models.EnrichedGame{
			AppId:           sg.AppId,
			Name:            sg.Name,
			OnGfn:           gfn != nil,
			PlaytimeMinutes: sg.PlaytimeMinutes,
			HeaderImage:     fmt.Sprintf("https://cdn.akamai.steamstatic.com/steam/apps/%d/header.jpg", sg.AppId),
			CapsuleImage:    fmt.Sprintf("https://cdn.akamai.steamstatic.com/steam/apps/%d/capsule_616x353.jpg", sg.AppId),
			SteamUrl:        fmt.Sprintf("https://store.steampowered.com/app/%d/", sg.AppId),
			IsFavorite:      fav.IsFavorite,
			IsPinned:        fav.IsPinned,
			Genres:          []string{},
		}
		if gfn != nil {
			eg.GfnId = fmt.Sprintf("%d", gfn.Id)
			eg.GfnUrl = fmt.Sprintf("https://play.geforcenow.com/games?game-id=%d", gfn.Id)
			eg.Publisher = gfn.Publisher
			if gfn.Genres != nil {
				eg.Genres = gfn.Genres
			}
		}

		// SteamSpy enrichment — fill genre gaps for games that GFN either
		// doesn't know about or returned empty for. Best-effort with a 24h
		// cache; upstream failure never blocks intersection assembly.
		if len(eg.Genres) == 0 {
			if extra, ok := s.steamSpy.Enrich(sg.AppId); ok {
				if len(extra.Genres) > 0 {
					eg.Genres = extra.Genres
				}
				if eg.Publisher == "" {
					eg.Publisher = extra.Publisher
				}
			}
		}
		result = append(result, eg)
	}
	return result, nil
}

func (s *GamesService) GetGenres() ([]string, error) {
	games, err := s.gfn.GetCatalog()
	if err != nil {
		return nil, err
	}
	seen := make(map[string]bool)
	var genres []string
	for _, g := range games {
		for _, genre := range g.Genres {
			if genre != "" && !seen[genre] {
				seen[genre] = true
				genres = append(genres, genre)
			}
		}
	}
	return genres, nil
}

// cheapSharkUA satisfies CheapShark's User-Agent requirement (added on their
// end 2026; a bare Go-http-client UA now gets a 400 "Missing or generic
// User-Agent header detected" instead of real results, which GetPrices was
// previously swallowing as a misleading "no results for appId" error).
const cheapSharkUA = "SwarmOS-GamingAgent/1.0 (+https://github.com/i30ltz)"

func (s *GamesService) cheapSharkGet(url string) (*http.Response, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", cheapSharkUA)
	return s.cs.Do(req)
}

// GetTopDeals returns the current cheapest CheapShark deals, capped at n. Used
// by Lucille's context builder so she can reference specific prices when
// recommending games. Best-effort: any HTTP or decode error returns an empty
// slice, never blocks the chat pipeline.
type DealSummary struct {
	Title       string `json:"title"`
	SalePrice   string `json:"salePrice"`
	NormalPrice string `json:"normalPrice"`
	Savings     string `json:"savings"`
	SteamAppID  string `json:"steamAppID,omitempty"`
	DealID      string `json:"dealID"`
}

func (s *GamesService) GetTopDeals(n int) ([]DealSummary, error) {
	if n <= 0 {
		n = 8
	}
	// storeID=1 = Steam; upperPrice=15 mirrors LucyServer's default so deals
	// track the same catalog.
	url := fmt.Sprintf("https://www.cheapshark.com/api/1.0/deals?storeID=1&upperPrice=15&pageSize=%d&sortBy=Price", n)
	resp, err := s.cheapSharkGet(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var raw []DealSummary
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return nil, err
	}
	if len(raw) > n {
		raw = raw[:n]
	}
	return raw, nil
}

func (s *GamesService) GetPrices(appId string) (*models.CheapSharkGameDetail, error) {
	url := fmt.Sprintf("https://www.cheapshark.com/api/1.0/games?steamAppID=%s&limit=1", appId)
	resp, err := s.cheapSharkGet(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var games []struct {
		GameID string `json:"gameID"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&games); err != nil || len(games) == 0 {
		return nil, fmt.Errorf("cheapshark: no results for appId %s", appId)
	}

	detail, err := s.cheapSharkGet(fmt.Sprintf("https://www.cheapshark.com/api/1.0/games?id=%s", games[0].GameID))
	if err != nil {
		return nil, err
	}
	defer detail.Body.Close()

	var gd models.CheapSharkGameDetail
	if err := json.NewDecoder(detail.Body).Decode(&gd); err != nil {
		return nil, err
	}
	return &gd, nil
}
