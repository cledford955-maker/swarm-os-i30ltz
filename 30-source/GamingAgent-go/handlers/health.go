package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
)

type HealthHandler struct {
	db *sql.DB
}

func NewHealthHandler(db *sql.DB) *HealthHandler {
	return &HealthHandler{db: db}
}

func (h *HealthHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.Health(w, r)
}

func (h *HealthHandler) Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if h.db != nil {
		if err := h.db.PingContext(r.Context()); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			json.NewEncoder(w).Encode(map[string]any{
				"status": "degraded",
				"error":  fmt.Sprintf("database ping failed: %v", err),
			})
			return
		}
	}
	json.NewEncoder(w).Encode(map[string]any{
		"status":   "ok",
		"database": "connected",
	})
}

// Health provides backward compatibility for callers that do not inject a DB.
func Health(w http.ResponseWriter, r *http.Request) {
	NewHealthHandler(nil).Health(w, r)
}
