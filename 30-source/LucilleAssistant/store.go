package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Store keeps care logs and time sessions as small JSON files. One file per
// day for care, one append-friendly file for sessions.
type Store struct {
	dir string
	mu  sync.Mutex
}

type MedTaken struct {
	Name    string    `json:"name"`
	TakenAt time.Time `json:"taken_at"`
}

type Meal struct {
	Label string    `json:"label"`
	At    time.Time `json:"at"`
}

type Sleep struct {
	Bed   time.Time `json:"bed"`
	Wake  time.Time `json:"wake"`
	Hours float64   `json:"hours"`
}

type CareDay struct {
	Date    string     `json:"date"`
	Meds    []MedTaken `json:"meds"`
	WaterML int        `json:"water_ml"`
	Meals   []Meal     `json:"meals"`
	Sleep   *Sleep     `json:"sleep,omitempty"`
}

type Session struct {
	ID      string     `json:"id"`
	Project string     `json:"project"`
	Kind    string     `json:"kind"` // project | gaming
	Start   time.Time  `json:"start"`
	End     *time.Time `json:"end,omitempty"`
}

func (s Session) Minutes(now time.Time) float64 {
	end := now
	if s.End != nil {
		end = *s.End
	}
	return end.Sub(s.Start).Minutes()
}

func openStore(dir string) (*Store, error) {
	if err := os.MkdirAll(filepath.Join(dir, "care"), 0o700); err != nil {
		return nil, err
	}
	return &Store{dir: dir}, nil
}

func day(t time.Time) string { return t.Format("2006-01-02") }

func (s *Store) readJSON(path string, v any) error {
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	return json.Unmarshal(b, v)
}

func (s *Store) writeJSON(path string, v any) error {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func (s *Store) carePath(date string) string {
	return filepath.Join(s.dir, "care", date+".json")
}

func newCareDay(date string) CareDay {
	return CareDay{Date: date, Meds: []MedTaken{}, Meals: []Meal{}}
}

func (s *Store) Care(date string) (CareDay, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := newCareDay(date)
	err := s.readJSON(s.carePath(date), &d)
	return d, err
}

func (s *Store) UpdateCare(date string, fn func(*CareDay)) (CareDay, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	d := newCareDay(date)
	if err := s.readJSON(s.carePath(date), &d); err != nil {
		return d, err
	}
	fn(&d)
	return d, s.writeJSON(s.carePath(date), d)
}

func (s *Store) sessionsPath() string { return filepath.Join(s.dir, "sessions.json") }

func (s *Store) Sessions() ([]Session, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []Session
	err := s.readJSON(s.sessionsPath(), &out)
	return out, err
}

func (s *Store) UpdateSessions(fn func([]Session) []Session) ([]Session, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var list []Session
	if err := s.readJSON(s.sessionsPath(), &list); err != nil {
		return nil, err
	}
	list = fn(list)
	return list, s.writeJSON(s.sessionsPath(), list)
}
