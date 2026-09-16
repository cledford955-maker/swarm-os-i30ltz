package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"time"
)

type App struct {
	cfg   Config
	store *Store
	cache *cache
}

// clock parses "HH:MM" onto the given day in local time.
func clock(on time.Time, hhmm string) time.Time {
	var h, m int
	fmt.Sscanf(hhmm, "%d:%d", &h, &m)
	return time.Date(on.Year(), on.Month(), on.Day(), h, m, 0, 0, time.Local)
}

// ── Care: meds, water, meals, sleep ─────────────────────────────

func (a *App) handleCare(w http.ResponseWriter, r *http.Request) {
	date := r.URL.Query().Get("date")
	if date == "" {
		date = day(time.Now())
	}
	d, err := a.store.Care(date)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]any{"ok": true, "day": d, "schedule": a.cfg.Meds,
		"water_goal_ml": a.cfg.WaterGoalML, "sleep_goal_hours": a.cfg.SleepGoal})
}

func (a *App) handleCareMed(w http.ResponseWriter, r *http.Request) {
	var req struct{ Name string }
	if err := readJSON(r, &req); err != nil || req.Name == "" {
		writeErr(w, 400, `Send {"name": "Morning meds"}.`)
		return
	}
	d, err := a.store.UpdateCare(day(time.Now()), func(d *CareDay) {
		for _, m := range d.Meds {
			if m.Name == req.Name {
				return // already logged today
			}
		}
		d.Meds = append(d.Meds, MedTaken{Name: req.Name, TakenAt: time.Now()})
	})
	a.respondCare(w, d, err)
}

func (a *App) handleCareWater(w http.ResponseWriter, r *http.Request) {
	var req struct{ ML int }
	if err := readJSON(r, &req); err != nil || req.ML == 0 || req.ML > 3000 || req.ML < -3000 {
		writeErr(w, 400, `Send {"ml": 250} (use a negative number to undo).`)
		return
	}
	d, err := a.store.UpdateCare(day(time.Now()), func(d *CareDay) {
		d.WaterML = max(0, d.WaterML+req.ML)
	})
	a.respondCare(w, d, err)
}

func (a *App) handleCareMeal(w http.ResponseWriter, r *http.Request) {
	var req struct{ Label string }
	_ = readJSON(r, &req)
	if req.Label == "" {
		req.Label = "Meal"
	}
	d, err := a.store.UpdateCare(day(time.Now()), func(d *CareDay) {
		d.Meals = append(d.Meals, Meal{Label: req.Label, At: time.Now()})
	})
	a.respondCare(w, d, err)
}

func (a *App) handleCareSleep(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Bed  time.Time `json:"bed"`
		Wake time.Time `json:"wake"`
	}
	if err := readJSON(r, &req); err != nil || !req.Wake.After(req.Bed) {
		writeErr(w, 400, `Send {"bed": RFC3339, "wake": RFC3339} with wake after bed.`)
		return
	}
	d, err := a.store.UpdateCare(day(req.Wake.Local()), func(d *CareDay) {
		d.Sleep = &Sleep{Bed: req.Bed, Wake: req.Wake, Hours: req.Wake.Sub(req.Bed).Hours()}
	})
	a.respondCare(w, d, err)
}

func (a *App) respondCare(w http.ResponseWriter, d CareDay, err error) {
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]any{"ok": true, "day": d})
}

// ── Nudges: what Lucille should nag about right now ─────────────

type Nudge struct {
	Kind     string `json:"kind"` // meds | water | food | sleep | break
	Severity string `json:"severity"`
	Text     string `json:"text"`
}

