package handlers

import (
	"encoding/json"
	"io"
	"net"
	"net/http"
	"time"
)

const lucilleSocket = "/run/lucille/ipc.sock"

func lucilleSend(command string) (string, error) {
	conn, err := net.DialTimeout("unix", lucilleSocket, 5*time.Second)
	if err != nil {
		return "", err
	}
	defer conn.Close()

	conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
	if _, err := conn.Write([]byte(command)); err != nil {
		return "", err
	}

	conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	buf := make([]byte, 64*1024)
	n, err := conn.Read(buf)
	if err != nil && err != io.EOF {
		return "", err
	}
	return string(buf[:n]), nil
}

func LucilleStatus(w http.ResponseWriter, r *http.Request) {
	resp, err := lucilleSend("status")
	if err != nil {
		http.Error(w, `{"error":"lucille-core unreachable: `+err.Error()+`"}`, http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(resp))
}

func LucillePipeline(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, `{"error":"bad request body"}`, http.StatusBadRequest)
		return
	}

	var req map[string]interface{}
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, `{"error":"invalid JSON"}`, http.StatusBadRequest)
		return
	}

	req["command"] = "run_pipeline"

	cmd, _ := json.Marshal(req)
	resp, err := lucilleSend(string(cmd))
	if err != nil {
		http.Error(w, `{"error":"lucille-core unreachable: `+err.Error()+`"}`, http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(resp))
}

func LucilleRouteTask(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, `{"error":"bad request body"}`, http.StatusBadRequest)
		return
	}

	var req map[string]interface{}
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, `{"error":"invalid JSON"}`, http.StatusBadRequest)
		return
	}

	req["command"] = "route_task"

	cmd, _ := json.Marshal(req)
	resp, err := lucilleSend(string(cmd))
	if err != nil {
		http.Error(w, `{"error":"lucille-core unreachable: `+err.Error()+`"}`, http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(resp))
}

func LucilleCheckpoint(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, `{"error":"bad request body"}`, http.StatusBadRequest)
		return
	}

	var req map[string]interface{}
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, `{"error":"invalid JSON"}`, http.StatusBadRequest)
		return
	}

	cmd, _ := json.Marshal(req)
	resp, err := lucilleSend(string(cmd))
	if err != nil {
		http.Error(w, `{"error":"lucille-core unreachable: `+err.Error()+`"}`, http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(resp))
}
