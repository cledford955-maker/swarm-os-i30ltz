// Package memory is the SWARM OS shared memory: one append-only log that
// LUCILLE (CachyOS / SWARM OS / EndeavourOS), the three companion phones and
// Claude's own memory files all converge on.
//
// Version 1.0.0 — 2026-09-16. Design: 90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md
//
// Every write, from any device, is a new immutable Entry — never an edit.
// Sync is therefore union-by-id, and there is nothing to conflict on.
package memory

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"
)

// SchemaVersion is written into every entry so a future format change can be
// detected by old readers instead of silently misparsed.
const SchemaVersion = 1

// MaxContentBytes bounds a single entry. memory.json (the largest imported
// document) is ~210 KB; 2 MB leaves room without letting one push fill a disk.
const MaxContentBytes = 2 << 20

// Kinds with special meaning. Any other lowercase kind is accepted as-is.
const (
	KindNote         = "note"          // free-form memory from a person or an AI
	KindFact         = "fact"          // durable fact about the project or user
	KindDecision     = "decision"      // an architecture/product decision + rationale
	KindDoc          = "doc"           // snapshot of a core file on /mnt/brains (key = filename)
	KindClaudeMemory = "claude_memory" // one Claude Code memory file (key = filename)
)

// Entry is one immutable memory record.
type Entry struct {
	V       int               `json:"v"`
	ID      string            `json:"id"`
	Device  string            `json:"device"`
	TS      string            `json:"ts"` // RFC 3339, UTC, nanosecond precision
	Kind    string            `json:"kind"`
	Key     string            `json:"key,omitempty"` // entries sharing kind+key supersede each other
	Content string            `json:"content"`
	Tags    []string          `json:"tags,omitempty"`
	Meta    map[string]string `json:"meta,omitempty"`
	Deleted bool              `json:"deleted,omitempty"` // tombstone for a keyed entry
}

var (
	deviceRe = regexp.MustCompile(`^[A-Za-z0-9._@-]{1,64}$`)
	kindRe   = regexp.MustCompile(`^[a-z][a-z0-9_]{0,31}$`)
	idRe     = regexp.MustCompile(`^[A-Za-z0-9-]{8,64}$`)
)

// NewEntry stamps a fresh entry for this device.
func NewEntry(device, kind, key, content string) Entry {
	return Entry{
		V:       SchemaVersion,
		ID:      NewID(),
		Device:  device,
		TS:      time.Now().UTC().Format(time.RFC3339Nano),
		Kind:    kind,
		Key:     key,
		Content: content,
	}
}

// NewID returns a random UUIDv4 string.
func NewID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic(err) // crypto/rand failing means the OS is broken
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	h := hex.EncodeToString(b[:])
	return h[0:8] + "-" + h[8:12] + "-" + h[12:16] + "-" + h[16:20] + "-" + h[20:]
}

// Validate rejects anything that would corrupt the log or a device's file name.
func (e Entry) Validate() error {
	switch {
	case e.V != SchemaVersion:
		return fmt.Errorf("unsupported schema version %d", e.V)
	case !idRe.MatchString(e.ID):
		return errors.New("invalid id")
	case !deviceRe.MatchString(e.Device):
		return errors.New("invalid device")
	case !kindRe.MatchString(e.Kind):
		return errors.New("invalid kind")
	case len(e.Key) > 200:
		return errors.New("key too long")
	case len(e.Content) > MaxContentBytes:
		return errors.New("content too large")
	}
	if _, err := time.Parse(time.RFC3339Nano, e.TS); err != nil {
		return errors.New("invalid ts")
	}
	return nil
}

// Time parses TS; Validate guarantees it succeeds for stored entries.
func (e Entry) Time() time.Time {
	t, _ := time.Parse(time.RFC3339Nano, e.TS)
	return t
}

// Before is the log's total order: timestamp, then id to break ties.
func (e Entry) Before(o Entry) bool {
	a, b := e.Time(), o.Time()
	if !a.Equal(b) {
		return a.Before(b)
	}
	return e.ID < o.ID
}

// DefaultDir is where the shared memory lives on every OS that mounts nvme0n1p5.
func DefaultDir() string {
	if d := os.Getenv("SWARM_MEMORY_DIR"); d != "" {
		return d
	}
	return "/mnt/brains/swarm-memory"
}

// LocalDeviceID names this OS install, e.g. "cachyos@cachyos-i30ltz". The OS id
// is included because CachyOS, SWARM OS and EndeavourOS share the same
// hardware and may share a hostname.
func LocalDeviceID() string {
	if d := os.Getenv("SWARM_DEVICE_ID"); d != "" {
		return d
	}
	osID := "linux"
	if data, err := os.ReadFile("/etc/os-release"); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if v, ok := strings.CutPrefix(line, "ID="); ok {
				osID = strings.Trim(v, `"`)
			}
		}
	}
	host, _ := os.Hostname()
	if host == "" {
		host = "unknown"
	}
	id := osID + "@" + host
	return regexp.MustCompile(`[^A-Za-z0-9._@-]`).ReplaceAllString(id, "-")
}
