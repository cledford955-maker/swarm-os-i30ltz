package services

import (
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"swarm-os/lucy-server/models"
)

var (
	newsHTTP = &http.Client{
		Timeout: 12 * time.Second,
	}
	htmlTagRE = regexp.MustCompile(`<[^>]+>`)

	newsCacheMu  sync.Mutex
	newsCache    = cacheEntry[[]models.NewsItem]{}
	dealsCacheMu sync.Mutex
	dealsCache   = cacheEntry[[]models.DealItem]{}
	feedCacheMu  sync.Mutex
	feedCache    = cacheEntry[[]models.NewsItem]{}
	devCacheMu   sync.Mutex
	devCache     = cacheEntry[[]models.NewsItem]{}

	newsCacheTTL = 3 * time.Hour
	devCacheTTL  = 15 * time.Minute
)

type cacheEntry[T any] struct {
	data      T
	updatedAt time.Time
}

func (c *cacheEntry[T]) fresh(ttl time.Duration) bool {
	return time.Since(c.updatedAt) < ttl
}

// GetNews returns gaming news from GameSpot + Boiling Steam RSS feeds.
func GetNews() ([]models.NewsItem, error) {
	newsCacheMu.Lock()
	defer newsCacheMu.Unlock()
	if newsCache.fresh(newsCacheTTL) && len(newsCache.data) > 0 {
		return newsCache.data, nil
	}
	items, err := fetchRSSFeeds(map[string]string{
		"GameSpot":         "https://www.gamespot.com/feeds/news/",
		"Boiling Steam":    "https://boilingsteam.com/feed/",
		// GamingOnLinux + Phoronix — the two feeds Linux gamers actually read.
		// (SWARM_AI_FEATURES.md 2026-09-15 backlog item; both feeds public, no key.)
		"GamingOnLinux":    "https://www.gamingonlinux.com/article_rss.php",
		"Phoronix":         "https://www.phoronix.com/rss.php",
	}, "gaming")
	if err == nil {
		newsCache = cacheEntry[[]models.NewsItem]{data: items, updatedAt: time.Now()}
	}
	return items, err
}

