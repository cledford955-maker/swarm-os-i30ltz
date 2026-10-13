package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"os"
	"time"
)

// HealthDeps holds the real dependencies the health handler inspects.
// Wire via NewHealthHandler; if nil, Health falls back to the legacy always-ok stub.
type HealthDeps struct {
	DB *sql.DB
}

var healthDeps *HealthDeps

// SetHealthDeps wires the real dependencies so the /health endpoint reflects
// actual service state rather than always returning ok.
func SetHealthDeps(deps *HealthDeps) {
	healthDeps = deps
}

// Health returns a real health payload: DB reachability + API key presence.
// This replaces the prior always-ok stub that hid dead keys and a closed DB
// (bugs surfaced in every audit since 2026-09-27).
func Health(w http.ResponseWriter, r *http.Request) {
	type check struct {
		OK      bool   `json:"ok"`
		Message string `json:"message,omitempty"`
	}
	type payload struct {
		Status    string           `json:"status"`
		Uptime    string           `json:"uptime"`
		Checks    map[string]check `json:"checks"`
	}

	checks := map[string]check{}
	allOK := true

	// DB ping
	if healthDeps != nil && healthDeps.DB != nil {
		ctx := r.Context()
		if err := healthDeps.DB.PingContext(ctx); err != nil {
			checks["db"] = check{OK: false, Message: err.Error()}
			allOK = false
		} else {
			checks["db"] = check{OK: true}
		}
	} else {
		checks["db"] = check{OK: false, Message: "not wired"}
		allOK = false
	}

	// Chat API key presence (OpenRouter or whatever chatAPIKeyEnv points at)
	chatKey := os.Getenv("OPENROUTER_API_KEY")
	if chatKey == "" {
		checks["chat_api_key"] = check{OK: false, Message: "OPENROUTER_API_KEY not set — Lucille chat dead"}
		allOK = false
	} else {
		checks["chat_api_key"] = check{OK: true}
	}

	// Steam API key
	steamKey := os.Getenv("STEAM_API_KEY")
	if steamKey == "" {
		checks["steam_api_key"] = check{OK: false, Message: "STEAM_API_KEY not set — library/intersection dead"}
		allOK = false
	} else {
		checks["steam_api_key"] = check{OK: true}
	}

	status := "ok"
	if !allOK {
		status = "degraded"
	}

	w.Header().Set("Content-Type", "application/json")
	if !allOK {
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	json.NewEncoder(w).Encode(payload{
		Status: status,
		Uptime: time.Since(startTime).Round(time.Second).String(),
		Checks: checks,
	})
}

var startTime = time.Now()
