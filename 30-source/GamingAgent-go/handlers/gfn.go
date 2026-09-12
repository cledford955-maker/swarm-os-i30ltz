package handlers

import (
	"encoding/json"
	"net/http"

	"swarm-os/gaming-agent/services"
)

type GfnHandler struct {
	gfn   *services.GfnService
	games *services.GamesService
}

func NewGfnHandler(gfn *services.GfnService, games *services.GamesService) *GfnHandler {
	return &GfnHandler{gfn: gfn, games: games}
}

func (h *GfnHandler) Catalog(w http.ResponseWriter, r *http.Request) {
	catalog, err := h.gfn.GetCatalog()
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(catalog)
}

func (h *GfnHandler) Genres(w http.ResponseWriter, r *http.Request) {
	genres, err := h.games.GetGenres()
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(genres)
}
