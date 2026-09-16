package main

import (
	"context"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"
)

// handleBrief gathers everything for the morning brief in parallel. Each
// section fails on its own so one dead service never blanks the brief.
func (a *App) handleBrief(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 12*time.Second)
	defer cancel()
	now := time.Now()
	out := map[string]any{"ok": true, "generated_at": now, "date": day(now)}
	errs := map[string]string{}
	var mu sync.Mutex
	set := func(k string, v any, err error) {
		mu.Lock()
		defer mu.Unlock()
		if err != nil {
			errs[k] = err.Error()
			return
		}
		out[k] = v
	}

	var wg sync.WaitGroup
	run := func(fn func()) { wg.Add(1); go func() { defer wg.Done(); fn() }() }
	run(func() { set("git", a.gitAll(), nil) })
	run(func() { set("drives", a.drives(), nil) })
	run(func() { set("nudges", a.nudges(now), nil) })
	run(func() {
		d, err := a.store.Care(day(now))
		set("care", map[string]any{"day": d, "schedule": a.cfg.Meds, "water_goal_ml": a.cfg.WaterGoalML}, err)
	})
	run(func() {
		list, err := a.store.Sessions()
		set("sessions", summarize(list, now), err)
	})
	run(func() { m, err := a.memory(6, "decision"); set("memory", m, err) })
	run(func() { v, err := a.google(ctx, "/gmail/unread"); set("mail", v, err) })
	run(func() {
		v, err := a.google(ctx, "/cal/events?maxResults=8&daysAhead=1&calendarId=primary")
		set("calendar", v, err)
	})
	run(func() {
		n, err := a.news(ctx)
		if len(n.Items) > 6 {
			n.Items = n.Items[:6]
		}
		set("news", n.Items, err)
	})
	run(func() {
		d, err := a.deals(ctx)
		if err == nil && len(d["steam"]) > 4 {
			d = map[string][]Deal{"steam": d["steam"][:4], "keys": d["keys"][:min(4, len(d["keys"]))]}
		}
		set("deals", d, err)
	})
	run(func() { g, err := a.steamRecent(ctx); set("steam_recent", g, err) })
	wg.Wait()

	out["errors"] = errs
	out["headline"] = a.headline(out, now)
	writeJSON(w, out)
}

// headline is Lucille's spoken summary — plain template, no LLM round trip.
func (a *App) headline(b map[string]any, now time.Time) string {
	var parts []string
	switch h := now.Hour(); {
	case h < 5:
		parts = append(parts, "You're still up.")
	case h < 12:
		parts = append(parts, "Morning.")
	case h < 18:
		parts = append(parts, "Afternoon check-in.")
	default:
		parts = append(parts, "Evening.")
	}
	if n, ok := b["nudges"].([]Nudge); ok && len(n) > 0 {
		parts = append(parts, n[0].Text)
	}
	if repos, ok := b["git"].([]RepoStatus); ok {
		for _, rs := range repos {
			if c := rs.Dirty + rs.Untracked; c > 0 {
				parts = append(parts, fmt.Sprintf("%s has %d uncommitted changes.", shortPath(rs.Path), c))
			}
		}
	}
	if s, ok := b["sessions"].(sessionSummary); ok {
		type kv struct {
			k string
			v float64
		}
		var top []kv
		for k, v := range s.WeekMin {
			top = append(top, kv{k, v})
		}
		sort.Slice(top, func(i, j int) bool { return top[i].v > top[j].v })
		if len(top) > 0 {
			parts = append(parts, fmt.Sprintf("Most of your week went to %s (%.1f h).", top[0].k, top[0].v/60))
		}
	}
	if drives, ok := b["drives"].([]DriveUsage); ok {
		for _, d := range drives {
			if d.Mounted && d.UsedPct >= 90 {
				parts = append(parts, fmt.Sprintf("%s is %.0f%% full.", d.Mount, d.UsedPct))
			}
		}
	}
	return strings.Join(parts, " ")
}

func shortPath(p string) string {
	if i := strings.LastIndex(strings.TrimRight(p, "/"), "/"); i >= 0 {
		return p[i+1:]
	}
	return p
}
