package handlers

import (
	"encoding/json"
	"net/http"

	"swarm-os/lucy-server/services"
)

// ── WebAuthn ─────────────────────────────────────────────────────────────────

func WARegisterOptions(w http.ResponseWriter, r *http.Request) {
	opts, err := services.WAGetRegisterOptions()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, opts)
}

func WARegisterVerify(w http.ResponseWriter, r *http.Request) {
	result, err := services.WAVerifyRegister(r)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, result)
}

func WALoginOptions(w http.ResponseWriter, r *http.Request) {
	opts, err := services.WAGetLoginOptions()
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, opts)
}

func WALoginVerify(w http.ResponseWriter, r *http.Request) {
	result, err := services.WAVerifyLogin(r)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, result)
}

func WAListCredentials(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.WAListCredentials())
}

func WAClearCredentials(w http.ResponseWriter, r *http.Request) {
	services.WAClearCredentials()
	writeJSON(w, map[string]string{"status": "ok"})
}

// ── Settings ─────────────────────────────────────────────────────────────────

func GetVoice(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]string{"voice": services.GetVoice()})
}

func SetVoice(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Voice string `json:"voice"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Voice == "" {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}
	services.SetVoice(req.Voice)
	writeJSON(w, map[string]string{"status": "ok", "voice": req.Voice})
}

func SetLoginPassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}
	ok, msg := services.SetLoginPassword(req.Password)
	if !ok {
		http.Error(w, `{"error":"`+msg+`"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]string{"status": "ok", "message": msg})
}

// VerifyLoginPassword backs the lock screen's forgotten-cipher recovery path.
func VerifyLoginPassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}
	ok, msg := services.VerifyLoginPassword(req.Password)
	if !ok {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": msg})
		return
	}
	writeJSON(w, map[string]string{"status": "ok", "message": msg})
}

func SetSudoPassword(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}
	ok, msg := services.SetSudoPassword(req.Password)
	if !ok {
		http.Error(w, `{"error":"`+msg+`"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]string{"status": "ok", "message": msg})
}

func SaveApiKeys(w http.ResponseWriter, r *http.Request) {
	var keys map[string]string
	if err := json.NewDecoder(r.Body).Decode(&keys); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}
	ok, msg := services.SaveApiKeys(keys)
	if !ok {
		http.Error(w, `{"error":"`+msg+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{"status": "ok", "message": msg})
}

// ── TOTP 2FA ─────────────────────────────────────────────────────────────────
// Scan the same QR on all phones at setup time — any of them will generate
// valid codes because they all share the same secret.

// TOTPStatus reports whether a TOTP secret is enrolled.
func TOTPStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]bool{"enabled": services.TOTPEnabled()})
}

// TOTPSetup generates a fresh secret + otpauth:// URI. The secret is NOT
// saved until the user confirms a valid code via TOTPConfirm.
func TOTPSetup(w http.ResponseWriter, r *http.Request) {
	secret, uri, err := services.TOTPSetup()
	if err != nil {
		http.Error(w, `{"error":"failed to generate secret"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]string{
		"secret":  secret,
		"uri":     uri,
		"message": "Scan the otpauth:// URI in Aegis / Google Authenticator / Bitwarden on each phone. Then POST to /api/settings/totp/confirm with {secret, code} to activate.",
	})
}

// TOTPConfirm verifies the first code against the pending secret and, if
// valid, persists the secret so all subsequent logins require a TOTP code.
func TOTPConfirm(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Secret string `json:"secret"`
		Code   string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Secret == "" || req.Code == "" {
		http.Error(w, `{"error":"secret and code required"}`, http.StatusBadRequest)
		return
	}
	if err := services.TOTPConfirm(req.Secret, req.Code); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid code — check phone clock and try the next code"})
		return
	}
	writeJSON(w, map[string]bool{"enabled": true})
}

// TOTPCheck validates a 6-digit code against the persisted secret.
// The lock screen calls this after a successful cipher match when TOTP is on.
func TOTPCheck(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Code string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}
	if !services.TOTPCheck(req.Code) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid or expired code"})
		return
	}
	writeJSON(w, map[string]bool{"valid": true})
}

// TOTPDisable clears the stored secret. Requires the current token (same auth
// as the API route) so someone who gets past auth but not the cipher can't
// trivially remove 2FA.
func TOTPDisable(w http.ResponseWriter, r *http.Request) {
	if err := services.TOTPDisable(); err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	writeJSON(w, map[string]bool{"enabled": false})
}

// ── Search & Daily Brief ─────────────────────────────────────────────────────

func GoogleBrief(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.GetDailyBrief())
}

func WebSearch(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	if q == "" {
		http.Error(w, `{"error":"missing query parameter q"}`, http.StatusBadRequest)
		return
	}
	results := services.SearchWeb(q, 8)
	writeJSON(w, results)
}
