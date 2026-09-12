package services

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"
)

type SearchResult struct {
	Title   string `json:"title"`
	URL     string `json:"url"`
	Snippet string `json:"snippet"`
	Source  string `json:"source"`
}

var searchClient = &http.Client{
	Timeout: 10 * time.Second,
}

var searchClientOnce sync.Once

func getSearchClient() *http.Client {
	searchClientOnce.Do(func() {
		searchClient = &http.Client{
			Timeout: 10 * time.Second,
		}
	})
	return searchClient
}

// SearchWeb queries DuckDuckGo (Instant Answer API + lite HTML scrape) for results.
func SearchWeb(query string, maxResults int) []SearchResult {
	if maxResults <= 0 {
		maxResults = 8
	}
	results := []SearchResult{}

	// 1. DDG Instant Answer API — quick abstract + related topics
	func() {
		client := getSearchClient()
		encoded := url.QueryEscape(query)
		resp, err := client.Get("https://api.duckduckgo.com/?q=" + encoded + "&format=json&no_html=1&skip_disambig=1")
		if err != nil {
			return
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)

		var doc map[string]json.RawMessage
		if err := json.Unmarshal(body, &doc); err != nil {
			return
		}

		abstract := jsonString(doc["Abstract"])
		abstractURL := jsonString(doc["AbstractURL"])
		abstractSource := jsonString(doc["AbstractSource"])
		if abstract != "" {
			results = append(results, SearchResult{
				Title:   cond(abstractSource != "", abstractSource, query),
				URL:     abstractURL,
				Snippet: abstract,
				Source:  "DDG Instant",
			})
		}

		// Related topics as additional results
		var topics []json.RawMessage
		if err := json.Unmarshal(doc["RelatedTopics"], &topics); err == nil {
			for _, t := range topics {
				if len(results) >= maxResults-1 {
					break
				}
				var topic map[string]json.RawMessage
				if err := json.Unmarshal(t, &topic); err != nil {
					continue
				}
				text := jsonString(topic["Text"])
				href := jsonString(topic["FirstURL"])
				if text != "" && href != "" {
					title := text
					if len(title) > 80 {
						title = title[:80]
					}
					results = append(results, SearchResult{
						Title:   title,
						URL:     href,
						Snippet: text,
						Source:  "DDG",
					})
				}
			}
		}
	}()

	// 2. If fewer than 3 results, scrape DDG lite HTML
	if len(results) < 3 {
		func() {
			client := getSearchClient()
			req, _ := http.NewRequest("GET", "https://lite.duckduckgo.com/lite/?q="+url.QueryEscape(query), nil)
			req.Header.Set("User-Agent", "Mozilla/5.0 LucyServer/1.0")
			resp, err := client.Do(req)
			if err != nil {
				return
			}
			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			html := string(body)

			linkRe := regexp.MustCompile(`(?i)<a[^>]+href="(https?://[^"]+)"[^>]*>([^<]+)</a>`)
			snippetRe := regexp.MustCompile(`(?is)<td[^>]+class="result-snippet"[^>]*>(.*?)</td>`)
			tagRe := regexp.MustCompile(`<[^>]+>`)

			links := linkRe.FindAllStringSubmatch(html, -1)
			snippets := snippetRe.FindAllStringSubmatch(html, -1)

			for i, m := range links {
				if len(results) >= maxResults {
					break
				}
				u := m[1]
				title := htmlDecode(m[2])
				snippet := ""
				if i < len(snippets) {
					snippet = strings.TrimSpace(tagRe.ReplaceAllString(snippets[i][1], ""))
				}
				duplicate := false
				for _, r := range results {
					if r.URL == u {
						duplicate = true
						break
					}
				}
				if !duplicate {
					results = append(results, SearchResult{Title: title, URL: u, Snippet: snippet, Source: "DDG"})
				}
			}
		}()
	}

	if len(results) > maxResults {
		results = results[:maxResults]
	}
	return results
}

// googleSvcBase is the optional GoogleWorkspaceService (port 8399).
const googleSvcBase = "http://127.0.0.1:8399"

// GetDailyBrief assembles email, calendar, dev news, and weather in parallel.
func GetDailyBrief() map[string]any {
	type result struct {
		key string
		val any
	}
	ch := make(chan result, 4)

	go func() { ch <- result{"emails", fetchGoogleEmails()} }()
	go func() { ch <- result{"calendar", fetchGoogleCalendar()} }()
	go func() {
		news, _ := GetDevNews()
		if len(news) > 5 {
			news = news[:5]
		}
		ch <- result{"dev_news", news}
	}()
	go func() { ch <- result{"weather", fetchWeather()} }()

	brief := map[string]any{
		"generated_at": time.Now().UTC().Format(time.RFC3339),
	}
	for i := 0; i < 4; i++ {
		r := <-ch
		brief[r.key] = r.val
	}
	return brief
}

