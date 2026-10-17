package services

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"swarm-os/gaming-agent/models"
)

type SteamService struct {
	client *http.Client
	cache  *cached[[]models.SteamGame]
}

func NewSteamService() *SteamService {
	return &SteamService{
		client: &http.Client{Timeout: 15 * time.Second},
		// Short TTL relative to GFN's 12h: playtime changes while the user
		// is actively playing, but every intersection/eval/chat call was
		// previously hitting Steam fresh with zero caching at all.
		cache: newCache[[]models.SteamGame](10 * time.Minute),
	}
}

func (s *SteamService) GetLibrary() ([]models.SteamGame, error) {
	if games, ok := s.cache.get(); ok {
		return games, nil
	}
	games, err := s.fetchLibrary()
	if err != nil {
		if stale, ok := s.cache.getStale(); ok && len(stale) > 0 {
			return stale, nil
		}
		return nil, err
	}
	s.cache.set(games)
	return games, nil
}

func (s *SteamService) fetchLibrary() ([]models.SteamGame, error) {
	key := os.Getenv("STEAM_API_KEY")
	id64 := os.Getenv("STEAM_ID64")
	if key == "" || id64 == "" {
		return nil, fmt.Errorf("STEAM_API_KEY or STEAM_ID64 not set")
	}

	url := fmt.Sprintf(
		"https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/"+
			"?key=%s&steamid=%s&include_appinfo=true&format=json",
		key, id64,
	)

	resp, err := s.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("steam fetch: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("steam API: HTTP %d", resp.StatusCode)
	}

	var sr models.SteamResponse
	if err := json.NewDecoder(resp.Body).Decode(&sr); err != nil {
		return nil, fmt.Errorf("steam decode: %w", err)
	}
	if sr.Response.Games == nil {
		return []models.SteamGame{}, nil
	}
	return sr.Response.Games, nil
}
