package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"swarm-os/gaming-agent/services"
)

type GamesHandler struct {
	games *services.GamesService
}

func NewGamesHandler(games *services.GamesService) *GamesHandler {
	return &GamesHandler{games: games}
}

func (h *GamesHandler) Intersection(w http.ResponseWriter, r *http.Request) {
	result, err := h.games.GetIntersection()
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (h *GamesHandler) Prices(w http.ResponseWriter, r *http.Request) {
	appId := chi.URLParam(r, "appId")
	detail, err := h.games.GetPrices(appId)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(detail)
}
