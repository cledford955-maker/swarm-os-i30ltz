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

## 2026-10-11 | Nightly Append | v6.2.88

### Status Update — Overnight / Morning

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-10 | v0.3.0-alpha | **[CRITICAL]** | BOOT-TEST RC-11: Physical boot test — unplug Debian, F12, i30LTZ | ⚠️ STATUS UNKNOWN — no commit or log entry confirming completed |
| 2026-10-10 | v6.2.87 | **[CRITICAL]** | API-KEYS: OpenRouter + Steam key to 20-runtime/.env | 🔴 STILL PENDING — Day 20+ |
| 2026-10-10 | v6.2.87 | **[HIGH]** | COMMIT: Dirty files in /mnt/Lucy + /mnt/recoverybuild | ✅ RESOLVED — auto-sync committed all files; repos CLEAN as of 22:44 ET |
| 2026-10-10 | v6.2.87 | **[HIGH]** | SYNC-FIX + LUKS: Fix sync_lucille_ai.sh + add LUKS unlock reminder | 🔴 STILL PENDING |
| 2026-10-10 | v6.2.87 | **[HIGH]** | ISO-REBUILD: sync to /mnt/swarmbuild, build_swarm_iso.sh, Ventoy boot | 🔴 STILL PENDING |

### Tomorrow's Top 5 (2026-10-12 Priority Queue)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-11 | v0.3.0-alpha | **[CRITICAL]** | BOOT-TEST: Unplug Debian drive, F12 boot, select i30LTZ Recovery — acceptance test | PENDING |
| 2026-10-11 | v6.2.88 | **[CRITICAL]** | API-KEYS: Add OpenRouter key + Steam key to 20-runtime/.env — Day 20+ dead | PENDING |
| 2026-10-11 | v6.2.22 | **[HIGH]** | COMPANION: Wire RecoveryAiScreen to live Dr. I30LTZ / MAD AI SSE backend endpoint | PENDING |
| 2026-10-11 | v6.2.88 | **[HIGH]** | SYNC-FIX: Drop --no-delete from sync_lucille_ai.sh + LUKS unlock before sync | PENDING |
| 2026-10-11 | v6.2.88 | **[HIGH]** | ISO-REBUILD: sync /mnt/Lucy → /mnt/swarmbuild, build_swarm_iso.sh, boot via Ventoy | PENDING |

> *Nightly append by LUCILLE CORE AI | 2026-10-11 00:00 ET | v6.2.88*


---

## 2026-10-12 | Nightly Append | v6.2.88

### Status Update -- Oct 11 Queue Review

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-11 | v0.3.0-alpha | CRITICAL | BOOT-TEST: Unplug Debian, F12, i30LTZ boot | RED STILL PENDING -- Day 3 unconfirmed |
| 2026-10-11 | v6.2.88 | CRITICAL | API-KEYS: OpenRouter + Steam to 20-runtime/.env | RED STILL PENDING -- Day 22+ |
| 2026-10-11 | v6.2.22 | HIGH | COMPANION: Wire RecoveryAiScreen to MAD AI SSE | RED STILL PENDING |
| 2026-10-11 | v6.2.88 | HIGH | SYNC-FIX: Drop --no-delete + LUKS unlock | RED STILL PENDING |
| 2026-10-11 | v6.2.88 | HIGH | ISO-REBUILD: sync swarmbuild, run build_swarm_iso.sh | RED STILL PENDING |

### New -- Carry Forward

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-12 | v0.3.0-alpha | CRITICAL | ai-board.tsv uncommitted in /mnt/recoverybuild -- commit it | PENDING |

### Tomorrow Top 5 (2026-10-13 Priority Queue)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-12 | v0.3.0-alpha | CRITICAL | BOOT-TEST RC-11: unplug Debian, F12 boot, select i30LTZ Recovery -- acceptance test | PENDING |
| 2026-10-12 | v6.2.88 | CRITICAL | API-KEYS: Add OpenRouter key + Steam key to 20-runtime/.env -- Day 22+ dead | PENDING |
| 2026-10-12 | v6.2.22 | HIGH | COMPANION: Wire RecoveryAiScreen to live MAD IT AI SSE endpoint BridgeClient /api/chat | PENDING |
| 2026-10-12 | v6.2.88 | HIGH | SYNC-FIX: Drop --no-delete from sync_lucille_ai.sh + unlock sda4 LUKS first | PENDING |
| 2026-10-12 | v6.2.22 | HIGH | BRAND-THEME: Apply red #cc1a1a / yellow #f0c020 / void #050508 to Color.kt + Theme.kt | PENDING |

