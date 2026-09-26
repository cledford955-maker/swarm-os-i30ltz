// Package handlers — inbound webhook receiver.
//
// External services (CI, GitHub, IFTTT, home-assistant, whatever) POST arbitrary
// JSON to /api/webhooks/{source}. The event is appended to a JSONL log at
// BaseDir()/webhooks/<source>.jsonl AND broadcast to any connected companions
// so a phone can render it.
//
// This is deliberately minimal: no per-source auth beyond the LucyServer auth
// token that already gates /api/*. If a caller can reach /api/webhooks/* they
// have the shared auth token, which is the same level of trust the whole API
// operates at.
package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"

	"swarm-os/lucy-server/services"
	"swarm-os/lucy-server/storage"
)

const maxWebhookBodyBytes = 256 * 1024 // 256 KiB — enough for CI payloads, blocks abuse

// sourceRe restricts the {source} path segment to safe characters so it can't
// escape the webhooks directory via traversal. `.` is deliberately absent.
var sourceRe = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,64}$`)

var webhookWriteMu sync.Mutex

// WebhookReceive handles POST /api/webhooks/{source}.
//
// Success: 200 with {"ok":true,"logged_to":"<path>","broadcast":<n>}.
// Rejects: 400 for bad source name, 413 for oversized body, 500 for I/O.
func WebhookReceive(w http.ResponseWriter, r *http.Request) {
	source := chi.URLParam(r, "source")
	if !sourceRe.MatchString(source) {
		http.Error(w, `{"error":"invalid source; use [A-Za-z0-9_-]{1,64}"}`, http.StatusBadRequest)
		return
	}

	// Cap body size before reading so a runaway payload can't OOM us.
	r.Body = http.MaxBytesReader(w, r.Body, maxWebhookBodyBytes)
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, `{"error":"body read failed or too large (256 KiB max)"}`, http.StatusRequestEntityTooLarge)
		return
	}

	// Best-effort JSON parse — we accept any content but note whether it was
	// structured so downstream consumers know.
	var parsed any
	structured := json.Unmarshal(body, &parsed) == nil

	receivedAt := time.Now().UTC()
	entry := map[string]any{
		"source":       source,
		"received_at":  receivedAt.Format(time.RFC3339Nano),
		"content_type": r.Header.Get("Content-Type"),
		"structured":   structured,
	}
	if structured {
		entry["payload"] = parsed
	} else {
		// Cap raw payload size we echo/log to prevent turning a truncated
		// binary blob into a giant JSONL line. 8 KiB is plenty for the
		// diagnostic case.
		if len(body) > 8192 {
			entry["payload_raw"] = string(body[:8192]) + "…"
		} else {
			entry["payload_raw"] = string(body)
		}
	}

	// Append to per-source JSONL. Ignore log errors for the response — the
	// broadcast still matters, and returning 500 for a full disk would drop
	// the webhook entirely.
	logPath, logErr := appendWebhookEntry(source, entry)

	// Fan out to companions so a phone can display "GitHub push to main"
	// or similar without waiting for a pull.
	services.GetCompanionHub().Broadcast(map[string]any{
		"type":   "webhook",
		"source": source,
		"at":     receivedAt.Format(time.RFC3339),
	})

	w.Header().Set("Content-Type", "application/json")
	resp := map[string]any{
		"ok":         true,
		"logged_to":  logPath,
		"broadcast":  services.GetCompanionHub().Count(),
		"structured": structured,
	}
	if logErr != nil {
		resp["log_error"] = logErr.Error()
	}
	json.NewEncoder(w).Encode(resp)
}

// appendWebhookEntry writes one JSONL line to BaseDir()/webhooks/<source>.jsonl.
// The webhooks directory is created on demand. Returns the log path even on
// write failure so the response can name it.
func appendWebhookEntry(source string, entry map[string]any) (string, error) {
	dir := filepath.Join(storage.BaseDir(), "webhooks")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", fmt.Errorf("mkdir %s: %w", dir, err)
	}
	path := filepath.Join(dir, source+".jsonl")

	webhookWriteMu.Lock()
	defer webhookWriteMu.Unlock()

	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return path, err
	}
	defer f.Close()

	line, err := json.Marshal(entry)
	if err != nil {
		return path, err
	}
	if _, err := f.Write(append(line, '\n')); err != nil {
		return path, err
	}
	return path, nil
}

// WebhookList handles GET /api/webhooks — returns the sources that have logs.
func WebhookList(w http.ResponseWriter, r *http.Request) {
	dir := filepath.Join(storage.BaseDir(), "webhooks")
	entries, err := os.ReadDir(dir)

	w.Header().Set("Content-Type", "application/json")
	sources := []map[string]any{}
	if err == nil {
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			name := e.Name()
			if filepath.Ext(name) != ".jsonl" {
				continue
			}
			info, _ := e.Info()
			var (
				size    int64
				modTime string
			)
			if info != nil {
				size = info.Size()
				modTime = info.ModTime().UTC().Format(time.RFC3339)
			}
			sources = append(sources, map[string]any{
				"source":     name[:len(name)-len(".jsonl")],
				"size_bytes": size,
				"mod_time":   modTime,
			})
		}
	}
	json.NewEncoder(w).Encode(map[string]any{"sources": sources})
}
