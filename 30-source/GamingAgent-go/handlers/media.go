package handlers

import (
	"encoding/json"
	"net/http"

	"swarm-os/gaming-agent/models"
	"swarm-os/gaming-agent/services"
)

type MediaHandler struct {
	media *services.MediaService
}

func NewMediaHandler(media *services.MediaService) *MediaHandler {
	return &MediaHandler{media: media}
}

func (h *MediaHandler) Status(w http.ResponseWriter, r *http.Request) {
	player := r.URL.Query().Get("player")
	status, err := h.media.GetStatus(player)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

var validMediaActions = map[string]bool{
	"play": true, "pause": true, "play-pause": true,
	"next": true, "previous": true, "stop": true,
}

func (h *MediaHandler) Control(w http.ResponseWriter, r *http.Request) {
	var req models.MediaControlRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if !validMediaActions[req.Action] {
		http.Error(w, "action must be one of: play, pause, play-pause, next, previous, stop", http.StatusBadRequest)
		return
	}
	if err := h.media.Control(req.Action, req.Player); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"ok": true})
}

func (h *MediaHandler) Volume(w http.ResponseWriter, r *http.Request) {
	var req models.MediaVolumeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if req.Volume < 0 || req.Volume > 1 {
		http.Error(w, "volume must be between 0.0 and 1.0", http.StatusBadRequest)
		return
	}
	if err := h.media.SetVolume(req.Volume, req.Player); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"ok": true})
}
