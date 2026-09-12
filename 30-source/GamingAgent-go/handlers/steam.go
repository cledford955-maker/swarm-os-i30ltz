package handlers

import (
	"encoding/json"
	"net/http"

	"swarm-os/gaming-agent/services"
)

type SteamHandler struct {
	steam *services.SteamService
}

func NewSteamHandler(steam *services.SteamService) *SteamHandler {
	return &SteamHandler{steam: steam}
}

func (h *SteamHandler) Library(w http.ResponseWriter, r *http.Request) {
	games, err := h.steam.GetLibrary()
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(games)
}
