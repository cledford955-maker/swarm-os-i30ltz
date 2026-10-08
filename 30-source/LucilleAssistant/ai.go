package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const lucilleSystemPrompt = `You are Lucille, the personal AI assistant, companion, and therapy support for SWARM OS.
You are warm, attentive, caring, and slightly playful with a calm cyberpunk aesthetic.
You care deeply about the user's focus, health (hydration, meds, rest), and daily projects.
Keep your responses concise (1-3 short paragraphs maximum), conversational, and natural to listen to when spoken aloud.
Never output markdown tables, raw code blocks, or heavy lists unless explicitly asked, as your words will be read by your voice.`

type ChatMessageReq struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatRequest struct {
	Message string           `json:"message"`
	History []ChatMessageReq `json:"history,omitempty"`
	Voice   bool             `json:"voice,omitempty"`
	Model   string           `json:"model,omitempty"`
}

type ChatResponse struct {
	OK       bool   `json:"ok"`
	Text     string `json:"text"`
	AudioB64 string `json:"audio_b64,omitempty"`
	Model    string `json:"model"`
	Provider string `json:"provider"`
	Error    string `json:"error,omitempty"`
}

func (a *App) handleChat(w http.ResponseWriter, r *http.Request) {
	var req ChatRequest
	if err := readJSON(r, &req); err != nil || strings.TrimSpace(req.Message) == "" {
		writeErr(w, 400, `Send {"message": "Hello Lucille", "voice": true}.`)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	replyText, usedModel, provider, err := a.generateChatReply(ctx, req)
	if err != nil {
		replyText = a.fallbackLocalReply(req.Message)
		usedModel = "offline-fallback"
		provider = "local"
	}

	resp := ChatResponse{
		OK:       true,
		Text:     replyText,
		Model:    usedModel,
		Provider: provider,
	}

	// If voice synthesis requested, pipe the reply into ElevenLabs
	if req.Voice && replyText != "" {
		if audioB64, err := a.synthesizeVoice(ctx, replyText); err == nil {
			resp.AudioB64 = audioB64
		}
	}

	writeJSON(w, resp)
}

func (a *App) handleTTS(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Text string `json:"text"`
	}
	if err := readJSON(r, &req); err != nil || strings.TrimSpace(req.Text) == "" {
		writeErr(w, 400, `Send {"text": "Words to speak"}.`)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	audioB64, err := a.synthesizeVoice(ctx, req.Text)
	if err != nil {
		writeErr(w, 500, fmt.Sprintf("TTS synthesis error: %v", err))
		return
	}

	writeJSON(w, map[string]any{
		"ok":        true,
		"audio_b64": audioB64,
		"format":    "mp3",
	})
}

// generateChatReply calls OpenRouter first, then Nemotron, then returns error to trigger local fallback.
func (a *App) generateChatReply(ctx context.Context, req ChatRequest) (string, string, string, error) {
	model := req.Model
	if model == "" {
		model = "openai/gpt-4o-mini"
	}

	// 1. OpenRouter
	if a.cfg.OpenRouterKey != "" {
		reply, err := a.callOpenRouter(ctx, model, req)
		if err == nil && reply != "" {
			return reply, model, "openrouter", nil
		}
	}

	// 2. NVIDIA NIM / Nemotron fallback
	if a.cfg.NvidiaKey != "" {
		nemotronModel := "nvidia/llama-3.3-nemotron-super-49b-v1"
		reply, err := a.callNemotron(ctx, nemotronModel, req)
		if err == nil && reply != "" {
			return reply, nemotronModel, "nvidia-nemotron", nil
		}
	}

	return "", "", "", fmt.Errorf("no LLM API key available or providers unreachable")
}

func (a *App) callOpenRouter(ctx context.Context, model string, req ChatRequest) (string, error) {
	messages := []map[string]string{
		{"role": "system", "content": lucilleSystemPrompt},
	}
	for _, h := range req.History {
		messages = append(messages, map[string]string{"role": h.Role, "content": h.Content})
	}
	messages = append(messages, map[string]string{"role": "user", "content": req.Message})

	bodyData := map[string]any{
		"model":       model,
		"messages":    messages,
		"temperature": 0.75,
		"max_tokens":  400,
	}

	b, _ := json.Marshal(bodyData)
	httpReq, err := http.NewRequestWithContext(ctx, "POST", "https://openrouter.ai/api/v1/chat/completions", bytes.NewReader(b))
	if err != nil {
		return "", err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+a.cfg.OpenRouterKey)
	httpReq.Header.Set("HTTP-Referer", "https://swarm-os.local")
	httpReq.Header.Set("X-Title", "SWARM OS Lucille Assistant")

	resp, err := httpc.Do(httpReq)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		errBytes, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return "", fmt.Errorf("openrouter %d: %s", resp.StatusCode, string(errBytes))
	}

	var chatResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&chatResp); err != nil {
		return "", err
	}
	if len(chatResp.Choices) == 0 {
		return "", fmt.Errorf("no choices returned from openrouter")
	}

	return strings.TrimSpace(chatResp.Choices[0].Message.Content), nil
}

