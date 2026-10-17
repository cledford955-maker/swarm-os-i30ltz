package services

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base32"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type totpStore struct {
	mu     sync.RWMutex
	Secret string `json:"secret,omitempty"` // base32, empty = disabled
}

var totpState = &totpStore{}

func init() { totpState.load() }

func (s *totpStore) filePath() string {
	dir := os.Getenv("LUCY_STATE_DIR")
	if dir == "" {
		dir = "/etc/swarm_os/lucy"
	}
	return filepath.Join(dir, "totp.json")
}

func (s *totpStore) load() {
	data, err := os.ReadFile(s.filePath())
	if err != nil {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	json.Unmarshal(data, s) //nolint:errcheck
}

func (s *totpStore) persist() error {
	s.mu.RLock()
	data, err := json.Marshal(s)
	s.mu.RUnlock()
	if err != nil {
		return err
	}
	return os.WriteFile(s.filePath(), data, 0600)
}

// TOTPSetup generates a fresh random secret and returns it alongside the
// otpauth:// URI. The secret is NOT saved yet — the caller must confirm a
// valid code via TOTPConfirm before the secret is persisted.
func TOTPSetup() (secret, uri string, err error) {
	raw := make([]byte, 20)
	if _, err = rand.Read(raw); err != nil {
		return
	}
	secret = base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(raw)
	// Standard otpauth URI — every TOTP app (Aegis, Google Auth, Bitwarden,
	// Raivo, Authy) recognises this format. Scan on all 3 phones at setup time
	// so any of them works to unlock.
	uri = fmt.Sprintf(
		"otpauth://totp/SWARM%%20OS:swarm?secret=%s&issuer=SWARM%%20OS&algorithm=SHA1&digits=6&period=30",
		secret,
	)
	return
}

// TOTPConfirm verifies code against secret (NOT the stored one) and, if
// valid, persists the secret. Call this after the user scanned the QR and
// entered their first code to confirm setup worked.
func TOTPConfirm(secret, code string) error {
	if !totpValidate(secret, code) {
		return fmt.Errorf("invalid code")
	}
	totpState.mu.Lock()
	totpState.Secret = secret
	totpState.mu.Unlock()
	return totpState.persist()
}

// TOTPEnabled reports whether a secret is enrolled.
func TOTPEnabled() bool {
	totpState.mu.RLock()
	defer totpState.mu.RUnlock()
	return totpState.Secret != ""
}

// TOTPCheck validates a 6-digit code against the persisted secret.
// Accepts current window ±1 (±30 s) to tolerate clock skew.
func TOTPCheck(code string) bool {
	totpState.mu.RLock()
	secret := totpState.Secret
	totpState.mu.RUnlock()
	if secret == "" {
		return false
	}
	return totpValidate(secret, code)
}

// TOTPDisable clears the stored secret.
func TOTPDisable() error {
	totpState.mu.Lock()
	totpState.Secret = ""
	totpState.mu.Unlock()
	return totpState.persist()
}

// totpValidate checks code against secret for the current ±1 windows.
func totpValidate(secret, code string) bool {
	step := time.Now().Unix() / 30
	for _, counter := range []int64{step - 1, step, step + 1} {
		if totpGenerate(secret, counter) == code {
			return true
		}
	}
	return false
}

// totpGenerate implements RFC 6238 / HOTP (RFC 4226).
func totpGenerate(base32Secret string, counter int64) string {
	key, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(base32Secret)
	if err != nil {
		return ""
	}
	msg := make([]byte, 8)
	binary.BigEndian.PutUint64(msg, uint64(counter))
	mac := hmac.New(sha1.New, key)
	mac.Write(msg)
	h := mac.Sum(nil)
	offset := h[len(h)-1] & 0x0f
	code := (int64(h[offset])&0x7f)<<24 |
		int64(h[offset+1])<<16 |
		int64(h[offset+2])<<8 |
		int64(h[offset+3])
	return fmt.Sprintf("%06d", code%int64(math.Pow10(6)))
}
