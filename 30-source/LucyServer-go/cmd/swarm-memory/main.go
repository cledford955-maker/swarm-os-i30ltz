// swarm-memory — command-line access to the SWARM OS shared memory.
//
// Version 1.0.0 — 2026-09-16. Works directly on /mnt/brains/swarm-memory, so it
// runs on CachyOS, SWARM OS and EndeavourOS with or without LucyServer.
package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"swarm-os/lucy-server/memory"
)

const version = "1.0.0"

const usage = `swarm-memory ` + version + ` — SWARM OS shared memory

Usage:
  swarm-memory add [-kind note|fact|decision] [-key KEY] [-tag T] TEXT   (TEXT "-" reads stdin)
  swarm-memory list [-kind K] [-q TEXT] [-limit N]
  swarm-memory current [-kind K]
  swarm-memory import-docs [-brains /mnt/brains]
  swarm-memory claude [-dir ~/.claude/projects/-mnt-Lucy/memory]
  swarm-memory sync [-peer URL ...]          peers default to peers.json
  swarm-memory render                        regenerate PROJECT_MEMORY.md
  swarm-memory tick                          import-docs + claude + sync + render
  swarm-memory mirror DEST                   copy the memory into a git checkout
  swarm-memory status

Environment:
  SWARM_MEMORY_DIR (default /mnt/brains/swarm-memory)  SWARM_DEVICE_ID
  SWARM_CLAUDE_MEMORY_DIR  SWARM_AUTH_TOKEN  SWARM_MEMORY_PEERS (comma-separated)
`

type multi []string

func (m *multi) String() string     { return strings.Join(*m, ",") }
func (m *multi) Set(v string) error { *m = append(*m, v); return nil }

func main() {
	if len(os.Args) < 2 || os.Args[1] == "-h" || os.Args[1] == "--help" || os.Args[1] == "help" {
		fmt.Print(usage)
		return
	}
	if os.Args[1] == "version" {
		fmt.Println(version)
		return
	}
	cmd, args := os.Args[1], os.Args[2:]
	store, err := memory.Open(memory.DefaultDir())
	if err != nil {
		die("cannot open %s: %v (is /mnt/brains mounted and writable?)", memory.DefaultDir(), err)
	}
	device := memory.LocalDeviceID()

	switch cmd {
	case "add":
		fsx := flag.NewFlagSet("add", flag.ExitOnError)
		kind := fsx.String("kind", memory.KindNote, "entry kind")
		key := fsx.String("key", "", "key: a newer entry with the same kind+key supersedes this one")
		var tags multi
		fsx.Var(&tags, "tag", "tag (repeatable)")
		fsx.Parse(args)
		text := strings.Join(fsx.Args(), " ")
		if text == "-" {
			data, _ := io.ReadAll(os.Stdin)
			text = string(data)
		}
		if strings.TrimSpace(text) == "" {
			die("nothing to add — pass the memory as text, or - to read stdin")
		}
		e := memory.NewEntry(device, *kind, *key, text)
		e.Tags = tags
		check(store.Append(e))
		check(memory.RenderProjectMemory(store))
		fmt.Printf("Added %s %s from %s\n", e.Kind, e.ID, device)

	case "list":
		fsx := flag.NewFlagSet("list", flag.ExitOnError)
		kind := fsx.String("kind", "", "only this kind")
		q := fsx.String("q", "", "text search")
		limit := fsx.Int("limit", 20, "max entries")
		fsx.Parse(args)
		entries, err := store.Query(memory.Query{Kind: *kind, Text: *q, Limit: *limit})
		check(err)
		for _, e := range entries {
			printEntry(e)
		}

	case "current":
		fsx := flag.NewFlagSet("current", flag.ExitOnError)
		kind := fsx.String("kind", "", "only this kind")
		fsx.Parse(args)
		entries, err := store.Current(*kind)
		check(err)
		for _, e := range entries {
			fmt.Printf("%-14s %-40s %6d bytes  %s  %s\n", e.Kind, e.Key, len(e.Content), e.TS[:19], e.Device)
		}

	case "import-docs":
		fsx := flag.NewFlagSet("import-docs", flag.ExitOnError)
		brains := fsx.String("brains", filepath.Dir(store.Dir()), "directory holding the core docs")
		fsx.Parse(args)
		n, err := memory.ImportDocs(store, device, *brains)
		check(err)
		fmt.Printf("Snapshotted %d changed core doc(s)\n", n)

	case "claude":
		fsx := flag.NewFlagSet("claude", flag.ExitOnError)
		dir := fsx.String("dir", memory.DefaultClaudeDir(), "Claude Code memory directory")
		fsx.Parse(args)
		res, err := memory.SyncClaudeMemory(store, device, *dir)
		check(err)
		fmt.Printf("Claude memory: %d imported, %d written locally, %d deleted\n", len(res.Imported), len(res.Exported), len(res.Deleted))

	case "sync":
		fsx := flag.NewFlagSet("sync", flag.ExitOnError)
		var peers multi
		fsx.Var(&peers, "peer", "peer base URL, e.g. http://100.105.12.16:8402 (repeatable)")
		fsx.Parse(args)
		if !runSync(store, device, peers) {
			os.Exit(1)
		}

	case "render":
		check(memory.RenderProjectMemory(store))
		fmt.Println("Wrote", filepath.Join(store.Dir(), "PROJECT_MEMORY.md"))

	case "tick":
		failed := false
		if n, err := memory.ImportDocs(store, device, filepath.Dir(store.Dir())); err != nil {
			warn("import-docs: %v", err)
			failed = true
		} else if n > 0 {
			fmt.Printf("Snapshotted %d changed core doc(s)\n", n)
		}
		if dir := memory.DefaultClaudeDir(); dirExists(filepath.Dir(dir)) {
			if res, err := memory.SyncClaudeMemory(store, device, dir); err != nil {
				warn("claude: %v", err)
				failed = true
			} else if len(res.Imported)+len(res.Exported)+len(res.Deleted) > 0 {
				fmt.Printf("Claude memory: %d imported, %d written locally, %d deleted\n", len(res.Imported), len(res.Exported), len(res.Deleted))
			}
		}
		if !runSync(store, device, nil) {
			failed = true // unreachable peers are normal offline; still render
		}
		check(memory.RenderProjectMemory(store))
		if failed {
			os.Exit(1)
		}

	case "mirror":
		if len(args) != 1 {
			die("usage: swarm-memory mirror DEST")
		}
		check(mirror(store.Dir(), filepath.Dir(store.Dir()), args[0]))
		fmt.Println("Mirrored to", args[0])

	case "status":
		fmt.Printf("dir:     %s\ndevice:  %s\nentries: %d\n", store.Dir(), device, store.Count())
		if ls := memory.NewLeases(store.Dir()).Get(); ls.Holder != "" {
			fmt.Printf("lease:   %s (until %s)\n", ls.Holder, ls.Expires)
		} else {
			fmt.Println("lease:   free")
		}
		for peer, st := range memory.PeerStates(store, device) {
			fmt.Printf("peer:    %s  last ok %s  %s\n", peer, orDash(st.LastOK), st.LastError)
		}

	default:
		die("unknown command %q\n\n%s", cmd, usage)
	}
}

