package services

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"swarm-os/lucy-server/models"
)

var codeExtensions = map[string]bool{
	".cs": true, ".js": true, ".ts": true, ".html": true, ".css": true,
	".py": true, ".json": true, ".md": true, ".sh": true,
	// extras useful for this project
	".go": true, ".dart": true, ".rs": true, ".toml": true, ".yaml": true, ".yml": true,
}

func ListDirectory(path string) ([]models.FileItemInfo, error) {
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil, fmt.Errorf("directory not found: %s", path)
	}

	var items []models.FileItemInfo
	for _, e := range entries {
		info, err := e.Info()
		if err != nil {
			continue
		}
		size := int64(0)
		if !e.IsDir() {
			size = info.Size()
		}
		items = append(items, models.FileItemInfo{
			Name:        e.Name(),
			Path:        filepath.Join(path, e.Name()),
			IsDirectory: e.IsDir(),
			Size:        size,
		})
	}

	// Directories first, then files; each group sorted by name — mirrors .NET original.
	sort.Slice(items, func(i, j int) bool {
		if items[i].IsDirectory != items[j].IsDirectory {
			return items[i].IsDirectory
		}
		return items[i].Name < items[j].Name
	})

	return items, nil
}

func AnalyzeDirectory(path string) (map[string]string, error) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil, fmt.Errorf("directory not found: %s", path)
	}
	result := RunCommand(fmt.Sprintf("du -sh %q", path), "")
	return map[string]string{"sizeInfo": strings.TrimSpace(result.StandardOutput)}, nil
}

func ListCodeFiles(path string) ([]string, error) {
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil, fmt.Errorf("directory not found: %s", path)
	}

	var files []string
	err := filepath.WalkDir(path, func(p string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		if codeExtensions[strings.ToLower(filepath.Ext(p))] {
			files = append(files, p)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return files, nil
}

func ReadFile(filename string) (string, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return "", fmt.Errorf("file not found: %s", filename)
	}
	return string(data), nil
}

func SaveFile(filename, content string) (bool, error) {
	dir := filepath.Dir(filename)
	if dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return false, err
		}
	}
	if err := os.WriteFile(filename, []byte(content), 0o644); err != nil {
		return false, err
	}
	return true, nil
}

func ApplyUpgrade(filename, content string) (bool, error) {
	// Same as SaveFile for now — add patch/diff support if needed later.
	return SaveFile(filename, content)
}

func MountRecovery() (bool, error) {
	const hostMount = "/tmp/host_system"
	if err := os.MkdirAll(hostMount, 0o755); err != nil {
		return false, err
	}
	return true, nil
}
