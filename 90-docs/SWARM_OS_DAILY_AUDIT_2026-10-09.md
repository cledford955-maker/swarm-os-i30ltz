# SWARM OS Daily Audit — 2026-10-09

**Model:** Sonnet 4.6 (scheduled health check)
**VERSION:** 6.2.87
**Branch:** i30ltz/compassionate-carson-rn0x9o

---

## Active Incidents (all ongoing, user action required)

| # | Incident | Status | Action needed |
|---|----------|--------|---------------|
| 1 | **OPENROUTER_API_KEY 401** — All Lucille routes dead (`/api/lucille/eval`, `/api/lucille/chat`, `/api/lucille/chat/stream`). Key has not been updated since 2026-09-20. | ONGOING (25 days) | Regenerate key at openrouter.ai and update `/mnt/Lucy/20-runtime/.env` + rebake ISO |
| 2 | **STEAM_API_KEY 403** — `/api/steam/library` and `/api/games/intersection` dead. | ONGOING (17 days) | Verify key in `.env`; re-check steamcommunity.com/dev/apikey |
| 3 | **swarm-ui.service silent crash on every boot** — labwc dies within 1-3s of PAM session open, reason unknown. `WLR_LOG_LEVEL=debug` + crash log capture committed since 2026-09-22 but no fresh ISO has been built and booted to collect the log. | ONGOING (24 days) | Run `sudo mkarchiso`, boot the resulting ISO, read `/mnt/Lucy/logs/swarm-ui-*.log` |
| 4 | **Storage** `/mnt/archive` 100% full, `/mnt/storage` 97% full | ONGOING (2 days) | Clean old build artifacts from `/mnt/archive` |

---

## Bugs Fixed This Run

### FIX-1 — CRITICAL: GoogleWorkspaceService port mismatch (8402 → 8399)

**Files changed:**
- `30-source/LucyServer-go/handlers/google_oauth.go` — `googleWorkspaceBase()` hardcoded 8402 (the memory LAN listener port), changed to 8399
- `30-source/LucyServer-go/main.go:555` — health probe was probing `127.0.0.1:8402/health`, changed to 8399
- `30-source/GamingAgent-go/services/lucille_service.go:272` — `googleWorkspaceCalendarBase()` was pointing at 8402, changed to 8399

**Impact:** All Google OAuth flows (auth URL, credential upload, code exchange, logout) were being proxied to the wrong port. Port 8402 is `SWARM_MEMORY_LISTEN` (the memory LAN sync listener). Port 8399 is what `google-workspace.service` binds via `ASPNETCORE_URLS=http://0.0.0.0:8399`. Every Google OAuth call through LucyServer and every Lucille calendar context fetch through GamingAgent would silently fail or return garbage. Confirmed by cross-referencing `systemd/google-workspace.service`, `services/search.go` (`const googleSvcBase = "http://127.0.0.1:8399"`), and `LucilleAssistant/config.go` (`GoogleURL: "http://127.0.0.1:8399"`).

### FIX-2 — HIGH: Retired model `nvidia/llama-3.3-nemotron-super-49b-v1` as default in LucyServer-go llm.go

**File:** `30-source/LucyServer-go/services/llm.go:45`

The fallback model for any LucyServer LLM call that didn't specify a `model_id` was the retired NVIDIA model (HTTP 410 since 2026-09-20). Changed to `moonshotai/kimi-k2.5` (routes to OpenRouter via the existing prefix logic, same model used by GamingAgent for Lucille chat).

### FIX-3 — MEDIUM: LucilleAssistant NIM fallback using retired model

**File:** `30-source/LucilleAssistant/ai.go:118`

Changed NIM fallback model from `nvidia/llama-3.3-nemotron-super-49b-v1` (HTTP 410) to `nvidia/nemotron-3.5-lightning-30b-a3b`.

### FIX-4 — MEDIUM: LucilleAssistant ideas generator using retired model

**File:** `30-source/LucilleAssistant/feeds.go:390`

Changed from `nvidia/llama-3.3-nemotron-super-49b-v1` to `nvidia/nemotron-3.5-lightning-30b-a3b`. Also updated the error message from `"Nemotron returned HTTP %d"` to `"NIM returned HTTP %d"` to be provider-agnostic.

---

## Open Bugs (unchanged from prior audits)

| Severity | Bug | Location |
|----------|-----|----------|
| MEDIUM | No `r.Context()` threading in `callChat()` — client disconnect doesn't cancel 120s OpenRouter request; goroutine + quota leaked per disconnect | `GamingAgent-go/services/lucille_service.go:345` |
| MEDIUM | GamingAgent `/health` always returns `{"status":"ok"}` — no DB ping, no API key presence check | `GamingAgent-go/handlers/health.go` |
| MEDIUM | `PriceAlertDaemon.CheckOnce()` burst-polls ~734 CheapShark calls with no inter-call sleep | `GamingAgent-go/services/price_alert.go:148` |
| MEDIUM | LucilleAssistant not staged in ISO; service file uses `/mnt/Lucy/...` paths not valid on installed system | `LucilleAssistant/systemd/lucille-assistant.service` |
| LOW | Fallback auth token `"swarm-token-2026"` committed publicly in both backends | `GamingAgent-go/main.go:208`, `LucyServer-go/main.go:424` |
| LOW | `lucille-wake-listener.service` transitively fails because it orders `After=swarm-ui.service` (which is crashing) | `airootfs/.../lucille-wake-listener.service` |

---

## Architecture Observations

- **No `NotImplemented()` routes**: All 100+ routes in LucyServer-go have real implementations. The `handlers/stub.go` helper exists but is unused — the full port is complete.
- **GLIBC 2.43 boundary**: `lucille-core` binary was built on Debian (GLIBC 2.43); if the Arch ISO ships with an older glibc, it will fail to start. Track this when building the next ISO.
- **All Go backends pass `go vet`**: Confirmed clean in the 2026-10-07 audit; no new Go files were added this run.
- **Marketplace mock data was purged**: The fake billing records, invented user reviews, and seeded templates were removed in the 2026-09-12 session. The in-memory store now starts empty.

---

## Suggestions (added to SWARM_AI_FEATURES.md IDEAS section)

1. Wire `r.Context()` into `callChat()` — one-line fix, stops goroutine/quota leaks
2. Fix GamingAgent `/health` — add DB ping + env-key presence check  
3. Add 100–200ms sleep between CheapShark calls in `PriceAlertDaemon.CheckOnce()`
4. Stage LucilleAssistant in the ISO with proper `/opt/swarm_os/` paths
5. Rotate the public fallback auth token `"swarm-token-2026"`
6. Add Tailscale mesh status to LucyServer `/health`
7. Add `httptest` smoke tests for GamingAgent handlers (currently zero test coverage)
8. Persist dev-platform state (extensions, releases, pipelines) to disk — currently in-memory only
9. Shared LLM provider abstraction across GamingAgent, LucyServer, LucilleAssistant
10. Boot fresh ISO and read the swarm-ui crash log — diagnostics have been ready since 2026-09-22

---

*Last updated: 2026-10-09 by Sonnet 4.6 scheduled health check*