// GetDeals returns game deals from CheapShark (Steam, up to $15).
func GetDeals() ([]models.DealItem, error) {
	dealsCacheMu.Lock()
	defer dealsCacheMu.Unlock()
	if dealsCache.fresh(newsCacheTTL) && len(dealsCache.data) > 0 {
		return dealsCache.data, nil
	}

	resp, err := newsHTTP.Get("https://www.cheapshark.com/api/1.0/deals?storeID=1&upperPrice=15")
	if err != nil {
		return []models.DealItem{}, nil
	}
	defer resp.Body.Close()

	var raw []struct {
		Title       string `json:"title"`
		SalePrice   string `json:"salePrice"`
		NormalPrice string `json:"normalPrice"`
		Savings     string `json:"savings"`
		StoreID     string `json:"storeID"`
		DealID      string `json:"dealID"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return []models.DealItem{}, nil
	}
	limit := 15
	if len(raw) < limit {
		limit = len(raw)
	}
	items := make([]models.DealItem, limit)
	for i, d := range raw[:limit] {
		items[i] = models.DealItem{
			Title: d.Title, SalePrice: d.SalePrice, NormalPrice: d.NormalPrice,
			Savings: d.Savings, StoreId: d.StoreID, DealId: d.DealID,
		}
	}
	dealsCache = cacheEntry[[]models.DealItem]{data: items, updatedAt: time.Now()}
	return items, nil
}

// GetNewsFeed returns gaming news from GameSpot + Boiling Steam + Linux Gaming News.
func GetNewsFeed() ([]models.NewsItem, error) {
	feedCacheMu.Lock()
	defer feedCacheMu.Unlock()
	if feedCache.fresh(newsCacheTTL) && len(feedCache.data) > 0 {
		return feedCache.data, nil
	}
	items, err := fetchRSSFeeds(map[string]string{
		"GameSpot":         "https://www.gamespot.com/feeds/news/",
		"Boiling Steam":    "https://boilingsteam.com/feed/",
		"Linux Gaming News": "https://linuxgaming.life/feed/",
		"GamingOnLinux":    "https://www.gamingonlinux.com/article_rss.php",
		"Phoronix":         "https://www.phoronix.com/rss.php",
	}, "gaming")
	if err == nil {
		feedCache = cacheEntry[[]models.NewsItem]{data: items, updatedAt: time.Now()}
	}
	return items, err
}

// GetDevNews returns developer news from Google + NVIDIA blogs.
func GetDevNews() ([]models.NewsItem, error) {
	devCacheMu.Lock()
	defer devCacheMu.Unlock()
	if devCache.fresh(devCacheTTL) && len(devCache.data) > 0 {
		return devCache.data, nil
	}
	items, err := fetchRSSFeeds(map[string]string{
		"Google Dev Blog":      "https://developers.googleblog.com/feeds/posts/default",
		"Android Developers":   "https://android-developers.googleblog.com/feeds/posts/default",
		"NVIDIA Developer News": "https://developer.nvidia.com/blog/feed/",
	}, "dev")
	if err == nil {
		devCache = cacheEntry[[]models.NewsItem]{data: items, updatedAt: time.Now()}
	}
	return items, err
}

// GetSteamLibrary fetches the user's Steam library using env credentials.
func GetSteamLibrary() (map[string]any, error) {
	steamKey := os.Getenv("STEAM_API_KEY")
	steamID := os.Getenv("STEAM_ID64")
	if steamKey == "" || steamID == "" {
		return map[string]any{"error": "Steam API key or Steam ID not configured", "games": []any{}}, nil
	}

	url := fmt.Sprintf(
		"https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=%s&steamid=%s&include_appinfo=true&include_played_free_games=true&format=json",
		steamKey, steamID)
	resp, err := newsHTTP.Get(url)
	if err != nil {
		return map[string]any{"error": err.Error(), "games": []any{}}, nil
	}
	defer resp.Body.Close()

	var raw struct {
		Response struct {
			Games []struct {
				Appid          int    `json:"appid"`
				Name           string `json:"name"`
				PlaytimeForever int   `json:"playtime_forever"`
			} `json:"games"`
		} `json:"response"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return map[string]any{"error": err.Error(), "games": []any{}}, nil
	}

	enriched := make([]map[string]any, 0, len(raw.Response.Games))
	for _, g := range raw.Response.Games {
		enriched = append(enriched, map[string]any{
			"appid":            g.Appid,
			"name":             g.Name,
			"playtime_forever": g.PlaytimeForever,
			"header_image":     fmt.Sprintf("https://cdn.akamai.steamstatic.com/steam/apps/%d/header.jpg", g.Appid),
			"capsule_image":    fmt.Sprintf("https://cdn.akamai.steamstatic.com/steam/apps/%d/capsule_616x353.jpg", g.Appid),
			"steam_url":        fmt.Sprintf("steam://rungameid/%d", g.Appid),
			"store_url":        fmt.Sprintf("https://store.steampowered.com/app/%d/", g.Appid),
		})
	}
	return map[string]any{"games": enriched, "total": len(enriched), "source": "steam"}, nil
}

