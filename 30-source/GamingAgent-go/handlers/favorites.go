package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	dbpkg "swarm-os/gaming-agent/db"
	"swarm-os/gaming-agent/models"
)

type FavoritesHandler struct {
	db *sql.DB
}

func NewFavoritesHandler(db *sql.DB) *FavoritesHandler {
	return &FavoritesHandler{db: db}
}

func (h *FavoritesHandler) Upsert(w http.ResponseWriter, r *http.Request) {
	var entry models.FavoriteEntry
	if err := json.NewDecoder(r.Body).Decode(&entry); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if err := dbpkg.UpsertFavorite(h.db, entry); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(entry)
}
