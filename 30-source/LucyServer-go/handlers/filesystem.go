package handlers

import (
	"encoding/json"
	"net/http"

	"swarm-os/lucy-server/models"
	"swarm-os/lucy-server/services"
)

type FilesystemHandler struct{}

func NewFilesystemHandler() *FilesystemHandler {
	return &FilesystemHandler{}
}

func (h *FilesystemHandler) ListDirectory(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path")
	if path == "" {
		path = "/"
	}
	items, err := services.ListDirectory(path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	writeJSON(w, items)
}

func (h *FilesystemHandler) AnalyzeDirectory(w http.ResponseWriter, r *http.Request) {
	var req models.FsAnalyzeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	result, err := services.AnalyzeDirectory(req.Path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	writeJSON(w, result)
}

func (h *FilesystemHandler) ListCodeFiles(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path")
	if path == "" {
		path = "/"
	}
	files, err := services.ListCodeFiles(path)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	writeJSON(w, files)
}

func (h *FilesystemHandler) ReadFile(w http.ResponseWriter, r *http.Request) {
	var req models.FileReadRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	content, err := services.ReadFile(req.Filename)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]string{"content": content})
}

func (h *FilesystemHandler) SaveFile(w http.ResponseWriter, r *http.Request) {
	var req models.FileSaveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	ok, err := services.SaveFile(req.Filename, req.Content)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]bool{"success": ok})
}

func (h *FilesystemHandler) ApplyUpgrade(w http.ResponseWriter, r *http.Request) {
	var req models.FileSaveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	ok, err := services.ApplyUpgrade(req.Filename, req.Content)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]bool{"success": ok})
}

func (h *FilesystemHandler) MountRecovery(w http.ResponseWriter, r *http.Request) {
	ok, err := services.MountRecovery()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]bool{"success": ok})
}
