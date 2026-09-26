package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestParseSemver(t *testing.T) {
	cases := []struct {
		in    string
		want  semverTriple
		match bool
	}{
		{"6.2.72", semverTriple{6, 2, 72}, true},
		{"v6.2.72", semverTriple{6, 2, 72}, true},
		{"swarm-os-v6.2.75-abc12345-2026.09.25-x86_64.iso", semverTriple{6, 2, 75}, true},
		{"SWARM_OS_v6.2.66.iso", semverTriple{6, 2, 66}, true},
		{"6.2.72+build.5", semverTriple{6, 2, 72}, true},
		{"6.2", semverTriple{}, false},
		{"", semverTriple{}, false},
		{"nonsense", semverTriple{}, false},
	}
	for _, c := range cases {
		got, ok := parseSemver(c.in)
		if ok != c.match {
			t.Errorf("parseSemver(%q) match=%v, want %v", c.in, ok, c.match)
			continue
		}
		if ok && got != c.want {
			t.Errorf("parseSemver(%q) = %v, want %v", c.in, got, c.want)
		}
	}
}

func TestSemverLess(t *testing.T) {
	a := semverTriple{6, 2, 72}
	b := semverTriple{6, 2, 75}
	c := semverTriple{6, 3, 0}
	d := semverTriple{7, 0, 0}
	if !a.less(b) {
		t.Error("6.2.72 should be < 6.2.75")
	}
	if !b.less(c) {
		t.Error("6.2.75 should be < 6.3.0")
	}
	if !c.less(d) {
		t.Error("6.3.0 should be < 7.0.0")
	}
	if a.less(a) {
		t.Error("equal versions must not be less")
	}
}