// GetGamePrices queries CheapShark for deals on a specific game.
func GetGamePrices(gameId string) (map[string]any, error) {
	resp, err := newsHTTP.Get("https://www.cheapshark.com/api/1.0/games?id=" + gameId)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	defer resp.Body.Close()

	var raw struct {
		Info  json.RawMessage `json:"info"`
		Deals []struct {
			Price       string `json:"price"`
			RetailPrice string `json:"retailPrice"`
			StoreId     string `json:"storeID"`
		} `json:"deals"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	if raw.Deals == nil {
		return map[string]any{"error": "no deals found"}, nil
	}

	sort.Slice(raw.Deals, func(i, j int) bool {
		return raw.Deals[i].Price < raw.Deals[j].Price
	})
	limit := 5
	if len(raw.Deals) < limit {
		limit = len(raw.Deals)
	}
	return map[string]any{
		"cheapest": raw.Deals[0],
		"deals":    raw.Deals[:limit],
		"info":     raw.Info,
	}, nil
}

// GetGameInfo fetches raw Steam app details.
func GetGameInfo(gameId string) (map[string]any, error) {
	resp, err := newsHTTP.Get("https://store.steampowered.com/api/appdetails?appids=" + gameId)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return map[string]any{"error": err.Error()}, nil
	}
	return map[string]any{"raw": string(b)}, nil
}

// GetGfnGames returns a static list of known GeForce Now titles.
// GFN has no public catalog API — GamingAgent-go's live catalog supersedes this.
func GetGfnGames() []string {
	return []string{
		"Cyberpunk 2077", "Fortnite", "Minecraft", "Apex Legends",
		"The Witcher 3", "Control", "Dying Light 2", "Red Dead Redemption 2",
		"Assassin's Creed Valhalla", "Watch Dogs: Legion",
	}
}

// OptimizeGfn returns streaming recommendations for a given game.
func OptimizeGfn(game string) map[string]any {
	return map[string]any{
		"status": "ok",
		"game":   game,
		"recommendations": []string{
			"Enable RTX On for ray tracing if supported",
			"Set resolution to 1080p for best streaming performance",
			"Use wired Ethernet for lowest latency",
			"Enable DLSS Quality mode for performance/quality balance",
			"Close background applications to free bandwidth",
		},
	}
}

// ── RSS parsing ──────────────────────────────────────────────────────────────

func fetchRSSFeeds(feeds map[string]string, category string) ([]models.NewsItem, error) {
	var mu sync.Mutex
	var wg sync.WaitGroup
	var all []models.NewsItem

	for src, url := range feeds {
		wg.Add(1)
		go func(source, feedURL string) {
			defer wg.Done()
			items, _ := fetchOneFeed(feedURL, source, category)
			mu.Lock()
			all = append(all, items...)
			mu.Unlock()
		}(src, url)
	}
	wg.Wait()

	sort.Slice(all, func(i, j int) bool {
		return all[i].PubDate > all[j].PubDate
	})
	return all, nil
}

func fetchOneFeed(url, source, category string) ([]models.NewsItem, error) {
	resp, err := newsHTTP.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	return parseRSS(body, source, category), nil
}

// rssChannel handles both RSS and Atom feeds via xml.Unmarshal.
// It uses two separate struct shapes and falls back between them.
type rssFeed struct {
	Channel struct {
		Items []rssItem `xml:"item"`
	} `xml:"channel"`
	Entries []atomEntry `xml:"entry"`
}

type rssItem struct {
	Title       string `xml:"title"`
	Link        string `xml:"link"`
	PubDate     string `xml:"pubDate"`
	Description string `xml:"description"`
}

type atomEntry struct {
	Title     string     `xml:"title"`
	Links     []atomLink `xml:"link"`
	Published string     `xml:"published"`
	Updated   string     `xml:"updated"`
	Summary   string     `xml:"summary"`
}

type atomLink struct {
	Href string `xml:"href,attr"`
	Rel  string `xml:"rel,attr"`
}

func parseRSS(data []byte, source, category string) []models.NewsItem {
	var feed rssFeed
	if err := xml.Unmarshal(data, &feed); err != nil {
		return nil
	}

	var items []models.NewsItem

	// RSS items
	for _, it := range feed.Channel.Items {
		snippet := htmlTagRE.ReplaceAllString(it.Description, "")
		if len(snippet) > 150 {
			snippet = snippet[:150] + "..."
		}
		items = append(items, models.NewsItem{
			Source:   source,
			Title:    strings.TrimSpace(it.Title),
			Link:     strings.TrimSpace(it.Link),
			PubDate:  it.PubDate,
			Snippet:  snippet,
			Category: category,
		})
		if len(items) >= 5 {
			break
		}
	}

	// Atom entries (when RSS channel is empty)
	if len(items) == 0 {
		for _, e := range feed.Entries {
			link := ""
			for _, l := range e.Links {
				if l.Rel != "edit" {
					link = l.Href
					break
				}
			}
			pubDate := e.Published
			if pubDate == "" {
				pubDate = e.Updated
			}
			snippet := htmlTagRE.ReplaceAllString(e.Summary, "")
			if len(snippet) > 150 {
				snippet = snippet[:150] + "..."
			}
			items = append(items, models.NewsItem{
				Source:   source,
				Title:    strings.TrimSpace(e.Title),
				Link:     link,
				PubDate:  pubDate,
				Snippet:  snippet,
				Category: category,
			})
			if len(items) >= 5 {
				break
			}
		}
	}

	return items
}
