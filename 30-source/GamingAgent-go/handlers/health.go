package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"os"
)

type HealthHandler struct {
	db *sql.DB
}

func NewHealthHandler(db *sql.DB) *HealthHandler {
	return &HealthHandler{db: db}
}

func (h *HealthHandler) Health(w http.ResponseWriter, r *http.Request) {
	type depStatus struct {
		OK     bool   `json:"ok"`
		Detail string `json:"detail,omitempty"`
	}
	type response struct {
		Status string               `json:"status"`
		DB     depStatus            `json:"db"`
		Keys   map[string]depStatus `json:"keys"`
	}

	dbOK := depStatus{OK: true}
	if err := h.db.PingContext(r.Context()); err != nil {
		dbOK = depStatus{OK: false, Detail: err.Error()}
	}

	keys := map[string]depStatus{
		"OPENROUTER_API_KEY": {OK: os.Getenv("OPENROUTER_API_KEY") != ""},
		"STEAM_API_KEY":      {OK: os.Getenv("STEAM_API_KEY") != ""},
	}

	overall := "ok"
	if !dbOK.OK {
		overall = "degraded"
	}
	for _, v := range keys {
		if !v.OK {
			overall = "degraded"
			break
		}
	}

	resp := response{Status: overall, DB: dbOK, Keys: keys}
	w.Header().Set("Content-Type", "application/json")
	if overall != "ok" {
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	json.NewEncoder(w).Encode(resp)
}

// Health is the legacy plain-function signature kept for backward compatibility
// with any code that wires it directly. Prefer NewHealthHandler when the DB is
// available.
func Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
