package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"swarm-os/lucy-server/models"
)

const (
	embedModel  = "nomic-embed-text"
	chunkSize   = 512
	chunkOverlap = 64
)

var ragMu sync.Mutex

func ragStorePath() string {
	return filepath.Join(lucyStateDir(), "rag_store.json")
}

func ollamaBaseURL() string {
	if u := os.Getenv("OLLAMA_BASE_URL"); u != "" {
		return strings.TrimRight(u, "/")
	}
	return "http://127.0.0.1:11434"
}

// RAGIngestText chunks, embeds via Ollama, and appends to the vector store.
func RAGIngestText(text, source string) (map[string]any, error) {
	if strings.TrimSpace(text) == "" {
		return map[string]any{"success": false, "error": "no text provided"}, nil
	}
	chunks := chunkText(text, source)
	embedded, err := embedChunks(chunks)
	if err != nil || len(embedded) == 0 {
		return map[string]any{"success": false, "error": "embedding failed or no chunks"}, nil
	}
	added, err := appendToStore(embedded, source)
	if err != nil {
		return map[string]any{"success": false, "error": err.Error()}, nil
	}
	return map[string]any{"success": true, "source": source, "chunks_added": added}, nil
}

// RAGIngestFile reads a file and delegates to RAGIngestText.
func RAGIngestFile(filePath string) (map[string]any, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return map[string]any{"success": false, "error": err.Error()}, nil
	}
	return RAGIngestText(string(data), filepath.Base(filePath))
}

// RAGListDocuments returns a summary of sources in the vector store.
func RAGListDocuments() (map[string]any, error) {
	store, err := loadStore()
	if err != nil {
		return map[string]any{"total_chunks": 0, "documents": []any{}}, nil
	}
	counts := map[string]int{}
	for _, d := range store {
		counts[d.Source]++
	}
	docs := make([]map[string]any, 0, len(counts))
	for src, count := range counts {
		docs = append(docs, map[string]any{"source": src, "chunk_count": count})
	}
	return map[string]any{"total_chunks": len(store), "documents": docs}, nil
}

// RAGDeleteDocument removes all chunks from a given source.
func RAGDeleteDocument(source string) (map[string]any, error) {
	ragMu.Lock()
	defer ragMu.Unlock()
	store, _ := loadStoreNoLock()
	before := len(store)
	filtered := store[:0]
	for _, d := range store {
		if d.Source != source {
			filtered = append(filtered, d)
		}
	}
	if err := saveStore(filtered); err != nil {
		return map[string]any{"success": false, "error": err.Error()}, nil
	}
	return map[string]any{"success": true, "removed": before - len(filtered)}, nil
}

// RAGClearStore wipes all vectors.
func RAGClearStore() (map[string]any, error) {
	ragMu.Lock()
	defer ragMu.Unlock()
	if err := saveStore([]models.RagDocument{}); err != nil {
		return map[string]any{"success": false, "error": err.Error()}, nil
	}
	return map[string]any{"success": true, "message": "RAG store cleared"}, nil
}

// GetVectorContext embeds the prompt via Ollama and returns the top-3 matching
// chunks from the store. Returns empty string if Ollama is offline or store is empty
// (graceful degradation — orchestrator still works without RAG).
func GetVectorContext(prompt string) string {
	if strings.TrimSpace(prompt) == "" {
		return ""
	}

	queryVec, err := embedOne(prompt)
	if err != nil || len(queryVec) == 0 {
		return "" // Ollama offline — silently degrade
	}

	store, err := loadStore()
	if err != nil || len(store) == 0 {
		return ""
	}

	type scored struct {
		score float64
		text  string
	}
	var hits []scored
	for _, doc := range store {
		if len(doc.Embedding) == 0 {
			continue
		}
		sim := cosineSimilarity(queryVec, doc.Embedding)
		if sim >= 0.35 {
			hits = append(hits, scored{sim, doc.Text})
		}
	}
	if len(hits) == 0 {
		return ""
	}
	// Sort descending, take top 3
	for i := 0; i < len(hits)-1; i++ {
		for j := i + 1; j < len(hits); j++ {
			if hits[j].score > hits[i].score {
				hits[i], hits[j] = hits[j], hits[i]
			}
		}
	}
	if len(hits) > 3 {
		hits = hits[:3]
	}
	parts := make([]string, len(hits))
	for i, h := range hits {
		parts[i] = h.text
	}
	return "\n\n[RETRIEVED CONVERSATION MEMORY]:\n" + strings.Join(parts, "\n---\n")
}

