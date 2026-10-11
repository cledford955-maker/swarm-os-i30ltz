# 📋 SWARM_OS Suite — MASTER BUILD LIST
**Project:** SWARM_OS Suite (LUCILLE + i30LTZ Recovery OS)
**Managed by:** LUCILLE CORE AI
**Created:** 2026-10-09 | **Version at Creation:** v6.2.87 / i30LTZ v0.3.0-alpha

---

## 🔧 FORMAT
`DATE | VERSION | PRIORITY | TASK DESCRIPTION | STATUS`

---

## 2026-10-09 | Morning Command Briefing | v6.2.87

### SWARM_OS / LUCILLE — New Entries

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-09 | v6.2.87 | **[CRITICAL]** | COMMIT: Push uncommitted LucilleAssistant changes — `ai.go`, `config.go`, `MainActivity.kt`, `NIGHTLY_LOG.md` sitting dirty on main branch. Run: `git -C /mnt/Lucy add 30-source/LucilleAssistant/ NIGHTLY_LOG.md && git commit -m "feat(lucille): commit LucilleAssistant ai/config/android changes"` | PENDING |
| 2026-10-09 | v6.2.87 | **[CRITICAL]** | API-KEYS: Add new OpenRouter key + Steam key to `20-runtime/.env`. Lucille AI chat has been dead 18+ days. After adding keys, add startup health-check in `ai.go` that warns on empty/invalid keys. | PENDING |
| 2026-10-09 | v6.2.87 | **[HIGH]** | SYNC-FIX: Fix `rsync --no-delete` bug in `70-scripts/sync_lucille_ai.sh`. Add post-run checksum integrity log to confirm backup state. Broken for weeks — backup pipeline producing zero successful syncs. | PENDING |
| 2026-10-09 | v6.2.87 | **[HIGH]** | LUKS-ALERT: Create a systemd service/timer (or desktop autostart) that checks `cryptsetup status luks-a24202ce-...` at login and fires a desktop notification if `sda4` (lucy-master) is locked. Unblocks the nightly sync pipeline. | PENDING |
| 2026-10-09 | v6.2.87 | **[HIGH]** | ISO-REBUILD: Sync `/mnt/Lucy` → `/mnt/swarmbuild`, run `build_swarm_iso.sh`, then boot via Ventoy to verify `swarm-ui.service` fix. v6.2.87 ISO is the product. No ISO in `swarm_os_out/` yet. | PENDING |
| 2026-10-09 | v6.2.87 | **[MEDIUM]** | CONFIG-HEALTHCHECK: Add `OpenRouterKey`, `SteamKey` fields to `config.go` `Config` struct. On load, log a WARNING if either field is empty. Surfaces missing-key issues immediately at startup rather than failing silently at runtime. | PENDING |

### i30LTZ Recovery OS — New Entries (Carry-forward + New)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-09 | v0.3.0-alpha | **[CRITICAL]** | RC-11: Add login user creation to `70-scripts/install-recovery-from-debian.sh`; run real install on sda3 (PARTUUID 993d0098) — OS currently uninstallable on real hardware. Blocker for all RC testing. | PENDING |
| 2026-10-09 | v0.3.0-alpha | **[HIGH]** | NODE-SERVICE: Install `i30ltz-node.service` so agent + Tailscale bridge survive reboots (`30-source/i30ltz-node/contrib/`). Hand-started only today. | PENDING |
| 2026-10-09 | v0.3.0-alpha | **[HIGH]** | INF-02: Fix `/etc/fstab` via `70-scripts/fstab.canonical` — 3 unstable by-id lines + malformed `/mnt/downloads` entry causing mount failures. | PENDING |
| 2026-10-09 | v0.3.0-alpha | **[HIGH]** | CP-20: ClamAV offline decision — bundle clamav + signatures (115 MB) in ISO for field-offline AV. Add to `40-iso-profile/`. | PENDING |
| 2026-10-09 | v0.3.0-alpha | **[MEDIUM]** | CP-14: Wire MAD IT AI SSE endpoints: process list, ClamAV trigger, SMART status into companion. | PENDING |
| 2026-10-09 | v0.3.0-alpha | **[MEDIUM]** | CP-18: Fix companion terminal session drop on tab switch — implement tmux session-persistence. | PENDING |

---

> *Append new entries below this line — newest date at bottom of each day's section.*

---

## 2026-10-10 | Nightly Append | v6.2.87

