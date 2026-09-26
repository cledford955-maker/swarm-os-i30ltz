// Package handlers — OTA update check.
//
// Compares the running SWARM OS version against the newest ISO published to
// the Ventoy release store (/mnt/ventoy/ISO/SWARM_OS/, tracked by latest.txt).
// The check is read-only; installing the ISO stays a deliberate user action
// (Ventoy boot menu, not a background update).
package handlers

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"swarm-os/lucy-server/services"
)

// releaseStorePaths lists candidate roots for published ISOs. Checked in
// order; the first extant one wins. Overridable in tests via SWARM_RELEASE_STORE.
func releaseStorePaths() []string {
	if custom := os.Getenv("SWARM_RELEASE_STORE"); custom != "" {
		return []string{custom}
	}
	return []string{
		"/mnt/ventoy/ISO/SWARM_OS",
		"/mnt/Lucy/10-releases",
	}
}

// versionFilePaths lists candidate roots for the running version. First hit wins.
func versionFilePaths() []string {
	if custom := os.Getenv("SWARM_VERSION_FILE"); custom != "" {
		return []string{custom}
	}
	return []string{
		"/etc/swarm-release", // installed system
		"/mnt/Lucy/VERSION",  // source of truth on build host
	}
}

var isoVersionRE = regexp.MustCompile(`swarm[-_]os[-_]v?(\d+)\.(\d+)\.(\d+)`)

// semverTriple is a comparable (major, minor, patch) tuple.
type semverTriple struct{ major, minor, patch int }

func (a semverTriple) less(b semverTriple) bool {
	if a.major != b.major {
		return a.major < b.major
	}
	if a.minor != b.minor {
		return a.minor < b.minor
	}
	return a.patch < b.patch
}

func (a semverTriple) String() string {
	return strconv.Itoa(a.major) + "." + strconv.Itoa(a.minor) + "." + strconv.Itoa(a.patch)
}

// parseSemver extracts a semver triple from a free-form string (either a bare
// "6.2.72" or an ISO filename). Returns (triple, true) on match.
func parseSemver(s string) (semverTriple, bool) {
	s = strings.TrimSpace(s)
	if m := isoVersionRE.FindStringSubmatch(strings.ToLower(s)); m != nil {
		maj, _ := strconv.Atoi(m[1])
		min, _ := strconv.Atoi(m[2])
		pat, _ := strconv.Atoi(m[3])
		return semverTriple{maj, min, pat}, true
	}
	parts := strings.SplitN(s, ".", 4)
	if len(parts) < 3 {
		return semverTriple{}, false
	}
	// Trim leading v/V.
	parts[0] = strings.TrimPrefix(strings.TrimPrefix(parts[0], "v"), "V")
	maj, err1 := strconv.Atoi(parts[0])
	min, err2 := strconv.Atoi(parts[1])
	// Take digits from parts[2] up to first non-digit (handles "72-abc" or "72+build").
	end := len(parts[2])
	for i, r := range parts[2] {
		if r < '0' || r > '9' {
			end = i
			break
		}
	}
	pat, err3 := strconv.Atoi(parts[2][:end])
	if err1 != nil || err2 != nil || err3 != nil {
		return semverTriple{}, false
	}
	return semverTriple{maj, min, pat}, true
}

// readCurrentVersion returns the running SWARM OS version. Prefers SWARM_VERSION
// env, then /etc/swarm-release (KEY=VALUE), then /mnt/Lucy/VERSION.
func readCurrentVersion() string {
	if v := strings.TrimSpace(os.Getenv("SWARM_VERSION")); v != "" {
		return v
	}
	for _, p := range versionFilePaths() {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		content := string(data)
		// /etc/swarm-release is `SWARM_VERSION=x.y.z\nSWARM_COMMIT=...`. Extract if present.
		if strings.Contains(content, "SWARM_VERSION=") {
			for _, line := range strings.Split(content, "\n") {
				if strings.HasPrefix(line, "SWARM_VERSION=") {
					return strings.TrimSpace(strings.TrimPrefix(line, "SWARM_VERSION="))
				}
			}
		}
		if v := strings.TrimSpace(content); v != "" {
			return v
		}
	}
	return "unknown"
}

// isoRelease describes a single published ISO.
type isoRelease struct {
	Filename  string `json:"filename"`
	Version   string `json:"version"`
	Path      string `json:"path"`
	SizeBytes int64  `json:"size_bytes"`
	SHA256    string `json:"sha256,omitempty"`
	ModTime   string `json:"mod_time"`
}

