package services

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func withMockCalendar(t *testing.T, handler http.Handler) {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	orig := googleWorkspaceCalendarBase
	googleWorkspaceCalendarBase = func() string { return srv.URL }
	t.Cleanup(func() { googleWorkspaceCalendarBase = orig })
}

func TestFetchUpcomingCalendarSummary_ReturnsEmptyWhenServiceDown(t *testing.T) {
	// Point at a closed port; must return "" without error / panic.
	orig := googleWorkspaceCalendarBase
	googleWorkspaceCalendarBase = func() string { return "http://127.0.0.1:1" }
	t.Cleanup(func() { googleWorkspaceCalendarBase = orig })

	got := fetchUpcomingCalendarSummary()
	if got != "" {
		t.Errorf("expected empty summary when service is unreachable, got %q", got)
	}
}

func TestFetchUpcomingCalendarSummary_ReturnsEmptyWhenUnauthenticated(t *testing.T) {
	// GoogleWorkspaceService returns 401/500 when the /cal endpoints are
	// called before OAuth completes. Our function must silently return "".
	withMockCalendar(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))

	got := fetchUpcomingCalendarSummary()
	if got != "" {
		t.Errorf("expected empty summary on 500, got %q", got)
	}
}

func TestFetchUpcomingCalendarSummary_ReturnsEmptyWhenNoEvents(t *testing.T) {
	withMockCalendar(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"ok":true,"events":[]}`))
	}))

	got := fetchUpcomingCalendarSummary()
	if got != "" {
		t.Errorf("expected empty summary with no events, got %q", got)
	}
}

func TestFetchUpcomingCalendarSummary_FormatsRealEvents(t *testing.T) {
	withMockCalendar(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify we passed the right query params.
		q := r.URL.Query()
		if q.Get("maxResults") == "" || q.Get("daysAhead") == "" {
			t.Errorf("missing expected query params: %v", q)
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"ok": true,
			"events": [
				{"summary":"Dentist","start":{"dateTime":"2026-09-26T09:00:00-04:00"}},
				{"summary":"Team standup","start":{"dateTime":"2026-09-26T10:30:00-04:00"}},
				{"summary":"Vacation day","start":{"date":"2026-09-30"}}
			]
		}`))
	}))

	got := fetchUpcomingCalendarSummary()
	if got == "" {
		t.Fatal("expected non-empty summary")
	}
	if !strings.Contains(got, "Dentist") {
		t.Errorf("summary missing Dentist: %q", got)
	}
	if !strings.Contains(got, "Team standup") {
		t.Errorf("summary missing Team standup: %q", got)
	}
	// All-day event (only "date" set) must still render.
	if !strings.Contains(got, "Vacation day") {
		t.Errorf("summary missing all-day Vacation day event: %q", got)
	}
	if !strings.Contains(got, "Upcoming calendar events") {
		t.Errorf("missing header line: %q", got)
	}
}

func TestFetchUpcomingCalendarSummary_MalformedJSONIsEmpty(t *testing.T) {
	withMockCalendar(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{not json`))
	}))
	got := fetchUpcomingCalendarSummary()
	if got != "" {
		t.Errorf("malformed JSON should yield empty summary, got %q", got)
	}
}