### Status Update from Last Night's Queue

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-09 | v0.3.0-alpha | **[CRITICAL]** | RC-11: Run real install on sda3 — install-recovery-from-debian.sh | ✅ COMPLETED 2026-10-09 (installed; btrfs UUID 71287bbf; boot test PENDING) |
| 2026-10-09 | v6.2.87 | **[CRITICAL]** | COMMIT: LucilleAssistant ai.go / config.go / MainActivity.kt | 🔴 STILL PENDING — 13 dirty files in /mnt/Lucy |
| 2026-10-09 | v6.2.87 | **[CRITICAL]** | API-KEYS: OpenRouter key + Steam key → 20-runtime/.env | 🔴 STILL PENDING — Day 19+ dead |
| 2026-10-09 | v6.2.87 | **[HIGH]** | SYNC-FIX: Fix rsync --no-delete bug in sync_lucille_ai.sh | 🔴 STILL PENDING — sync ok=0 every run |
| 2026-10-09 | v6.2.87 | **[HIGH]** | LUKS-ALERT: systemd service to check sda4 LUKS status at login | PENDING |
| 2026-10-09 | v6.2.87 | **[HIGH]** | ISO-REBUILD: build_swarm_iso.sh + Ventoy boot test | PENDING |

### Tomorrow's Top 5 (2026-10-11 Priority Queue)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-10 | v0.3.0-alpha | **[CRITICAL]** | BOOT-TEST RC-11: Unplug Debian drive, F12 boot, select i30LTZ Recovery — acceptance test for the RC-11 install | PENDING |
| 2026-10-10 | v6.2.87 | **[CRITICAL]** | API-KEYS: Add OpenRouter key + Steam key to 20-runtime/.env — Lucille chat dead day 19+ | PENDING |
| 2026-10-10 | v6.2.87 | **[HIGH]** | COMMIT: `git add -A && git commit` in both /mnt/Lucy and /mnt/recoverybuild — 27 dirty files across suite | PENDING |
| 2026-10-10 | v6.2.87 | **[HIGH]** | SYNC-FIX + LUKS: Fix sync_lucille_ai.sh --no-delete flag + add LUKS unlock reminder service | PENDING |
| 2026-10-10 | v6.2.87 | **[HIGH]** | ISO-REBUILD: sync /mnt/Lucy → /mnt/swarmbuild, run build_swarm_iso.sh, boot from Ventoy | PENDING |

> *Nightly append by LUCILLE CORE AI | 2026-10-10 00:00 ET*

---

## 2026-10-11 | Automated Health Check + Code Audit | v6.2.87

### Active Incidents (Carried Forward — Still Open)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-09 | v6.2.87 | **[CRITICAL]** | INC-1: OpenRouter API key 401 — Lucille chat (GamingAgent + LucyServer) DEAD, day 20+ | 🔴 OPEN |
| 2026-10-09 | v6.2.87 | **[CRITICAL]** | INC-2: Steam Web API key 403 — library/intersection endpoints return errors silently | 🔴 OPEN |
| 2026-10-09 | v6.2.87 | **[CRITICAL]** | INC-3: swarm-ui.service crashes at ISO boot (Day 24+) — WLR_LOG_LEVEL=debug still in place, real cause uncaptured | 🔴 OPEN |
| 2026-10-09 | v6.2.87 | **[HIGH]** | INC-5: sync_lucille_ai.sh `--no-delete` flag unsupported by rsync 3.5.0 — sync ok=0 every run for weeks | 🔴 OPEN |

