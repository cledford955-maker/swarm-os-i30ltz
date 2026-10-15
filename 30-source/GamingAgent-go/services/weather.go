package services

// Minimal weather context for Lucille. Uses wttr.in's `?format=j1` endpoint —
// no API key, IP-geolocated by default, WEATHER_LOCATION env for override.
// Cached ~15 minutes so a chatty session doesn't hammer the service.
//
// Best-effort: any fetch, decode, or timeout error returns "" so chat is
// never blocked on weather.

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

const weatherTTL = 15 * time.Minute

var (
	weatherMu       sync.Mutex
	weatherCached   string
	weatherCachedAt time.Time
	weatherFetchMu  sync.Mutex
	// Overridable in tests.
	weatherBaseURL     = func() string {
		if v := os.Getenv("WTTR_BASE_URL"); v != "" {
			return v
		}
		return "https://wttr.in"
	}
	weatherHTTPClient = &http.Client{Timeout: 4 * time.Second}
)

// fetchWeatherSummary returns a short "Current weather" block for Lucille's
// context, or "" on any failure. Cached for weatherTTL.
func fetchWeatherSummary() string {
	weatherMu.Lock()
	if weatherCached != "" && time.Since(weatherCachedAt) < weatherTTL {
		s := weatherCached
		weatherMu.Unlock()
		return s
	}
	weatherMu.Unlock()

	weatherFetchMu.Lock()
	defer weatherFetchMu.Unlock()

	// Double-check under fetch lock to prevent TOCTOU race
	weatherMu.Lock()
	if weatherCached != "" && time.Since(weatherCachedAt) < weatherTTL {
		s := weatherCached
		weatherMu.Unlock()
		return s
	}
	weatherMu.Unlock()

	loc := strings.TrimSpace(os.Getenv("WEATHER_LOCATION")) // e.g. "Austin,TX"; empty = IP geo
	u := fmt.Sprintf("%s/%s?format=j1", weatherBaseURL(), url.PathEscape(loc))

	resp, err := weatherHTTPClient.Get(u)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return ""
	}

	var raw struct {
		CurrentCondition []struct {
			TempF         string `json:"temp_F"`
			FeelsLikeF    string `json:"FeelsLikeF"`
			WeatherDesc   []struct{ Value string } `json:"weatherDesc"`
			WindspeedMiles string `json:"windspeedMiles"`
			Humidity       string `json:"humidity"`
			LocalObsDateTime string `json:"localObsDateTime"`
		} `json:"current_condition"`
		NearestArea []struct {
			AreaName []struct{ Value string } `json:"areaName"`
			Region   []struct{ Value string } `json:"region"`
		} `json:"nearest_area"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return ""
	}
	if len(raw.CurrentCondition) == 0 {
		return ""
	}
	c := raw.CurrentCondition[0]
	desc := ""
	if len(c.WeatherDesc) > 0 {
		desc = c.WeatherDesc[0].Value
	}
	place := ""
	if len(raw.NearestArea) > 0 {
		if len(raw.NearestArea[0].AreaName) > 0 {
			place = raw.NearestArea[0].AreaName[0].Value
		}
		if len(raw.NearestArea[0].Region) > 0 {
			r := raw.NearestArea[0].Region[0].Value
			if place != "" && r != "" {
				place = place + ", " + r
			} else if r != "" {
				place = r
			}
		}
	}

	var sb strings.Builder
	sb.WriteString("Current weather")
	if place != "" {
		sb.WriteString(" (")
		sb.WriteString(place)
		sb.WriteString(")")
	}
	sb.WriteString(": ")
	sb.WriteString(desc)
	if c.TempF != "" {
		sb.WriteString(fmt.Sprintf(", %s°F", c.TempF))
	}
	if c.FeelsLikeF != "" && c.FeelsLikeF != c.TempF {
		sb.WriteString(fmt.Sprintf(" (feels %s°F)", c.FeelsLikeF))
	}
	if c.WindspeedMiles != "" {
		sb.WriteString(fmt.Sprintf(", wind %s mph", c.WindspeedMiles))
	}
	if c.Humidity != "" {
		sb.WriteString(fmt.Sprintf(", %s%% humidity", c.Humidity))
	}
	sb.WriteString(". Use for gaming-session suggestions (indoor when stormy/hot; outdoor breaks if pleasant).")

	out := sb.String()
	weatherMu.Lock()
	weatherCached = out
	weatherCachedAt = time.Now()
	weatherMu.Unlock()
	return out
}
