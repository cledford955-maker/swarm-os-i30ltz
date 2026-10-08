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

// WebSocket streams a live install_swarm_os.sh run. The target is named by
// partition UUIDs (rootUuid = formatted btrfs root, espUuid = kept FAT EFI)
// plus the disk they belong to. Each must match ListDisks()'s own output, so
// nothing from the client reaches the sudo command line unchecked.
func (h *InstallHandler) WebSocket(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	target, ok := services.FindInstallTarget(q.Get("disk"), q.Get("rootUuid"), q.Get("espUuid"))
	if !ok {
		http.Error(w, "unknown or unsafe install target", http.StatusBadRequest)
		return
	}

	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	services.HandleInstallSession(conn, target)
}
