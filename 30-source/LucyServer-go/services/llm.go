package services

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"

	"swarm-os/lucy-server/models"
)

// StreamChat routes a chat request to the correct LLM provider based on modelId,
// then streams response chunks over the returned channel. The caller must drain
// the channel; a non-nil error is sent as the last (and possibly only) value.
//
// Provider routing (mirrors ILlmProvider.CanHandle logic from .NET):
//   - "nvidia/*"       → NVIDIA NIM  (NVIDIA_API_KEY)
//   - "groq/*"         → Groq        (GROQ_API_KEY)
//   - "ollama/*"       → Ollama local (http://localhost:11434)
//   - anything else    → OpenRouter  (OPENROUTER_API_KEY)
func StreamChat(ctx context.Context, req models.LucyRequest) (<-chan string, <-chan error) {
	chunks := make(chan string, 64)
	errCh := make(chan error, 1)

	go func() {
		defer close(chunks)
		defer close(errCh)
		err := streamToChannel(ctx, req, chunks)
		if err != nil {
			errCh <- err
		}
	}()

	return chunks, errCh
}

func streamToChannel(ctx context.Context, req models.LucyRequest, out chan<- string) error {
	modelId := req.ModelId
	if modelId == "" {
		modelId = "nvidia/llama-3.3-nemotron-super-49b-v1"
	}

	var (
		baseURL    string
		apiKey     string
		actualModel = modelId
	)

	switch {
	case strings.HasPrefix(modelId, "nvidia/"):
		baseURL = "https://integrate.api.nvidia.com/v1"
		apiKey = os.Getenv("NVIDIA_API_KEY")
	case strings.HasPrefix(modelId, "groq/"):
		baseURL = "https://api.groq.com/openai/v1"
		apiKey = os.Getenv("GROQ_API_KEY")
		actualModel = strings.TrimPrefix(modelId, "groq/")
	case strings.HasPrefix(modelId, "ollama/"):
		baseURL = "http://localhost:11434/v1"
		apiKey = "ollama"
		actualModel = strings.TrimPrefix(modelId, "ollama/")
	default:
		// OpenRouter — handles "openai/*", "anthropic/*", "or/*", bare slash-models, etc.
		baseURL = "https://openrouter.ai/api/v1"
		apiKey = os.Getenv("OPENROUTER_API_KEY")
	}

	return streamOpenAICompat(ctx, baseURL, apiKey, actualModel, req.Messages, out)
}

// streamOpenAICompat handles OpenAI-compatible SSE streaming endpoints.
// All providers (NVIDIA NIM, Groq, OpenRouter, Ollama) speak this protocol.
func streamOpenAICompat(ctx context.Context, baseURL, apiKey, modelId string, messages []models.ChatMessage, out chan<- string) error {
	type msg struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	}
	type reqBody struct {
		Model    string `json:"model"`
		Messages []msg  `json:"messages"`
		Stream   bool   `json:"stream"`
	}

	msgs := make([]msg, len(messages))
	for i, m := range messages {
		msgs[i] = msg{Role: m.Role, Content: m.Content}
	}

	body, err := json.Marshal(reqBody{Model: modelId, Messages: msgs, Stream: true})
	if err != nil {
		return err
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)
	if strings.Contains(baseURL, "openrouter") {
		httpReq.Header.Set("HTTP-Referer", "https://lucy.local")
		httpReq.Header.Set("X-Title", "Lucy")
	}

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("LLM provider %s returned %d: %s", baseURL, resp.StatusCode, string(b))
	}

	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		line := scanner.Text()
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		data := strings.TrimPrefix(line, "data: ")
		if data == "[DONE]" {
			break
		}

		var parsed struct {
			Choices []struct {
				Delta struct {
					Content string `json:"content"`
				} `json:"delta"`
			} `json:"choices"`
		}
		if err := json.Unmarshal([]byte(data), &parsed); err != nil {
			continue
		}
		if len(parsed.Choices) > 0 {
			if chunk := parsed.Choices[0].Delta.Content; chunk != "" {
				out <- chunk
			}
		}
	}
	return scanner.Err()
}
