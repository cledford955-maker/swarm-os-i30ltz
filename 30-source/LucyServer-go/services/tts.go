package services

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
)

// Voice name conventions understood by GenerateTTSBase64:
//
//   "openrouter/<voice>"  → OpenRouter TTS (OPENROUTER_API_KEY), maps to
//                           openai/tts-1-hd with that voice name.
//                           Dr. Boltz default: "openrouter/onyx"
//   "eleven/<id>"         → ElevenLabs by explicit voice ID
//   <32 hex chars>        → Fish Audio reference ID
//   "boltz"               → resolves to BOLTZ_TTS_VOICE env (default: openrouter/onyx)
//   "lucille"             → resolves to LUCILLE_TTS_VOICE env (default: eleven/EXAVITQu4vr4xnSDxMaL — Bella)
//   anything else         → ElevenLabs, voice resolved via resolveElevenVoiceID
//
// Fallback chain: primary provider → edge-tts CLI (offline).
// OS agents and the Android companion both call /api/tts/generate; they get
// the same voice by passing the same voiceName — persona voices are reusable
// across the entire stack.

// Persona voice defaults. Override via env on the running system.
const (
	defaultBoltzVoice   = "openrouter/onyx"                  // deep authoritative male
	defaultLucilleVoice = "eleven/EXAVITQu4vr4xnSDxMaL"     // ElevenLabs Bella — sultry female
)

func resolvePersonaVoice(voiceName string) string {
	switch voiceName {
	case "boltz", "dr_boltz", "boltz_voice":
		if v := os.Getenv("BOLTZ_TTS_VOICE"); v != "" {
			return v
		}
		return defaultBoltzVoice
	case "lucille", "lucille_voice":
		if v := os.Getenv("LUCILLE_TTS_VOICE"); v != "" {
			return v
		}
		return defaultLucilleVoice
	}
	return voiceName
}

// GenerateTTSBase64 returns base64-encoded MP3 audio for the given text.
func GenerateTTSBase64(text, voiceName string) (string, error) {
	cleanText := strings.ReplaceAll(text, "*", "")
	if cleanText == "" {
		return "", fmt.Errorf("empty text")
	}

	voiceName = resolvePersonaVoice(voiceName)

	// OpenRouter TTS → openai/tts-1-hd (uses OPENROUTER_API_KEY)
	if strings.HasPrefix(voiceName, "openrouter/") {
		voice := strings.TrimPrefix(voiceName, "openrouter/")
		if key := os.Getenv("OPENROUTER_API_KEY"); key != "" {
			if b64, err := openRouterTTS(cleanText, voice, key); err == nil {
				return b64, nil
			}
		}
		// If OpenRouter unavailable, fall through to ElevenLabs / edge-tts
	}

	// Fish Audio (32-char reference ID)
	if len(voiceName) == 32 {
		if key := os.Getenv("FISH_AUDIO_KEY"); key != "" {
			if b64, err := fishAudioTTS(cleanText, voiceName, key); err == nil {
				return b64, nil
			}
		}
	}

	// ElevenLabs
	if key := os.Getenv("ELEVEN_API_KEY"); key != "" {
		vid := resolveElevenVoiceID(voiceName)
		if b64, err := elevenLabsTTS(cleanText, vid, key); err == nil {
			return b64, nil
		}
	}

	// FOSS fallback: edge-tts CLI
	return edgeTTSCLI(cleanText, voiceName)
}

// openRouterTTS calls OpenRouter's OpenAI-compatible audio/speech endpoint.
// Model is always openai/tts-1-hd (best quality at a few cents per 1k chars).
// Supported voices: alloy, echo, fable, onyx, nova, shimmer.
// onyx = deep authoritative male (Dr. Boltz)
// nova / shimmer = expressive female (Lucille alternative if ElevenLabs is down)
func openRouterTTS(text, voice, apiKey string) (string, error) {
	body, _ := json.Marshal(map[string]any{
		"model":           "openai/tts-1-hd",
		"input":           text,
		"voice":           voice,
		"response_format": "mp3",
	})
	req, err := http.NewRequest(http.MethodPost, "https://openrouter.ai/api/v1/audio/speech", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("HTTP-Referer", "https://swarm-os.local")
	req.Header.Set("X-Title", "SWARM OS")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("OpenRouter TTS %d: %s", resp.StatusCode, string(b))
	}
	audio, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(audio), nil
}

func resolveElevenVoiceID(voiceName string) string {
	if strings.HasPrefix(voiceName, "eleven/") {
		return strings.TrimPrefix(voiceName, "eleven/")
	}
	// If it looks like a bare ElevenLabs voice ID (alphanumeric, 20 chars), use it.
	if len(voiceName) == 20 && !strings.Contains(voiceName, "-") {
		return voiceName
	}
	if id := os.Getenv("ELEVEN_VOICE_ID"); id != "" {
		return id
	}
	return "21m00Tcm4TlvDq8ikWAM" // Rachel — ElevenLabs default
}

func elevenLabsTTS(text, voiceID, apiKey string) (string, error) {
	body, _ := json.Marshal(map[string]any{
		"text":     text,
		"model_id": "eleven_multilingual_v2",
		"voice_settings": map[string]any{
			"stability":        0.5,
			"similarity_boost": 0.75,
		},
	})
	url := fmt.Sprintf("https://api.elevenlabs.io/v1/text-to-speech/%s", voiceID)
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("xi-api-key", apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("ElevenLabs %d: %s", resp.StatusCode, string(b))
	}
	audio, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(audio), nil
}

func fishAudioTTS(text, referenceID, apiKey string) (string, error) {
	body, _ := json.Marshal(map[string]string{
		"text":         text,
		"reference_id": referenceID,
		"format":       "mp3",
	})
	req, err := http.NewRequest(http.MethodPost, "https://api.fish.audio/v1/tts", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("Fish Audio %d: %s", resp.StatusCode, string(b))
	}
	audio, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(audio), nil
}

// edgeTTSCLI shells out to the `edge-tts` Python CLI if installed.
// Install with: pip install edge-tts
func edgeTTSCLI(text, voice string) (string, error) {
	if voice == "" || !strings.Contains(voice, "Neural") {
		voice = "en-GB-SoniaNeural"
	}
	result := RunCommand(
		fmt.Sprintf(`edge-tts --voice %q --text %q --write-media /tmp/swarm-tts-out.mp3 && base64 /tmp/swarm-tts-out.mp3`,
			voice, text),
		"",
	)
	if result.ExitCode != 0 {
		return "", fmt.Errorf("edge-tts failed: %s", result.StandardError)
	}
	return strings.TrimSpace(result.StandardOutput), nil
}
