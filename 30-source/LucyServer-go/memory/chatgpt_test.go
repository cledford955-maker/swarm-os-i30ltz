package memory

import (
	"os"
	"path/filepath"
	"testing"
)

func TestChatGPTChangedSnapshotsAndMissingFiles(t *testing.T) {
	s, err := Open(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	source := `[{"id":"chat-123","title":"Project","current_node":"b","mapping":{"a":{"parent":null,"message":{"author":{"role":"user"},"content":{"parts":["Build app"]}}},"b":{"parent":"a","message":{"author":{"role":"assistant"},"content":{"parts":["Actual reply"]}}},"unused":{"parent":"a","message":{"author":{"role":"assistant"},"content":{"parts":["Abandoned branch"]}}}}}]`
	path := filepath.Join(dir, "conversations.json")
	os.WriteFile(path, []byte(source), 0600)
	os.WriteFile(filepath.Join(dir, "saved-memories.md"), []byte("I30LTZ is the repair companion."), 0600)
	if n, err := ImportChatGPT(s, "test", dir); err != nil || n != 2 {
		t.Fatalf("first import %d: %v", n, err)
	}
	if n, err := ImportChatGPT(s, "test", dir); err != nil || n != 0 {
		t.Fatalf("repeat %d: %v", n, err)
	}
	current, _ := s.Current("chatgpt_conversation")
	if len(current) != 1 || current[0].Meta["sync_mode"] != "export_snapshot" {
		t.Fatal(current)
	}
	os.Remove(path)
	if n, err := ImportChatGPT(s, "test", dir); err != nil || n != 0 {
		t.Fatalf("missing export %d: %v", n, err)
	}
	current, _ = s.Current("chatgpt_conversation")
	if len(current) != 1 {
		t.Fatal("Missing file erased conversation")
	}
	os.WriteFile(filepath.Join(dir, "saved-memories.md"), []byte("Updated preference"), 0600)
	if n, err := ImportChatGPT(s, "test", dir); err != nil || n != 1 {
		t.Fatalf("changed %d: %v", n, err)
	}
}

func TestChatGPTInvalidExportDoesNotPartiallyImport(t *testing.T) {
	s, _ := Open(t.TempDir())
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "conversations.json"), []byte(`[{"id":"broken","current_node":"x","mapping":{}}]`), 0600)
	if _, err := ImportChatGPT(s, "test", dir); err == nil {
		t.Fatal("Accepted broken mapping")
	}
	if s.Count() != 0 {
		t.Fatal("Partial import")
	}
}