func (a *App) nudges(now time.Time) []Nudge {
	out := []Nudge{}
	d, _ := a.store.Care(day(now))

	taken := map[string]bool{}
	for _, m := range d.Meds {
		taken[m.Name] = true
	}
	for _, dose := range a.cfg.Meds {
		due := clock(now, dose.At)
		if taken[dose.Name] || now.Before(due) {
			continue
		}
		late := now.Sub(due)
		sev := "warn"
		if late > 2*time.Hour {
			sev = "critical"
		}
		out = append(out, Nudge{"meds", sev, fmt.Sprintf("%s were due at %s. Take them, then tap it off.", dose.Name, dose.At)})
	}

	wake, bed := clock(now, a.cfg.WakeAt), clock(now, a.cfg.BedAt)
	if !bed.After(wake) {
		bed = bed.Add(24 * time.Hour)
	}
	if now.After(wake) && now.Before(bed) {
		frac := now.Sub(wake).Hours() / bed.Sub(wake).Hours()
		target := int(frac * float64(a.cfg.WaterGoalML))
		if gap := target - d.WaterML; gap >= 500 {
			sev := "warn"
			if gap >= 1000 {
				sev = "critical"
			}
			out = append(out, Nudge{"water", sev, fmt.Sprintf("You're %d ml behind on water. Grab a glass.", gap)})
		}
		last := wake
		if n := len(d.Meals); n > 0 {
			last = d.Meals[n-1].At
		}
		if gap := now.Sub(last).Hours(); gap >= a.cfg.MealGapHrs {
			out = append(out, Nudge{"food", "warn", fmt.Sprintf("No food logged for %.0f hours. Eat something real.", gap)})
		}
	}

	h := now.Hour()
	if h >= 1 && h < 5 {
		out = append(out, Nudge{"sleep", "critical", "It's past 1 AM. Commit, push, and go to sleep — the build will still be there."})
	}
	if d.Sleep == nil && h >= 10 && h < 20 {
		out = append(out, Nudge{"sleep", "info", "Log last night's sleep so I can track it."})
	} else if d.Sleep != nil && d.Sleep.Hours < a.cfg.SleepGoal-1.5 {
		out = append(out, Nudge{"sleep", "warn", fmt.Sprintf("Only %.1f h of sleep last night. Go easy and aim for an early night.", d.Sleep.Hours)})
	}

	sessions, _ := a.store.Sessions()
	for _, s := range sessions {
		if s.End == nil && s.Minutes(now) >= float64(a.cfg.BreakAfter) {
			out = append(out, Nudge{"break", "warn", fmt.Sprintf("%.0f min straight on %s. Stand up, stretch, drink water.", s.Minutes(now), s.Project)})
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return sevRank(out[i].Severity) > sevRank(out[j].Severity) })
	return out
}

func sevRank(s string) int {
	switch s {
	case "critical":
		return 2
	case "warn":
		return 1
	}
	return 0
}

func (a *App) handleNudges(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]any{"ok": true, "nudges": a.nudges(time.Now())})
}

// ── Sessions: time on projects and gaming ───────────────────────

func newID() string {
	b := make([]byte, 6)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

type sessionSummary struct {
	Active     []Session          `json:"active"`
	TodayMin   map[string]float64 `json:"today_minutes"`
	WeekMin    map[string]float64 `json:"week_minutes"`
	GamingWeek float64            `json:"gaming_week_minutes"`
	Recent     []Session          `json:"recent"`
}

func summarize(list []Session, now time.Time) sessionSummary {
	sum := sessionSummary{TodayMin: map[string]float64{}, WeekMin: map[string]float64{}}
	today := day(now)
	weekAgo := now.AddDate(0, 0, -7)
	for _, s := range list {
		if s.End == nil {
			sum.Active = append(sum.Active, s)
		}
		m := s.Minutes(now)
		if day(s.Start.Local()) == today {
			sum.TodayMin[s.Project] += m
		}
		if s.Start.After(weekAgo) {
			sum.WeekMin[s.Project] += m
			if s.Kind == "gaming" {
				sum.GamingWeek += m
			}
		}
	}
	n := len(list)
	for i := n - 1; i >= 0 && i >= n-10; i-- {
		sum.Recent = append(sum.Recent, list[i])
	}
	return sum
}

func (a *App) handleSessions(w http.ResponseWriter, r *http.Request) {
	list, err := a.store.Sessions()
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]any{"ok": true, "projects": a.cfg.Projects, "summary": summarize(list, time.Now())})
}

func (a *App) handleSessionStart(w http.ResponseWriter, r *http.Request) {
	var req struct{ Project, Kind string }
	if err := readJSON(r, &req); err != nil || strings.TrimSpace(req.Project) == "" {
		writeErr(w, 400, `Send {"project": "SWARM OS ISO", "kind": "project"|"gaming"}.`)
		return
	}
	if req.Kind != "gaming" {
		req.Kind = "project"
	}
	now := time.Now()
	list, err := a.store.UpdateSessions(func(l []Session) []Session {
		// Only one active session at a time — starting a new one closes the old.
		for i := range l {
			if l[i].End == nil {
				l[i].End = &now
			}
		}
		return append(l, Session{ID: newID(), Project: req.Project, Kind: req.Kind, Start: now})
	})
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]any{"ok": true, "summary": summarize(list, now)})
}

func (a *App) handleSessionStop(w http.ResponseWriter, r *http.Request) {
	now := time.Now()
	list, err := a.store.UpdateSessions(func(l []Session) []Session {
		for i := range l {
			if l[i].End == nil {
				l[i].End = &now
			}
		}
		return l
	})
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, map[string]any{"ok": true, "summary": summarize(list, now)})
}
