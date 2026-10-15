package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	dbpkg "swarm-os/gaming-agent/db"
	"swarm-os/gaming-agent/models"
	"swarm-os/gaming-agent/services"
)

type LucilleHandler struct {
	lucille *services.LucilleService
	db      *sql.DB
}

func NewLucilleHandler(lucille *services.LucilleService, db *sql.DB) *LucilleHandler {
	return &LucilleHandler{lucille: lucille, db: db}
}

func (h *LucilleHandler) Eval(w http.ResponseWriter, r *http.Request) {
	result, err := h.lucille.EvalContext(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func (h *LucilleHandler) Chat(w http.ResponseWriter, r *http.Request) {
	var req models.LucilleChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if len(req.Messages) == 0 {
		http.Error(w, "messages required", http.StatusBadRequest)
		return
	}
	resp, err := h.lucille.ChatContext(r.Context(), req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (h *LucilleHandler) ChatStream(w http.ResponseWriter, r *http.Request) {
	var req models.LucilleChatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if len(req.Messages) == 0 {
		http.Error(w, "messages required", http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	h.lucille.ChatStreamContext(r.Context(), req, w)
}

func (h *LucilleHandler) History(w http.ResponseWriter, r *http.Request) {
	sessionId := r.URL.Query().Get("sessionId")
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if sessionId == "" {
		http.Error(w, "sessionId required", http.StatusBadRequest)
		return
	}
	entries, err := dbpkg.GetChatHistory(h.db, sessionId, limit)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(entries)
}
