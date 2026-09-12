package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/gorilla/websocket"

	"swarm-os/lucy-server/services"
)

// CheckOrigin always allows: this API's only access control is
// swarmAuthMiddleware (loopback or X-Swarm-Auth token) in main.go, matching
// the .NET original which also didn't gate WebSocket upgrades by origin.
var wsUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type SystemHandler struct{}

func NewSystemHandler() *SystemHandler {
	return &SystemHandler{}
}

func (h *SystemHandler) RunCommand(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Command string `json:"command"`
		Cwd     string `json:"cwd"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	writeJSON(w, services.RunCommand(req.Command, req.Cwd))
}

func (h *SystemHandler) SetClipboard(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	writeJSON(w, services.SetClipboardText(req.Text))
}

func (h *SystemHandler) Processes(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.GetProcesses())
}

func (h *SystemHandler) KillProcess(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Pid int `json:"pid"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]bool{"success": services.KillProcess(req.Pid)})
}

func (h *SystemHandler) Stats(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.GetSystemStats())
}

func (h *SystemHandler) ListPackages(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.ListPackages())
}

func (h *SystemHandler) UninstallPackage(w http.ResponseWriter, r *http.Request) {
	var req struct {
		PackageName string `json:"packageName"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	writeJSON(w, services.UninstallPackage(req.PackageName))
}

func (h *SystemHandler) TerminalWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	services.HandleTerminalSession(conn)
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}