// ── Chunking ─────────────────────────────────────────────────────────────────

func chunkText(text, source string) []models.RagDocument {
	paragraphs := strings.Split(text, "\n\n")
	var chunks []models.RagDocument
	var buf strings.Builder

	for _, para := range paragraphs {
		para = strings.TrimSpace(para)
		if para == "" {
			continue
		}
		if buf.Len()+len(para) > chunkSize && buf.Len() > 0 {
			chunks = append(chunks, models.RagDocument{Text: strings.TrimSpace(buf.String()), Source: source})
			tail := buf.String()
			buf.Reset()
			if len(tail) > chunkOverlap {
				buf.WriteString(tail[len(tail)-chunkOverlap:])
			} else {
				buf.WriteString(tail)
			}
		}
		buf.WriteString(para)
		buf.WriteString("\n\n")
	}
	if buf.Len() > 0 {
		chunks = append(chunks, models.RagDocument{Text: strings.TrimSpace(buf.String()), Source: source})
	}
	return chunks
}

// ── Embedding ────────────────────────────────────────────────────────────────

func embedOne(text string) ([]float32, error) {
	body, _ := json.Marshal(map[string]string{"model": embedModel, "input": text})
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Post(ollamaBaseURL()+"/api/embed", "application/json", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		Embeddings [][]float32 `json:"embeddings"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	if len(result.Embeddings) == 0 {
		return nil, fmt.Errorf("no embeddings returned")
	}
	return result.Embeddings[0], nil
}

func embedChunks(docs []models.RagDocument) ([]models.RagDocument, error) {
	client := &http.Client{Timeout: 30 * time.Second}
	var embedded []models.RagDocument
	for i := range docs {
		body, _ := json.Marshal(map[string]string{"model": embedModel, "input": docs[i].Text})
		resp, err := client.Post(ollamaBaseURL()+"/api/embed", "application/json", bytes.NewReader(body))
		if err != nil {
			continue
		}
		var result struct {
			Embeddings [][]float32 `json:"embeddings"`
		}
		json.NewDecoder(resp.Body).Decode(&result)
		resp.Body.Close()
		if len(result.Embeddings) > 0 {
			docs[i].Embedding = result.Embeddings[0]
			embedded = append(embedded, docs[i])
		}
	}
	return embedded, nil
}

// ── Store I/O ─────────────────────────────────────────────────────────────────

func loadStore() ([]models.RagDocument, error) {
	ragMu.Lock()
	defer ragMu.Unlock()
	return loadStoreNoLock()
}

func loadStoreNoLock() ([]models.RagDocument, error) {
	path := ragStorePath()
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return []models.RagDocument{}, nil
	}
	if err != nil {
		return nil, err
	}
	var store []models.RagDocument
	if err := json.Unmarshal(data, &store); err != nil {
		return nil, err
	}
	return store, nil
}

func appendToStore(newDocs []models.RagDocument, source string) (int, error) {
	ragMu.Lock()
	defer ragMu.Unlock()
	store, _ := loadStoreNoLock()
	// Re-ingest is idempotent: remove old chunks from same source first.
	filtered := store[:0]
	for _, d := range store {
		if d.Source != source {
			filtered = append(filtered, d)
		}
	}
	filtered = append(filtered, newDocs...)
	return len(newDocs), saveStore(filtered)
}

func saveStore(store []models.RagDocument) error {
	path := ragStorePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.Marshal(store)
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0o644)
}

// ── Math ──────────────────────────────────────────────────────────────────────

func cosineSimilarity(a, b []float32) float64 {
	var dot, magA, magB float64
	lim := len(a)
	if len(b) < lim {
		lim = len(b)
	}
	for i := 0; i < lim; i++ {
		ai, bi := float64(a[i]), float64(b[i])
		dot += ai * bi
		magA += ai * ai
		magB += bi * bi
	}
	if magA == 0 || magB == 0 {
		return 0
	}
	return dot / (math.Sqrt(magA) * math.Sqrt(magB))
}
