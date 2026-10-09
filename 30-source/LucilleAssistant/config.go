package main

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
	"strings"
)

type MedDose struct {
	Name string `json:"name"`
	At   string `json:"at"` // "HH:MM" local time
}

type Config struct {
	Listen      string    `json:"listen"`
	DataDir     string    `json:"data_dir"`
	Repos       []string  `json:"repos"`
	Mounts      []string  `json:"mounts"`
	Projects    []string  `json:"projects"`
	Meds        []MedDose `json:"meds"`
	WaterGoalML int       `json:"water_goal_ml"`
	WakeAt      string    `json:"wake_at"`
	BedAt       string    `json:"bed_at"`
	MealGapHrs  float64   `json:"meal_gap_hours"`
	BreakAfter  int       `json:"break_after_minutes"`
	SleepGoal   float64   `json:"sleep_goal_hours"`
	MemoryDir   string    `json:"memory_dir"`
	GoogleURL   string    `json:"google_workspace_url"`
	GamingURL   string    `json:"gaming_agent_url"`
	NewsFeeds   []Feed    `json:"news_feeds"`
	NewsBlock   []string  `json:"news_blocklist"`

	Token         string `json:"-"`
	SteamKey      string `json:"-"`
	SteamID       string `json:"-"`
	NvidiaKey     string `json:"-"`
	OpenRouterKey string `json:"-"`
	ElevenKey     string `json:"-"`
	ElevenVoiceID string `json:"-"`
}

type Feed struct {
	Name string `json:"name"`
	URL  string `json:"url"`
	Tag  string `json:"tag"` // arch | linux | gaming | distro
}

func defaultConfig() Config {
	home, _ := os.UserHomeDir()
	return Config{
		Listen:  "127.0.0.1:8403;100.82.1.21:8403",
		DataDir: filepath.Join(home, ".local/share/lucille-assistant"),
		Repos:   []string{"/mnt/swarmbuild", "/mnt/Lucy"},
		Mounts:  []string{"/", "/home", "/mnt/swarmbuild", "/mnt/Lucy", "/mnt/brains", "/mnt/ventoy", "/mnt/recoverybuild", "/mnt/boltz"},
		Projects: []string{
			"SWARM OS ISO", "LucyServer-go", "Companion app", "Lucille Assistant", "Recovery OS",
		},
		Meds: []MedDose{
			{Name: "Morning meds", At: "09:00"},
			{Name: "Evening meds", At: "21:00"},
		},
		WaterGoalML: 2500,
		WakeAt:      "08:00",
		BedAt:       "00:30",
		MealGapHrs:  5,
		BreakAfter:  90,
		SleepGoal:   7.5,
		MemoryDir:   "/mnt/brains/swarm-memory",
		GoogleURL:   "http://127.0.0.1:8399",
		GamingURL:   "http://127.0.0.1:8401",
		NewsFeeds: []Feed{
			{Name: "Arch Linux", URL: "https://archlinux.org/feeds/news/", Tag: "arch"},
			{Name: "CachyOS", URL: "https://cachyos.org/rss.xml", Tag: "distro"},
			{Name: "GamingOnLinux", URL: "https://www.gamingonlinux.com/article_rss.php", Tag: "gaming"},
			{Name: "Phoronix", URL: "https://www.phoronix.com/rss.php", Tag: "linux"},
			{Name: "DistroWatch", URL: "https://distrowatch.com/news/dw.xml", Tag: "distro"},
			{Name: "Steam News", URL: "https://store.steampowered.com/feeds/news/", Tag: "gaming"},
		},
		// No real-world news or politics — anything matching these is dropped.
		NewsBlock: []string{
			"election", "president", "congress", "senate", "parliament", "politic", "trump", "biden",
			"democrat", "republican", "war ", "ukraine", "russia", "israel", "gaza", "tariff",
			"lawsuit", "government", "sanction", "military", "protest", "white house", "supreme court",
		},
	}
}

func loadEnvFiles() {
	paths := []string{
		"/mnt/swarmbuild/20-runtime/.env",
		"/mnt/Lucy/20-runtime/.env",
		"/etc/swarm_os.env",
	}
	for _, p := range paths {
		b, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(b), "\n") {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				k := strings.TrimSpace(parts[0])
				v := strings.TrimSpace(parts[1])
				v = strings.Trim(v, `"'`)
				if os.Getenv(k) == "" {
					_ = os.Setenv(k, v)
				}
			}
		}
	}
}

// loadConfig merges ~/.config/lucille-assistant/config.json over the defaults
// and writes the merged file back on first run so it is easy to edit.
func loadConfig() Config {
	loadEnvFiles()
	cfg := defaultConfig()
	home, _ := os.UserHomeDir()
	path := envOr("LUCILLE_ASSISTANT_CONFIG", filepath.Join(home, ".config/lucille-assistant/config.json"))
	if b, err := os.ReadFile(path); err == nil {
		if err := json.Unmarshal(b, &cfg); err != nil {
			log.Printf("config %s: %v (using defaults)", path, err)
		}
	} else if os.IsNotExist(err) {
		_ = os.MkdirAll(filepath.Dir(path), 0o755)
		if b, err := json.MarshalIndent(cfg, "", "  "); err == nil {
			_ = os.WriteFile(path, b, 0o644)
			log.Printf("wrote default config to %s — edit meds, repos and projects there", path)
		}
	}
	cfg.Listen = envOr("LUCILLE_ASSISTANT_LISTEN", cfg.Listen)
	cfg.DataDir = envOr("LUCILLE_ASSISTANT_DATA", cfg.DataDir)
	cfg.Token = os.Getenv("SWARM_AUTH_TOKEN")
	cfg.SteamKey = os.Getenv("STEAM_API_KEY")
	cfg.SteamID = envOr("STEAM_ID64", os.Getenv("STEAM_ID"))
	cfg.NvidiaKey = os.Getenv("NVIDIA_API_KEY")
	cfg.OpenRouterKey = os.Getenv("OPENROUTER_API_KEY")
	cfg.ElevenKey = os.Getenv("ELEVEN_API_KEY")
	cfg.ElevenVoiceID = envOr("ELEVEN_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")
	return cfg
}
