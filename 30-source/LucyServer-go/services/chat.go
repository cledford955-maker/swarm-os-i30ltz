package services

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"

	"swarm-os/lucy-server/models"
)

// lucyStateDir is overridable via LUCY_STATE_DIR env var.
// Deviation from .NET original: .NET hardcodes /mnt/i30ltz-brains/AI/memory.json
// (a mount that does not exist on this system — chat history has silently failed
// on every real boot). Go port uses /etc/swarm_os/lucy/ instead, consistent with
// GamingAgent-go's /etc/swarm_os/gaming.db convention.
func lucyStateDir() string {
	if d := os.Getenv("LUCY_STATE_DIR"); d != "" {
		return d
	}
	return "/etc/swarm_os/lucy"
}

func memoryFilePath(username string) string {
	dir := lucyStateDir()
	if username != "" {
		return filepath.Join(dir, fmt.Sprintf("memory_%s.json", username))
	}
	return filepath.Join(dir, "memory.json")
}

var chatMu sync.Mutex

func defaultChatData() *models.ChatData {
	return &models.ChatData{
		ActiveChatId: "default",
		Chats: map[string]*models.ChatInfo{
			"default": {
				Title:   "Main Chat",
				History: []models.ChatMessage{},
				Pinned:  false,
				Privacy: "shared",
			},
		},
	}
}

func LoadAllChats(username string) (*models.ChatData, error) {
	path := memoryFilePath(username)

	chatMu.Lock()
	defer chatMu.Unlock()

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return defaultChatData(), nil
		}
		return defaultChatData(), nil
	}

	var cd models.ChatData
	if err := json.Unmarshal(data, &cd); err != nil {
		return defaultChatData(), nil
	}
	if cd.Chats == nil {
		return defaultChatData(), nil
	}

	// Normalize: ensure every chat has a non-nil History and a Privacy value.
	for _, info := range cd.Chats {
		if info.History == nil {
			info.History = []models.ChatMessage{}
		}
		if info.Privacy == "" {
			info.Privacy = "shared"
		}
	}

	return &cd, nil
}

func SaveAllChats(cd *models.ChatData, username string) error {
	path := memoryFilePath(username)

	chatMu.Lock()
	defer chatMu.Unlock()

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(cd, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, b, 0o644)
}
