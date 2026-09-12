package db

import (
	"database/sql"

	"swarm-os/gaming-agent/models"
)

func InsertChatMessage(db *sql.DB, sessionId, role, content string) error {
	_, err := db.Exec(
		`INSERT INTO chat_history (session_id, role, content) VALUES (?, ?, ?)`,
		sessionId, role, content,
	)
	return err
}

func GetChatHistory(db *sql.DB, sessionId string, limit int) ([]models.ChatHistoryEntry, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := db.Query(`
		SELECT id, role, content, created_at
		FROM chat_history
		WHERE session_id = ?
		ORDER BY id DESC
		LIMIT ?
	`, sessionId, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []models.ChatHistoryEntry
	for rows.Next() {
		var e models.ChatHistoryEntry
		if err := rows.Scan(&e.Id, &e.Role, &e.Content, &e.CreatedAt); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	// Reverse to chronological order
	for i, j := 0, len(entries)-1; i < j; i, j = i+1, j-1 {
		entries[i], entries[j] = entries[j], entries[i]
	}
	return entries, rows.Err()
}
