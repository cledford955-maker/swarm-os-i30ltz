package handlers

import (
	"net/http"

	"swarm-os/lucy-server/services"
)

type InstallHandler struct{}

func NewInstallHandler() *InstallHandler {
	return &InstallHandler{}
}

// Disks lists candidate target disks for the graphical installer.
func (h *InstallHandler) Disks(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, services.ListDisks())
}

// WebSocket streams a live install_swarm_os.sh run. The `disk` query param
// is validated against ListDisks()'s own output — never trusted as a raw
// client string, since it becomes part of a sudo command line.
func (h *InstallHandler) WebSocket(w http.ResponseWriter, r *http.Request) {
	disk := r.URL.Query().Get("disk")

	valid := false
	for _, d := range services.ListDisks() {
		if d.Path == disk {
			valid = true
			break
		}
	}
	if !valid {
		http.Error(w, "unknown or unsafe disk path", http.StatusBadRequest)
		return
	}

	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	services.HandleInstallSession(conn, disk)
}
