package services

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	_ "modernc.org/sqlite"

	dbpkg "swarm-os/gaming-agent/db"
)

// helper — open a fresh gaming.db in a temp dir with the price_alerts schema.
func newTestDB(t *testing.T) *sql.DB {
	t.Helper()
	path := filepath.Join(t.TempDir(), "gaming.db")
	t.Setenv("GAMING_DB_PATH", path)
	db, err := dbpkg.Open()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func TestParseIntervalEnv_Defaults(t *testing.T) {
	os.Unsetenv("PRICE_ALERT_INTERVAL")
	if parseIntervalEnv() != defaultPriceAlertInterval {
		t.Errorf("unset env should use default")
	}
	t.Setenv("PRICE_ALERT_INTERVAL", "not-a-duration")
	if parseIntervalEnv() != defaultPriceAlertInterval {
		t.Errorf("invalid duration should fall back to default")
	}
	t.Setenv("PRICE_ALERT_INTERVAL", "10s")
	if parseIntervalEnv() != defaultPriceAlertInterval {
		t.Errorf("<1m intervals must be rejected to protect CheapShark")
	}
	t.Setenv("PRICE_ALERT_INTERVAL", "6h")
	if got := parseIntervalEnv(); got.Hours() != 6 {
		t.Errorf("6h parse = %v", got)
	}
}

func TestParseThresholdEnv_Defaults(t *testing.T) {
	os.Unsetenv("PRICE_ALERT_THRESHOLD")
	if parseThresholdEnv() != defaultPriceAlertThreshold {
		t.Errorf("unset env should use default")
	}
	t.Setenv("PRICE_ALERT_THRESHOLD", "0")
	if parseThresholdEnv() != defaultPriceAlertThreshold {
		t.Errorf("<=0 threshold should fall back to default")
	}
	t.Setenv("PRICE_ALERT_THRESHOLD", "7.5")
	if got := parseThresholdEnv(); got != 7.5 {
		t.Errorf("threshold parse = %v", got)
	}
}

func TestParseDealPrice(t *testing.T) {
	if parseDealPrice("9.99") != 9.99 {
		t.Error("valid price parse")
	}
	if parseDealPrice("nonsense") != -1 {
		t.Error("bad price should yield -1")
	}
}

func TestRecordAlert_Dedupes(t *testing.T) {
	db := newTestDB(t)
	d := &PriceAlertDaemon{db: db, threshold: 15}

	a := PriceAlert{AppID: 220, Title: "Half-Life 2", DealID: "abc123",
		SalePrice: "0.99", NormalPrice: "9.99", Savings: "90", Threshold: 15}
	d.recordAlert(a)
	d.recordAlert(a) // same deal_id inside 7 days — should be a no-op

	var count int
	db.QueryRow("SELECT COUNT(*) FROM price_alerts").Scan(&count)
	if count != 1 {
		t.Errorf("expected 1 row after dedupe, got %d", count)
	}

	// Different deal ID → new row.
	b := a
	b.DealID = "different-id"
	d.recordAlert(b)
	db.QueryRow("SELECT COUNT(*) FROM price_alerts").Scan(&count)
	if count != 2 {
		t.Errorf("expected 2 rows after new deal id, got %d", count)
	}
}

func TestRecentAlerts_ReturnsNewestFirst(t *testing.T) {
	db := newTestDB(t)
	d := &PriceAlertDaemon{db: db, threshold: 15}
	// Insert three, in the order they arrive.
	for i, id := range []string{"deal-1", "deal-2", "deal-3"} {
		d.recordAlert(PriceAlert{
			AppID: 100 + i, Title: "Game", DealID: id,
			SalePrice: "5.00", NormalPrice: "20.00", Savings: "75", Threshold: 15,
		})
	}

	got, err := RecentAlerts(db, 10)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 3 {
		t.Fatalf("expected 3, got %d", len(got))
	}
	// Newest first — deal-3 comes back before deal-1.
	if got[0].DealID != "deal-3" || got[2].DealID != "deal-1" {
		t.Errorf("order wrong: %v", []string{got[0].DealID, got[1].DealID, got[2].DealID})
	}
}

func TestRecentAlerts_LimitClamped(t *testing.T) {
	db := newTestDB(t)
	if _, err := RecentAlerts(db, -5); err != nil {
		t.Errorf("negative limit should be clamped and still succeed, got %v", err)
	}
	if _, err := RecentAlerts(db, 5000); err != nil {
		t.Errorf("huge limit should be clamped and still succeed, got %v", err)
	}
}

func TestPushWebhook_SendsJSON(t *testing.T) {
	var seenBody []byte
	var seenAuth, seenCT string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seenAuth = r.Header.Get("X-Swarm-Auth")
		seenCT = r.Header.Get("Content-Type")
		seenBody, _ = readAll(r.Body)
		w.WriteHeader(200)
	}))
	defer srv.Close()

	t.Setenv("PRICE_ALERT_WEBHOOK_URL", srv.URL)
	t.Setenv("SWARM_AUTH_TOKEN", "test-token")

	d := &PriceAlertDaemon{http: &http.Client{}}
	d.pushWebhook(PriceAlert{AppID: 220, Title: "HL2", DealID: "deal-x",
		SalePrice: "0.99", NormalPrice: "9.99", Savings: "90", Threshold: 15})

	if seenAuth != "test-token" {
		t.Errorf("auth header = %q", seenAuth)
	}
	if seenCT != "application/json" {
		t.Errorf("content-type = %q", seenCT)
	}
	var out map[string]any
	if err := json.Unmarshal(seenBody, &out); err != nil {
		t.Fatalf("body not JSON: %v (%s)", err, seenBody)
	}
	if out["app_id"] != float64(220) || out["deal_id"] != "deal-x" {
		t.Errorf("payload wrong: %v", out)
	}
}

func TestPushWebhook_NoURLIsSilent(t *testing.T) {
	os.Unsetenv("PRICE_ALERT_WEBHOOK_URL")
	d := &PriceAlertDaemon{http: &http.Client{}}
	// Must not panic or block.
	d.pushWebhook(PriceAlert{AppID: 1, Title: "x", DealID: "y"})
}

func TestStartStop_Idempotent(t *testing.T) {
	d := &PriceAlertDaemon{stop: make(chan struct{}), interval: defaultPriceAlertInterval}
	d.Start()
	d.Start() // second call is a no-op — must not panic on channel reuse
	d.Stop()
	d.Stop() // second stop must not panic
}

func TestParsePaceDelayEnv(t *testing.T) {
	os.Unsetenv("PRICE_ALERT_PACE_MS")
	if got := parsePaceDelayEnv(); got != 150*time.Millisecond {
		t.Errorf("default pace delay = %v, want 150ms", got)
	}

	t.Setenv("PRICE_ALERT_PACE_MS", "50")
	if got := parsePaceDelayEnv(); got != 50*time.Millisecond {
		t.Errorf("50ms pace delay = %v, want 50ms", got)
	}

	t.Setenv("PRICE_ALERT_PACE_MS", "invalid")
	if got := parsePaceDelayEnv(); got != 150*time.Millisecond {
		t.Errorf("invalid pace delay = %v, want 150ms", got)
	}
}

// tiny helper — avoids pulling in io just for one call.
func readAll(r interface{ Read(p []byte) (int, error) }) ([]byte, error) {
	buf := make([]byte, 4096)
	out := []byte{}
	for {
		n, err := r.Read(buf)
		if n > 0 {
			out = append(out, buf[:n]...)
		}
		if err != nil {
			if err.Error() == "EOF" {
				return out, nil
			}
			return out, err
		}
	}
}
