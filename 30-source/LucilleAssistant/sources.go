package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"
)

// ── tiny TTL cache so the phone can refresh freely ──────────────

type cacheEntry struct {
	at  time.Time
	val any
}

type cache struct {
	mu sync.Mutex
	m  map[string]cacheEntry
}

func newCache() *cache { return &cache{m: map[string]cacheEntry{}} }

func (c *cache) get(key string, ttl time.Duration, fn func() (any, error)) (any, error) {
	c.mu.Lock()
	e, ok := c.m[key]
	c.mu.Unlock()
	if ok && time.Since(e.at) < ttl {
		return e.val, nil
	}
	v, err := fn()
	if err != nil {
		if ok {
			return e.val, nil // stale beats nothing
		}
		return nil, err
	}
	c.mu.Lock()
	c.m[key] = cacheEntry{time.Now(), v}
	c.mu.Unlock()
	return v, nil
}

var httpc = &http.Client{Timeout: 8 * time.Second}

func getJSON(ctx context.Context, u string, v any) error {
	req, _ := http.NewRequestWithContext(ctx, "GET", u, nil)
	req.Header.Set("User-Agent", "lucille-assistant/"+version+" (SWARM OS)")
	resp, err := httpc.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 300))
		return fmt.Errorf("%s: HTTP %d %s", u, resp.StatusCode, strings.TrimSpace(string(b)))
	}
	return json.NewDecoder(resp.Body).Decode(v)
}

// ── Git ─────────────────────────────────────────────────────────

type RepoStatus struct {
	Path       string   `json:"path"`
	Branch     string   `json:"branch"`
	Ahead      int      `json:"ahead"`
	Behind     int      `json:"behind"`
	Dirty      int      `json:"dirty"`
	Untracked  int      `json:"untracked"`
	LastCommit string   `json:"last_commit"`
	LastWhen   string   `json:"last_when"`
	Changed    []string `json:"changed"`
	Error      string   `json:"error,omitempty"`
}

func git(dir string, args ...string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "git", append([]string{"-C", dir}, args...)...)
	out, err := cmd.Output()
	return strings.TrimRight(string(out), "\n"), err
}

func repoStatus(dir string) RepoStatus {
	rs := RepoStatus{Path: dir}
	out, err := git(dir, "status", "--porcelain=v1", "-b")
	if err != nil {
		rs.Error = "not a git repo or git failed"
		return rs
	}
	for i, line := range strings.Split(out, "\n") {
		if i == 0 && strings.HasPrefix(line, "## ") {
			head := strings.TrimPrefix(line, "## ")
			rs.Branch = strings.SplitN(head, "...", 2)[0]
			if j := strings.Index(head, "["); j >= 0 {
				fmt.Sscanf(extract(head[j:], "ahead "), "%d", &rs.Ahead)
				fmt.Sscanf(extract(head[j:], "behind "), "%d", &rs.Behind)
			}
			continue
		}
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "??") {
			rs.Untracked++
		} else {
			rs.Dirty++
		}
		if len(rs.Changed) < 8 {
			rs.Changed = append(rs.Changed, strings.TrimSpace(line[2:]))
		}
	}
	if log, err := git(dir, "log", "-1", "--format=%s\x1f%cr"); err == nil {
		p := strings.SplitN(log, "\x1f", 2)
		rs.LastCommit = p[0]
		if len(p) > 1 {
			rs.LastWhen = p[1]
		}
	}
	return rs
}

func extract(s, prefix string) string {
	if i := strings.Index(s, prefix); i >= 0 {
		return s[i+len(prefix):]
	}
	return ""
}

func (a *App) gitAll() []RepoStatus {
	out := make([]RepoStatus, len(a.cfg.Repos))
	var wg sync.WaitGroup
	for i, r := range a.cfg.Repos {
		wg.Add(1)
		go func() { defer wg.Done(); out[i] = repoStatus(r) }()
	}
	wg.Wait()
	return out
}

func (a *App) handleGit(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"ok": true, "repos": a.gitAll()})
}

// ── Local drives ────────────────────────────────────────────────

type DriveUsage struct {
	Mount   string  `json:"mount"`
	Mounted bool    `json:"mounted"`
	Device  string  `json:"device,omitempty"`
	FS      string  `json:"fs,omitempty"`
	TotalGB float64 `json:"total_gb"`
	UsedGB  float64 `json:"used_gb"`
	FreeGB  float64 `json:"free_gb"`
	UsedPct float64 `json:"used_pct"`
}

func mountTable() map[string][2]string {
	m := map[string][2]string{}
	f, err := os.Open("/proc/mounts")
	if err != nil {
		return m
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		p := strings.Fields(sc.Text())
		if len(p) >= 3 {
			m[strings.ReplaceAll(p[1], `\040`, " ")] = [2]string{p[0], p[2]}
		}
	}
	return m
}

func (a *App) drives() []DriveUsage {
	mt := mountTable()
	var out []DriveUsage
	for _, mnt := range a.cfg.Mounts {
		d := DriveUsage{Mount: mnt}
		if info, ok := mt[mnt]; ok {
			d.Mounted, d.Device, d.FS = true, info[0], info[1]
			var st syscall.Statfs_t
			if syscall.Statfs(mnt, &st) == nil {
				bs := float64(st.Bsize)
				d.TotalGB = float64(st.Blocks) * bs / 1e9
				d.FreeGB = float64(st.Bavail) * bs / 1e9
				d.UsedGB = d.TotalGB - float64(st.Bfree)*bs/1e9
				if d.TotalGB > 0 {
					d.UsedPct = 100 * d.UsedGB / d.TotalGB
				}
			}
		}
		out = append(out, d)
	}
	return out
}

