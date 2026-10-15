// Price-alert daemon.
//
// Polls CheapShark once every 24h for every owned Steam game and files a row
// into `price_alerts` (plus an HTTP push to a webhook URL when configured)
// whenever a game drops below its threshold.
//
// Defaults:
//   Threshold: $15  (matches LucyServer's GetDeals()'s `upperPrice=15`)
//   Interval:  24h  (CheapShark etiquette; overridable via PRICE_ALERT_INTERVAL)
//   Notify:    optional POST to $PRICE_ALERT_WEBHOOK_URL (typically the
//              LucyServer /api/webhooks/price_alerts endpoint I added earlier)
//
// This is a slow background daemon — a bad Steam key doesn't crash it, it
// simply logs and retries at the next tick.

package services

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"

	"swarm-os/gaming-agent/models"
)

const (
	defaultPriceAlertThreshold = 15.0
	defaultPriceAlertInterval  = 24 * time.Hour
)

// PriceAlert is one triggered alert (also matches the JSON we push to the
// webhook URL).
type PriceAlert struct {
	AppID       int     `json:"app_id"`
	Title       string  `json:"title"`
	SalePrice   string  `json:"sale_price"`
	NormalPrice string  `json:"normal_price"`
	Savings     string  `json:"savings"`
	DealID      string  `json:"deal_id"`
	Threshold   float64 `json:"threshold"`
}

type PriceAlertDaemon struct {
	steam     *SteamService
	games     *GamesService
	db        *sql.DB
	http      *http.Client
	interval  time.Duration
	threshold float64
	paceDelay time.Duration
	// Guard so Start() is idempotent.
	mu      sync.Mutex
	started bool
	stop    chan struct{}
}

func NewPriceAlertDaemon(steam *SteamService, games *GamesService, db *sql.DB) *PriceAlertDaemon {
	return &PriceAlertDaemon{
		steam:     steam,
		games:     games,
		db:        db,
		http:      &http.Client{Timeout: 6 * time.Second},
		interval:  parseIntervalEnv(),
		threshold: parseThresholdEnv(),
		paceDelay: parsePaceDelayEnv(),
		stop:      make(chan struct{}),
	}
}

func parsePaceDelayEnv() time.Duration {
	v := os.Getenv("PRICE_ALERT_PACE_MS")
	if v == "" {
		return 150 * time.Millisecond
	}
	ms, err := strconv.Atoi(v)
	if err != nil || ms < 0 {
		return 150 * time.Millisecond
	}
	return time.Duration(ms) * time.Millisecond
}

func parseIntervalEnv() time.Duration {
	v := os.Getenv("PRICE_ALERT_INTERVAL")
	if v == "" {
		return defaultPriceAlertInterval
	}
	d, err := time.ParseDuration(v)
	if err != nil || d < time.Minute {
		return defaultPriceAlertInterval
	}
	return d
}

func parseThresholdEnv() float64 {
	v := os.Getenv("PRICE_ALERT_THRESHOLD")
	if v == "" {
		return defaultPriceAlertThreshold
	}
	f, err := strconv.ParseFloat(v, 64)
	if err != nil || f <= 0 {
		return defaultPriceAlertThreshold
	}
	return f
}

// Start begins the daemon in a background goroutine. Safe to call multiple
// times; only the first call actually starts the loop.
func (d *PriceAlertDaemon) Start() {
	d.mu.Lock()
	if d.started {
		d.mu.Unlock()
		return
	}
	d.started = true
	d.mu.Unlock()

	go d.run()
}

// Stop signals the daemon to exit. Safe to call multiple times.
func (d *PriceAlertDaemon) Stop() {
	d.mu.Lock()
	defer d.mu.Unlock()
	if !d.started {
		return
	}
	select {
	case <-d.stop:
		// Already stopped.
	default:
		close(d.stop)
	}
	d.started = false
}

func (d *PriceAlertDaemon) run() {
	// First tick fires after a short warmup — never at t=0. This gives Steam/
	// GFN cache warming a chance to complete before we hit CheapShark.
	timer := time.NewTimer(30 * time.Second)
	defer timer.Stop()
	for {
		select {
		case <-d.stop:
			return
		case <-timer.C:
			if err := d.CheckOnce(); err != nil {
				log.Printf("[price-alert] check failed: %v", err)
			}
			timer.Reset(d.interval)
		}
	}
}

