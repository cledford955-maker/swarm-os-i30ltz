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
		disks = append(disks, InstallDisk{
			Path:            path,
			SizeBytes:       sizeBytes,
			SizeHuman:       sizeHuman,
			Model:           model,
			HasLuks:         luksSet[path[strings.LastIndex(path, "/")+1:]],
			PartitionsReady: pathExists(efi) && pathExists(root),
		})
	}
	return disks
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
	Password string `json:"password"`
}

// HandleInstallSession runs install_swarm_os.sh --disk <disk> --non-interactive
// under sudo (see /etc/sudoers.d/20-swarm-installer for the scoped NOPASSWD
// grant this depends on) and relays its output live over the WebSocket, same
// bidirectional-relay shape as HandleTerminalSession in terminal.go — reused
// rather than reinvented, and bidirectional (not just output) on purpose: if
// something unexpected still prompts, the operator watching the log can type
// into it rather than the whole install silently wedging.
//
// disk MUST already be validated by the caller (handlers/install.go) against
// the exact set ListDisks() just returned — never pass through a raw client
// string un-checked, this becomes a sudo command line.
//
// The i30ltz account password (needed when no prior install's shadow hash
// was preserved) crosses this boundary via a root-readable-only tempfile,
// NOT a `sudo VAR=value` environment passthrough — sudo's default `env_reset`
// policy strips arbitrary env vars from the elevated process, so that
// wouldn't reliably reach the script anyway. This mirrors the same
// PASSFILE pattern swarm-unseal-secrets already uses for its own passphrase.
func HandleInstallSession(conn *websocket.Conn, disk string) {
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

	args := []string{"-n", "/usr/local/bin/install_swarm_os.sh", "--disk", disk, "--non-interactive"}
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