func (a *App) handleDrives(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"ok": true, "drives": a.drives()})
}

// ── Google Workspace (mail, calendar, Drive) via GoogleWorkspaceService :8399

func (a *App) google(ctx context.Context, path string) (map[string]any, error) {
	var v map[string]any
	if err := getJSON(ctx, strings.TrimRight(a.cfg.GoogleURL, "/")+path, &v); err != nil {
		return nil, fmt.Errorf("Google Workspace service isn't answering on %s — start GoogleWorkspaceService and sign in (%v)", a.cfg.GoogleURL, err)
	}
	return v, nil
}

func (a *App) proxyGoogle(w http.ResponseWriter, r *http.Request, paths map[string]string) {
	out := map[string]any{"ok": true}
	for key, p := range paths {
		v, err := a.google(r.Context(), p)
		if err != nil {
			writeJSON(w, map[string]any{"ok": false, "connected": false, "error": err.Error()})
			return
		}
		out[key] = v
	}
	out["connected"] = true
	writeJSON(w, out)
}

func (a *App) handleMail(w http.ResponseWriter, r *http.Request) {
	a.proxyGoogle(w, r, map[string]string{
		"unread": "/gmail/unread",
		"inbox":  "/gmail/inbox?maxResults=10&unreadOnly=true",
	})
}

func (a *App) handleCalendar(w http.ResponseWriter, r *http.Request) {
	days := r.URL.Query().Get("days")
	if days == "" {
		days = "2"
	}
	a.proxyGoogle(w, r, map[string]string{
		"events": "/cal/events?maxResults=15&daysAhead=" + url.QueryEscape(days) + "&calendarId=primary",
	})
}

func (a *App) handleGDrive(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query().Get("q")
	p := "/drive/list?maxResults=12"
	if q != "" {
		p = "/drive/search?maxResults=12&q=" + url.QueryEscape(q)
	}
	a.proxyGoogle(w, r, map[string]string{"files": p, "quota": "/drive/quota"})
}

// ── Shared memory (/mnt/brains/swarm-memory) ────────────────────

type MemEntry struct {
	ID      string `json:"id"`
	Device  string `json:"device"`
	TS      string `json:"ts"`
	Kind    string `json:"kind"`
	Key     string `json:"key,omitempty"`
	Content string `json:"content"`
}

func (a *App) memory(limit int, kind string) ([]MemEntry, error) {
	files, err := filepath.Glob(filepath.Join(a.cfg.MemoryDir, "log", "*.jsonl"))
	if err != nil || len(files) == 0 {
		return nil, fmt.Errorf("no shared memory log at %s/log", a.cfg.MemoryDir)
	}
	all := []MemEntry{}
	for _, f := range files {
		fh, err := os.Open(f)
		if err != nil {
			continue
		}
		sc := bufio.NewScanner(fh)
		sc.Buffer(make([]byte, 1<<20), 8<<20)
		for sc.Scan() {
			var e MemEntry
			if json.Unmarshal(sc.Bytes(), &e) == nil {
				if kind == "" && e.Kind == "claude_memory" {
					continue // the raw Claude memory files are noise in a brief
				}
				if kind != "" && e.Kind != kind {
					continue
				}
				all = append(all, e)
			}
		}
		fh.Close()
	}
	sort.Slice(all, func(i, j int) bool { return all[i].TS > all[j].TS })
	if len(all) > limit {
		all = all[:limit]
	}
	return all, nil
}

func (a *App) handleMemory(w http.ResponseWriter, r *http.Request) {
	entries, err := a.memory(25, r.URL.Query().Get("kind"))
	if err != nil {
		writeJSON(w, map[string]any{"ok": false, "error": err.Error()})
		return
	}
	writeJSON(w, map[string]any{"ok": true, "entries": entries})
}

func (a *App) handleMemoryAdd(w http.ResponseWriter, r *http.Request) {
	var req struct{ Kind, Key, Text string }
	if err := readJSON(r, &req); err != nil || strings.TrimSpace(req.Text) == "" {
		writeErr(w, 400, `Send {"kind": "note|fact|decision", "key": "optional-topic", "text": "..."}.`)
		return
	}
	switch req.Kind {
	case "note", "fact", "decision":
	default:
		req.Kind = "note"
	}
	args := []string{"add", "-kind", req.Kind, "-tag", "lucille-assistant"}
	if req.Key != "" {
		args = append(args, "-key", req.Key)
	}
	args = append(args, "-")
	bin, err := exec.LookPath("swarm-memory")
	if err != nil {
		home, _ := os.UserHomeDir()
		bin = filepath.Join(home, ".local/bin/swarm-memory")
	}
	cmd := exec.CommandContext(r.Context(), bin, args...)
	cmd.Stdin = strings.NewReader(req.Text)
	out, err := cmd.CombinedOutput()
	if err != nil {
		writeErr(w, 500, fmt.Sprintf("swarm-memory add failed: %v %s", err, out))
		return
	}
	writeJSON(w, map[string]any{"ok": true, "output": strings.TrimSpace(string(out))})
}
