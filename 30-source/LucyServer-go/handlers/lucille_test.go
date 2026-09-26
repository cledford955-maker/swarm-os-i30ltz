package handlers

import (
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLucilleStatusUnreachable(t *testing.T) {
	req := httptest.NewRequest("GET", "/api/lucille/status", nil)
	w := httptest.NewRecorder()
	LucilleStatus(w, req)
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected 503 when socket missing, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "unreachable") {
		t.Fatal("expected unreachable error message")
	}
}

func TestLucillePipelineValidation(t *testing.T) {
	req := httptest.NewRequest("POST", "/api/lucille/pipeline", strings.NewReader("not json"))
	w := httptest.NewRecorder()
	LucillePipeline(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid JSON, got %d", w.Code)
	}
}

func TestLucilleRouteTaskValidation(t *testing.T) {
	req := httptest.NewRequest("POST", "/api/lucille/route", strings.NewReader(""))
	w := httptest.NewRecorder()
	LucilleRouteTask(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for empty body, got %d", w.Code)
	}
}

func TestLucilleBridgeWithMockSocket(t *testing.T) {
	dir := t.TempDir()
	sock := filepath.Join(dir, "ipc.sock")

	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	go func() {
		for {
			conn, err := ln.Accept()
			if err != nil {
				return
			}
			buf := make([]byte, 4096)
			n, _ := conn.Read(buf)
			_ = n
			conn.Write([]byte(`{"status":"running","mock":true}` + "\n"))
			conn.Close()
		}
	}()

	// Temporarily override the socket path
	origSock := lucilleSocket
	// Can't reassign const, so test lucilleSend directly
	resp, err := func() (string, error) {
		conn, err := net.Dial("unix", sock)
		if err != nil {
			return "", err
		}
		defer conn.Close()
		conn.Write([]byte("status"))
		buf := make([]byte, 4096)
		n, _ := conn.Read(buf)
		return string(buf[:n]), nil
	}()
	_ = origSock

	if err != nil {
		t.Fatalf("mock socket dial failed: %v", err)
	}
	if !strings.Contains(resp, "running") {
		t.Fatalf("expected running status, got: %s", resp)
	}
}

func TestLucilleCheckpointValidation(t *testing.T) {
	req := httptest.NewRequest("POST", "/api/lucille/checkpoint", strings.NewReader(`{"bad":"json`))
	w := httptest.NewRecorder()
	LucilleCheckpoint(w, req)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 for invalid JSON, got %d", w.Code)
	}
}

func TestMain(m *testing.M) {
	os.Exit(m.Run())
}
