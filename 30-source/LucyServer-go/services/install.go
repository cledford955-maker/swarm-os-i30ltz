package services

import (
	"encoding/json"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"

	"github.com/gorilla/websocket"
)

// InstallDisk describes one candidate target disk for the graphical
// installer — enough for the Flutter UI to render a safe picker without
// shelling out to lsblk itself.
type InstallDisk struct {
	Path            string `json:"path"` // e.g. /dev/nvme0n1
	SizeBytes       int64  `json:"sizeBytes"`
	SizeHuman       string `json:"sizeHuman"` // e.g. "1.0 TB", from lsblk directly
	Model           string `json:"model"`
	HasLuks         bool   `json:"hasLuks"`         // an encrypted partition exists — almost certainly NOT the install target
	PartitionsReady bool   `json:"partitionsReady"` // EFI+ROOT partitions already exist (p1/p2 or 1/2) — install_swarm_os.sh --non-interactive requires this
	// Filesystem UUIDs of the target partitions, read from the partitions
	// themselves. The install is driven by these, not by the disk path: the
	// root is formatted, the EFI is mounted and kept. Empty unless the
	// partition exists with the expected filesystem (btrfs root, FAT EFI).
	EfiUUID  string `json:"efiUuid,omitempty"`
	RootUUID string `json:"rootUuid,omitempty"`
}

// ListDisks mirrors install_swarm_os.sh's own auto-detect logic (same
// lsblk fields, same "disk" + non-removable filter) but returns every
// candidate instead of picking one — the operator picks in the GUI, same
// safety bar as the CLI's typed-confirmation, just via an explicit click
// instead of typing the path.
func ListDisks() []InstallDisk {
	lsblk := RunCommand(`lsblk -dpno NAME,TYPE,RM,SIZE,SIZE,MODEL --bytes`, "")
	luks := RunCommand(`lsblk -rno PKNAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1}' | sort -u`, "")
	luksSet := map[string]bool{}
	for _, name := range strings.Split(luks.StandardOutput, "\n") {
		if name != "" {
			luksSet[name] = true
		}
	}

	var disks []InstallDisk
	for _, line := range strings.Split(lsblk.StandardOutput, "\n") {
		fields := strings.Fields(line)
		if len(fields) < 4 || fields[1] != "disk" || fields[2] != "0" {
			continue // not a disk, or removable (RM=1) — same filter as the CLI's auto-detect
		}
		path := fields[0]
		// lsblk reports zram (RAM-backed swap) as TYPE=disk too — found via
		// live testing 2026-09-19, /dev/zram0 showed up as a clickable
		// install target. Same latent gap exists in install_swarm_os.sh's
		// own auto-detect filter, harmless there only because zram is
		// always far smaller than a real disk so sort-by-size never picks
		// it — not something to rely on when every candidate is listed and
		// clickable instead of auto-picked.
		if strings.Contains(path, "/zram") {
			continue
		}
		sizeBytes, _ := strconv.ParseInt(fields[3], 10, 64)
		model := ""
		if len(fields) > 5 {
			model = strings.Join(fields[5:], " ")
		}

		sizeHuman := RunCommand("lsblk -dno SIZE "+path, "").StandardOutput
		sizeHuman = strings.TrimSpace(sizeHuman)

		efi, root := targetPartitions(path)
		disk := InstallDisk{
			Path:            path,
			SizeBytes:       sizeBytes,
			SizeHuman:       sizeHuman,
			Model:           model,
			HasLuks:         luksSet[path[strings.LastIndex(path, "/")+1:]],
			PartitionsReady: pathExists(efi) && pathExists(root),
		}
		if disk.PartitionsReady {
			disk.EfiUUID = partitionUUID(efi, "vfat")
			disk.RootUUID = partitionUUID(root, "btrfs")
		}
		disks = append(disks, disk)
	}
	return disks
}

// partitionUUID returns the filesystem UUID of dev if it has the wanted
// filesystem type, and "" otherwise. The installer refuses anything else too;
// this only keeps the GUI from offering a target it would reject.
//
// It reads udev's database, not the blkid cache: after a format the blkid
// cache can still hold the old UUID, while udev is updated as soon as the
// partition is re-probed, and udev is readable without root.
func partitionUUID(dev, wantType string) string {
	props := RunCommand("udevadm info -q property -n "+dev, "").StandardOutput
	var typ, uuid string
	for _, line := range strings.Split(props, "\n") {
		switch {
		case strings.HasPrefix(line, "ID_FS_TYPE="):
			typ = strings.TrimPrefix(line, "ID_FS_TYPE=")
		case strings.HasPrefix(line, "ID_FS_UUID="):
			uuid = strings.TrimPrefix(line, "ID_FS_UUID=")
		}
	}
	if typ != wantType {
		return ""
	}
	return uuid
}

// FindInstallTarget returns the listed disk whose partitions carry exactly the
// given UUIDs. The UUIDs come from the client, so they are only accepted when
// they match what ListDisks reports right now. The installer checks protected
// partitions again on its own side.
func FindInstallTarget(disk, rootUUID, espUUID string) (InstallDisk, bool) {
	if rootUUID == "" || espUUID == "" {
		return InstallDisk{}, false
	}
	for _, d := range ListDisks() {
		if d.Path == disk && d.PartitionsReady && d.RootUUID == rootUUID && d.EfiUUID == espUUID {
			return d, true
		}
	}
	return InstallDisk{}, false
}

