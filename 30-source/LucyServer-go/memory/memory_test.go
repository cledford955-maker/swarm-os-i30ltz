package memory

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
)

func TestAppendSinceAndDedupe(t *testing.T) {
	s, err := Open(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	a := NewEntry("cachyos@lucille", KindNote, "", "first")
	b := NewEntry("phone-a1", KindNote, "", "second")
	if err := s.Append(a); err != nil {
		t.Fatal(err)
	}
	all, cur, err := s.Since(nil)
	if err != nil || len(all) != 1 {
		t.Fatalf("got %d entries, err %v", len(all), err)
	}
	n, err := s.Ingest([]Entry{a, b, b}) // a is known, b is repeated in the batch
	if err != nil || n != 1 {
		t.Fatalf("ingest accepted %d, err %v; want 1", n, err)
	}
	newer, _, _ := s.Since(cur)
	if len(newer) != 1 || newer[0].ID != b.ID {
		t.Fatalf("Since(cursor) = %+v, want only b", newer)
	}
	if _, err := os.Stat(filepath.Join(s.Dir(), "log", "phone-a1.jsonl")); err != nil {
		t.Fatalf("phone entry not in its own device file: %v", err)
	}
}

func TestSecondProcessWritesAreSeen(t *testing.T) {
	dir := t.TempDir()
	s1, _ := Open(dir)
	s2, _ := Open(dir) // stands in for the CLI running next to LucyServer
	if err := s2.Append(NewEntry("cachyos@lucille", KindFact, "k", "v")); err != nil {
		t.Fatal(err)
	}
	cur, err := s1.Current(KindFact)
	if err != nil || len(cur) != 1 {
		t.Fatalf("s1 sees %d facts, err %v", len(cur), err)
	}
}

func TestPartialLineIsNotConsumed(t *testing.T) {
	dir := t.TempDir()
	s, _ := Open(dir)
	e := NewEntry("dev1", KindNote, "", "whole")
	line, _ := json.Marshal(e)
	path := filepath.Join(dir, "log", "dev1.jsonl")
	os.WriteFile(path, line[:len(line)/2], 0o644) // writer is mid-line
	if s.Refresh(); s.Count() != 0 {
		t.Fatal("half a line was parsed")
	}
	os.WriteFile(path, append(line, '\n'), 0o644)
	if s.Refresh(); s.Count() != 1 {
		t.Fatal("completed line was not picked up")
	}
}

func TestCurrentAndTombstone(t *testing.T) {
	s, _ := Open(t.TempDir())
	old := NewEntry("d", KindFact, "editor", "vim")
	time.Sleep(time.Millisecond)
	newer := NewEntry("d", KindFact, "editor", "kate")
	s.Append(newer, old) // order on disk must not matter
	cur, _ := s.Current(KindFact)
	if len(cur) != 1 || cur[0].Content != "kate" {
		t.Fatalf("Current = %+v, want kate", cur)
	}
	time.Sleep(time.Millisecond)
	del := NewEntry("d", KindFact, "editor", "")
	del.Deleted = true
	s.Append(del)
	if cur, _ := s.Current(KindFact); len(cur) != 0 {
		t.Fatalf("tombstoned key still current: %+v", cur)
	}
}

func TestValidateRejectsPathTricks(t *testing.T) {
	e := NewEntry("../../etc/passwd", KindNote, "", "x")
	if e.Validate() == nil {
		t.Fatal("device id with path separators accepted")
	}
}

func TestLease(t *testing.T) {
	l := NewLeases(t.TempDir())
	now := time.Now()
	l.now = func() time.Time { return now }
	if _, err := l.Acquire("phone-a", false); err != nil {
		t.Fatal(err)
	}
	if _, err := l.Acquire("phone-b", false); err != ErrLeaseHeld {
		t.Fatalf("second device got the lease: %v", err)
	}
	if ok, _ := l.CanWriteLive("phone-b"); ok {
		t.Fatal("non-holder allowed to write live")
	}
	if _, err := l.Acquire("phone-b", true); err != nil {
		t.Fatalf("take over failed: %v", err)
	}
	now = now.Add(LeaseTTL + time.Second)
	if ls := l.Get(); ls.Holder != "" {
		t.Fatalf("lease did not expire: %+v", ls)
	}
}

func TestClaudeSyncBothWays(t *testing.T) {
	s, _ := Open(t.TempDir())
	cachy, swarm := t.TempDir(), t.TempDir() // same user, two OS installs

	os.WriteFile(filepath.Join(cachy, "MEMORY.md"), []byte("- index"), 0o644)
	os.WriteFile(filepath.Join(cachy, "user_shell.md"), []byte("fish"), 0o644)
	res, err := SyncClaudeMemory(s, "cachyos@lucille", cachy)
	if err != nil || len(res.Imported) != 2 {
		t.Fatalf("import: %+v %v", res, err)
	}

	res, _ = SyncClaudeMemory(s, "swarm@lucille", swarm)
	if len(res.Exported) != 2 {
		t.Fatalf("swarm OS did not receive both files: %+v", res)
	}

	// Edit on SWARM OS, delete on SWARM OS, then CachyOS picks both up.
	os.WriteFile(filepath.Join(swarm, "user_shell.md"), []byte("fish 4"), 0o644)
	os.Remove(filepath.Join(swarm, "MEMORY.md"))
	SyncClaudeMemory(s, "swarm@lucille", swarm)
	res, _ = SyncClaudeMemory(s, "cachyos@lucille", cachy)
	got, _ := os.ReadFile(filepath.Join(cachy, "user_shell.md"))
	if string(got) != "fish 4" {
		t.Fatalf("edit not propagated: %q (%+v)", got, res)
	}
	if _, err := os.Stat(filepath.Join(cachy, "MEMORY.md")); !os.IsNotExist(err) {
		t.Fatal("delete not propagated")
	}

	// A second run with no changes does nothing.
	res, _ = SyncClaudeMemory(s, "cachyos@lucille", cachy)
	if len(res.Imported)+len(res.Exported)+len(res.Deleted) != 0 {
		t.Fatalf("idle sync did work: %+v", res)
	}
}

// Two independent Claude Code projects (different .../projects/<name>/memory
// directories — e.g. one session working in /mnt/Lucy, another in the
// Debian homedir) each have their own MEMORY.md. Before project-namespacing
// the log key, syncing both from the same device collided: the second
// project's MEMORY.md silently overwrote the first's in the log, and the
// first project's local file on its next sync.
func TestClaudeSyncDoesNotCollideAcrossProjects(t *testing.T) {
	s, _ := Open(t.TempDir())
	root := t.TempDir()
	lucyMem := filepath.Join(root, "projects", "-mnt-Lucy", "memory")
	homeMem := filepath.Join(root, "projects", "-home-i30ltz", "memory")
	os.MkdirAll(lucyMem, 0o755)
	os.MkdirAll(homeMem, 0o755)

	os.WriteFile(filepath.Join(lucyMem, "MEMORY.md"), []byte("lucy project index"), 0o644)
	os.WriteFile(filepath.Join(homeMem, "MEMORY.md"), []byte("home project index"), 0o644)

	// Same device syncing both projects, as one Debian machine running two
	// Claude Code sessions in different working directories would.
	if res, err := SyncClaudeMemory(s, "debian@debian", lucyMem); err != nil || len(res.Imported) != 1 {
		t.Fatalf("lucy import: %+v %v", res, err)
	}
	if res, err := SyncClaudeMemory(s, "debian@debian", homeMem); err != nil || len(res.Imported) != 1 {
		t.Fatalf("home import: %+v %v", res, err)
	}

	// Each project's sync should leave the OTHER project's file untouched.
	got, _ := os.ReadFile(filepath.Join(lucyMem, "MEMORY.md"))
	if string(got) != "lucy project index" {
		t.Fatalf("lucy MEMORY.md was clobbered by the home project's sync: %q", got)
	}
	got, _ = os.ReadFile(filepath.Join(homeMem, "MEMORY.md"))
	if string(got) != "home project index" {
		t.Fatalf("home MEMORY.md was clobbered: %q", got)
	}

	// Re-syncing lucy again must still see it as unchanged, not pull in the
	// home project's content.
	res, _ := SyncClaudeMemory(s, "debian@debian", lucyMem)
	if len(res.Imported)+len(res.Exported)+len(res.Deleted) != 0 {
		t.Fatalf("idle re-sync of lucy did work (cross-project leak?): %+v", res)
	}
}

func TestClaudeSyncRefusesEscapingNames(t *testing.T) {
	s, _ := Open(t.TempDir())
	bad := NewEntry("phone-x", KindClaudeMemory, "../../.bashrc", "evil")
	s.Append(bad)
	dir := t.TempDir()
	if _, err := SyncClaudeMemory(s, "d", dir); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "..", "..", ".bashrc")); err == nil {
		t.Fatal("wrote outside the memory directory")
	}
}

