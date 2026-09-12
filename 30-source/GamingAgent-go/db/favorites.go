package db

import (
	"database/sql"

	"swarm-os/gaming-agent/models"
)

func UpsertFavorite(db *sql.DB, e models.FavoriteEntry) error {
	_, err := db.Exec(`
		INSERT INTO favorites (app_id, is_favorite, is_pinned, updated_at)
		VALUES (?, ?, ?, datetime('now'))
		ON CONFLICT(app_id) DO UPDATE SET
			is_favorite = excluded.is_favorite,
			is_pinned   = excluded.is_pinned,
			updated_at  = excluded.updated_at
	`, e.AppId, boolToInt(e.IsFavorite), boolToInt(e.IsPinned))
	return err
}

func GetFavorites(db *sql.DB) (map[int]models.FavoriteEntry, error) {
	rows, err := db.Query(`SELECT app_id, is_favorite, is_pinned FROM favorites`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	m := make(map[int]models.FavoriteEntry)
	for rows.Next() {
		var appId, fav, pin int
		if err := rows.Scan(&appId, &fav, &pin); err != nil {
			return nil, err
		}
		m[appId] = models.FavoriteEntry{
			AppId:      appId,
			IsFavorite: fav == 1,
			IsPinned:   pin == 1,
		}
	}
	return m, rows.Err()
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
