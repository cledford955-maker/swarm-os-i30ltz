// GET /api/price-alerts — returns the recent rows in the `price_alerts` table.
package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"swarm-os/gaming-agent/services"
)

type PriceAlertHandler struct {
	db *sql.DB
}

func NewPriceAlertHandler(database *sql.DB) *PriceAlertHandler {
	return &PriceAlertHandler{db: database}
}

func (h *PriceAlertHandler) Recent(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}
	alerts, err := services.RecentAlerts(h.db, limit)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if alerts == nil {
		alerts = []services.PriceAlert{} // never return null — Flutter expects []
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"alerts": alerts, "count": len(alerts)})
}