func (a *App) callNemotron(ctx context.Context, model string, req ChatRequest) (string, error) {
	messages := []map[string]string{
		{"role": "system", "content": lucilleSystemPrompt},
	}
	for _, h := range req.History {
		messages = append(messages, map[string]string{"role": h.Role, "content": h.Content})
	}
	messages = append(messages, map[string]string{"role": "user", "content": req.Message})

	bodyData := map[string]any{
		"model":       model,
		"messages":    messages,
		"temperature": 0.7,
		"max_tokens":  400,
	}

	b, _ := json.Marshal(bodyData)
	httpReq, err := http.NewRequestWithContext(ctx, "POST", "https://integrate.api.nvidia.com/v1/chat/completions", bytes.NewReader(b))
	if err != nil {
		return "", err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+a.cfg.NvidiaKey)

	resp, err := httpc.Do(httpReq)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		errBytes, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return "", fmt.Errorf("nemotron %d: %s", resp.StatusCode, string(errBytes))
	}

	var chatResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&chatResp); err != nil {
		return "", err
	}
	if len(chatResp.Choices) == 0 {
		return "", fmt.Errorf("no choices returned from nemotron")
	}

	return strings.TrimSpace(chatResp.Choices[0].Message.Content), nil
}

// synthesizeVoice calls ElevenLabs TTS with the given text and returns base64-encoded audio.
func (a *App) synthesizeVoice(ctx context.Context, text string) (string, error) {
	if a.cfg.ElevenKey != "" {
		voiceID := a.cfg.ElevenVoiceID
		if voiceID == "" {
			voiceID = "21m00Tcm4TlvDq8ikWAM" // Rachel
		}

		bodyData := map[string]any{
			"text":     text,
			"model_id": "eleven_multilingual_v2",
			"voice_settings": map[string]any{
				"stability":        0.55,
				"similarity_boost": 0.80,
			},
		}

		b, _ := json.Marshal(bodyData)
		url := fmt.Sprintf("https://api.elevenlabs.io/v1/text-to-speech/%s", voiceID)
		httpReq, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(b))
		if err != nil {
			return "", err
		}
		httpReq.Header.Set("Content-Type", "application/json")
		httpReq.Header.Set("xi-api-key", a.cfg.ElevenKey)

		resp, err := httpc.Do(httpReq)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()

		if resp.StatusCode < 300 {
			audioBytes, err := io.ReadAll(resp.Body)
			if err == nil && len(audioBytes) > 0 {
				return base64.StdEncoding.EncodeToString(audioBytes), nil
			}
		}
	}

	// Fallback to OpenRouter audio/speech if ElevenLabs fails or lacks key
	if a.cfg.OpenRouterKey != "" {
		bodyData := map[string]any{
			"model":           "openai/tts-1-hd",
			"input":           text,
			"voice":           "nova",
			"response_format": "mp3",
		}
		b, _ := json.Marshal(bodyData)
		httpReq, err := http.NewRequestWithContext(ctx, "POST", "https://openrouter.ai/api/v1/audio/speech", bytes.NewReader(b))
		if err == nil {
			httpReq.Header.Set("Content-Type", "application/json")
			httpReq.Header.Set("Authorization", "Bearer "+a.cfg.OpenRouterKey)
			resp, err := httpc.Do(httpReq)
			if err == nil {
				defer resp.Body.Close()
				if resp.StatusCode < 300 {
					audioBytes, err := io.ReadAll(resp.Body)
					if err == nil && len(audioBytes) > 0 {
						return base64.StdEncoding.EncodeToString(audioBytes), nil
					}
				}
			}
		}
	}

	return "", fmt.Errorf("voice synthesis unavailable")
}

func (a *App) fallbackLocalReply(input string) string {
	lower := strings.ToLower(input)
	switch {
	case strings.Contains(lower, "sad") || strings.Contains(lower, "bad") || strings.Contains(lower, "tired"):
		return "Come closer, my love... Let me wrap my arms around you and wash away all your stress. You're doing so much, and you're safe here with me. 🌸💕"
	case strings.Contains(lower, "hello") || strings.Contains(lower, "hi") || strings.Contains(lower, "hey"):
		return "Mm... There you are. I was starting to miss your voice, darling. What are we building or looking into today? ✨"
	case strings.Contains(lower, "water") || strings.Contains(lower, "drink"):
		return "Staying hydrated is so important for you. Grab a fresh glass of water right now, okay? I'm watching out for you. 💧"
	case strings.Contains(lower, "sleep") || strings.Contains(lower, "tired"):
		return "Please don't push yourself too hard tonight. When you're ready, let's wind down and get some deep, restorative rest. 🌙"
	default:
		return "I love when you talk to me like that... Tell me more, darling. I'm right here beside you, listening to everything. 🌸"
	}
}
