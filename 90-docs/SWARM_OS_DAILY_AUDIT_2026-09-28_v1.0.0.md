# SWARM OS Daily Audit — 2026-09-28
**Version:** v1.0.0  
**Machine:** LUCILLE (cachyos-i30ltz) · Intel UHD CometLake · 16 GB RAM  
**Source read:** `/mnt/Lucy` (live working drive)  
**Audit time:** 2026-09-28 01:10 UTC (scheduled run — non-interactive, user absent)  
**Master List:** [SNfWViWjiL2CYKvxY7gLCr](https://claude.ai/artifact/SNfWViWjiL2CYKvxY7gLCr)

---

## 1. INVENTORY

| Item | Value |
|---|---|
| VERSION | **6.2.72** |
| Git last commits (24h) | 3 × `auto-sync` commits (PROJECT_MEMORY.md only) — no code changes |
| .env last modified | 2026-09-20 — **5 days stale since OPENROUTER_API_KEY regeneration needed** |
| GamingAgent tests | `services`: PASS (40+ cases) — handlers: **no tests at all** |
| LucyServer tests | `handlers`, `memory`, `services`: all PASS (cached) |
| go vet | Both services: **CLEAN** |

---

## 2. ACTIVE INCIDENTS

### ⚠️ INCIDENT-1 — OPENROUTER_API_KEY returning 401 (ONGOING — since ≥2026-09-26)
**Severity:** CRITICAL — all Lucille routes dead  
**Affected:** GamingAgent-go `/api/lucille/eval`, `/api/lucille/chat`, `/api/lucille/chat/stream`  
**Symptom:** `callChat()` returns "nemotron response parse failed" (error string is also stale — still says Nemotron, model is Kimi K2.5 on OpenRouter)  
**Root cause:** `.env` `OPENROUTER_API_KEY` is likely expired or was never updated after the key was noted as 401 in the 2026-09-26 audit  
**Resolution:** Regenerate key at openrouter.ai → update `/mnt/Lucy/20-runtime/.env` → rebuild/restart `gaming-agent.service`  
**Note:** The `.env` has not been modified since 2026-09-20 (8+ days old). The 2026-09-26 audit confirmed 401 was active.

### ⚠️ INCIDENT-2 — STEAM_API_KEY 403 (ONGOING — since ≥2026-09-20)
**Severity:** HIGH — Steam library unavailable  
**Affected:** GamingAgent-go `/api/steam/library`, `/api/games/intersection`  
**Symptom:** 403 straight from Steam  
**Resolution:** Regenerate key at steamcommunity.com/dev/apikey → update `.env`  
**Note:** Flagged in 2026-09-20 audit, flagged again 2026-09-26. Not fixed. `STEAM_API_KEY` last updated in `.env` 2026-09-20.

### ⚠️ INCIDENT-3 — swarm-ui.service silent-crash recurrence (ONGOING — since 2026-09-15)
**Severity:** HIGH — SWARM OS desktop does not boot on Ventoy/QEMU  
**Affected:** Live Kiosk boot → falls back to getty/autologin with motd banner  
**Status:** Diagnostics added (WLR_LOG_LEVEL=debug, systemctl snapshot) but not yet root-caused. No fresh ISO built.  
**Next step:** Build ISO, boot real hardware or VM, read the new debug logs.

---

## 3. BUGS FOUND

### BUG-A — `callChat()` does not check HTTP status before JSON decode [HIGH]
**File:** `30-source/GamingAgent-go/services/lucille_service.go:368-377`  
**Problem:** After getting the response from OpenRouter, the non-streaming path jumps straight to `json.NewDecoder(resp.Body).Decode(&raw)` with no `resp.StatusCode` check. A 401, 429, or 503 from OpenRouter produces `"nemotron response parse failed"` with zero diagnostic information about why the call failed.  
**Scenario:** OPENROUTER_API_KEY expired → every `/api/lucille/chat` call returns HTTP 401 → clients see an opaque error, not "key is invalid."  
**Fix:** Add `if resp.StatusCode < 200 || resp.StatusCode >= 300 { b, _ := io.ReadAll(io.LimitReader(resp.Body, 512)); return "", fmt.Errorf("chat API %d: %s", resp.StatusCode, strings.TrimSpace(string(b))) }` before the decode. Apply the same fix in the `Eval()` function (line ~134).  
**Note:** The calendar helper `fetchUpcomingCalendarSummary()` (line ~287) already does this correctly — use it as the pattern.

### BUG-B — Stale "nemotron response parse failed" error string [MEDIUM]
**File:** `30-source/GamingAgent-go/services/lucille_service.go:375`  
**Problem:** Model is now `moonshotai/kimi-k2.5` via OpenRouter. Error string still says "nemotron response parse failed" — misleads debugging.  
**Fix:** Change to `"chat model response parse failed"` (provider-agnostic, matching the constant naming convention).

### BUG-C — `/health` always returns `{"status":"ok"}` — hides key/DB failures [MEDIUM]
**File:** `30-source/GamingAgent-go/handlers/health.go:8-11`  
**Problem:** `/health` is a single-line `{"status":"ok"}` with zero dependency checking. With OPENROUTER_API_KEY invalid and STEAM_API_KEY invalid, the service still reports healthy. The LucyServer rich health check (checks GamingAgent via probeHTTP) doesn't help because that just checks if the port is open.  
**Suggested fix:** Add basic checks: DB ping, check `os.Getenv("OPENROUTER_API_KEY") != ""`, check `os.Getenv("STEAM_API_KEY") != ""` — surface as `"keys_configured"` sub-object in the response without exposing key values.

### BUG-D — `PriceAlertDaemon` polls 367+ games in a burst (LOW)
**File:** `30-source/GamingAgent-go/services/` (price alert daemon)  
**Problem:** ~734 CheapShark HTTP calls per day fired in a tight loop with no delay. Could hit rate limits.  
**Fix:** Add 600ms sleep between game lookups (already flagged in 2026-09-26 audit, not yet applied).

---

## 4. WIRING GAPS / MISSING CONNECTIONS

### GAP-1 — GamingAgent handlers package has ZERO tests
**Severity:** MEDIUM  
**Files:** `30-source/GamingAgent-go/handlers/` (favorites.go, games.go, gfn.go, health.go, lucille.go, media.go, price_alerts.go, steam.go)  
**Issue:** All handler logic is tested through services but handlers themselves have no test coverage. A broken handler signature, missing middleware, or wrong JSON field name would not be caught.  
**Suggestion:** Add at minimum a smoke-test per handler using `httptest.NewRecorder` — follow the pattern already used in `LucyServer-go/handlers/`.

### GAP-2 — `lucilleActionProtocol` verbs not audited against `dashboard.html`
**Severity:** LOW  
**Files:** `30-source/GamingAgent-go/services/lucille_service.go` (system prompt), `30-source/swarm-overlay/assets/dashboard.html` (`dispatchAction()`)  
**Issue:** The model is instructed to produce `ACTION: <verb> [arg]` lines, and dashboard.html has a corresponding `dispatchAction()`. These two lists have never been formally verified to match. A verb in the system prompt with no handler in the dashboard (or vice versa) silently does nothing.

### GAP-3 — `PRICE_ALERT_WEBHOOK_URL` undocumented; LucyServer consumer endpoint unverified
**Severity:** LOW  
**Issue:** The price alert daemon uses `PRICE_ALERT_WEBHOOK_URL` env var, not documented in `CLAUDE.md` alongside the other API keys. The receiving LucyServer endpoint (if any) has not been verified to exist.

### GAP-4 — `swarm-ui.service` boot fix source-DONE but not ISO-built or booted
**Severity:** HIGH (deployment gap, not a code bug)  
**Files:** `40-iso-profile/.../etc/systemd/system/swarm-ui.service`, `70-scripts/DESKTOP_BOOT_REPAIR.md`  
**Issue:** Boot repair work (PAMName fix, gamescope opt-in, swarm-ui-cleanup.sh) is committed to source but no fresh ISO has been built and booted to prove it works. Boot is still silently failing on Ventoy and QEMU.

### GAP-5 — LucyServer-go missing direct context cancellation on OpenRouter/ElevenLabs calls
**Severity:** LOW  
**Issue:** `AiCoderDispatch` and TTS routes use `http.DefaultClient.Do(req)` / a client with a global timeout, but no per-request context cancellation tied to the HTTP handler's `r.Context()`. A client disconnect mid-stream does not abort the upstream API call, wasting tokens and cost.

---

## 5. PERFORMANCE / RESOURCE NOTES

- `.env` last modified 2026-09-20 (8 days) — API keys are likely stale/expired. Both active incidents trace to `.env`.
- auto-sync commits fire every 10 min but only update `PROJECT_MEMORY.md` — no code commits in 24h. System appears idle.
- `swarm-memory` logs 54 entries, all `cachyos@cachyos-i30ltz` origin. No phone/companion entries — companion sync not live.

---

## 6. RESOLVED ITEMS (last 24h)

None — only PROJECT_MEMORY.md auto-sync commits in the past 24 hours. No code changes landed.

---

## 7. SUGGESTIONS TO IMPROVE RECOVERY OS

1. **Fix callChat() status check immediately (BUG-A)** — this is a one-line add and would have made the current OpenRouter 401 incident instantly diagnosable instead of showing a cryptic "nemotron parse failed." It will happen again the next time a key rotates.

2. **Add a real dependency health endpoint to GamingAgent** — surface key-configured booleans, DB ping result, and last-successful-external-call timestamps in `/health`. The LucyServer model is good; apply the same pattern to GamingAgent. This would expose INCIDENT-1 and INCIDENT-2 to monitoring without exposing actual key values.

3. **Add handler-level smoke tests for GamingAgent** — services are well-tested but handlers have zero coverage. A 5-minute pass adding `httptest` cases for at least the Lucille and Steam handlers would catch regressions in routing/auth wiring.

4. **Force a fresh ISO build + boot pass** — boot has been silently failing since 2026-09-15. Three separate fixes have been committed (PAMName, gamescope, swarm-ui-cleanup.sh, WLR_LOG_LEVEL debug) but never verified via a real boot. The debug logging added in the 2026-09-22 pass will finally capture the real exit reason — but only if someone builds the ISO and boots it.

5. **Document `PRICE_ALERT_WEBHOOK_URL` and `WEATHER_LOCATION` in CLAUDE.md** — both are active env vars used by GamingAgent but absent from the API keys section in CLAUDE.md. Anyone setting up a new `.env` will miss them.

6. **Wire context cancellation to OpenRouter calls** — tie `r.Context()` through to the `http.NewRequestWithContext()` call in `AiCoderDispatch`, Lucille chat, and TTS routes. This is a correctness improvement (no orphaned API calls on disconnect) and reduces cost.

7. **Regenerate `.env` API keys** — `.env` has not been modified since 2026-09-20. At minimum `OPENROUTER_API_KEY` (confirmed 401) and `STEAM_API_KEY` (confirmed 403) need fresh values. Consider adding a `check-keys.sh` script that does a lightweight health-probe of each configured key and prints pass/fail.

---

*Audit completed 2026-09-28 01:15 UTC (automated, non-interactive)*
