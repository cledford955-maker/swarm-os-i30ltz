package models

import (
	"encoding/json"
	"testing"
)

func TestSteamGame_JSON(t *testing.T) {
	raw := `{"appid":730,"name":"Counter-Strike 2","playtime_forever":120,"img_icon_url":"icon.jpg"}`
	var game SteamGame
	if err := json.Unmarshal([]byte(raw), &game); err != nil {
		t.Fatalf("unmarshal SteamGame failed: %v", err)
	}
	if game.AppId != 730 || game.Name != "Counter-Strike 2" || game.PlaytimeMinutes != 120 {
		t.Errorf("unexpected game fields: %+v", game)
	}

	b, err := json.Marshal(game)
	if err != nil {
		t.Fatalf("marshal SteamGame failed: %v", err)
	}
	var gameRoundtrip SteamGame
	if err := json.Unmarshal(b, &gameRoundtrip); err != nil {
		t.Fatalf("roundtrip unmarshal failed: %v", err)
	}
	if gameRoundtrip.AppId != game.AppId || gameRoundtrip.Name != game.Name {
		t.Errorf("roundtrip mismatch: got %+v, want %+v", gameRoundtrip, game)
	}
}

func TestGfnGame_JSON(t *testing.T) {
	raw := `{"id":1001,"title":"Cyberpunk 2077","steamUrl":"https://store.steampowered.com/app/1091500","status":"AVAILABLE","genres":["RPG","Open World"],"publisher":"CD PROJEKT RED","store":"Steam"}`
	var gfn GfnGame
	if err := json.Unmarshal([]byte(raw), &gfn); err != nil {
		t.Fatalf("unmarshal GfnGame failed: %v", err)
	}
	if gfn.Id != 1001 || gfn.Title != "Cyberpunk 2077" || len(gfn.Genres) != 2 {
		t.Errorf("unexpected gfn fields: %+v", gfn)
	}
}

func TestEnrichedGame_JSON(t *testing.T) {
	e := EnrichedGame{
		AppId:           1091500,
		Name:            "Cyberpunk 2077",
		OnGfn:           true,
		GfnId:           "1001",
		Genres:          []string{"RPG", "Sci-Fi"},
		PlaytimeMinutes: 450,
		IsFavorite:      true,
		IsPinned:        true,
	}
	b, err := json.Marshal(e)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}

	var parsed EnrichedGame
	if err := json.Unmarshal(b, &parsed); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if parsed.AppId != e.AppId || !parsed.OnGfn || !parsed.IsFavorite || !parsed.IsPinned {
		t.Errorf("field mismatch: %+v", parsed)
	}
}

func TestLucilleEvalResult_JSON(t *testing.T) {
	eval := LucilleEvalResult{
		GenreFilters:      []string{"Action", "RPG"},
		PinGames:          []string{"Cyberpunk 2077"},
		SortBy:            "playtime",
		FavoriteGames:     []string{"Half-Life 2"},
		Summary:           "You enjoy immersive story games.",
		SystemSuggestions: []string{"Launch on GFN", "Check deals"},
		TopGames: []TopGame{
			{Name: "Cyberpunk 2077", Hours: 45.5, OnGfn: true},
		},
	}
	b, err := json.Marshal(eval)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}

	var parsed LucilleEvalResult
	if err := json.Unmarshal(b, &parsed); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if parsed.SortBy != "playtime" || len(parsed.TopGames) != 1 || parsed.TopGames[0].Hours != 45.5 {
		t.Errorf("eval result mismatch: %+v", parsed)
	}
}

func TestLucilleChatModels_JSON(t *testing.T) {
	req := LucilleChatRequest{
		SessionId: "session-abc",
		Messages: []ChatMessage{
			{Role: "user", Content: "What game should I play tonight?"},
		},
	}
	b, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("marshal request failed: %v", err)
	}

	var parsedReq LucilleChatRequest
	if err := json.Unmarshal(b, &parsedReq); err != nil {
		t.Fatalf("unmarshal request failed: %v", err)
	}
	if parsedReq.SessionId != req.SessionId || len(parsedReq.Messages) != 1 {
		t.Errorf("request mismatch: %+v", parsedReq)
	}

	resp := LucilleChatResponse{
		Reply:     "Play Cyberpunk 2077 on GFN!",
		SessionId: "session-abc",
	}
	bResp, _ := json.Marshal(resp)
	var parsedResp LucilleChatResponse
	if err := json.Unmarshal(bResp, &parsedResp); err != nil {
		t.Fatalf("unmarshal response failed: %v", err)
	}
	if parsedResp.Reply != resp.Reply {
		t.Errorf("response reply mismatch: %q", parsedResp.Reply)
	}
}

func TestMediaModels_JSON(t *testing.T) {
	ctl := MediaControlRequest{Action: "play-pause", Player: "spotify"}
	bCtl, _ := json.Marshal(ctl)
	var parsedCtl MediaControlRequest
	if err := json.Unmarshal(bCtl, &parsedCtl); err != nil || parsedCtl.Action != "play-pause" {
		t.Errorf("media control mismatch: %+v", parsedCtl)
	}

	vol := MediaVolumeRequest{Volume: 0.75, Player: "vlc"}
	bVol, _ := json.Marshal(vol)
	var parsedVol MediaVolumeRequest
	if err := json.Unmarshal(bVol, &parsedVol); err != nil || parsedVol.Volume != 0.75 {
		t.Errorf("media volume mismatch: %+v", parsedVol)
	}
}
