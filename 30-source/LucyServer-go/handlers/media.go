package handlers

import (
	"encoding/json"
	"net/http"

	"swarm-os/lucy-server/models"
	"swarm-os/lucy-server/services"
)

// ── TTS ──────────────────────────────────────────────────────────────────────

func TTSGenerate(w http.ResponseWriter, r *http.Request) {
	var req models.GenerateVoiceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	audio, err := services.GenerateTTSBase64(req.Text, req.VoiceName)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"audio": audio})
}

// ── Ollama local model management ────────────────────────────────────────────

func OllamaListModels(w http.ResponseWriter, r *http.Request) {
	models, _ := services.OllamaListModels()
	writeJSON(w, models)
}

func OllamaPullModel(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Model string `json:"model"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if err := services.OllamaStartPull(req.Model); err != nil {
		writeJSON(w, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, map[string]string{"status": "ok", "message": "Started pulling " + req.Model})
}

func OllamaGetPullStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.OllamaGetPullStatus())
}

// ── News & Games ─────────────────────────────────────────────────────────────

func GetNews(w http.ResponseWriter, r *http.Request) {
	items, _ := services.GetNews()
	writeJSON(w, items)
}

func GetDeals(w http.ResponseWriter, r *http.Request) {
	items, _ := services.GetDeals()
	writeJSON(w, items)
}

func GetNewsFeed(w http.ResponseWriter, r *http.Request) {
	items, _ := services.GetNewsFeed()
	writeJSON(w, items)
}

func GetDevNews(w http.ResponseWriter, r *http.Request) {
	items, _ := services.GetDevNews()
	writeJSON(w, items)
}

func GetSteamLibrary(w http.ResponseWriter, r *http.Request) {
	result, _ := services.GetSteamLibrary()
	writeJSON(w, result)
}

func GetGamePrices(w http.ResponseWriter, r *http.Request) {
	gameId := r.URL.Query().Get("gameId")
	result, _ := services.GetGamePrices(gameId)
	writeJSON(w, result)
}

func GetGameInfo(w http.ResponseWriter, r *http.Request) {
	gameId := r.URL.Query().Get("gameId")
	result, _ := services.GetGameInfo(gameId)
	writeJSON(w, result)
}

func GetGfnGames(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.GetGfnGames())
}

func OptimizeGfn(w http.ResponseWriter, r *http.Request) {
	var req models.GfnOptimizeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	writeJSON(w, services.OptimizeGfn(req.Game))
}

// ── RAG ──────────────────────────────────────────────────────────────────────

func RAGIngest(w http.ResponseWriter, r *http.Request) {
	var req models.RagIngestRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	if req.Source == "" {
		req.Source = "manual"
	}
	result, _ := services.RAGIngestText(req.Text, req.Source)
	writeJSON(w, result)
}

func RAGIngestFile(w http.ResponseWriter, r *http.Request) {
	var req models.RagFileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	result, _ := services.RAGIngestFile(req.FilePath)
	writeJSON(w, result)
}

func RAGListDocuments(w http.ResponseWriter, r *http.Request) {
	result, _ := services.RAGListDocuments()
	writeJSON(w, result)
}

func RAGDeleteDocument(w http.ResponseWriter, r *http.Request) {
	source := r.URL.Query().Get("source")
	result, _ := services.RAGDeleteDocument(source)
	writeJSON(w, result)
}

func RAGClearStore(w http.ResponseWriter, r *http.Request) {
	result, _ := services.RAGClearStore()
	writeJSON(w, result)
}
