package memory

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// RenderProjectMemory writes <dir>/PROJECT_MEMORY.md: a plain-text view of the
// log that any AI (Claude, GPT, a local model) can read cold. It is generated
// — edits belong in the log (`swarm-memory add`), not in this file.
func RenderProjectMemory(s *Store) error {
	all, _, err := s.Since(nil)
	if err != nil {
		return err
	}
	current, err := s.Current("")
	if err != nil {
		return err
	}

	var b strings.Builder
	now := time.Now().UTC().Format("2006-01-02 15:04 UTC")
	fmt.Fprintf(&b, "# SWARM OS Shared Memory\n\n")
	fmt.Fprintf(&b, "_Generated %s from %d log entries. Do not edit — add memories with `swarm-memory add`, the companion app, or `POST /api/memory/entries`._\n\n", now, len(all))
	b.WriteString("Log: `log/<device>.jsonl` (append-only, one file per device). Spec: `90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md` in /mnt/Lucy.\n\n")

	devices := map[string]int{}
	for _, e := range all {
		devices[e.Device]++
	}
	b.WriteString("## Devices\n\n")
	for _, d := range sortedKeys(devices) {
		fmt.Fprintf(&b, "- `%s` — %d entries\n", d, devices[d])
	}

	section := func(title, kind string, full bool) {
		var rows []Entry
		for _, e := range current {
			if e.Kind == kind {
				rows = append(rows, e)
			}
		}
		if len(rows) == 0 {
			return
		}
		fmt.Fprintf(&b, "\n## %s\n", title)
		for _, e := range rows {
			if full {
				fmt.Fprintf(&b, "\n### %s\n_%s · %s_\n\n%s\n", e.Key, e.Device, e.TS[:min(len(e.TS), 19)], strings.TrimSpace(e.Content))
			} else {
				fmt.Fprintf(&b, "- `%s` — %d bytes, updated %s by `%s`\n", e.Key, len(e.Content), e.TS[:min(len(e.TS), 19)], e.Device)
			}
		}
	}
	section("Decisions", KindDecision, true)
	section("Facts", KindFact, true)
	section("Claude memory", KindClaudeMemory, true)
	section("ChatGPT saved memory (imported snapshot)", "chatgpt_memory", true)
	section("ChatGPT conversations (imported snapshots; full text in log)", "chatgpt_conversation", false)
	section("Core documents (full text in the log; originals on /mnt/brains)", KindDoc, false)

	var notes []Entry
	for i := len(all) - 1; i >= 0 && len(notes) < 100; i-- {
		e := all[i]
		if e.Key == "" && !e.Deleted {
			notes = append(notes, e)
		}
	}
	if len(notes) > 0 {
		b.WriteString("\n## Recent notes (newest first, last 100)\n\n")
		for _, e := range notes {
			fmt.Fprintf(&b, "- **%s** `%s` %s — %s\n", e.TS[:min(len(e.TS), 16)], e.Device, e.Kind, oneLine(e.Content, 400))
		}
	}
	return writeFileAtomic(filepath.Join(s.Dir(), "PROJECT_MEMORY.md"), b.String())
}

func oneLine(s string, max int) string {
	s = strings.Join(strings.Fields(s), " ")
	if len(s) > max {
		s = s[:max] + "…"
	}
	return s
}

func sortedKeys(m map[string]int) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
