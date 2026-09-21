package main

import (
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/rs/cors"

	"swarm-os/gaming-agent/db"
	"swarm-os/gaming-agent/handlers"
	"swarm-os/gaming-agent/services"
)

func main() {
	database, err := db.Open()
	if err != nil {
		fmt.Fprintf(os.Stderr, "db open: %v\n", err)
		os.Exit(1)
	}

	// Services
	gfnSvc := services.NewGfnService()
	steamSvc := services.NewSteamService()
	gamesSvc := services.NewGamesService(gfnSvc, steamSvc, database)
	lucilleSvc := services.NewLucilleService(gfnSvc, steamSvc, database)
	mediaSvc := services.NewMediaService()

	// Warm GFN catalog in background
	go gfnSvc.WarmCache()

	// Handlers
	gfnH := handlers.NewGfnHandler(gfnSvc, gamesSvc)
	steamH := handlers.NewSteamHandler(steamSvc)
	gamesH := handlers.NewGamesHandler(gamesSvc)
	favH := handlers.NewFavoritesHandler(database)
	lucilleH := handlers.NewLucilleHandler(lucilleSvc, database)
	mediaH := handlers.NewMediaHandler(mediaSvc)

	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(securityHeaders)
	// Catalog routes below are deliberately readable from any origin, so CORS
	// stays permissive here. The protected group guards itself with originGate
	// (see swarmAuthMiddleware), which is the check that actually matters —
	// CORS governs whether a page may read a response, not whether this server
	// executes the request.
	r.Use(cors.New(cors.Options{
		AllowedOrigins: []string{"*"},
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Content-Type", "X-Swarm-Auth", "Authorization"},
	}).Handler)

	r.Get("/health", handlers.Health)

	r.Route("/api", func(r chi.Router) {
		// Read-only game-catalog data — no API-key cost beyond the shared 12h
		// cache, nothing destructive. Left open, matching the original design
		// ("CORS open for dashboard") so the dashboard artifact keeps working
		// unmodified regardless of what origin it's loaded from.
		r.Get("/gfn/catalog", gfnH.Catalog)
		r.Get("/steam/library", steamH.Library)
		r.Get("/games/intersection", gamesH.Intersection)
		r.Get("/games/genres", gfnH.Genres)
		r.Get("/games/prices/{appId}", gamesH.Prices)
		// Now-playing is read-only status, same trust level as the catalog
		// routes above; play/pause/skip/volume are mutating and sit in the
		// protected group below next to /games/favorite.
		r.Get("/media/status", mediaH.Status)

		// Everything below either mutates persistent state, spends the
		// owner's chat-API quota per call (see lucille_service.go's
		// chatAPIKeyEnv for which key — this has changed providers more than
		// once), or returns past chat content — same swarmAuthMiddleware
		// pattern LucyServer-go already uses (loopback bypass, or
		// X-Swarm-Auth/Authorization token match). Previously this whole
		// service had zero auth: any device on the trusted tailnet
		// (nftables.conf accepts all tailscale0 traffic) could flip favorites
		// or burn that quota with no credential at all. Found while wiring
		// Task #3 (harden baseline).
		r.Group(func(r chi.Router) {
			r.Use(originGate)
			r.Use(swarmAuthMiddleware)
			r.Post("/games/favorite", favH.Upsert)
			r.Post("/media/control", mediaH.Control)
			r.Post("/media/volume", mediaH.Volume)
			// Chat-model calls: eval is expensive (full analysis), chat is per-turn.
			// 5/min on eval prevents runaway quota burn; 20/min on chat covers
			// fast interactive use. stream shares the chat limit.
			r.With(rateLimiter(5, time.Minute)).Get("/lucille/eval", lucilleH.Eval)
			r.With(rateLimiter(20, time.Minute)).Post("/lucille/chat", lucilleH.Chat)
			r.With(rateLimiter(20, time.Minute)).Post("/lucille/chat/stream", lucilleH.ChatStream)
			r.Get("/lucille/history", lucilleH.History)
		})
	})

	addr := os.Getenv("ASPNETCORE_URLS")
	if addr == "" {
		addr = "http://0.0.0.0:8401"
	}
	// Strip http:// prefix for net/http
	listenAddr := addr
	if len(listenAddr) > 7 && listenAddr[:7] == "http://" {
		listenAddr = listenAddr[7:]
	}

	fmt.Printf("[GamingAgent] listening on %s\n", addr)
	if err := http.ListenAndServe(listenAddr, r); err != nil {
		fmt.Fprintf(os.Stderr, "server: %v\n", err)
		os.Exit(1)
	}
}

