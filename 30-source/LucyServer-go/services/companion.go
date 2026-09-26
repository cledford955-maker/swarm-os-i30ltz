package services

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	companionPingInterval = 5 * time.Second
	companionPongWait     = 10 * time.Second
	companionWriteWait    = 3 * time.Second
)

type CompanionConn struct {
	DeviceID   string    `json:"device_id"`
	DeviceName string    `json:"device_name"`
	ConnectedAt time.Time `json:"connected_at"`
	LastPong   time.Time `json:"last_pong"`
}

type CompanionHub struct {
	mu    sync.RWMutex
	conns map[*websocket.Conn]*CompanionConn
}

var companionHub = &CompanionHub{
	conns: make(map[*websocket.Conn]*CompanionConn),
}

func GetCompanionHub() *CompanionHub { return companionHub }

func (h *CompanionHub) add(conn *websocket.Conn, cc *CompanionConn) {
	h.mu.Lock()
	h.conns[conn] = cc
	h.mu.Unlock()
}

func (h *CompanionHub) remove(conn *websocket.Conn) {
	h.mu.Lock()
	delete(h.conns, conn)
	h.mu.Unlock()
}

func (h *CompanionHub) Connected() []CompanionConn {
	h.mu.RLock()
	defer h.mu.RUnlock()
	out := make([]CompanionConn, 0, len(h.conns))
	for _, cc := range h.conns {
		out = append(out, *cc)
	}
	return out
}

func (h *CompanionHub) Count() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.conns)
}

// Broadcast fans a JSON-serialisable payload out to every connected companion.
// Best-effort: a slow or dropped client is skipped (no cross-client blocking),
// never returns an error to the caller. Used for OTA update pushes so all
// phones learn about a new ISO the moment lucy-server sees one, instead of
// waiting for their next /api/updates/check poll.
func (h *CompanionHub) Broadcast(payload any) {
	blob, err := json.Marshal(payload)
	if err != nil {
		return
	}
	// Snapshot the conns under RLock so a slow send can't hold up new
	// connect/disconnect activity.
	h.mu.RLock()
	targets := make([]*websocket.Conn, 0, len(h.conns))
	for c := range h.conns {
		targets = append(targets, c)
	}
	h.mu.RUnlock()

	for _, c := range targets {
		c.SetWriteDeadline(time.Now().Add(companionWriteWait))
		// Non-fatal: if this write fails the client's read loop will detect
		// it and clean up via defer companionHub.remove().
		_ = c.WriteMessage(websocket.TextMessage, blob)
	}
}

// HandleCompanionHeartbeat manages a single companion WebSocket connection.
// The client sends a JSON hello on connect: {"device_id":"...", "device_name":"..."}.
// After that the server sends Ping frames every 5s; the client's WebSocket
// library replies with Pong automatically. If no Pong arrives within 10s the
// server closes the connection. The client may also send JSON messages which
// are echoed back as status updates.
func HandleCompanionHeartbeat(conn *websocket.Conn) {
	defer conn.Close()

	conn.SetReadDeadline(time.Now().Add(companionPongWait))

	cc := &CompanionConn{
		DeviceID:    "unknown",
		DeviceName:  "unknown",
		ConnectedAt: time.Now(),
		LastPong:    time.Now(),
	}

	// Read the optional hello message (first message within the pong window).
	_, msg, err := conn.ReadMessage()
	if err == nil {
		var hello struct {
			DeviceID   string `json:"device_id"`
			DeviceName string `json:"device_name"`
		}
		if json.Unmarshal(msg, &hello) == nil {
			if hello.DeviceID != "" {
				cc.DeviceID = hello.DeviceID
			}
			if hello.DeviceName != "" {
				cc.DeviceName = hello.DeviceName
			}
		}
	} else {
		return
	}

	companionHub.add(conn, cc)
	defer companionHub.remove(conn)

	fmt.Fprintf(os.Stderr, "[companion] connected: %s (%s)\n", cc.DeviceName, cc.DeviceID)
	defer fmt.Fprintf(os.Stderr, "[companion] disconnected: %s (%s)\n", cc.DeviceName, cc.DeviceID)

	// Send welcome with server identity.
	welcome, _ := json.Marshal(map[string]any{
		"type":       "welcome",
		"server":     "lucy-server",
		"companions": companionHub.Count(),
	})
	conn.SetWriteDeadline(time.Now().Add(companionWriteWait))
	conn.WriteMessage(websocket.TextMessage, welcome)

	conn.SetPongHandler(func(string) error {
		cc.LastPong = time.Now()
		conn.SetReadDeadline(time.Now().Add(companionPongWait))
		return nil
	})

	done := make(chan struct{})

	// Ping ticker goroutine.
	go func() {
		ticker := time.NewTicker(companionPingInterval)
		defer ticker.Stop()
		for {
			select {
			case <-done:
				return
			case <-ticker.C:
				conn.SetWriteDeadline(time.Now().Add(companionWriteWait))
				if err := conn.WriteControl(websocket.PingMessage, nil, time.Now().Add(companionWriteWait)); err != nil {
					return
				}
			}
		}
	}()

	// Read loop — keeps the connection alive and processes any client messages.
	defer close(done)
	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			return
		}
		// Echo status back. Companions can send {"type":"status", ...} messages
		// which we acknowledge so they know the channel is bidirectional.
		var envelope struct {
			Type string `json:"type"`
		}
		if json.Unmarshal(msg, &envelope) == nil && envelope.Type == "status" {
			ack, _ := json.Marshal(map[string]any{
				"type": "ack",
				"of":   "status",
				"at":   time.Now().UTC().Format(time.RFC3339),
			})
			conn.SetWriteDeadline(time.Now().Add(companionWriteWait))
			conn.WriteMessage(websocket.TextMessage, ack)
		}
	}
}
