package handlers

import (
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"swarm-os/lucy-server/services"
)

// ── VMs ───────────────────────────────────────────────────────────────────────

func VmList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.VmList())
}

func VmGet(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	vm := services.VmGet(id)
	if vm == nil {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, vm)
}

func VmCreate(w http.ResponseWriter, r *http.Request) {
	var req services.VmCreateRequest
	if err := decodeJSON(r, &req); err != nil {
		http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
		return
	}
	vm, err := services.VmCreate(req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, vm)
}

func VmStart(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if ok := services.VmStart(id); !ok {
		http.Error(w, `{"error":"Failed to start VM"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"success": true, "message": "VM started"})
}

func VmStop(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	force := r.URL.Query().Get("force") == "true"
	if ok := services.VmStop(id, force); !ok {
		http.Error(w, `{"error":"Failed to stop VM"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"success": true, "message": "VM stopped"})
}

func VmPause(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if ok := services.VmPause(id); !ok {
		http.Error(w, `{"error":"Failed to pause VM"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"success": true, "message": "VM paused"})
}

func VmResume(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if ok := services.VmResume(id); !ok {
		http.Error(w, `{"error":"Failed to resume VM"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"success": true, "message": "VM resumed"})
}

func VmDelete(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	if ok := services.VmDelete(id); !ok {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"success": true, "message": "VM deleted"})
}

// ── VM Telemetry ──────────────────────────────────────────────────────────────

func VmGetTelemetry(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	t := services.VmGetTelemetry(id)
	if t == nil {
		http.Error(w, `{"error":"VM not running or telemetry unavailable"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, t)
}

func VmGetTelemetryHistory(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	minutes := 15
	if v := r.URL.Query().Get("minutes"); v != "" {
		if n, err := strconv.Atoi(v); err == nil { minutes = n }
	}
	writeJSON(w, services.VmGetTelemetryHistory(id, minutes))
}

// ── Snapshots ─────────────────────────────────────────────────────────────────

func VmListSnapshots(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	snaps, _ := services.VmListSnapshots(id)
	writeJSON(w, snaps)
}

func VmCreateSnapshot(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	var req services.VmSnapshotCreateRequest
	_ = decodeJSON(r, &req)
	snap, err := services.VmCreateSnapshot(id, req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, snap)
}

func VmRestoreSnapshot(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	name := chi.URLParam(r, "name")
	if ok := services.VmRestoreSnapshot(id, name); !ok {
		http.Error(w, `{"error":"Failed to restore snapshot"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"success": true, "message": "Snapshot '" + name + "' restored"})
}

func VmDeleteSnapshot(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	name := chi.URLParam(r, "name")
	if ok := services.VmDeleteSnapshot(id, name); !ok {
		http.Error(w, `{"error":"Failed to delete snapshot"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, map[string]any{"success": true, "message": "Snapshot '" + name + "' deleted"})
}

// ── Environment Templates ─────────────────────────────────────────────────────

func EnvTemplateList(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.EnvTemplateList())
}

func EnvTemplateGet(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	t := services.EnvTemplateGet(id)
	if t == nil {
		http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, t)
}

func EnvTemplateInstantiate(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	name := r.URL.Query().Get("name")
	vm, err := services.EnvTemplateInstantiate(id, name)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}
	w.WriteHeader(http.StatusCreated)
	writeJSON(w, vm)
}

// ── Device Mirror ─────────────────────────────────────────────────────────────

func MirrorStart(w http.ResponseWriter, r *http.Request) {
	var body struct {
		DeviceSerial string `json:"device_serial"`
		DeviceModel  string `json:"device_model"`
		IsWireless   bool   `json:"is_wireless"`
		IPAddress    string `json:"ip_address"`
		Port         int    `json:"port"`
		MaxFPS       int    `json:"max_fps"`
		BitrateMbps  int    `json:"bitrate_mbps"`
		ForwardAudio bool   `json:"forward_audio"`
	}
	_ = decodeJSON(r, &body)
	sess := services.MirrorStart(body.DeviceSerial, body.DeviceModel, body.IsWireless, body.IPAddress, body.Port, body.MaxFPS, body.BitrateMbps, body.ForwardAudio)
	writeJSON(w, map[string]any{"session": sess})
}

func MirrorStop(w http.ResponseWriter, r *http.Request) {
	sessionID := chi.URLParam(r, "sessionId")
	if ok := services.MirrorStop(sessionID); !ok {
		http.Error(w, `{"error":"session not found"}`, http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]any{"success": true})
}

func MirrorListActive(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"sessions": services.MirrorListActive()})
}

func DeviceStats(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.GetDeviceHardwareStats())
}

// ── Telemetry & Crash ─────────────────────────────────────────────────────────

func CrashReportList(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil { limit = n }
	}
	writeJSON(w, map[string]any{"crash_reports": services.CrashList(limit)})
}

func CrashReportSubmit(w http.ResponseWriter, r *http.Request) {
	var body struct {
		AppName     string            `json:"app_name"`
		Version     string            `json:"version"`
		ExType      string            `json:"exception_type"`
		Message     string            `json:"exception_message"`
		StackTrace  string            `json:"raw_stack_trace"`
		Metadata    map[string]string `json:"environment_metadata"`
	}
	if err := decodeJSON(r, &body); err != nil || body.AppName == "" {
		http.Error(w, `{"error":"app_name required"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, services.CrashSubmit(body.AppName, body.Version, body.ExType, body.Message, body.StackTrace, body.Metadata))
}

func AppAnalytics(w http.ResponseWriter, r *http.Request) {
	appID := r.URL.Query().Get("app_id")
	writeJSON(w, services.AppAnalytics(appID))
}

// ── Security ──────────────────────────────────────────────────────────────────

func SecurityAuditLogs(w http.ResponseWriter, r *http.Request) {
	limit := 100
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil { limit = n }
	}
	writeJSON(w, map[string]any{"audit_logs": services.SecurityAuditLogs(limit)})
}

func SecurityScanPackage(w http.ResponseWriter, r *http.Request) {
	var body struct {
		PackagePath string `json:"package_path"`
	}
	if err := decodeJSON(r, &body); err != nil || body.PackagePath == "" {
		http.Error(w, `{"error":"package_path required"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, services.SecurityScanPackage(body.PackagePath))
}

func SecurityVerifiedDevelopers(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"verified_developers": services.SecurityVerifiedDevelopers()})
}

// ── Sandbox ───────────────────────────────────────────────────────────────────

func SandboxExecute(w http.ResponseWriter, r *http.Request) {
	var req services.SandboxExecutionRequest
	if err := decodeJSON(r, &req); err != nil || req.Code == "" {
		http.Error(w, `{"error":"code required"}`, http.StatusBadRequest)
		return
	}
	writeJSON(w, services.SandboxExecute(req))
}
