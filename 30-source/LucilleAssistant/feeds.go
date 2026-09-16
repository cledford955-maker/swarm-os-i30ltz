package main

import (
	"bytes"
	"context"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

// ── News: Arch, distro, Linux and Linux-gaming feeds only ───────

type NewsItem struct {
	Source  string    `json:"source"`
	Tag     string    `json:"tag"`
	Title   string    `json:"title"`
	Link    string    `json:"link"`
	Summary string    `json:"summary"`
	When    time.Time `json:"when"`
}

type rssDoc struct {
	Items []struct {
		Title   string `xml:"title"`
		Link    string `xml:"link"`
		Desc    string `xml:"description"`
		PubDate string `xml:"pubDate"`
		Date    string `xml:"date"`
	} `xml:"channel>item"`
	Entries []struct {
		Title string `xml:"title"`
		Link  struct {
			Href string `xml:"href,attr"`
		} `xml:"link"`
		Summary string `xml:"summary"`
		Updated string `xml:"updated"`
	} `xml:"entry"`
}

var tagRe = regexp.MustCompile(`<[^>]*>`)

func cleanText(s string, n int) string {
	s = strings.Join(strings.Fields(html.UnescapeString(tagRe.ReplaceAllString(s, " "))), " ")
	if r := []rune(s); len(r) > n {
		return string(r[:n]) + "…"
	}
	return s
}

func parseWhen(s string) time.Time {
	s = strings.TrimSpace(s)
	for _, f := range []string{time.RFC1123Z, time.RFC1123, time.RFC3339, "Mon, 2 Jan 2006 15:04:05 -0700", "Mon, 02 Jan 2006 15:04:05 MST"} {
		if t, err := time.Parse(f, s); err == nil {
			return t
		}
	}
	return time.Time{}
}

func fetchFeed(ctx context.Context, f Feed) ([]NewsItem, error) {
	req, _ := http.NewRequestWithContext(ctx, "GET", f.URL, nil)
	req.Header.Set("User-Agent", "lucille-assistant/"+version+" (SWARM OS)")
	resp, err := httpc.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	var doc rssDoc
	dec := xml.NewDecoder(bytes.NewReader(body))
	dec.Strict = false
	dec.CharsetReader = func(_ string, in io.Reader) (io.Reader, error) { return in, nil }
	if err := dec.Decode(&doc); err != nil {
		return nil, err
	}
	var out []NewsItem
	for _, it := range doc.Items {
		w := parseWhen(it.PubDate)
		if w.IsZero() {
			w = parseWhen(it.Date)
		}
		out = append(out, NewsItem{f.Name, f.Tag, cleanText(it.Title, 160), strings.TrimSpace(it.Link), cleanText(it.Desc, 220), w})
	}
	for _, e := range doc.Entries {
		out = append(out, NewsItem{f.Name, f.Tag, cleanText(e.Title, 160), e.Link.Href, cleanText(e.Summary, 220), parseWhen(e.Updated)})
	}
	if len(out) > 12 {
		out = out[:12]
	}
	return out, nil
}

func (a *App) blocked(it NewsItem) bool {
	s := strings.ToLower(" " + it.Title + " " + it.Summary + " ")
	for _, b := range a.cfg.NewsBlock {
		if strings.Contains(s, strings.ToLower(b)) {
			return true
		}
	}
	return false
}

type newsResult struct {
	Items   []NewsItem        `json:"items"`
	Errors  map[string]string `json:"errors"`
	Dropped int               `json:"dropped_off_topic"`
}

func (a *App) news(ctx context.Context) (newsResult, error) {
	v, err := a.cache.get("news", 30*time.Minute, func() (any, error) {
		res := newsResult{Errors: map[string]string{}}
		var mu sync.Mutex
		var wg sync.WaitGroup
		for _, f := range a.cfg.NewsFeeds {
			wg.Add(1)
			go func() {
				defer wg.Done()
				items, err := fetchFeed(ctx, f)
				mu.Lock()
				defer mu.Unlock()
				if err != nil {
					res.Errors[f.Name] = err.Error()
					return
				}
				for _, it := range items {
					if a.blocked(it) {
						res.Dropped++
						continue
					}
					res.Items = append(res.Items, it)
				}
			}()
		}
		wg.Wait()
		sort.Slice(res.Items, func(i, j int) bool { return res.Items[i].When.After(res.Items[j].When) })
		if len(res.Items) == 0 {
			return nil, fmt.Errorf("no feeds answered")
		}
		return res, nil
	})
	if err != nil {
		return newsResult{}, err
	}
	return v.(newsResult), nil
}

func (a *App) handleNews(w http.ResponseWriter, r *http.Request) {
	res, err := a.news(r.Context())
	if err != nil {
		writeJSON(w, map[string]any{"ok": false, "error": err.Error()})
		return
	}
	tag := r.URL.Query().Get("tag")
	items := res.Items
	if tag != "" {
		items = nil
		for _, it := range res.Items {
			if it.Tag == tag {
				items = append(items, it)
			}
		}
	}
	writeJSON(w, map[string]any{"ok": true, "items": items, "errors": res.Errors, "dropped_off_topic": res.Dropped})
}

// ── Deals: Steam sales + authorized key stores (CheapShark) ─────

const cheapshark = "https://www.cheapshark.com/api/1.0"

// Authorized key resellers CheapShark tracks (no grey-market marketplaces).
var keyStores = map[string]string{
	"2": "GamersGate", "3": "GreenManGaming", "15": "Fanatical", "21": "WinGameStore",
	"23": "GameBillet", "24": "Voidu", "27": "Gamesplanet", "29": "2Game", "30": "IndieGala",
	"33": "DLGamer", "34": "Noctre", "35": "DreamGame",
}

type Deal struct {
	Title       string `json:"title"`
	Store       string `json:"store"`
	SalePrice   string `json:"sale_price"`
	NormalPrice string `json:"normal_price"`
	Savings     int    `json:"savings_pct"`
	SteamAppID  string `json:"steam_app_id"`
	Rating      string `json:"steam_rating_pct"`
	Thumb       string `json:"thumb"`
	URL         string `json:"url"`
}

type csDeal struct {
	Title, StoreID, DealID, SalePrice, NormalPrice, Savings, SteamAppID, SteamRatingPercent, Thumb string
}

func toDeal(d csDeal) Deal {
	var sav float64
	fmt.Sscanf(d.Savings, "%f", &sav)
	store := keyStores[d.StoreID]
	if d.StoreID == "1" {
		store = "Steam"
	}
	return Deal{d.Title, store, d.SalePrice, d.NormalPrice, int(sav + 0.5), d.SteamAppID, d.SteamRatingPercent, d.Thumb,
		"https://www.cheapshark.com/redirect?dealID=" + url.QueryEscape(d.DealID)}
}

func (a *App) deals(ctx context.Context) (map[string][]Deal, error) {
	v, err := a.cache.get("deals", time.Hour, func() (any, error) {
		out := map[string][]Deal{}
		var steam, keys []csDeal
		if err := getJSON(ctx, cheapshark+"/deals?storeID=1&onSale=1&sortBy=Deal%20Rating&pageSize=15&steamRating=75", &steam); err != nil {
			return nil, err
		}
		ids := make([]string, 0, len(keyStores))
		for id := range keyStores {
			ids = append(ids, id)
		}
		if err := getJSON(ctx, cheapshark+"/deals?onSale=1&sortBy=Deal%20Rating&pageSize=20&steamRating=75&storeID="+strings.Join(ids, ","), &keys); err != nil {
			return nil, err
		}
		for _, d := range steam {
			out["steam"] = append(out["steam"], toDeal(d))
		}
		for _, d := range keys {
			out["keys"] = append(out["keys"], toDeal(d))
		}
		return out, nil
	})
	if err != nil {
		return nil, err
	}
	return v.(map[string][]Deal), nil
}

func (a *App) handleDeals(w http.ResponseWriter, r *http.Request) {
	d, err := a.deals(r.Context())
	if err != nil {
		writeJSON(w, map[string]any{"ok": false, "error": "CheapShark didn't answer: " + err.Error()})
		return
	}
	writeJSON(w, map[string]any{"ok": true, "steam": d["steam"], "keys": d["keys"], "source": "cheapshark.com"})
}

// handleDealLookup compares every tracked store's price for one game title.
func (a *App) handleDealLookup(w http.ResponseWriter, r *http.Request) {
	title := strings.TrimSpace(r.URL.Query().Get("title"))
	if title == "" {
		writeErr(w, 400, "Add ?title=Hades")
		return
	}
	var games []struct{ GameID, External, Cheapest, SteamAppID, Thumb string }
	if err := getJSON(r.Context(), cheapshark+"/games?limit=1&title="+url.QueryEscape(title), &games); err != nil || len(games) == 0 {
		writeJSON(w, map[string]any{"ok": false, "error": "No store lists a game called " + title})
		return
	}
	var detail struct {
		Info              struct{ Title, SteamAppID string }
		CheapestPriceEver struct {
			Price string
			Date  int64
		}
		Deals []struct{ StoreID, DealID, Price, RetailPrice, Savings string }
	}
	if err := getJSON(r.Context(), cheapshark+"/games?id="+games[0].GameID, &detail); err != nil {
		writeErr(w, 502, err.Error())
		return
	}
	var prices []Deal
	for _, d := range detail.Deals {
		prices = append(prices, toDeal(csDeal{Title: detail.Info.Title, StoreID: d.StoreID, DealID: d.DealID,
			SalePrice: d.Price, NormalPrice: d.RetailPrice, Savings: d.Savings}))
	}
	writeJSON(w, map[string]any{"ok": true, "title": detail.Info.Title, "steam_app_id": detail.Info.SteamAppID,
		"lowest_ever": detail.CheapestPriceEver.Price, "lowest_ever_date": time.Unix(detail.CheapestPriceEver.Date, 0).Format("2006-01-02"),
		"prices": prices})
}

// ── Gaming hours: Steam playtime + logged gaming sessions ───────

type RecentGame struct {
	AppID       int     `json:"appid"`
	Name        string  `json:"name"`
	Hours2Weeks float64 `json:"hours_2weeks"`
	HoursTotal  float64 `json:"hours_total"`
}

func (a *App) steamRecent(ctx context.Context) ([]RecentGame, error) {
	if a.cfg.SteamKey == "" || a.cfg.SteamID == "" {
		return nil, fmt.Errorf("STEAM_API_KEY / STEAM_ID64 not set")
	}
	v, err := a.cache.get("steam-recent", 20*time.Minute, func() (any, error) {
		var resp struct {
			Response struct {
				Games []struct {
					AppID           int    `json:"appid"`
					Name            string `json:"name"`
					Playtime2Weeks  int    `json:"playtime_2weeks"`
					PlaytimeForever int    `json:"playtime_forever"`
				} `json:"games"`
			} `json:"response"`
		}
		u := "https://api.steampowered.com/IPlayerService/GetRecentlyPlayedGames/v1/?format=json&key=" +
			url.QueryEscape(a.cfg.SteamKey) + "&steamid=" + url.QueryEscape(a.cfg.SteamID)
		if err := getJSON(ctx, u, &resp); err != nil {
			// Never echo the URL — it carries the key.
			if strings.Contains(err.Error(), "HTTP 403") || strings.Contains(err.Error(), "HTTP 401") {
				return nil, fmt.Errorf("Steam rejected STEAM_API_KEY (403) — make a new key at steamcommunity.com/dev/apikey")
			}
			return nil, fmt.Errorf("Steam Web API didn't answer")
		}
		var out []RecentGame
		for _, g := range resp.Response.Games {
			out = append(out, RecentGame{g.AppID, g.Name, float64(g.Playtime2Weeks) / 60, float64(g.PlaytimeForever) / 60})
		}
		return out, nil
	})
	if err != nil {
		return nil, err
	}
	return v.([]RecentGame), nil
}

func (a *App) handleGaming(w http.ResponseWriter, r *http.Request) {
	out := map[string]any{"ok": true}
	games, err := a.steamRecent(r.Context())
	if err != nil {
		out["steam_error"] = err.Error()
	}
	var total float64
	for _, g := range games {
		total += g.Hours2Weeks
	}
	out["steam_recent"], out["steam_hours_2weeks"] = games, total
	list, _ := a.store.Sessions()
	out["logged_week_hours"] = summarize(list, time.Now()).GamingWeek / 60
	writeJSON(w, out)
}

// ── Build ideas: Nemotron with project context, curated fallback ─

type Idea struct {
	Title string `json:"title"`
	Pitch string `json:"pitch"`
	Stack string `json:"stack"`
	Size  string `json:"size"` // evening | weekend | sprint
}

var fallbackIdeas = []Idea{
	{"Hex launcher heatmap", "Tint each hex icon on the SWARM desktop by how many hours you spent in that app this week.", "Flutter + Lucille Assistant /api/sessions", "weekend"},
	{"Proton compatibility sentinel", "Watch ProtonDB for your wishlist and ping when a game moves to Gold or Platinum.", "Go worker + GamingAgent :8401", "weekend"},
	{"ISO build flight recorder", "Record every build_swarm_iso run — duration, package diff, failure line — and graph it.", "Bash hook + Go + SQLite", "evening"},
	{"Voice check-in", "Say 'Lucille, meds done' on the phone and it ticks the care log through ElevenLabs/whisper.", "Companion app + /api/care", "weekend"},
	{"Pacman update risk score", "Before -Syu, cross-check pending packages against Arch news for manual-intervention notices.", "Go + /api/news + checkupdates", "evening"},
	{"Lightning wallpaper that reacts to load", "Bolts in the desktop background fire faster as CPU/GPU load climbs.", "Flutter shader + /proc/stat", "sprint"},
}

func (a *App) ideas(ctx context.Context) ([]Idea, string, error) {
	if a.cfg.NvidiaKey == "" {
		return fallbackIdeas, "curated", nil
	}
	v, err := a.cache.get("ideas", 6*time.Hour, func() (any, error) {
		var ctxLines []string
		for _, rs := range a.gitAll() {
			ctxLines = append(ctxLines, fmt.Sprintf("repo %s: %d changed, last commit %q %s", rs.Path, rs.Dirty+rs.Untracked, rs.LastCommit, rs.LastWhen))
		}
		if mem, err := a.memory(10, ""); err == nil {
			for _, e := range mem {
				ctxLines = append(ctxLines, fmt.Sprintf("memory %s/%s: %s", e.Kind, e.Key, cleanText(e.Content, 200)))
			}
		}
		list, _ := a.store.Sessions()
		for p, m := range summarize(list, time.Now()).WeekMin {
			ctxLines = append(ctxLines, fmt.Sprintf("this week %s: %.1f h", p, m/60))
		}
		prompt := "You are Lucille, the AI of SWARM OS (a custom Arch Linux desktop: labwc, Flutter shell, Rust/Slint panel, Go agents, Android companion). " +
			"The user builds Linux distros, games on Linux, and likes native lightweight tools (never Electron). " +
			"Suggest 6 concrete app/project/build ideas that fit what they are working on. " +
			"Reply with ONLY a JSON array of objects {\"title\",\"pitch\",\"stack\",\"size\"} where size is evening, weekend or sprint. Context:\n" +
			strings.Join(ctxLines, "\n")
		body, _ := json.Marshal(map[string]any{
			"model":       "nvidia/llama-3.3-nemotron-super-49b-v1",
			"messages":    []map[string]string{{"role": "system", "content": "detailed thinking off"}, {"role": "user", "content": prompt}},
			"temperature": 0.8, "max_tokens": 1200,
		})
		c, cancel := context.WithTimeout(ctx, 45*time.Second)
		defer cancel()
		req, _ := http.NewRequestWithContext(c, "POST", "https://integrate.api.nvidia.com/v1/chat/completions", bytes.NewReader(body))
		req.Header.Set("Authorization", "Bearer "+a.cfg.NvidiaKey)
		req.Header.Set("Content-Type", "application/json")
		resp, err := (&http.Client{Timeout: 50 * time.Second}).Do(req)
		if err != nil {
			return nil, err
		}
		defer resp.Body.Close()
		var cr struct {
			Choices []struct{ Message struct{ Content string } }
		}
		if err := json.NewDecoder(resp.Body).Decode(&cr); err != nil || len(cr.Choices) == 0 {
			return nil, fmt.Errorf("Nemotron returned HTTP %d with no answer", resp.StatusCode)
		}
		txt := cr.Choices[0].Message.Content
		i, j := strings.Index(txt, "["), strings.LastIndex(txt, "]")
		var ideas []Idea
		if i < 0 || j <= i || json.Unmarshal([]byte(txt[i:j+1]), &ideas) != nil || len(ideas) == 0 {
			return nil, fmt.Errorf("Nemotron answer wasn't a JSON list")
		}
		return ideas, nil
	})
	if err != nil {
		return fallbackIdeas, "curated (Nemotron: " + err.Error() + ")", nil
	}
	return v.([]Idea), "nemotron", nil
}

func (a *App) handleIdeas(w http.ResponseWriter, r *http.Request) {
	ideas, src, _ := a.ideas(r.Context())
	writeJSON(w, map[string]any{"ok": true, "ideas": ideas, "source": src})
}
