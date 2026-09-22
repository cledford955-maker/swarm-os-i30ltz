package memory

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// DefaultChatGPTDir holds explicitly supplied exports, never browser credentials.
func DefaultChatGPTDir(s *Store) string {
	if dir := os.Getenv("SWARM_CHATGPT_IMPORT_DIR"); dir != "" {
		return dir
	}
	return filepath.Join(filepath.Dir(s.Dir()), "chatgpt-import")
}

type chatGPTConversation struct {
	ID             string `json:"id"`
	ConversationID string `json:"conversation_id"`
	Title          string `json:"title"`
	CurrentNode    string `json:"current_node"`
	Mapping        map[string]struct {
		Parent  string `json:"parent"`
		Message *struct {
			ID     string `json:"id"`
			Author struct {
				Role string `json:"role"`
			} `json:"author"`
			Content struct {
				Parts []json.RawMessage `json:"parts"`
			} `json:"content"`
		} `json:"message"`
	} `json:"mapping"`
}

// ImportChatGPT imports conversations*.json exports and saved-memories.md.
// Only changed source content appends a new entry. Missing files never erase
// memories: an absent/partial export is not evidence of a source deletion.
// It is an import of a dated snapshot, not a claim of continuous cloud access.
func ImportChatGPT(s *Store, device, dir string) (int, error) {
	current, err := s.Current("")
	if err != nil {
		return 0, err
	}
	latest := map[string]Entry{}
	for _, e := range current {
		latest[e.Kind+"/"+e.Key] = e
	}
	var batch []Entry
	add := func(kind, key, content, source string) error {
		if old, ok := latest[kind+"/"+key]; ok && old.Content == content {
			return nil
		}
		e := NewEntry(device, kind, key, content)
		e.Meta = map[string]string{"source": source, "sha256": hashOf(content), "sync_mode": "export_snapshot", "provider": "ChatGPT"}
		if info, err := os.Stat(source); err == nil {
			e.Meta["source_modified"] = info.ModTime().UTC().Format("2006-01-02T15:04:05Z")
		}
		if err := e.Validate(); err != nil {
			return err
		}
		batch = append(batch, e)
		latest[kind+"/"+key] = e
		return nil
	}
	files, err := filepath.Glob(filepath.Join(dir, "conversations*.json"))
	if err != nil {
		return 0, err
	}
	sort.Strings(files)
	for _, file := range files {
		info, err := os.Lstat(file)
		if err != nil {
			return 0, err
		}
		if !info.Mode().IsRegular() || info.Size() > 128<<20 {
			return 0, fmt.Errorf("invalid or oversized ChatGPT export: %s", file)
		}
		data, err := os.ReadFile(file)
		if err != nil {
			return 0, err
		}
		var chats []chatGPTConversation
		if err = json.Unmarshal(data, &chats); err != nil {
			return 0, fmt.Errorf("ChatGPT export %s: %w", file, err)
		}
		for _, chat := range chats {
			id := chat.ID
			if id == "" {
				id = chat.ConversationID
			}
			if id == "" || chat.CurrentNode == "" {
				return 0, fmt.Errorf("ChatGPT export is missing conversation identity/current_node")
			}
			var chain []string
			seen := map[string]bool{}
			for node := chat.CurrentNode; node != ""; {
				if seen[node] {
					return 0, fmt.Errorf("cycle in ChatGPT conversation %s", id)
				}
				seen[node] = true
				item, ok := chat.Mapping[node]
				if !ok {
					return 0, fmt.Errorf("missing node in ChatGPT conversation %s", id)
				}
				chain = append(chain, node)
				node = item.Parent
			}
			var content strings.Builder
			fmt.Fprintf(&content, "# %s\n\nChatGPT conversation %s. Export snapshot; attachments/non-text parts are not imported.\n", chat.Title, id)
			for i := len(chain) - 1; i >= 0; i-- {
				message := chat.Mapping[chain[i]].Message
				if message == nil {
					continue
				}
				if message.Author.Role != "user" && message.Author.Role != "assistant" {
					continue
				}
				fmt.Fprintf(&content, "\n## %s\n", message.Author.Role)
				for _, part := range message.Content.Parts {
					var text string
					if json.Unmarshal(part, &text) == nil {
						content.WriteString(text)
						content.WriteByte('\n')
					} else {
						content.WriteString("[Non-text attachment omitted]\n")
					}
				}
			}
			if err := add("chatgpt_conversation", id, content.String(), file); err != nil {
				return 0, err
			}
		}
	}
	saved := filepath.Join(dir, "saved-memories.md")
	if info, err := os.Lstat(saved); err == nil {
		if !info.Mode().IsRegular() || info.Size() > MaxContentBytes {
			return 0, fmt.Errorf("invalid or oversized saved-memories.md")
		}
		data, err := os.ReadFile(saved)
		if err != nil {
			return 0, err
		}
		if strings.TrimSpace(string(data)) == "" {
			return 0, fmt.Errorf("saved-memories.md is empty; not importing an empty snapshot")
		}
		if err := add("chatgpt_memory", "saved-memories", string(data), saved); err != nil {
			return 0, err
		}
	} else if !os.IsNotExist(err) {
		return 0, err
	}
	if len(batch) == 0 {
		return 0, nil
	}
	return len(batch), s.Append(batch...)
}