> Nightly append by LUCILLE CORE AI | 2026-10-12 00:00 ET | v6.2.88

---

## 2026-10-14 | Automated Health Check Audit | v6.2.88

### Code Bugs Fixed This Run

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | **[HIGH]** | SYNC-FIX: Dropped `--no-delete` flag from `70-scripts/sync_lucille_ai.sh` (unsupported on rsync 3.5.0 — root cause of INC-5 / ok=0 every run) | ✅ FIXED |
| 2026-10-14 | v6.2.88 | **[HIGH]** | LLM-DEFAULT: Fixed `30-source/LucyServer-go/services/llm.go` default model — was `nvidia/llama-3.3-nemotron-super-49b-v1` (RETIRED, HTTP 410 since 2026-09-20); now `moonshotai/kimi-k2.5` (active OpenRouter model) | ✅ FIXED |

### Ongoing Active Incidents (unresolved, requires user action)

| Incident | Severity | Description | Day | Fix |
|---------|---------|-------------|-----|-----|
| INC-1 | 🔴 CRITICAL | OpenRouter API key 401 — Lucille chat DEAD | Day 24+ | Add new OpenRouter key to `20-runtime/.env` |
| INC-2 | 🟠 HIGH | Steam Web API key 403 | Day 24+ | Regen at steamcommunity.com/dev/apikey |
| INC-3 | 🟠 HIGH | swarm-ui.service crash on live ISO — drops to tty1 | Day 28+ | Rebuild ISO after sync to /mnt/swarmbuild |
| INC-4 | 🔴 CRITICAL | /mnt/archive 100% full | Day 7+ | `python3 dedupe_archive.py` or manual rotation |
| INC-5 | 🟠 HIGH | rsync `--no-delete` flag → sync ok=0 | ✅ FIXED | Fixed in this run |
| INC-6 | 🟡 MEDIUM | sda4 LUKS locked — AI sync skips every run | Ongoing | `sudo cryptsetup open /dev/sda4 luks-a24202ce-...` |
| INC-7 | 🟡 MEDIUM | ai-board.tsv uncommitted in recoverybuild | Ongoing | `git add ai-board.tsv && git commit` |

### Mocked / Unwired Items Requiring Future Work

| Service | Location | Status |
|---------|---------|--------|
| RecoveryAiScreen | `lucille-companion/…/ui/screen/` | **NOT WIRED** — UI exists but no BridgeClient `/api/chat` connection |
| AppAnalytics DAU/MAU | `LucyServer-go/services/virtualization.go` | **ZERO PLACEHOLDER** — hardcoded fake values (2150 DAU) removed; real telemetry pipeline does not exist |
| Marketplace analytics | `LucyServer-go/services/devplatform.go` | **EMPTY** — fake revenue/template seed data removed; no real pipeline |
| SWARM_AUTH_TOKEN | `LucyServer-go/main.go:swarmAuthMiddleware` | **DEFAULT "swarm-token-2026"** — known public fallback; rotate before exposing on LAN |

### Improvement Suggestions

1. **Add startup key-check to GamingAgent** — `services/lucille_service.go` silently fails at chat time when `OPENROUTER_API_KEY` is empty; log a `WARN` at service init, same pattern used for `STEAM_API_KEY`
2. **LUKS unlock notifier** — create a lightweight systemd oneshot (or `.desktop` autostart) that fires a desktop notification via `notify-send` when sda4 (`a24202ce-...`) is locked at login; unblocks the nightly AI sync
3. **Rate-limiter memory leak** — `rateLimiter` in `LucyServer-go/main.go` never evicts IP buckets; fine for a personal device but add periodic GC if uptime extends past a week (comment already notes this)
4. **ISO rebuild** — `swarm-ui.service` crash fix is staged but never tested; rebuild ISO and boot via Ventoy to close this Day 28 incident
5. **Telemetry pipeline** — AppAnalytics and Marketplace analytics both return zeros/empty; wire real usage counters or document explicitly as "not implemented" so the dashboard shows honest state

> Automated health audit by Claude Code | 2026-10-14 | v6.2.88
