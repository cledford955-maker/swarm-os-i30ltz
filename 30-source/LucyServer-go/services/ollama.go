package services

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"
)

const ollamaBase = "http://127.0.0.1:11434"

// pullStatus is the global pull progress state, matching the .NET original's
// static field approach (one active pull at a time, status polled via GET).
type pullStatusT struct {
	Status     string `json:"status"`
	Model      string `json:"model"`
	Message    string `json:"message"`
	Percentage int    `json:"percentage"`
}

var (
	ollamaMu   sync.Mutex
	pullStatus = pullStatusT{Status: "idle", Model: "", Message: "", Percentage: 0}
)

// OllamaListModels queries Ollama's /api/tags and returns model names.
// Returns empty list (not error) when Ollama is offline — same as .NET original.
func OllamaListModels() ([]string, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(ollamaBase + "/api/tags")
	if err != nil {
		return []string{}, nil // Ollama offline — silently return empty
	}
	defer resp.Body.Close()

	var result struct {
		Models []struct {
			Name string `json:"name"`
		} `json:"models"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return []string{}, nil
	}
	names := make([]string, 0, len(result.Models))
	for _, m := range result.Models {
		names = append(names, m.Name)
	}
	return names, nil
}

// OllamaStartPull kicks off an async model pull. Returns error if one is already running.
func OllamaStartPull(modelName string) error {
	ollamaMu.Lock()
	if pullStatus.Status == "pulling" {
		ollamaMu.Unlock()
		return fmt.Errorf("another model is currently being pulled")
	}
	pullStatus = pullStatusT{Status: "pulling", Model: modelName, Message: "Initializing pull...", Percentage: 0}
	ollamaMu.Unlock()

	go doPull(modelName)
	return nil
}

// OllamaGetPullStatus returns the current pull status snapshot.
func OllamaGetPullStatus() pullStatusT {
	ollamaMu.Lock()
	defer ollamaMu.Unlock()
	return pullStatus
}

func doPull(modelName string) {
	client := &http.Client{Timeout: 60 * time.Minute}

	body, _ := json.Marshal(map[string]any{"name": modelName, "stream": true})
	req, err := http.NewRequest(http.MethodPost, ollamaBase+"/api/pull", bytes.NewReader(body))
	if err != nil {
		setStatus(pullStatusT{Status: "error", Model: modelName, Message: err.Error()})
		return
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		setStatus(pullStatusT{Status: "error", Model: modelName, Message: err.Error()})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		b, _ := io.ReadAll(resp.Body)
		setStatus(pullStatusT{Status: "error", Model: modelName, Message: fmt.Sprintf("HTTP %d: %s", resp.StatusCode, string(b))})
		return
	}

	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		var chunk struct {
			Status    string `json:"status"`
			Completed int64  `json:"completed"`
			Total     int64  `json:"total"`
		}
		if err := json.Unmarshal([]byte(line), &chunk); err != nil {
			continue
		}
		pct := 0
		if chunk.Total > 0 {
			pct = int(float64(chunk.Completed) / float64(chunk.Total) * 100)
		}
		msg := chunk.Status
		if pct > 0 {
			msg = fmt.Sprintf("%s (%d%%)", chunk.Status, pct)
		}
		ollamaMu.Lock()
		pullStatus.Message = msg
		pullStatus.Percentage = pct
		ollamaMu.Unlock()
	}

	setStatus(pullStatusT{Status: "success", Model: modelName, Message: "Model pulled successfully!", Percentage: 100})
}

func setStatus(s pullStatusT) {
	ollamaMu.Lock()
	pullStatus = s
	ollamaMu.Unlock()
}