func TestImportDocsOnlyOnChange(t *testing.T) {
	brains := t.TempDir()
	s, _ := Open(filepath.Join(brains, "swarm-memory"))
	os.WriteFile(filepath.Join(brains, "llcy_memory.md"), []byte("v1"), 0o644)
	if n, _ := ImportDocs(s, "d", brains); n != 1 {
		t.Fatalf("first import = %d", n)
	}
	if n, _ := ImportDocs(s, "d", brains); n != 0 {
		t.Fatalf("unchanged import = %d", n)
	}
	os.WriteFile(filepath.Join(brains, "llcy_memory.md"), []byte("v2"), 0o644)
	if n, _ := ImportDocs(s, "d", brains); n != 1 {
		t.Fatalf("changed import = %d", n)
	}
}

// Two stores syncing through HTTP converge, including gossip of a third
// device's entries, and a live write is refused while another device is main.
func TestPeerSyncOverHTTP(t *testing.T) {
	serverStore, _ := Open(t.TempDir())
	api := &API{Store: serverStore, Leases: NewLeases(serverStore.Dir()), Device: "swarm@lucille"}
	r := chi.NewRouter()
	r.Use(TokenOnly(func() string { return "tok" }))
	r.Route("/api/memory", api.Routes)
	srv := httptest.NewServer(r)
	defer srv.Close()

	phone, _ := Open(t.TempDir())
	phone.Append(NewEntry("phone-a", KindNote, "", "from phone"))
	phone.Ingest([]Entry{NewEntry("phone-b", KindNote, "", "gossiped from phone b")})
	serverStore.Append(NewEntry("swarm@lucille", KindDecision, "sync", "append-only"))

	if res := SyncWithPeer(phone, "phone-a", srv.URL, "wrong"); res.Err == nil {
		t.Fatal("wrong token accepted")
	}
	res := SyncWithPeer(phone, "phone-a", srv.URL, "tok")
	if res.Err != nil || res.Pulled != 1 || res.Pushed != 3 {
		t.Fatalf("sync = %+v", res)
	}
	if serverStore.Count() != 3 || phone.Count() != 3 {
		t.Fatalf("not converged: server %d phone %d", serverStore.Count(), phone.Count())
	}
	if res := SyncWithPeer(phone, "phone-a", srv.URL, "tok"); res.Pulled != 0 || res.Pushed != 0 {
		t.Fatalf("idle sync moved data: %+v", res)
	}

	api.Leases.Acquire("phone-b", false)
	req, _ := http.NewRequest(http.MethodPost, srv.URL+"/api/memory/entries", strings.NewReader(`{"device":"phone-a","content":"live"}`))
	req.Header.Set("X-Swarm-Auth", "tok")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusConflict {
		t.Fatalf("live write while phone-b is main = %d, want 409", resp.StatusCode)
	}
}

func TestRender(t *testing.T) {
	s, _ := Open(t.TempDir())
	s.Append(NewEntry("d", KindDecision, "no-web-shell", "Native UI only."), NewEntry("d", KindNote, "", "hello"))
	if err := RenderProjectMemory(s); err != nil {
		t.Fatal(err)
	}
	data, _ := os.ReadFile(filepath.Join(s.Dir(), "PROJECT_MEMORY.md"))
	if !strings.Contains(string(data), "Native UI only.") || !strings.Contains(string(data), "hello") {
		t.Fatalf("render missing content:\n%s", data)
	}
}