func fetchGoogleEmails() any {
	client := getSearchClient()
	resp, err := client.Get(googleSvcBase + "/auth/status")
	if err != nil {
		return map[string]any{"authenticated": false, "messages": []any{}}
	}
	defer resp.Body.Close()
	var status map[string]any
	json.NewDecoder(resp.Body).Decode(&status)
	if auth, _ := status["authenticated"].(bool); !auth {
		return map[string]any{"authenticated": false, "messages": []any{}}
	}

	resp2, err := client.Get(googleSvcBase + "/gmail/inbox?maxResults=5&unreadOnly=true")
	if err != nil {
		return map[string]any{"authenticated": true, "messages": []any{}}
	}
	defer resp2.Body.Close()
	var inbox map[string]any
	json.NewDecoder(resp2.Body).Decode(&inbox)
	msgs := inbox["messages"]
	if msgs == nil {
		msgs = []any{}
	}
	return map[string]any{"authenticated": true, "messages": msgs}
}

func fetchGoogleCalendar() any {
	client := getSearchClient()
	resp, err := client.Get(googleSvcBase + "/auth/status")
	if err != nil {
		return map[string]any{"authenticated": false, "events": []any{}}
	}
	defer resp.Body.Close()
	var status map[string]any
	json.NewDecoder(resp.Body).Decode(&status)
	if auth, _ := status["authenticated"].(bool); !auth {
		return map[string]any{"authenticated": false, "events": []any{}}
	}

	resp2, err := client.Get(googleSvcBase + "/cal/events?maxResults=5&daysAhead=1&calendarId=primary")
	if err != nil {
		return map[string]any{"authenticated": true, "events": []any{}}
	}
	defer resp2.Body.Close()
	var cal map[string]any
	json.NewDecoder(resp2.Body).Decode(&cal)
	events := cal["events"]
	if events == nil {
		events = []any{}
	}
	return map[string]any{"authenticated": true, "events": events}
}

func fetchWeather() any {
	lat := os.Getenv("WEATHER_LAT")
	if lat == "" {
		lat = "41.8781"
	}
	lon := os.Getenv("WEATHER_LON")
	if lon == "" {
		lon = "-87.6298"
	}

	u := "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon +
		"&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m" +
		"&temperature_unit=fahrenheit&wind_speed_unit=mph&forecast_days=1"

	client := getSearchClient()
	resp, err := client.Get(u)
	if err != nil {
		return map[string]any{"error": "Weather unavailable"}
	}
	defer resp.Body.Close()

	var data map[string]json.RawMessage
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return map[string]any{"error": "Weather unavailable"}
	}

	var current map[string]json.RawMessage
	if err := json.Unmarshal(data["current"], &current); err != nil {
		return map[string]any{"error": "Weather unavailable"}
	}

	tempF := jsonFloat(current["temperature_2m"])
	feelsF := jsonFloat(current["apparent_temperature"])
	wind := jsonFloat(current["wind_speed_10m"])
	code := int(jsonFloat(current["weather_code"]))

	return map[string]any{
		"temperature_f": tempF,
		"feels_like_f":  feelsF,
		"wind_mph":      wind,
		"condition":     wmoCodeToDescription(code),
	}
}

func wmoCodeToDescription(code int) string {
	switch {
	case code == 0:
		return "Clear sky"
	case code >= 1 && code <= 3:
		return "Partly cloudy"
	case code == 45 || code == 48:
		return "Foggy"
	case code >= 51 && code <= 55:
		return "Drizzle"
	case code >= 61 && code <= 65:
		return "Rain"
	case code >= 71 && code <= 75:
		return "Snow"
	case code >= 80 && code <= 82:
		return "Rain showers"
	case code == 95:
		return "Thunderstorm"
	default:
		return "Mixed conditions"
	}
}

// ── helpers ──────────────────────────────────────────────────────────────────

func jsonString(raw json.RawMessage) string {
	if raw == nil {
		return ""
	}
	var s string
	if err := json.Unmarshal(raw, &s); err != nil {
		return ""
	}
	return s
}

func jsonFloat(raw json.RawMessage) float64 {
	if raw == nil {
		return 0
	}
	var f float64
	json.Unmarshal(raw, &f)
	return f
}

func htmlDecode(s string) string {
	s = strings.ReplaceAll(s, "&amp;", "&")
	s = strings.ReplaceAll(s, "&lt;", "<")
	s = strings.ReplaceAll(s, "&gt;", ">")
	s = strings.ReplaceAll(s, "&quot;", "\"")
	s = strings.ReplaceAll(s, "&#39;", "'")
	return s
}

func cond(test bool, a, b string) string {
	if test {
		return a
	}
	return b
}
