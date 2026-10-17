package handlers

import (
	"encoding/json"
	"net/http"

	"swarm-os/lucy-server/services"
)

type CompanionHandler struct{}

func NewCompanionHandler() *CompanionHandler {
	return &CompanionHandler{}
}

func (h *CompanionHandler) WebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	services.HandleCompanionHeartbeat(conn)
}

func (h *CompanionHandler) Status(w http.ResponseWriter, r *http.Request) {
	hub := services.GetCompanionHub()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"connected": hub.Count(),
		"companions": hub.Connected(),
	})
}