// targetPartitions mirrors install_swarm_os.sh's NVMe-vs-SATA partition
// naming exactly (p1/p2 for nvme/mmcblk, 1/2 otherwise).
func targetPartitions(disk string) (efi, root string) {
	if strings.Contains(disk, "nvme") || strings.Contains(disk, "mmcblk") {
		return disk + "p1", disk + "p2"
	}
	return disk + "1", disk + "2"
}

func pathExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// installHandshake is the first (and only expected) client->server message
// on the install WebSocket, sent immediately after connecting, before any
// install output starts.
type installHandshake struct {
	// Password is the i30ltz user-account password (sudo / terminal commands).
	Password string `json:"password"`
	// AdminPassword is the SWARM OS admin login password used by the
	// Flutter lock-screen for "forgot cipher" recovery. When empty the
	// installer warns but continues; the user can set it later in Settings.
	AdminPassword string `json:"adminPassword"`
}

// HandleInstallSession runs install_swarm_os.sh --root-uuid <uuid> --esp-uuid
// <uuid> --non-interactive under sudo (see /etc/sudoers.d/20-swarm-installer
// for the NOPASSWD grant) and relays its output live over the WebSocket, same
// bidirectional-relay shape as HandleTerminalSession in terminal.go — reused
// rather than reinvented, and bidirectional (not just output) on purpose: if
// something unexpected still prompts, the operator watching the log can type
// into it rather than the whole install silently wedging.
//
// target MUST come from FindInstallTarget, which checks the client's UUIDs
// against ListDisks() — never build this from a raw client string, since it
// becomes a sudo command line.
//
// The i30ltz account password (needed when no prior install's shadow hash
// was preserved) crosses this boundary via a root-readable-only tempfile,
// NOT a `sudo VAR=value` environment passthrough — sudo's default `env_reset`
// policy strips arbitrary env vars from the elevated process, so that
// wouldn't reliably reach the script anyway. This mirrors the same
// PASSFILE pattern swarm-unseal-secrets already uses for its own passphrase.
func HandleInstallSession(conn *websocket.Conn, target InstallDisk) {
	defer conn.Close()

	_, first, err := conn.ReadMessage()
	if err != nil {
		return
	}
	var hs installHandshake
	if err := json.Unmarshal(first, &hs); err != nil {
		_ = conn.WriteMessage(websocket.TextMessage, []byte("Bad handshake: expected {\"password\": \"...\"} as the first message.\n"))
		return
	}

	args := []string{"-n", "/usr/local/bin/install_swarm_os.sh",
		"--root-uuid", target.RootUUID, "--esp-uuid", target.EfiUUID, "--non-interactive"}
	if hs.Password != "" {
		pwFile, err := os.CreateTemp("", "swarm-install-pw-*")
		if err != nil {
			_ = conn.WriteMessage(websocket.TextMessage, []byte("Could not stage password: "+err.Error()+"\n"))
			return
		}
		defer os.Remove(pwFile.Name()) // belt-and-suspenders — the script itself unlinks it right after reading
		if err := pwFile.Chmod(0o600); err != nil {
			_ = pwFile.Close()
			return
		}
		if _, err := pwFile.WriteString(hs.Password); err != nil {
			_ = pwFile.Close()
			return
		}
		_ = pwFile.Close()
		args = append(args, "--password-file", pwFile.Name())
	}
	if hs.AdminPassword != "" {
		adminPwFile, err := os.CreateTemp("", "swarm-install-adminpw-*")
		if err != nil {
			_ = conn.WriteMessage(websocket.TextMessage, []byte("Could not stage admin password: "+err.Error()+"\n"))
			return
		}
		defer os.Remove(adminPwFile.Name())
		if err := adminPwFile.Chmod(0o600); err != nil {
			_ = adminPwFile.Close()
			return
		}
		if _, err := adminPwFile.WriteString(hs.AdminPassword); err != nil {
			_ = adminPwFile.Close()
			return
		}
		_ = adminPwFile.Close()
		args = append(args, "--admin-password-file", adminPwFile.Name())
	}

	cmd := exec.Command("sudo", args...)
	cmd.Env = os.Environ()

	stdin, err := cmd.StdinPipe()
	if err != nil {
		return
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return
	}

	if err := cmd.Start(); err != nil {
		_ = conn.WriteMessage(websocket.TextMessage, []byte("Could not start installer: "+err.Error()+"\n"))
		return
	}

	done := make(chan struct{})
	var once sync.Once
	finish := func() { once.Do(func() { close(done) }) }

	go func() { // WS -> process stdin (only matters if something unexpectedly prompts)
		defer finish()
		for {
			_, data, err := conn.ReadMessage()
			if err != nil {
				return
			}
			if _, err := stdin.Write(data); err != nil {
				return
			}
		}
	}()

	go func() { defer finish(); relayToWebSocket(stdout, conn) }()
	go func() { defer finish(); relayToWebSocket(stderr, conn) }()

	go func() {
		defer finish()
		_ = cmd.Wait()
	}()

	<-done

	if cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
}
