package services

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func withMockSteamSpy(t *testing.T, handler http.Handler) *SteamSpyService {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	t.Setenv("STEAMSPY_BASE_URL", srv.URL)
	return NewSteamSpyService()
}

func TestSteamSpyEnrich_GenreAndTagsMerge(t *testing.T) {
	svc := withMockSteamSpy(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"appid": 220,
			"name": "Half-Life 2",
			"developer": "Valve",
			"publisher": "Valve",
			"genre": "Action, Adventure",
			"tags": {"Classic": 5000, "FPS": 8000, "Story Rich": 3000, "Sci-fi": 4000},
			"positive": 190000, "negative": 5000
		}`))
	}))

	got, ok := svc.Enrich(220)
	if !ok {
		t.Fatal("Enrich should have returned ok=true for a full response")
	}
	if got.Developer != "Valve" || got.Publisher != "Valve" {
		t.Errorf("developer/publisher = %q/%q", got.Developer, got.Publisher)
	}
	if got.PositivePercent < 95 {
		t.Errorf("positive percent = %d, want ~97", got.PositivePercent)
	}
	// Genres from `genre` come first, then top tags by vote.
	if len(got.Genres) < 3 {
		t.Fatalf("expected at least 3 genres, got %v", got.Genres)
	}
	if got.Genres[0] != "Action" || got.Genres[1] != "Adventure" {
		t.Errorf("genre order lost prefix from 'genre' field: %v", got.Genres)
	}
	// Top tag by votes is FPS (8000) — must appear after the explicit genres.
	fpsIdx := indexOf(got.Genres, "FPS")
	if fpsIdx < 0 {
		t.Errorf("top tag FPS missing: %v", got.Genres)
	}
}

func TestSteamSpyEnrich_CachesResult(t *testing.T) {
	hits := 0
	svc := withMockSteamSpy(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		w.Write([]byte(`{"appid":220,"developer":"Valve","genre":"Action","tags":{}}`))
	}))
	_, _ = svc.Enrich(220)
	_, _ = svc.Enrich(220)
	_, _ = svc.Enrich(220)
	if hits != 1 {
		t.Errorf("expected 1 upstream call, got %d", hits)
	}
}

func TestSteamSpyEnrich_ServiceUnreachable(t *testing.T) {
	t.Setenv("STEAMSPY_BASE_URL", "http://127.0.0.1:1")
	svc := NewSteamSpyService()
	got, ok := svc.Enrich(220)
	if ok {
		t.Errorf("ok should be false when upstream is unreachable, got %v", got)
	}
}

func TestSteamSpyEnrich_BadAppID(t *testing.T) {
	svc := NewSteamSpyService()
	if _, ok := svc.Enrich(0); ok {
		t.Error("Enrich(0) should return ok=false")
	}
	if _, ok := svc.Enrich(-1); ok {
		t.Error("Enrich(-1) should return ok=false")
	}
}

func TestSteamSpyEnrich_MalformedJSON(t *testing.T) {
	svc := withMockSteamSpy(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{not json`))
	}))
	if _, ok := svc.Enrich(220); ok {
		t.Error("malformed JSON should return ok=false")
	}
}

func TestSteamSpyEnrich_NoReviewsReturnsMinusOne(t *testing.T) {
	svc := withMockSteamSpy(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"appid":123,"developer":"X","positive":0,"negative":0}`))
	}))
	got, _ := svc.Enrich(123)
	if got.PositivePercent != -1 {
		t.Errorf("no reviews should yield -1, got %d", got.PositivePercent)
	}
}

func TestSteamSpyEnrich_GenreOnlyNoTags(t *testing.T) {
	svc := withMockSteamSpy(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"appid":999,"developer":"","genre":"Puzzle","tags":null}`))
	}))
	got, ok := svc.Enrich(999)
	if !ok {
		t.Fatal("genre alone should mark result as usable")
	}
	if len(got.Genres) != 1 || got.Genres[0] != "Puzzle" {
		t.Errorf("genres = %v, want [Puzzle]", got.Genres)
	}
}

func TestMergeGenresAndTopTags_CapsAtN(t *testing.T) {
	tags := map[string]int{"A": 100, "B": 90, "C": 80, "D": 70, "E": 60}
	got := mergeGenresAndTopTags("X, Y", tags, 3)
	if len(got) != 3 {
		t.Errorf("cap not honored: %v", got)
	}
	if got[0] != "X" || got[1] != "Y" || got[2] != "A" {
		t.Errorf("order wrong: %v", got)
	}
}

func TestMergeGenresAndTopTags_DedupesAcrossGenreAndTags(t *testing.T) {
	tags := map[string]int{"Action": 1000, "RPG": 500}
	got := mergeGenresAndTopTags("Action", tags, 6)
	// "Action" from genre must not repeat when it also appears in tags.
	count := 0
	for _, g := range got {
		if g == "Action" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("dedup failed: %v", got)
	}
}

func indexOf(s []string, want string) int {
	for i, v := range s {
		if strings.EqualFold(v, want) {
			return i
		}
	}
	return -1
}

func TestItoa(t *testing.T) {
	cases := map[int]string{0: "0", 1: "1", 220: "220", 9999999: "9999999", -5: "-5"}
	for n, want := range cases {
		if got := itoa(n); got != want {
			t.Errorf("itoa(%d) = %q, want %q", n, got, want)
		}
	}
}