// scanReleases walks the release store and returns the newest ISO by semver.
// Missing/unreadable stores are skipped, not fatal. Returns (release, true) if
// at least one parseable ISO was found.
func scanReleases() (isoRelease, bool) {
	var best isoRelease
	var bestVer semverTriple
	found := false

	for _, root := range releaseStorePaths() {
		entries, err := os.ReadDir(root)
		if err != nil {
			continue
		}
		// latest.txt short-circuits: if it points to an ISO in this dir, prefer it.
		if data, err := os.ReadFile(filepath.Join(root, "latest.txt")); err == nil {
			name := strings.TrimSpace(string(data))
			full := filepath.Join(root, name)
			if info, err := os.Stat(full); err == nil && !info.IsDir() {
				if ver, ok := parseSemver(name); ok {
					if !found || bestVer.less(ver) {
						best = isoRelease{
							Filename:  name,
							Version:   ver.String(),
							Path:      full,
							SizeBytes: info.Size(),
							SHA256:    readSidecarSHA256(full),
							ModTime:   info.ModTime().UTC().Format(time.RFC3339),
						}
						bestVer = ver
						found = true
					}
				}
			}
		}
		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}
			name := entry.Name()
			if !strings.HasSuffix(strings.ToLower(name), ".iso") {
				continue
			}
			ver, ok := parseSemver(name)
			if !ok {
				continue
			}
			if !found || bestVer.less(ver) {
				info, err := entry.Info()
				if err != nil {
					continue
				}
				full := filepath.Join(root, name)
				best = isoRelease{
					Filename:  name,
					Version:   ver.String(),
					Path:      full,
					SizeBytes: info.Size(),
					SHA256:    readSidecarSHA256(full),
					ModTime:   info.ModTime().UTC().Format(time.RFC3339),
				}
				bestVer = ver
				found = true
			}
		}
	}
	return best, found
}

// readSidecarSHA256 reads a `<iso>.sha256` file if present. Returns "" when
// absent or unreadable — the checksum sidecar is optional (older ISOs pre-2026-09-24
// don't have one).
func readSidecarSHA256(isoPath string) string {
	data, err := os.ReadFile(isoPath + ".sha256")
	if err != nil {
		return ""
	}
	// The file is either `<hex>` alone or `<hex>  <filename>` (sha256sum format).
	fields := strings.Fields(strings.TrimSpace(string(data)))
	if len(fields) == 0 {
		return ""
	}
	return fields[0]
}

// UpdatesCheck handles GET /api/updates/check.
//
// Response:
//
//	{
//	  "current_version":  "6.2.72",
//	  "latest_version":   "6.2.75",
//	  "update_available": true,
//	  "latest_iso": {
//	    "filename":   "swarm-os-v6.2.75-<commit>-<date>-x86_64.iso",
//	    "version":    "6.2.75",
//	    "path":       "/mnt/ventoy/ISO/SWARM_OS/swarm-os-v6.2.75-...iso",
//	    "size_bytes": 3221225472,
//	    "sha256":     "abc...",
//	    "mod_time":   "2026-09-25T12:34:56Z"
//	  },
//	  "checked_at": "2026-09-25T12:34:56Z"
//	}
//
// When no release store is mounted or no parseable ISO is found, latest_iso is
// null and update_available is false — the endpoint never fabricates.
func UpdatesCheck(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	current := readCurrentVersion()
	resp := map[string]any{
		"current_version":  current,
		"checked_at":       time.Now().UTC().Format(time.RFC3339),
		"update_available": false,
		"latest_iso":       nil,
		"latest_version":   nil,
	}

	release, ok := scanReleases()
	if !ok {
		json.NewEncoder(w).Encode(resp)
		return
	}

	resp["latest_iso"] = release
	resp["latest_version"] = release.Version

	// update_available only when we can parse both sides.
	curVer, curOK := parseSemver(current)
	newVer, newOK := parseSemver(release.Version)
	updateAvail := curOK && newOK && curVer.less(newVer)
	if updateAvail {
		resp["update_available"] = true
		// Push to any connected companion phones — de-duped so repeat polls
		// don't spam a phone with the same notification. See broadcast helper.
		maybeBroadcastUpdate(current, release)
	}
	json.NewEncoder(w).Encode(resp)
}

// lastBroadcastMu / lastBroadcastVersion de-duplicate OTA push notifications.
// The first time /api/updates/check sees a newer ISO than the running system,
// we push to companions; subsequent checks for the same version stay silent
// until the ISO changes or the LucyServer process restarts.
var (
	lastBroadcastMu      sync.Mutex
	lastBroadcastVersion string
)

func maybeBroadcastUpdate(currentVersion string, release isoRelease) {
	lastBroadcastMu.Lock()
	defer lastBroadcastMu.Unlock()
	if lastBroadcastVersion == release.Version {
		return
	}
	lastBroadcastVersion = release.Version

	services.GetCompanionHub().Broadcast(map[string]any{
		"type":            "swarm_os_update_available",
		"current_version": currentVersion,
		"latest_version":  release.Version,
		"filename":        release.Filename,
		"size_bytes":      release.SizeBytes,
		"sha256":          release.SHA256,
		"at":              time.Now().UTC().Format(time.RFC3339),
	})
}