// defaultAllowedOrigins are the browser origins allowed to reach the protected
// routes. claude.ai is included because the gaming dashboard is published as an
// artifact there and calls these routes from the user's browser.
//
// Override with SWARM_ALLOWED_ORIGINS (comma-separated) if the dashboard is
// served from somewhere else. If the dashboard's Lucille panels stop working
// after this change, the browser console will show the blocked origin — add it
// here rather than restoring a wildcard.
var defaultAllowedOrigins = []string{
	"https://claude.ai",
	"http://localhost:8401",
	"http://127.0.0.1:8401",
}

func allowedOrigins() []string {
	if env := strings.TrimSpace(os.Getenv("SWARM_ALLOWED_ORIGINS")); env != "" {
		var out []string
		for _, o := range strings.Split(env, ",") {
			if o = strings.TrimSpace(o); o != "" {
				out = append(out, o)
			}
		}
		if len(out) > 0 {
			return out
		}
	}
	return defaultAllowedOrigins
}

// originGate rejects requests carrying an untrusted browser Origin before
// swarmAuthMiddleware can admit them via its loopback bypass.
//
// A browser request to 127.0.0.1 is a loopback connection from this server's
// point of view, so the bypass alone would let any web page the user is
// visiting spend the owner's chat-API quota through /lucille/eval, read past
// conversations through /lucille/history, and write favorites. CORS does not
// prevent that — it only decides whether the attacking page may read the
// reply, and the quota is spent either way.
//
// Native clients (the Android companion via OkHttp, curl) send no Origin and
// pass through untouched. This gate is applied only to the protected group;
// the read-only catalog routes stay open to any origin by design.
func originGate(next http.Handler) http.Handler {
	allowed := allowedOrigins()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && !slices.Contains(allowed, origin) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusForbidden)
			json.NewEncoder(w).Encode(map[string]string{
				"error":  "Origin not permitted for this route.",
				"origin": origin,
			})
			return
		}
		next.ServeHTTP(w, r)
	})
}

// swarmAuthMiddleware mirrors LucyServer-go's middleware of the same name
// (main.go) exactly, including its "swarm-token-2026" fallback: the Android
// companion app and the old .NET LucyServer both hardcode that literal
// string as their pre-shared X-Swarm-Auth value, so changing the fallback
// here would silently break every existing client with no way for them to
// discover the new value. Loopback traffic (the dashboard artifact opened in
// a browser on this same box) bypasses the check entirely, same as today.
func swarmAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("X-Swarm-Auth")
		bearerHeader := r.Header.Get("Authorization")
		expectedToken := os.Getenv("SWARM_AUTH_TOKEN")
		if expectedToken == "" {
			expectedToken = "swarm-token-2026"
		}

		if !isLoopback(r) && authHeader != expectedToken && !strings.Contains(bearerHeader, expectedToken) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusUnauthorized)
			json.NewEncoder(w).Encode(map[string]string{
				"error": "Unauthorized SWARM access. Missing or invalid X-Swarm-Auth header.",
			})
			return
		}
		next.ServeHTTP(w, r)
	})
}

func isLoopback(r *http.Request) bool {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

// securityHeaders adds defensive HTTP response headers to every response.
func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}

// ipBucket is a fixed-window counter per remote IP.
type ipBucket struct {
	mu          sync.Mutex
	count       int
	windowStart time.Time
}

// rateLimiter returns a middleware that limits each remote IP to max requests
// per window. Buckets are never evicted — this server restarts frequently
// enough that memory growth from unique IPs is not a concern here.
func rateLimiter(max int, window time.Duration) func(http.Handler) http.Handler {
	var buckets sync.Map
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			host, _, err := net.SplitHostPort(r.RemoteAddr)
			if err != nil {
				host = r.RemoteAddr
			}
			now := time.Now()
			val, _ := buckets.LoadOrStore(host, &ipBucket{windowStart: now})
			b := val.(*ipBucket)
			b.mu.Lock()
			if now.Sub(b.windowStart) >= window {
				b.count = 0
				b.windowStart = now
			}
			b.count++
			over := b.count > max
			b.mu.Unlock()
			if over {
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Retry-After", fmt.Sprintf("%.0f", window.Seconds()))
				w.WriteHeader(http.StatusTooManyRequests)
				json.NewEncoder(w).Encode(map[string]string{"error": "rate limit exceeded"})
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
