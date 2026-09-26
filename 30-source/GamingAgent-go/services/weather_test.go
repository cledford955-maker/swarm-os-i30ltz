package services

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func resetWeatherCache(t *testing.T) {
	t.Helper()
	weatherMu.Lock()
	weatherCached = ""
	weatherCachedAt = time.Time{}
	weatherMu.Unlock()
}

func withMockWeather(t *testing.T, handler http.Handler) {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	orig := weatherBaseURL
	weatherBaseURL = func() string { return srv.URL }
	t.Cleanup(func() { weatherBaseURL = orig })
	resetWeatherCache(t)
}

func TestFetchWeatherSummary_ServiceDown(t *testing.T) {
	orig := weatherBaseURL
	weatherBaseURL = func() string { return "http://127.0.0.1:1" } // unroutable
	t.Cleanup(func() { weatherBaseURL = orig })
	resetWeatherCache(t)

	if got := fetchWeatherSummary(); got != "" {
		t.Errorf("expected empty on service-down, got %q", got)
	}
}

func TestFetchWeatherSummary_Non2xxIsEmpty(t *testing.T) {
	withMockWeather(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	if got := fetchWeatherSummary(); got != "" {
		t.Errorf("expected empty on 500, got %q", got)
	}
}

func TestFetchWeatherSummary_FormatsRealResponse(t *testing.T) {
	withMockWeather(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"current_condition": [{
				"temp_F": "72",
				"FeelsLikeF": "70",
				"weatherDesc": [{"value": "Partly cloudy"}],
				"windspeedMiles": "8",
				"humidity": "55",
				"localObsDateTime": "2026-09-25 14:00"
			}],
			"nearest_area": [{
				"areaName": [{"value": "Austin"}],
				"region": [{"value": "Texas"}]
			}]
		}`))
	}))

	got := fetchWeatherSummary()
	if got == "" {
		t.Fatal("expected non-empty summary")
	}
	for _, want := range []string{"Partly cloudy", "72°F", "70°F", "Austin", "Texas", "8 mph", "55%"} {
		if !strings.Contains(got, want) {
			t.Errorf("summary missing %q: %q", want, got)
		}
	}
}

func TestFetchWeatherSummary_UsesCache(t *testing.T) {
	hits := 0
	withMockWeather(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"current_condition":[{"temp_F":"60","weatherDesc":[{"value":"Clear"}]}],
			"nearest_area":[{"areaName":[{"value":"Nowhere"}]}]
		}`))
	}))

	_ = fetchWeatherSummary()
	_ = fetchWeatherSummary()
	_ = fetchWeatherSummary()

	if hits != 1 {
		t.Errorf("expected 1 upstream hit due to cache, got %d", hits)
	}
}

func TestFetchWeatherSummary_MalformedJSONIsEmpty(t *testing.T) {
	withMockWeather(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{not json`))
	}))
	if got := fetchWeatherSummary(); got != "" {
		t.Errorf("malformed JSON should yield empty summary, got %q", got)
	}
}

func TestFetchWeatherSummary_MissingCurrentConditionIsEmpty(t *testing.T) {
	withMockWeather(t, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"current_condition":[]}`))
	}))
	if got := fetchWeatherSummary(); got != "" {
		t.Errorf("empty current_condition should yield empty summary, got %q", got)
	}
}
