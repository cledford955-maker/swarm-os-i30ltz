package memory

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// CoreDocs are the files at the root of /mnt/brains that are part of the
// shared memory. They stay where LucyServer already reads them; each change is
// snapshotted into the log as a KindDoc entry so phones and git get a copy.
var CoreDocs = []string{
	"Lucy_Core_Prompt.md",
	"Dr_Boltz_Core_Prompt.md",
	"llcy_memory.md",
	"lucille_personas_memory.json",
	"memory.json",
	"users.json",
}

func hashOf(s string) string {
	sum := sha256.Sum256([]byte(s))
	return hex.EncodeToString(sum[:])
}

// ImportDocs snapshots every core doc whose content differs from the newest
// doc entry for it. brainsDir is normally the parent of the store (/mnt/brains).
// Docs flow one way: the files on /mnt/brains are authoritative.
func ImportDocs(s *Store, device, brainsDir string) (int, error) {
	current, err := s.Current(KindDoc)
	if err != nil {
		return 0, err
	}
	latest := map[string]Entry{}
	for _, e := range current {
		latest[e.Key] = e
	}
	var batch []Entry
	for _, name := range CoreDocs {
		data, err := os.ReadFile(filepath.Join(brainsDir, name))
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return 0, err
		}
		content := string(data)
		if prev, ok := latest[name]; ok && prev.Content == content {
			continue
		}
		e := NewEntry(device, KindDoc, name, content)
		e.Meta = map[string]string{"sha256": hashOf(content), "source": filepath.Join(brainsDir, name)}
		batch = append(batch, e)
	}
	if len(batch) == 0 {
		return 0, nil
	}
	return len(batch), s.Append(batch...)
}

// ClaudeResult reports what a Claude memory sync did.
type ClaudeResult struct {
	Imported, Exported, Deleted []string
}

// SyncClaudeMemory keeps a Claude Code memory directory
// (~/.claude/projects/<project>/memory) and the shared log in step, both ways.
//
// Per-device state (<store>/state/claude-<device>.json) records each file's
// hash at the last sync, which is what tells "I changed this locally" apart
// from "someone else changed this in the log":
//   - local changed since last sync            -> append a new entry (local wins; the log keeps both)
//   - local unchanged, log has something newer -> write the log's version to disk
//   - local deleted since last sync            -> append a tombstone
//   - log tombstone, local unchanged           -> delete the local file
func SyncClaudeMemory(s *Store, device, claudeDir string) (ClaudeResult, error) {
	var res ClaudeResult
	if err := os.MkdirAll(claudeDir, 0o755); err != nil {
		return res, err
	}
	statePath := filepath.Join(s.Dir(), "state", "claude-"+device+".json")
	state := map[string]string{}
	if data, err := os.ReadFile(statePath); err == nil {
		_ = json.Unmarshal(data, &state)
	}

	all, _, err := s.Since(nil)
	if err != nil {
		return res, err
	}
	latest := map[string]Entry{} // including tombstones
	for _, e := range all {
		if e.Kind == KindClaudeMemory && e.Key != "" {
			latest[e.Key] = e
		}
	}

	local := map[string]string{}
	files, _ := filepath.Glob(filepath.Join(claudeDir, "*.md"))
	for _, f := range files {
		data, err := os.ReadFile(f)
		if err != nil {
			return res, err
		}
		local[filepath.Base(f)] = string(data)
	}

	keys := map[string]struct{}{}
	for k := range local {
		keys[k] = struct{}{}
	}
	for k := range latest {
		keys[k] = struct{}{}
	}
	for k := range state {
		keys[k] = struct{}{}
	}
	sorted := make([]string, 0, len(keys))
	for k := range keys {
		if validClaudeName(k) {
			sorted = append(sorted, k)
		}
	}
	sort.Strings(sorted)

	var batch []Entry
	newState := map[string]string{}
	for _, name := range sorted {
		content, haveLocal := local[name]
		lastHash, synced := state[name]
		logE, inLog := latest[name]
		logLive := inLog && !logE.Deleted

		switch {
		case haveLocal && (!synced || hashOf(content) != lastHash):
			// Changed or created here since the last sync.
			if !(logLive && logE.Content == content) {
				batch = append(batch, NewEntry(device, KindClaudeMemory, name, content))
				res.Imported = append(res.Imported, name)
			}
			newState[name] = hashOf(content)

		case haveLocal: // unchanged locally
			if logLive && logE.Content != content {
				if err := writeFileAtomic(filepath.Join(claudeDir, name), logE.Content); err != nil {
					return res, err
				}
				res.Exported = append(res.Exported, name)
				newState[name] = hashOf(logE.Content)
			} else if inLog && logE.Deleted {
				if err := os.Remove(filepath.Join(claudeDir, name)); err != nil && !errors.Is(err, fs.ErrNotExist) {
					return res, err
				}
				res.Deleted = append(res.Deleted, name)
			} else {
				newState[name] = lastHash
			}

		case synced: // existed at last sync, gone now: deleted here
			if logLive {
				t := NewEntry(device, KindClaudeMemory, name, "")
				t.Deleted = true
				batch = append(batch, t)
				res.Deleted = append(res.Deleted, name)
			}

		case logLive: // new from another device
			if err := writeFileAtomic(filepath.Join(claudeDir, name), logE.Content); err != nil {
				return res, err
			}
			res.Exported = append(res.Exported, name)
			newState[name] = hashOf(logE.Content)
		}
	}

	if len(batch) > 0 {
		if err := s.Append(batch...); err != nil {
			return res, err
		}
	}
	data, _ := json.MarshalIndent(newState, "", "  ")
	return res, writeFileAtomic(statePath, string(data))
}

// validClaudeName keeps a log entry from writing outside the memory directory.
func validClaudeName(name string) bool {
	return strings.HasSuffix(name, ".md") && filepath.Base(name) == name && !strings.HasPrefix(name, ".")
}

func writeFileAtomic(path, content string) error {
	tmp := path + ".swarm-tmp"
	if err := os.WriteFile(tmp, []byte(content), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// DefaultClaudeDir is Claude Code's memory directory for the /mnt/Lucy project.
func DefaultClaudeDir() string {
	if d := os.Getenv("SWARM_CLAUDE_MEMORY_DIR"); d != "" {
		return d
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".claude", "projects", "-mnt-Lucy", "memory")
}