func runSync(store *memory.Store, device string, peers []string) bool {
	if len(peers) == 0 {
		peers = memory.Peers(store)
		if env := os.Getenv("SWARM_MEMORY_PEERS"); env != "" {
			peers = append(peers, strings.Split(env, ",")...)
		}
	}
	if len(peers) == 0 {
		fmt.Println("No peers configured (add them to peers.json or pass -peer)")
		return true
	}
	ok := true
	token := memory.AuthToken()
	for _, p := range peers {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		res := memory.SyncWithPeer(store, device, p, token)
		if res.Err != nil {
			warn("%s: %v", p, res.Err)
			ok = false
			continue
		}
		fmt.Printf("%s: pulled %d, pushed %d\n", p, res.Pulled, res.Pushed)
	}
	return ok
}

// mirror copies the durable parts of the memory into dest for git: the log,
// the rendered view, peers.json and the original core docs. Volatile files
// (lease.json, state/) are left out so git only changes when memory does.
func mirror(storeDir, brainsDir, dest string) error {
	logDest := filepath.Join(dest, "log")
	docsDest := filepath.Join(dest, "docs")
	for _, d := range []string{logDest, docsDest} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			return err
		}
	}
	want := map[string]bool{}
	logs, _ := filepath.Glob(filepath.Join(storeDir, "log", "*.jsonl"))
	for _, f := range logs {
		want[filepath.Base(f)] = true
		if err := copyFile(f, filepath.Join(logDest, filepath.Base(f))); err != nil {
			return err
		}
	}
	old, _ := filepath.Glob(filepath.Join(logDest, "*.jsonl"))
	for _, f := range old {
		if !want[filepath.Base(f)] {
			os.Remove(f)
		}
	}
	for _, name := range []string{"PROJECT_MEMORY.md", "peers.json", "README.md"} {
		if err := copyFile(filepath.Join(storeDir, name), filepath.Join(dest, name)); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return err
		}
	}
	for _, name := range memory.CoreDocs {
		if err := copyFile(filepath.Join(brainsDir, name), filepath.Join(docsDest, name)); err != nil && !errors.Is(err, fs.ErrNotExist) {
			return err
		}
	}
	return nil
}

func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	if cur, err := os.ReadFile(dst); err == nil && string(cur) == string(data) {
		return nil // leave mtime alone
	}
	tmp := dst + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, dst)
}

func printEntry(e memory.Entry) {
	t, _ := time.Parse(time.RFC3339Nano, e.TS)
	key := ""
	if e.Key != "" {
		key = " [" + e.Key + "]"
	}
	content := strings.Join(strings.Fields(e.Content), " ")
	if len(content) > 160 {
		content = content[:160] + "…"
	}
	if e.Deleted {
		content = "(deleted)"
	}
	fmt.Printf("%s  %-24s %s%s  %s\n", t.Local().Format("2006-01-02 15:04"), e.Device, e.Kind, key, content)
}

func dirExists(p string) bool { fi, err := os.Stat(p); return err == nil && fi.IsDir() }

func orDash(s string) string {
	if s == "" {
		return "never"
	}
	return s
}

func check(err error) {
	if err != nil {
		die("%v", err)
	}
}

func warn(format string, a ...any) { fmt.Fprintf(os.Stderr, "swarm-memory: "+format+"\n", a...) }

func die(format string, a ...any) {
	warn(format, a...)
	os.Exit(1)
}
