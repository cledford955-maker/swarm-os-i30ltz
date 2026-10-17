package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"

	"swarm-os/lucy-server/services"
)

func dialCompanion(t *testing.T, s *httptest.Server) *websocket.Conn {
	t.Helper()
	url := "ws" + strings.TrimPrefix(s.URL, "http") + "/api/companion/ws"
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	return conn
}

func TestCompanionHello(t *testing.T) {
	h := NewCompanionHandler()
	mux := http.NewServeMux()
	mux.HandleFunc("/api/companion/ws", h.WebSocket)
	s := httptest.NewServer(mux)
	defer s.Close()

	conn := dialCompanion(t, s)
	defer conn.Close()

	// Send hello.
	hello := map[string]string{"device_id": "pixel-7", "device_name": "i30ltz Pixel"}
	msg, _ := json.Marshal(hello)
	if err := conn.WriteMessage(websocket.TextMessage, msg); err != nil {
		t.Fatalf("write hello: %v", err)
	}

	// Read welcome response.
	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, data, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read welcome: %v", err)
	}
	var welcome map[string]any
	if err := json.Unmarshal(data, &welcome); err != nil {
		t.Fatalf("parse welcome: %v", err)
	}
	if welcome["type"] != "welcome" {
		t.Errorf("expected welcome type, got %v", welcome["type"])
	}
	if welcome["server"] != "lucy-server" {
		t.Errorf("expected lucy-server, got %v", welcome["server"])
	}
}

func TestCompanionHubTracking(t *testing.T) {
	h := NewCompanionHandler()
	mux := http.NewServeMux()
	mux.HandleFunc("/api/companion/ws", h.WebSocket)
	s := httptest.NewServer(mux)
	defer s.Close()

	hub := services.GetCompanionHub()
	before := hub.Count()

	conn := dialCompanion(t, s)
	hello := map[string]string{"device_id": "test-device", "device_name": "Test Phone"}
	msg, _ := json.Marshal(hello)
	conn.WriteMessage(websocket.TextMessage, msg)

	// Read welcome to confirm registration.
	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	conn.ReadMessage()

	// Give goroutine time to register.
	time.Sleep(100 * time.Millisecond)

	if hub.Count() != before+1 {
		t.Errorf("expected %d companions, got %d", before+1, hub.Count())
	}

	companions := hub.Connected()
	found := false
	for _, c := range companions {
		if c.DeviceID == "test-device" {
			found = true
			if c.DeviceName != "Test Phone" {
				t.Errorf("expected device name Test Phone, got %s", c.DeviceName)
			}
		}
	}
	if !found {
		t.Error("test-device not found in hub")
	}

	conn.Close()
	time.Sleep(100 * time.Millisecond)

	if hub.Count() != before {
		t.Errorf("expected %d companions after disconnect, got %d", before, hub.Count())
	}
}

func TestCompanionStatusAck(t *testing.T) {
	h := NewCompanionHandler()
	mux := http.NewServeMux()
	mux.HandleFunc("/api/companion/ws", h.WebSocket)
	s := httptest.NewServer(mux)
	defer s.Close()

	conn := dialCompanion(t, s)
	defer conn.Close()

	// Hello.
	hello, _ := json.Marshal(map[string]string{"device_id": "ack-test"})
	conn.WriteMessage(websocket.TextMessage, hello)
	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	conn.ReadMessage() // welcome

	// Send a status message.
	status, _ := json.Marshal(map[string]string{"type": "status", "battery": "82%"})
	conn.WriteMessage(websocket.TextMessage, status)

	// Read ack.
	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	_, data, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read ack: %v", err)
	}
	var ack map[string]any
	json.Unmarshal(data, &ack)
	if ack["type"] != "ack" {
		t.Errorf("expected ack type, got %v", ack["type"])
	}
	if ack["of"] != "status" {
		t.Errorf("expected of=status, got %v", ack["of"])
	}
}

func TestCompanionPingReceived(t *testing.T) {
	h := NewCompanionHandler()
	mux := http.NewServeMux()
	mux.HandleFunc("/api/companion/ws", h.WebSocket)
	s := httptest.NewServer(mux)
	defer s.Close()

	conn := dialCompanion(t, s)
	defer conn.Close()

	// Hello.
	hello, _ := json.Marshal(map[string]string{"device_id": "ping-test"})
	conn.WriteMessage(websocket.TextMessage, hello)
	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	conn.ReadMessage() // welcome

	// Clear the deadline so the read goroutine below can wait long enough
	// for the server's 5-second ping ticker to fire.
	conn.SetReadDeadline(time.Time{})

	// Wait for a ping from the server (5s interval + some margin).
	pingReceived := make(chan struct{})
	conn.SetPingHandler(func(string) error {
		close(pingReceived)
		return conn.WriteControl(websocket.PongMessage, nil, time.Now().Add(time.Second))
	})

	// Must keep reading to process control frames.
	go func() {
		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				return
			}
		}
	}()

	select {
	case <-pingReceived:
		// success
	case <-time.After(8 * time.Second):
		t.Fatal("no ping received within 8s")
	}
}

func TestCompanionStatusEndpoint(t *testing.T) {
	h := NewCompanionHandler()
	mux := http.NewServeMux()
	mux.HandleFunc("/api/companion/status", h.Status)
	s := httptest.NewServer(mux)
	defer s.Close()

	resp, err := http.Get(s.URL + "/api/companion/status")
	if err != nil {
		t.Fatalf("GET status: %v", err)
	}
	defer resp.Body.Close()

	var body map[string]any
	json.NewDecoder(resp.Body).Decode(&body)

	if _, ok := body["connected"]; !ok {
		t.Error("missing 'connected' field")
	}
	if _, ok := body["companions"]; !ok {
		t.Error("missing 'companions' field")
	}
}
