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

	"swarm-os/lucy-server/handlers"
)

func main() {
	r := chi.NewRouter()
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(securityHeaders)
	r.Use(cors.New(cors.Options{
		// Explicit allowlist, never "*". With "*" any web page could preflight
		// successfully against this server; see originGate below for why the
		// CORS config alone is not the security boundary.
		AllowedOrigins: allowedOrigins(),
		AllowedMethods: []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders: []string{"Content-Type", "X-Swarm-Auth", "Authorization"},
	}).Handler)
	r.Use(originGate)
	r.Use(swarmAuthMiddleware)

	r.Get("/health", func(w http.ResponseWriter, req *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	// ── WebAuthn (task #20) — NOT under /api/, exempt from swarmAuthMiddleware
	// by design, same as the .NET original. ──────────────────────────────────
	r.Get("/webauthn/register/options", handlers.WARegisterOptions)
	r.Post("/webauthn/register/verify", handlers.WARegisterVerify)
	r.Get("/webauthn/login/options", handlers.WALoginOptions)
	r.Post("/webauthn/login/verify", handlers.WALoginVerify)
	r.Get("/webauthn/list", handlers.WAListCredentials)
	r.Post("/webauthn/clear", handlers.WAClearCredentials)

	// ── Lucy orchestrator (task #18) — NOT under /api/ either. ────────────────
	// Rate-limited: LLM calls consume provider quota; 15 requests per IP per
	// minute is generous for interactive use but hard to hit accidentally.
	r.With(rateLimiter(15, time.Minute)).Post("/lucy", handlers.LucyHandler)
	// Unfiltered vault mode — requires /mnt/slick to be mounted (returns 503 otherwise).
	// Slick context only; brains/safety prompt is intentionally excluded.
	r.With(rateLimiter(15, time.Minute)).Post("/lucy/unfiltered", handlers.UnfilteredLucyHandler)
	// Dr. Boltz — eval, systems optimization, recovery AI.
	// Available from both SWARM OS and the Endeavor recovery drive (both mount /mnt/boltz).
	r.With(rateLimiter(15, time.Minute)).Post("/boltz", handlers.BoltzHandler)

	sysH := handlers.NewSystemHandler()
	fsH := handlers.NewFilesystemHandler()
	chatH := handlers.NewChatHandler()
	installH := handlers.NewInstallHandler()

	memAPI := openMemory()

	r.Route("/api", func(api chi.Router) {
		// Shared memory (2026-09-16) — log at /mnt/brains/swarm-memory, synced
		// across the OSes, the companion phones and Claude's memory files.
		api.Route("/memory", memoryRoutes(memAPI))

		// TTS (task #19) — the ONE /api/ prefix exempted from the auth
		// middleware in the .NET original (see swarmAuthMiddleware below).
		// Rate-limited: ElevenLabs charges per character; 10 calls/min prevents
		// runaway cost even if a client is misbehaving.
		api.With(rateLimiter(10, time.Minute)).Post("/tts/generate", handlers.TTSGenerate)

		// System integration (task #16) — DONE
		// run_command executes arbitrary shell. 30/min is fast enough for IDE
		// use; a tight loop hitting this endpoint is almost certainly abuse.
		api.With(rateLimiter(30, time.Minute)).Post("/run_command", sysH.RunCommand)
		api.Post("/clipboard/set", sysH.SetClipboard)
		// /api/terminal/run maps to the SAME RunCommand as /api/run_command in
		// the .NET original (both just call RunCommandAsync) — not a typo.
		api.Post("/terminal/run", sysH.RunCommand)
		api.Get("/terminal/ws", sysH.TerminalWebSocket)

		// Graphical installer — the Flutter "Install SWARM OS" flow. Disk
		// listing is a plain GET; the actual install runs over a WebSocket so
		// the UI gets live output the same way the terminal does.
		api.Get("/install/disks", installH.Disks)
		api.Get("/install/ws", installH.WebSocket)
		api.Get("/system/processes", sysH.Processes)
		api.Post("/system/process/kill", sysH.KillProcess)
		api.Get("/system/stats", sysH.Stats)
		api.Get("/packages/list", sysH.ListPackages)
		api.Post("/packages/uninstall", sysH.UninstallPackage)

		// Filesystem & code (task #17) — DONE
		api.Get("/fs", fsH.ListDirectory)
		api.Post("/fs/analyze", fsH.AnalyzeDirectory)
		api.Get("/code/files", fsH.ListCodeFiles)
		api.Post("/code/read", fsH.ReadFile)
		api.Post("/code/save", fsH.SaveFile)
		api.Post("/code/apply_upgrade", fsH.ApplyUpgrade)
		api.Post("/recovery/mount", fsH.MountRecovery)

		// Chat history & session management (task #18) — DONE
		api.Get("/chats", chatH.ListChats)
		api.Post("/chats/new", chatH.NewChat)
		api.Post("/chats/delete", chatH.DeleteChat)
		api.Post("/chats/rename", chatH.RenameChat)
		api.Post("/chats/select", chatH.SelectChat)
		api.Post("/chats/toggle_pin", chatH.TogglePin)
		api.Post("/chats/toggle_privacy", chatH.TogglePrivacy)

		// Ollama local model management (task #19) — DONE
		api.Get("/local_models", handlers.OllamaListModels)
		api.Post("/pull_model", handlers.OllamaPullModel)
		api.Get("/pull_status", handlers.OllamaGetPullStatus)

		// News, deals, and games (task #19) — DONE
		api.Get("/news", handlers.GetNews)
		api.Get("/deals", handlers.GetDeals)
		api.Get("/news-feed", handlers.GetNewsFeed)
		api.Get("/dev-news", handlers.GetDevNews)
		api.Get("/steam-library", handlers.GetSteamLibrary)
		api.Get("/game-prices", handlers.GetGamePrices)
		api.Get("/game-info", handlers.GetGameInfo)
		api.Get("/gfn/games", handlers.GetGfnGames)
		api.Post("/gfn/optimize", handlers.OptimizeGfn)

		// Settings & admin (task #20)
		api.Get("/settings/voice/get", handlers.GetVoice)
		api.Post("/settings/voice", handlers.SetVoice)
		api.Post("/settings/login_password", handlers.SetLoginPassword)
		api.Post("/settings/verify_login_password", handlers.VerifyLoginPassword)
		api.Post("/settings/sudo_password", handlers.SetSudoPassword)
		api.Post("/admin/save-keys", handlers.SaveApiKeys)

		// TOTP 2FA (phones as authenticators — scan same QR on all 3 phones)
		api.Get("/settings/totp/status", handlers.TOTPStatus)
		api.Post("/settings/totp/setup", handlers.TOTPSetup)
		api.Post("/settings/totp/confirm", handlers.TOTPConfirm)
		api.Post("/settings/totp/check", handlers.TOTPCheck)
		api.Delete("/settings/totp", handlers.TOTPDisable)

		// Search & daily brief (task #20)
		api.Get("/google/brief", handlers.GoogleBrief)
		api.Get("/search", handlers.WebSearch)

		// RAG ingestion (task #19) — DONE
		api.Post("/rag/ingest", handlers.RAGIngest)
		api.Post("/rag/ingest/file", handlers.RAGIngestFile)
		api.Get("/rag/documents", handlers.RAGListDocuments)
		api.Delete("/rag/document", handlers.RAGDeleteDocument)
		api.Delete("/rag/clear", handlers.RAGClearStore)

		// Developer platform (task #21) — DONE
		api.Route("/extensions", func(ext chi.Router) {
			ext.Post("/local/link", handlers.ExtLinkLocal)
			ext.Get("/local/list", handlers.ExtListLocal)
			ext.Delete("/local/{extensionId}", handlers.ExtUnlink)
			ext.Post("/dependencies/resolve", handlers.ExtResolveDeps)
			ext.Get("/updates/check", handlers.ExtCheckUpdates)
		})
		api.Route("/releases", func(rel chi.Router) {
			rel.Post("/publish", handlers.ReleasePublish)
			rel.Get("/{appId}", handlers.ReleaseGet)
			rel.Post("/{id}/promote", handlers.ReleasePromote)
		})
		api.Route("/git", func(git chi.Router) {
			git.Get("/repos", handlers.GitListRepos)
			git.Post("/repos/create", handlers.GitCreateRepo)
		})
		api.Route("/ci", func(ci chi.Router) {
			ci.Post("/pipelines/trigger", handlers.CiTriggerPipeline)
			ci.Get("/pipelines/{id}", handlers.CiGetPipeline)
		})
		api.Route("/artifacts", func(art chi.Router) {
			art.Get("/", handlers.ArtifactList)
			art.Get("/{id}/download", handlers.ArtifactDownload)
		})
		api.Route("/oauth", func(oauth chi.Router) {
			oauth.Get("/{provider}/login", handlers.OAuthLogin)
			oauth.Get("/{provider}/callback", handlers.OAuthCallback)
		})
		api.Get("/analytics/dashboard", handlers.AnalyticsDashboard)

		// AI coder, cloud workspaces, marketplace (task #21 — AdvancedEcosystemEndpoints.cs)
		api.Post("/ai-coder/task", handlers.AiCoderTask)
		api.Post("/ai-coder/suggest-fixes", handlers.AiCoderSuggestFixes)
		api.Get("/ai-coder/history", handlers.AiCoderHistory)
		api.Get("/workspaces/cloud", handlers.WorkspaceList)
		api.Post("/workspaces/cloud/create", handlers.WorkspaceCreate)
		api.Post("/workspaces/cloud/{id}/sync", handlers.WorkspaceSync)
		api.Get("/templates/community", handlers.MarketplaceTemplates)
		api.Post("/templates/community/submit", handlers.MarketplaceSubmitTemplate)
		api.Get("/marketplace/reviews/{extensionId}", handlers.MarketplaceGetReviews)
		api.Post("/marketplace/reviews/post", handlers.MarketplacePostReview)
		api.Post("/marketplace/purchase", handlers.MarketplacePurchase)
		api.Get("/marketplace/analytics", handlers.MarketplaceAnalytics)
		// Device mirror, telemetry, security (task #22 — AdvancedEcosystemEndpoints.cs)
		api.Post("/device/mirror/start", handlers.MirrorStart)
		api.Post("/device/mirror/{sessionId}/stop", handlers.MirrorStop)
		api.Get("/device/mirror/sessions", handlers.MirrorListActive)
		api.Get("/device/stats", handlers.DeviceStats)
		api.Get("/telemetry/crash-reports", handlers.CrashReportList)
		api.Post("/telemetry/crash-reports/submit", handlers.CrashReportSubmit)
		api.Get("/telemetry/app-analytics", handlers.AppAnalytics)
		api.Get("/security/audit-logs", handlers.SecurityAuditLogs)
		api.Post("/security/scan-package", handlers.SecurityScanPackage)
		api.Get("/security/verified-developers", handlers.SecurityVerifiedDevelopers)

		// Virtualization, environment templates, sandbox (task #22 — VirtualizationEndpoints.cs)
		api.Route("/vms", func(vm chi.Router) {
			vm.Get("/", handlers.VmList)
			vm.Get("/{id}", handlers.VmGet)
			vm.Post("/create", handlers.VmCreate)
			vm.Post("/{id}/start", handlers.VmStart)
			vm.Post("/{id}/stop", handlers.VmStop)
			vm.Post("/{id}/pause", handlers.VmPause)
			vm.Post("/{id}/resume", handlers.VmResume)
			vm.Delete("/{id}", handlers.VmDelete)
			vm.Get("/{id}/telemetry", handlers.VmGetTelemetry)
			vm.Get("/{id}/telemetry/history", handlers.VmGetTelemetryHistory)
			vm.Get("/{id}/snapshots", handlers.VmListSnapshots)
			vm.Post("/{id}/snapshots", handlers.VmCreateSnapshot)
			vm.Post("/{id}/snapshots/{name}/restore", handlers.VmRestoreSnapshot)
			vm.Delete("/{id}/snapshots/{name}", handlers.VmDeleteSnapshot)
		})
		api.Route("/templates/environments", func(tmpl chi.Router) {
			tmpl.Get("/", handlers.EnvTemplateList)
			tmpl.Get("/{id}", handlers.EnvTemplateGet)
			tmpl.Post("/{id}/instantiate", handlers.EnvTemplateInstantiate)
		})
		api.Post("/sandbox/execute", handlers.SandboxExecute)
	})

	addr := os.Getenv("ASPNETCORE_URLS")
	if addr == "" {
		addr = "http://0.0.0.0:5000"
	}
	// Like ASP.NET Core, several URLs may be given, separated by ';'. The first
	// is required; later ones (e.g. a Tailscale IP that comes up after boot)
	// are retried in the background instead of taking the server down.
	var listenAddrs []string
	for _, u := range strings.FieldsFunc(addr, func(c rune) bool { return c == ';' || c == ',' }) {
		if u = strings.TrimSpace(u); u != "" {
			listenAddrs = append(listenAddrs, strings.TrimPrefix(u, "http://"))
		}
	}

	if memAPI != nil {
		go serveMemoryLAN(memAPI)
	}

	for _, extra := range listenAddrs[1:] {
		go func(a string) {
			for {
				fmt.Printf("[LucyServer] listening on http://%s\n", a)
				err := http.ListenAndServe(a, r)
				fmt.Fprintf(os.Stderr, "[LucyServer] listener %s: %v (retrying in 10s)\n", a, err)
				time.Sleep(10 * time.Second)
			}
		}(extra)
	}

	fmt.Printf("[LucyServer] listening on http://%s\n", listenAddrs[0])
	if err := http.ListenAndServe(listenAddrs[0], r); err != nil {
		fmt.Fprintf(os.Stderr, "server: %v\n", err)
		os.Exit(1)
	}
}

// defaultAllowedOrigins are the only browser origins permitted to talk to this
// server. Same-origin local pages only — the Flutter shell, the Android
// companion and curl are native clients that send no Origin header at all and
// are unaffected by this list.
var defaultAllowedOrigins = []string{
	"http://localhost:5000",
	"http://127.0.0.1:5000",
	"http://[::1]:5000",
}

// allowedOrigins returns the browser origins this server accepts. Extend it
// with SWARM_ALLOWED_ORIGINS (comma-separated) rather than reintroducing "*".
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

// originGate rejects any request carrying a browser Origin this server does not
// trust — before swarmAuthMiddleware gets a chance to wave it through on the
// strength of a loopback address.
//
// This closes a remote-code-execution path. The auth middleware treats every
// loopback connection as authenticated, and a request a browser makes to
// 127.0.0.1 *is* a loopback connection as far as the server is concerned. So
// any web page the user happened to be visiting could POST to
// /api/run_command — arbitrary shell execution — and the CORS config could not
// prevent it, because CORS only governs whether the attacker may *read* the
// response, not whether the server executes the request.
//
// WebSockets made it worse: /api/terminal/ws attaches a live shell, and
// browser WebSocket connections are not subject to CORS at all. An Origin check
// is the only thing that stops `new WebSocket("ws://127.0.0.1:5000/...")` from
// a hostile page, which is why this gate runs on every path rather than only
// under /api/ — /lucy and /webauthn/* are equally reachable from a browser.
//
// Native clients (dart:io, OkHttp, curl) send no Origin header and pass
// through untouched; browsers always attach one to cross-origin requests and
// to WebSocket handshakes, so the hostile case is exactly the case that is
// caught.
func originGate(next http.Handler) http.Handler {
	allowed := allowedOrigins()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && !slices.Contains(allowed, origin) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusForbidden)
			json.NewEncoder(w).Encode(map[string]string{
				"error":  "Origin not permitted.",
				"origin": origin,
			})
			return
		}
		next.ServeHTTP(w, r)
	})
}

// swarmAuthMiddleware replicates the .NET original's inline middleware
// exactly (Program.cs lines 77-96): every /api/* route except /api/tts/*
// requires either a loopback connection, an exact X-Swarm-Auth header match,
// or an Authorization header that CONTAINS the token (not an exact match —
// preserved as-is even though that's a looser check than X-Swarm-Auth's,
// since changing auth semantics during a port is not this task's job).
// /webauthn/* and /lucy are NOT under /api/ and so are NOT covered by this
// middleware, same as the original — not a gap introduced by this port.
//
// The loopback branch below is only safe because originGate runs first: a
// browser request to 127.0.0.1 is a loopback connection too, so without that
// gate this check hands any web page full access. Do not reorder them, and do
// not reintroduce a wildcard CORS origin.
func swarmAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path
		if strings.HasPrefix(path, "/api/") && !strings.HasPrefix(path, "/api/tts") {
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
// These are belt-and-suspenders given originGate already guards browser access,
// but defence-in-depth is cheap.
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
// enough (systemd Restart=on-failure) that memory growth from unique IPs is
// not a concern for a personal-device OS.
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
