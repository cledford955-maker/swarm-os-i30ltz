package main

import (
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"

	"swarm-os/lucy-server/memory"
)

// openMemory opens the shared memory store, or returns nil when /mnt/brains is
// not mounted (live ISO, nofail mount). The server still starts; memory routes
// answer 503 until it is.
func openMemory() *memory.API {
	dir := memory.DefaultDir()
	store, err := memory.Open(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[LucyServer] shared memory unavailable at %s: %v\n", dir, err)
		return nil
	}
	fmt.Printf("[LucyServer] shared memory: %s (%d entries)\n", dir, store.Count())
	return &memory.API{Store: store, Leases: memory.NewLeases(dir), Device: memory.LocalDeviceID()}
}

func memoryRoutes(a *memory.API) func(chi.Router) {
	return func(r chi.Router) {
		if a == nil {
			r.HandleFunc("/*", func(w http.ResponseWriter, _ *http.Request) {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusServiceUnavailable)
				fmt.Fprint(w, `{"error":"shared memory unavailable: mount /mnt/brains and restart lucy-server"}`)
			})
			return
		}
		a.Routes(r)
	}
}

// serveMemoryLAN runs the sync-only listener phones use on the local network
// when Tailscale is down (SWARM_MEMORY_LISTEN, default :8402). It exposes
// nothing but /api/memory/* and always requires the token.
func serveMemoryLAN(a *memory.API) {
	addr := os.Getenv("SWARM_MEMORY_LISTEN")
	if addr == "" {
		addr = "0.0.0.0:8402"
	}
	if addr == "off" {
		return
	}
	r := chi.NewRouter()
	r.Use(chimiddleware.Recoverer)
	r.Use(securityHeaders)
	r.Use(memory.TokenOnly(memory.AuthToken))
	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"status":"ok","device":%q}`, a.Device)
	})
	r.Route("/api/memory", a.Routes)
	srv := &http.Server{Addr: addr, Handler: r, ReadHeaderTimeout: 10 * time.Second}
	fmt.Printf("[LucyServer] memory sync listening on %s\n", addr)
	if err := srv.ListenAndServe(); err != nil {
		fmt.Fprintf(os.Stderr, "[LucyServer] memory sync listener: %v\n", err)
	}
}