// CheckOnce runs the daemon body exactly once. Exposed for tests.
func (d *PriceAlertDaemon) CheckOnce() error {
	library, err := d.steam.GetLibrary()
	if err != nil {
		return fmt.Errorf("steam library: %w", err)
	}
	if len(library) == 0 {
		return nil
	}

	alerts := 0
	for _, g := range library {
		select {
		case <-d.stop:
			return nil
		default:
		}
		if triggered, ok := d.checkGame(g); ok {
			alerts++
			d.recordAlert(triggered)
			d.pushWebhook(triggered)
		}
		if d.paceDelay > 0 {
			select {
			case <-d.stop:
				return nil
			case <-time.After(d.paceDelay):
			}
		}
	}
	log.Printf("[price-alert] check complete: %d games scanned, %d alerts", len(library), alerts)
	return nil
}

// checkGame consults CheapShark for one Steam game. Returns the PriceAlert
// only if the cheapest current price is below the daemon's threshold.
func (d *PriceAlertDaemon) checkGame(g models.SteamGame) (PriceAlert, bool) {
	detail, err := d.games.GetPrices(strconv.Itoa(g.AppId))
	if err != nil || detail == nil || len(detail.Deals) == 0 {
		return PriceAlert{}, false
	}
	// Deals aren't guaranteed sorted; pick the cheapest.
	cheapestIdx := 0
	cheapest := parseDealPrice(detail.Deals[0].Price)
	for i, deal := range detail.Deals[1:] {
		p := parseDealPrice(deal.Price)
		if p >= 0 && (cheapest < 0 || p < cheapest) {
			cheapestIdx = i + 1
			cheapest = p
		}
	}
	if cheapest < 0 || cheapest >= d.threshold {
		return PriceAlert{}, false
	}
	deal := detail.Deals[cheapestIdx]
	return PriceAlert{
		AppID:       g.AppId,
		Title:       g.Name,
		SalePrice:   deal.Price,
		NormalPrice: deal.RetailPrice,
		Savings:     deal.Savings,
		DealID:      deal.DealID,
		Threshold:   d.threshold,
	}, true
}

// parseDealPrice returns the numeric price or -1 on parse failure.
func parseDealPrice(s string) float64 {
	f, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return -1
	}
	return f
}

func (d *PriceAlertDaemon) recordAlert(a PriceAlert) {
	// Skip if we already saw an alert for this deal_id (CheapShark keeps a
	// deal live for a while; we only want one row per drop event).
	var existing int
	err := d.db.QueryRow(
		`SELECT COUNT(1) FROM price_alerts WHERE deal_id = ? AND created_at > datetime('now', '-7 days')`,
		a.DealID,
	).Scan(&existing)
	if err == nil && existing > 0 {
		return
	}
	_, err = d.db.Exec(
		`INSERT INTO price_alerts (app_id, title, sale_price, normal_price, savings, deal_id, threshold)
		 VALUES (?, ?, ?, ?, ?, ?, ?)`,
		a.AppID, a.Title, a.SalePrice, a.NormalPrice, a.Savings, a.DealID, a.Threshold,
	)
	if err != nil {
		log.Printf("[price-alert] insert failed for %q: %v", a.Title, err)
	}
}

func (d *PriceAlertDaemon) pushWebhook(a PriceAlert) {
	url := os.Getenv("PRICE_ALERT_WEBHOOK_URL")
	if url == "" {
		return
	}
	body, _ := json.Marshal(a)
	req, err := http.NewRequest("POST", url, bytes.NewReader(body))
	if err != nil {
		return
	}
	req.Header.Set("Content-Type", "application/json")
	if tok := os.Getenv("SWARM_AUTH_TOKEN"); tok != "" {
		req.Header.Set("X-Swarm-Auth", tok)
	}
	resp, err := d.http.Do(req)
	if err != nil {
		log.Printf("[price-alert] webhook push failed: %v", err)
		return
	}
	resp.Body.Close()
}

// RecentAlerts returns the last `limit` price alerts, newest first. Used by
// GET /api/price-alerts.
func RecentAlerts(db *sql.DB, limit int) ([]PriceAlert, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}
	rows, err := db.Query(
		`SELECT app_id, title, sale_price, normal_price, savings, deal_id, threshold
		 FROM price_alerts ORDER BY id DESC LIMIT ?`,
		limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []PriceAlert
	for rows.Next() {
		var a PriceAlert
		if err := rows.Scan(&a.AppID, &a.Title, &a.SalePrice, &a.NormalPrice,
			&a.Savings, &a.DealID, &a.Threshold); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}
