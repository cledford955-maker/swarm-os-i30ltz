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
}

func NewSteamService() *SteamService {
	return &SteamService{
		client: &http.Client{Timeout: 15 * time.Second},
	}
}

func (s *SteamService) GetLibrary() ([]models.SteamGame, error) {
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
