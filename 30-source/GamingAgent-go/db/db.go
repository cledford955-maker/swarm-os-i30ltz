package db

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"

	_ "modernc.org/sqlite"
)

func Open() (*sql.DB, error) {
	path := os.Getenv("GAMING_DB_PATH")
	if path == "" {
		path = "/etc/swarm_os/gaming.db"
	}

	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return nil, fmt.Errorf("db dir: %w", err)
	}

	db, err := sql.Open("sqlite", path+"?_journal=WAL&_timeout=5000")
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}

	if err := migrate(db); err != nil {
		return nil, fmt.Errorf("migrate: %w", err)
	}

	return db, nil
}

func migrate(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS favorites (
			app_id      INTEGER PRIMARY KEY,
			is_favorite INTEGER NOT NULL DEFAULT 0,
			is_pinned   INTEGER NOT NULL DEFAULT 0,
			updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
		);

		CREATE TABLE IF NOT EXISTS chat_history (
			id         INTEGER PRIMARY KEY AUTOINCREMENT,
			session_id TEXT    NOT NULL,
			role       TEXT    NOT NULL,
			content    TEXT    NOT NULL,
			created_at TEXT    NOT NULL DEFAULT (datetime('now'))
		);

		CREATE INDEX IF NOT EXISTS idx_chat_session ON chat_history(session_id, id);

		-- Price-alert log. Rows appended by PriceAlertDaemon (services/price_alert.go)
		-- when a game in the user's Steam library drops below its threshold.
		-- Reused by future dashboard "Price alerts" panel.
		CREATE TABLE IF NOT EXISTS price_alerts (
			id         INTEGER PRIMARY KEY AUTOINCREMENT,
			app_id     INTEGER NOT NULL,
			title      TEXT    NOT NULL,
			sale_price TEXT    NOT NULL,
			normal_price TEXT  NOT NULL,
			savings    TEXT    NOT NULL,
			deal_id    TEXT    NOT NULL,
			threshold  REAL    NOT NULL,
			created_at TEXT    NOT NULL DEFAULT (datetime('now'))
		);
		CREATE INDEX IF NOT EXISTS idx_price_alerts_appid  ON price_alerts(app_id, created_at);
		CREATE INDEX IF NOT EXISTS idx_price_alerts_recent ON price_alerts(created_at);
	`)
	return err
}