// helper: build a fake release store with the given ISO filenames.
func makeFakeStore(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := t.TempDir()
	for name, content := range files {
		full := filepath.Join(dir, name)
		if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

func TestUpdatesCheck_NoStore(t *testing.T) {
	// Point at an empty directory.
	t.Setenv("SWARM_RELEASE_STORE", t.TempDir())
	t.Setenv("SWARM_VERSION", "6.2.72")

	req := httptest.NewRequest(http.MethodGet, "/api/updates/check", nil)
	rec := httptest.NewRecorder()
	UpdatesCheck(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["update_available"] != false {
		t.Errorf("update_available = %v, want false", body["update_available"])
	}
	if body["latest_iso"] != nil {
		t.Errorf("latest_iso = %v, want nil", body["latest_iso"])
	}
	if body["current_version"] != "6.2.72" {
		t.Errorf("current_version = %v", body["current_version"])
	}
}

func TestUpdatesCheck_UpdateAvailable(t *testing.T) {
	dir := makeFakeStore(t, map[string]string{
		"swarm-os-v6.2.66.iso":               "fake66",
		"swarm-os-v6.2.72.iso":               "fake72",
		"swarm-os-v6.2.75-abc-x86_64.iso":    "fake75",
		"swarm-os-v6.2.75-abc-x86_64.iso.sha256": "deadbeef1234  swarm-os-v6.2.75-abc-x86_64.iso\n",
		"latest.txt":                         "swarm-os-v6.2.75-abc-x86_64.iso\n",
	})
	t.Setenv("SWARM_RELEASE_STORE", dir)
	t.Setenv("SWARM_VERSION", "6.2.72")

	req := httptest.NewRequest(http.MethodGet, "/api/updates/check", nil)
	rec := httptest.NewRecorder()
	UpdatesCheck(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", rec.Code)
	}
	var body struct {
		CurrentVersion  string      `json:"current_version"`
		LatestVersion   string      `json:"latest_version"`
		UpdateAvailable bool        `json:"update_available"`
		LatestISO       *isoRelease `json:"latest_iso"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.CurrentVersion != "6.2.72" {
		t.Errorf("current = %s, want 6.2.72", body.CurrentVersion)
	}
	if body.LatestVersion != "6.2.75" {
		t.Errorf("latest = %s, want 6.2.75", body.LatestVersion)
	}
	if !body.UpdateAvailable {
		t.Error("update_available should be true")
	}
	if body.LatestISO == nil {
		t.Fatal("latest_iso should be populated")
	}
	if body.LatestISO.SHA256 != "deadbeef1234" {
		t.Errorf("sha256 = %q, want deadbeef1234", body.LatestISO.SHA256)
	}
	if body.LatestISO.Filename != "swarm-os-v6.2.75-abc-x86_64.iso" {
		t.Errorf("filename = %q", body.LatestISO.Filename)
	}
}

func TestUpdatesCheck_UpToDate(t *testing.T) {
	dir := makeFakeStore(t, map[string]string{
		"swarm-os-v6.2.72.iso": "fake",
	})
	t.Setenv("SWARM_RELEASE_STORE", dir)
	t.Setenv("SWARM_VERSION", "6.2.72")

	req := httptest.NewRequest(http.MethodGet, "/api/updates/check", nil)
	rec := httptest.NewRecorder()
	UpdatesCheck(rec, req)

	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["update_available"] != false {
		t.Errorf("update_available = %v, want false (running == latest)", body["update_available"])
	}
	if body["latest_version"] != "6.2.72" {
		t.Errorf("latest_version = %v, want 6.2.72", body["latest_version"])
	}
}

func TestUpdatesCheck_OlderVersionInStoreIgnored(t *testing.T) {
	// Store has a newer AND an older ISO; latest.txt correctly points to the
	// newer one. We must pick the newer, not just what latest.txt says (defense
	// against a stale latest.txt).
	dir := makeFakeStore(t, map[string]string{
		"swarm-os-v6.2.66.iso":            "old",
		"swarm-os-v6.2.75.iso":            "new",
		"swarm-os-v6.2.75.iso.sha256":     "beef  swarm-os-v6.2.75.iso\n",
		"latest.txt":                      "swarm-os-v6.2.66.iso\n", // stale
	})
	t.Setenv("SWARM_RELEASE_STORE", dir)
	t.Setenv("SWARM_VERSION", "6.2.72")

	req := httptest.NewRequest(http.MethodGet, "/api/updates/check", nil)
	rec := httptest.NewRecorder()
	UpdatesCheck(rec, req)

	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["latest_version"] != "6.2.75" {
		t.Errorf("latest_version = %v, want 6.2.75 (must beat stale latest.txt)", body["latest_version"])
	}
	if body["update_available"] != true {
		t.Error("update_available should be true")
	}
}

func TestUpdatesCheck_UnknownRunningVersion(t *testing.T) {
	dir := makeFakeStore(t, map[string]string{
		"swarm-os-v6.2.75.iso": "fake",
	})
	t.Setenv("SWARM_RELEASE_STORE", dir)
	t.Setenv("SWARM_VERSION", "unknown")
	// Also point away from real version files.
	t.Setenv("SWARM_VERSION_FILE", filepath.Join(t.TempDir(), "no-such-file"))

	req := httptest.NewRequest(http.MethodGet, "/api/updates/check", nil)
	rec := httptest.NewRecorder()
	UpdatesCheck(rec, req)

	var body map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	// latest_version populated, but update_available stays false when we can't
	// parse the running version — no fabrication.
	if body["latest_version"] != "6.2.75" {
		t.Errorf("latest_version = %v", body["latest_version"])
	}
	if body["update_available"] != false {
		t.Errorf("update_available = %v, want false when current is 'unknown'", body["update_available"])
	}
}

func TestMaybeBroadcastUpdate_DedupesSameVersion(t *testing.T) {
	// Reset dedup state so this test doesn't depend on order.
	lastBroadcastMu.Lock()
	lastBroadcastVersion = ""
	lastBroadcastMu.Unlock()

	release := isoRelease{Version: "6.2.75", Filename: "swarm-os-v6.2.75.iso", SizeBytes: 100}

	// First call: should update the recorded version.
	maybeBroadcastUpdate("6.2.72", release)
	lastBroadcastMu.Lock()
	v1 := lastBroadcastVersion
	lastBroadcastMu.Unlock()
	if v1 != "6.2.75" {
		t.Errorf("first call: lastBroadcastVersion = %q, want 6.2.75", v1)
	}

	// Second call with same release: state should NOT advance (no reset). We
	// can't easily observe "no broadcast" without a hub mock, but we can
	// verify the version field is unchanged, which is the dedup invariant.
	maybeBroadcastUpdate("6.2.72", release)
	lastBroadcastMu.Lock()
	v2 := lastBroadcastVersion
	lastBroadcastMu.Unlock()
	if v2 != v1 {
		t.Errorf("dedup: lastBroadcastVersion mutated between identical calls (%q → %q)", v1, v2)
	}

	// Third call with a newer release: state should advance.
	release2 := isoRelease{Version: "6.2.80", Filename: "swarm-os-v6.2.80.iso"}
	maybeBroadcastUpdate("6.2.72", release2)
	lastBroadcastMu.Lock()
	v3 := lastBroadcastVersion
	lastBroadcastMu.Unlock()
	if v3 != "6.2.80" {
		t.Errorf("newer release: lastBroadcastVersion = %q, want 6.2.80", v3)
	}
}

func TestReadSidecarSHA256(t *testing.T) {
	dir := t.TempDir()
	iso := filepath.Join(dir, "a.iso")
	os.WriteFile(iso, []byte("x"), 0o644)
	os.WriteFile(iso+".sha256", []byte("abc123def  a.iso\n"), 0o644)

	if got := readSidecarSHA256(iso); got != "abc123def" {
		t.Errorf("readSidecarSHA256 = %q, want abc123def", got)
	}

	// Missing sidecar → "".
	iso2 := filepath.Join(dir, "b.iso")
	os.WriteFile(iso2, []byte("x"), 0o644)
	if got := readSidecarSHA256(iso2); got != "" {
		t.Errorf("readSidecarSHA256 missing = %q, want empty", got)
	}
}
