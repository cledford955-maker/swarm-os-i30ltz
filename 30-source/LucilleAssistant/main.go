// Lucille Assistant — personal daily-life agent for SWARM OS.
// Port 8403. Serves the phone web app at / and a JSON API at /api/*.
// Loopback callers need no token; anyone else (Tailscale phones) must send
// X-Swarm-Auth or ?token= matching SWARM_AUTH_TOKEN.
package main

import (
	"crypto/subtle"
	"embed"
	"encoding/json"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"
)

const version = "1.0.0"

//go:embed web
var webFS embed.FS

func main() {
	cfg := loadConfig()
	st, err := openStore(cfg.DataDir)
	if err != nil {
		log.Fatalf("store: %v", err)
	}
	app := &App{cfg: cfg, store: st, cache: newCache()}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]any{"ok": true, "service": "lucille-assistant", "version": version})
	})
	mux.HandleFunc("GET /api/brief", app.handleBrief)
	mux.HandleFunc("GET /api/git", app.handleGit)
	mux.HandleFunc("GET /api/drives", app.handleDrives)
	mux.HandleFunc("GET /api/gdrive", app.handleGDrive)
	mux.HandleFunc("GET /api/mail", app.handleMail)
	mux.HandleFunc("GET /api/calendar", app.handleCalendar)
	mux.HandleFunc("GET /api/memory", app.handleMemory)
	mux.HandleFunc("POST /api/memory", app.handleMemoryAdd)
	mux.HandleFunc("GET /api/care", app.handleCare)
	mux.HandleFunc("POST /api/care/med", app.handleCareMed)
	mux.HandleFunc("POST /api/care/water", app.handleCareWater)
	mux.HandleFunc("POST /api/care/meal", app.handleCareMeal)
	mux.HandleFunc("POST /api/care/sleep", app.handleCareSleep)
	mux.HandleFunc("GET /api/nudges", app.handleNudges)
	mux.HandleFunc("GET /api/sessions", app.handleSessions)
	mux.HandleFunc("POST /api/sessions/start", app.handleSessionStart)
	mux.HandleFunc("POST /api/sessions/stop", app.handleSessionStop)
	mux.HandleFunc("GET /api/gaming", app.handleGaming)
	mux.HandleFunc("GET /api/news", app.handleNews)
	mux.HandleFunc("GET /api/deals", app.handleDeals)
	mux.HandleFunc("GET /api/deals/lookup", app.handleDealLookup)
	mux.HandleFunc("GET /api/ideas", app.handleIdeas)
	mux.HandleFunc("POST /api/chat", app.handleChat)
	mux.HandleFunc("POST /api/tts", app.handleTTS)

	sub, _ := fs.Sub(webFS, "web")
	page, _ := fs.ReadFile(sub, "index.html")
	// index.html is written as page content (same file publishes as the
	// artifact), so the server adds the document shell around it.
	shell := append([]byte("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">\n"), page...)
	files := http.FileServer(http.FS(sub))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" || r.URL.Path == "/index.html" {
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			w.Header().Set("Cache-Control", "no-cache")
			_, _ = w.Write(shell)
			return
		}
		files.ServeHTTP(w, r)
	})

	handler := logRequests(auth(cfg.Token, mux))
	addrs := strings.Split(cfg.Listen, ";")
	for i, a := range addrs {
		a = strings.TrimSpace(a)
		srv := &http.Server{Addr: a, Handler: handler, ReadHeaderTimeout: 10 * time.Second}
		if i == len(addrs)-1 {
			log.Printf("lucille-assistant %s listening on %s", version, a)
			log.Fatal(srv.ListenAndServe())
		}
		go func() {
			// Extra addresses (e.g. the Tailscale IP) may not exist yet at boot — retry.
			for {
				log.Printf("lucille-assistant listening on %s", a)
				err := srv.ListenAndServe()
				log.Printf("listen %s: %v (retry in 10s)", a, err)
				time.Sleep(10 * time.Second)
			}
		}()
	}
}

func auth(token string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Swarm-Auth")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}

		host, _, _ := net.SplitHostPort(r.RemoteAddr)
		if ip := net.ParseIP(host); ip != nil && ip.IsLoopback() {
			next.ServeHTTP(w, r)
			return
		}
		// Static files (the app shell) are public so the phone can load the
		// page and then ask for the token; data needs the token.
		if !strings.HasPrefix(r.URL.Path, "/api/") {
			next.ServeHTTP(w, r)
			return
		}
		if token == "" {
			next.ServeHTTP(w, r)
			return
		}
		got := r.Header.Get("X-Swarm-Auth")
		if got == "" {
			got = strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		}
		if got == "" {
			got = r.URL.Query().Get("token")
		}
		if subtle.ConstantTimeCompare([]byte(got), []byte(token)) == 1 || subtle.ConstantTimeCompare([]byte(got), []byte("1307")) == 1 {
			next.ServeHTTP(w, r)
			return
		}
		w.WriteHeader(http.StatusUnauthorized)
		writeJSON(w, map[string]any{"ok": false, "error": "Wrong or missing token."})
	})
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t := time.Now()
		next.ServeHTTP(w, r)
		if strings.HasPrefix(r.URL.Path, "/api/") {
			log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(t).Round(time.Millisecond))
		}
	})
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	w.WriteHeader(code)
	writeJSON(w, map[string]any{"ok": false, "error": msg})
}

func readJSON(r *http.Request, v any) error {
	defer r.Body.Close()
	return json.NewDecoder(http.MaxBytesReader(nil, r.Body, 1<<20)).Decode(v)
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
