package services

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"golang.org/x/crypto/bcrypt"
)

var (
	settingsMu   sync.RWMutex
	currentVoice = "en-GB-SoniaNeural"
)

var allowedAPIKeys = map[string]bool{
	"OPENROUTER_API_KEY": true,
	"NVIDIA_API_KEY":     true,
	"GEMINI_API_KEY":     true,
	"CLAUDE_API_KEY":     true,
	"ANTHROPIC_API_KEY":  true,
	"GROQ_API_KEY":       true,
	"STEAM_API_KEY":      true,
	"STEAM_ID64":         true,
}

// GetVoice returns the current TTS voice name.
func GetVoice() string {
	settingsMu.RLock()
	defer settingsMu.RUnlock()
	return currentVoice
}

// SetVoice updates the in-memory TTS voice setting.
func SetVoice(voice string) {
	settingsMu.Lock()
	defer settingsMu.Unlock()
	currentVoice = voice
}

// SetLoginPassword hashes and saves a new login password.
func SetLoginPassword(password string) (bool, string) {
	if strings.TrimSpace(password) == "" {
		return false, "Password cannot be empty"
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return false, "Failed to hash password: " + err.Error()
	}
	path := filepath.Join(lucyStateDir(), "login_password.txt")
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return false, "Failed to create directory: " + err.Error()
	}
	if err := os.WriteFile(path, hash, 0o600); err != nil {
		return false, "Failed to save login password: " + err.Error()
	}
	return true, "Login password updated successfully"
}

// VerifyLoginPassword checks a candidate password against the stored bcrypt
// hash. Used by the lock screen's "forgotten cipher" recovery path (see
// cyber_stone_lock_screen.dart) — fails closed (false) if no login password
// has ever been set, rather than treating "no hash on disk" as a pass. That
// distinction matters: the lock screen used to have a hidden corner-tap
// gesture that unlocked unconditionally with no verification at all (a real
// auth bypass, found+fixed 2026-09-11); this endpoint must never reproduce
// that by accident on a fresh install where no password has been configured.
func VerifyLoginPassword(password string) (bool, string) {
	path := filepath.Join(lucyStateDir(), "login_password.txt")
	hash, err := os.ReadFile(path)
	if err != nil {
		return false, "No login password configured"
	}
	if bcrypt.CompareHashAndPassword(hash, []byte(password)) != nil {
		return false, "Incorrect password"
	}
	return true, "Password verified"
}

// SetSudoPassword validates that the password actually works with sudo. It
// does NOT persist it — the earlier version wrote it to sudo_password.txt in
// plaintext (0600), but nothing in this codebase or the .NET original it was
// ported from ever read that file back. A plaintext root-capable password
// sitting on disk with no consumer is pure liability with no offsetting
// benefit, especially given this server has already had one RCE-class bug
// (the loopback+origin gap fixed 2026-09-12) — removed 2026-09-19 rather than
// hardened, since there is nothing to harden it *for*. If a real consumer
// (e.g. first-boot auto-elevation) is built later, it should prompt fresh
// each time rather than resurrect long-lived plaintext storage.
func SetSudoPassword(password string) (bool, string) {
	if password == "" {
		return true, "Sudo password check cleared"
	}
	cmd := exec.Command("sudo", "-S", "-k", "true")
	cmd.Stdin = strings.NewReader(password + "\n")
	if err := cmd.Run(); err != nil {
		return false, "Invalid sudo password: authentication failed"
	}
	return true, "Sudo password verified"
}

// envFilePath returns the path to the environment file.
// Defaults to /etc/swarm_os.env (the baked env in the live system).
func envFilePath() string {
	if p := os.Getenv("LUCY_ENV_FILE"); p != "" {
		return p
	}
	return "/etc/swarm_os.env"
}

// SaveApiKeys updates allowed environment variables both in-process and in the env file.
func SaveApiKeys(keys map[string]string) (bool, string) {
	path := envFilePath()

	var lines []string
	if data, err := os.ReadFile(path); err == nil {
		sc := bufio.NewScanner(strings.NewReader(string(data)))
		for sc.Scan() {
			lines = append(lines, sc.Text())
		}
	}

	for k, v := range keys {
		if !allowedAPIKeys[k] {
			continue
		}
		os.Setenv(k, v)

		updated := false
		for i, line := range lines {
			if strings.HasPrefix(line, k+"=") {
				lines[i] = fmt.Sprintf("%s=%s", k, v)
				updated = true
				break
			}
		}
		if !updated {
			lines = append(lines, fmt.Sprintf("%s=%s", k, v))
		}
	}

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return false, err.Error()
	}
	content := strings.Join(lines, "\n")
	if len(lines) > 0 {
		content += "\n"
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return false, err.Error()
	}
	return true, "API keys saved and loaded successfully."
}