### New Findings from 2026-10-11 Code Audit

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-11 | v6.2.87 | **[HIGH]** | SECURITY: Default auth token `swarm-token-2026` hardcoded in LucyServer-go/main.go:424, GamingAgent-go/main.go:208, peer.go:192, Flutter swarm_config.dart:13, and companion SwarmConnection.kt:94. Fallback is widely known; set SWARM_AUTH_TOKEN env var in /etc/swarm_os.env before next ISO build. | PENDING |
| 2026-10-11 | v6.2.87 | **[HIGH]** | RATE-LIMIT HOLE: 88 of 95 API routes in LucyServer-go have NO per-IP rate limiter. Only /lucy, /boltz, /tts/generate, /run_command, /verify_login_password, /totp/check, /lucille/pipeline and /lucille/route are guarded. /ai-coder/task, /code/save, /sandbox/execute, and /rag/* are unthrottled mutating endpoints. Add rateLimiter() to at least those four. | PENDING |
| 2026-10-11 | v6.2.87 | **[HIGH]** | WIRING GAP: SteamSpy enrichment service (GamingAgent-go/services/steamspy_service.go) is instantiated inside NewGamesService only — it is never exposed to handlers or Lucille for genre/tag context. Wire SteamSpy data into /api/games/intersection response and Lucille buildContextMessages() so Lucille can reference genres and popularity scores. | PENDING |
| 2026-10-11 | v6.2.87 | **[HIGH]** | WIRING GAP: Calendar integration (fetchUpcomingCalendarSummary) in lucille_service.go polls GoogleWorkspaceService on :8402 but GOOGLE_WORKSPACE_URL env var is never set in /etc/swarm_os.env or the airootfs. It silently skips every call. Document it as "requires Google OAuth setup" in SWARM_AI_FEATURES.md and add it to the env template. | PENDING |
| 2026-10-11 | v6.2.87 | **[MEDIUM]** | CRASH RISK: webauthn.go:66 calls `panic("webauthn init: ...")` if the go-webauthn library returns an error on startup. Since this is called lazily on first WebAuthn request (not at boot), a bad config will crash the LucyServer process mid-session without a journal entry naming WebAuthn. Replace with a logged error + 503 return. | PENDING |
| 2026-10-11 | v6.2.87 | **[MEDIUM]** | DEVPLATFORM REVENUE DATA: services/devplatform.go:781 note confirms old code seeded fake BillingRecords as "Settled" payments — this was fixed (store now starts empty). Confirm the fix is in the ISO build and the analytics dashboard shows no phantom revenue on a fresh boot. Low risk but worth a boot-time check. | PENDING |
| 2026-10-11 | v6.2.87 | **[MEDIUM]** | MISSING STARTUP KEY CHECK: GamingAgent and LucyServer silently return HTTP errors when API keys are missing — no warning at startup. Add an `os.Getenv` check at main() startup that logs a WARNING banner when OPENROUTER_API_KEY, STEAM_API_KEY, or STEAM_ID64 are empty, so the problem is immediately visible in the journal after ISO boot. | PENDING |
| 2026-10-11 | v0.3.0-alpha | **[MEDIUM]** | BOOT-TEST STILL PENDING: RC-11 Recovery OS installed (UUID 71287bbf), but standalone boot (Debian drive unplugged) not yet verified. This is the only proof of independence. | PENDING |
| 2026-10-11 | v6.2.87 | **[LOW]** | DIAGNOSTIC NOISE: swarm-ui.service has `WLR_LOG_LEVEL=debug` set permanently (added 2026-09-22 for crash diagnosis). Once the crash root cause is found and fixed, remove this line — it bloats the journal with wlroots internals on every boot. | PENDING |

### Improvement Suggestions (2026-10-11)

| # | Suggestion | Impact |
|---|-----------|--------|
| S1 | **API key health endpoint** — add `GET /health/keys` to both GamingAgent and LucyServer that returns `{"openrouter": "ok/missing", "steam": "ok/missing"}` without exposing key values. Companion and dashboard can poll it to show a "Lucille offline" badge before a user tries to chat. | High |
| S2 | **Structured logging** — replace all `fmt.Printf("[GamingAgent]...")` and `fmt.Fprintf(os.Stderr, ...)` calls with a minimal leveled logger (e.g. `log/slog`, stdlib since Go 1.21). Makes journal parsing `journalctl -u gaming-agent -o json` actually useful. | Medium |
| S3 | **SteamSpy genre injection into Lucille context** — wire the already-built SteamSpyService enrichment into Lucille's `buildContextMessages()` so she can say "your top Action game is X" instead of only knowing playtime. Zero new dependencies, the service just isn't plumbed through. | Medium |
| S4 | **Consolidate swarm-token-2026 into a single source of truth** — it appears in 5 files (2 Go, 1 Kotlin, 1 Dart, 1 Go const). Create one `tokens.go` constant package in a shared location, or enforce it comes exclusively from the SWARM_AUTH_TOKEN env var with no fallback (breaking old clients is acceptable for a personal project — security over compatibility here). | Medium |
| S5 | **ISO build gate: key presence check** — add a pre-build assertion in `build_swarm_iso.sh` that checks `20-runtime/.env` for non-empty OPENROUTER_API_KEY and STEAM_API_KEY before running `mkarchiso`. Prevents shipping a broken AI again. `grep -qE '^OPENROUTER_API_KEY=.+' 20-runtime/.env || { echo "ERROR: OPENROUTER_API_KEY not set"; exit 1; }` | High |
| S6 | **Calendar GOOGLE_WORKSPACE_URL in env template** — add it to `airootfs/etc/swarm_os.env` as a commented-out line with a note that it requires Google OAuth setup via `/api/google/auth/upload_credentials`. Currently the calendar feature is silently dead on every install with no indication why. | Low |

> *Automated health check by Claude Sonnet 4.6 | 2026-10-11 ET*
