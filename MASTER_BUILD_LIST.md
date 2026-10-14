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

## 2026-10-13 | Nightly Append | v6.2.88

### Status Update — Oct 12 Queue Review

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-12 | v0.3.0-alpha | CRITICAL | BOOT-TEST RC-11: Unplug Debian, F12 boot, i30LTZ Recovery | 🔴 STILL PENDING — Day 4 unconfirmed |
| 2026-10-12 | v6.2.88 | CRITICAL | API-KEYS: OpenRouter + Steam key to 20-runtime/.env | 🔴 STILL PENDING — Day 23+ dead |
| 2026-10-12 | v6.2.22 | HIGH | COMPANION: Wire RecoveryAiScreen to MAD IT AI SSE endpoint | 🔴 STILL PENDING |
| 2026-10-12 | v6.2.88 | HIGH | SYNC-FIX: Drop --no-delete from sync_lucille_ai.sh + unlock sda4 | 🔴 STILL PENDING — sync ok=0 all day |
| 2026-10-12 | v6.2.22 | HIGH | BRAND-THEME: Apply red/yellow/void to Color.kt + Theme.kt | 🔴 STILL PENDING |

### New — Today's Activity (2026-10-13)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-13 | v0.3.0-alpha | ✅ WIN | i30LTZ eval.rs: Added Drive/Part structs, lsblk parsing, Ollama detection (+150 lines) | COMMITTED (pending auto-sync) |
| 2026-10-13 | v0.3.0-alpha | ✅ WIN | i30LTZ main.rs: Major refactor (+1394 lines reshuffled) | COMMITTED (pending auto-sync) |
| 2026-10-13 | v0.3.0-alpha | NOTE | swarm-ui.service: 2 boot captures logged (13:05, 13:10 ET) — service started+exited clean on live ISO | LOGGED |
| 2026-10-13 | v0.3.0-alpha | ⚠️ FLAG | recoverybuild: 37 dirty/uncommitted files — source work done but not committed | NEEDS COMMIT |

### Tomorrow Top 5 (2026-10-14 Priority Queue)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-13 | v0.3.0-alpha | **[CRITICAL]** | COMMIT: `git -C /mnt/recoverybuild add -A && git commit -m "feat(eval): drive/part structs + lsblk + ollama detection; refactor main"` — 37 dirty files | PENDING |
| 2026-10-13 | v0.3.0-alpha | **[CRITICAL]** | BOOT-TEST RC-11: Unplug Debian, F12 boot, select i30LTZ Recovery — Day 4 unconfirmed | PENDING |
| 2026-10-13 | v6.2.88 | **[CRITICAL]** | API-KEYS: Add OpenRouter key + Steam key to 20-runtime/.env — Lucille chat Day 23+ dead | PENDING |
| 2026-10-13 | v6.2.22 | **[HIGH]** | COMPANION: Wire RecoveryAiScreen to live MAD IT AI SSE endpoint (BridgeClient /api/chat) | PENDING |
| 2026-10-13 | v6.2.88 | **[HIGH]** | SYNC-FIX: Drop --no-delete from 70-scripts/sync_lucille_ai.sh — one-line fix, weeks overdue | PENDING |

> Nightly append by LUCILLE CORE AI | 2026-10-13 18:36 UTC (14:36 ET) | v6.2.88

---

## 2026-10-14 | Nightly Append | v6.2.88

### Status Update — Oct 13 Priority Queue Review

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-13 | v0.3.0-alpha | CRITICAL | COMMIT: git -C /mnt/recoverybuild add -A && git commit | 🔴 STILL PENDING — 31 dirty files now include NEW ui.rs (283 lines) |
| 2026-10-13 | v0.3.0-alpha | CRITICAL | BOOT-TEST RC-11: Unplug Debian, F12 boot, i30LTZ Recovery | 🔴 STILL PENDING — Day 5 unconfirmed |
| 2026-10-13 | v6.2.88 | CRITICAL | API-KEYS: OpenRouter key to 20-runtime/.env — Lucille online chat dead | 🟡 PARTIAL — offline chat FIXED (1.7.0 cutover, qwen3:4b live). Online key still needed. |
| 2026-10-13 | v6.2.22 | HIGH | COMPANION: Wire RecoveryAiScreen to MAD I30LTZ AI SSE endpoint | 🔴 STILL PENDING |
| 2026-10-13 | v6.2.88 | HIGH | SYNC-FIX: Drop --no-delete from sync_lucille_ai.sh | 🔴 STILL PENDING |

### New — Tonight's Discoveries (2026-10-14)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v0.3.0-alpha | ✅ WIN | ui.rs BORN: 283-line enterprise console UI module (Raylib palette/fonts/widgets) | SOURCE EXISTS — uncommitted |
| 2026-10-14 | v0.3.0-alpha | ✅ WIN | i30ltz-ide/ scaffold created — Flutter-based IDE project initialized | UNTRACKED |
| 2026-10-14 | v6.2.88 | ✅ WIN | Lucille 1.7.0 cutover DONE — offline chat working (qwen3:4b, verified 15s reply) | LIVE |
| 2026-10-14 | v6.2.88 | ✅ WIN | Archive freed — /mnt/archive at 67% (214G free); INC-4 resolved | RESOLVED |

### Tomorrow Top 5 (2026-10-15 Priority Queue)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v0.3.0-alpha | **[CRITICAL]** | COMMIT: `git -C /mnt/recoverybuild add -A && git commit -m "feat(ui): enterprise console UI + eval/main refactor + IDE scaffold"` — 31 dirty files w/ new ui.rs | PENDING |
| 2026-10-14 | v0.3.0-alpha | **[CRITICAL]** | BOOT-TEST RC-11: Unplug Debian drive, F12, select i30LTZ Recovery — Day 5 still unconfirmed | PENDING |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | API-KEY: Paste real OpenRouter key in Config → "Lucille's brains" — offline ok but online model still 401 | PENDING |
| 2026-10-14 | v6.2.22 | **[HIGH]** | COMPANION: Wire RecoveryAiScreen to MAD I30LTZ AI SSE endpoint (BridgeClient /api/chat) | PENDING |
| 2026-10-14 | v6.2.88 | **[HIGH]** | SYNC-FIX: Drop --no-delete flag from 70-scripts/sync_lucille_ai.sh (one line) | PENDING |

> *Nightly append by LUCILLE CORE AI | 2026-10-14 00:00 ET | v6.2.88*

---

## 2026-10-14 | Project A (SWARM OS) session | v6.2.88

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | **[HIGH]** | SYNC-FIX: `--no-delete` removed from `70-scripts/sync_lucille_ai.sh`; mirror excludes added (62 GB → ~14 GB); checksum now opt-in (`SYNC_CHECKSUM=1`) | 🟡 FIXED on branch `LUCILLE/projecta-build-list-ecbd47`, scratch-tested; NOT yet merged to main, NOT tested on a real drive |
| 2026-10-14 | v6.2.88 | **[HIGH]** | LUKS-ALERT | ⏸ DEFERRED — no notification daemon in the SWARM image; overlaps the Secure Boot/TPM auto-unlock plan |
| 2026-10-14 | v6.2.88 | **[HIGH]** | ISO-REBUILD | ⏸ NEEDS USER — sudo for mkarchiso, Ventoy write, physical boot test |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | API-KEY (OpenRouter) | ⏸ NEEDS USER — real key |
| 2026-10-14 | v6.2.88 | MEDIUM | `sync_lucille_ai.sh` `RECOVERY_BIN` points at a path that no longer exists on Lucy | NEW |

### Project A — second pass (2026-10-14, later)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | MEDIUM | `sync_lucille_ai.sh` `RECOVERY_BIN` stale path | ✅ FIXED on branch — now `/mnt/recoverybuild/30-source/i30ltz-recovery/target/release/i30ltz-recovery` (override `RECOVERY_BIN`); tracker append only when something synced and the tracker exists |
| 2026-10-14 | v6.2.88 | **[HIGH]** | LUKS-ALERT | 🟡 BUILT on branch, unit tests only: `70-scripts/luks_lock_reminder.sh` + `luks-lock-reminder.service` (user unit, once per login, silent when the T7 is absent or unlocked). **Not installed** — after merge run `/mnt/Lucy/70-scripts/luks_lock_reminder.sh --install` as your user. Tested for real only against slick's locked LUKS; lucy-master (T7) is not attached |
| 2026-10-09 | v0.3.0-alpha | HIGH | INF-02 fstab | ℹ Debian `/etc/fstab` already uses UUIDs and `/mnt/downloads` is well-formed. Remaining: `/mnt/lucilleassistant` (by-id) should be `/mnt/lucillebuild` by UUID, and the `/mnt/recoveryos` line pins `96969ed2…`, which matches neither doc UUID (`71287bbf…`, `490b9e60…`). Needs sudo + the T7 attached — NOT touched |
| 2026-10-14 | v6.2.88 | LOW | `update_build_tracker.sh` still uses the old `i30ltz-recovery(seperate-related-project)` path | NEW |

### Project A — direction change (user, 2026-10-14)

User: nothing should use LUKS anymore (only the 21 GB `slick` partition, nvme0n1p6, still does); Ventoy and ISOs are retired; SWARM OS and Debian are updated live, not by rebuilding ISOs.

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | — | SLICK: (was: remove LUKS from `nvme0n1p6` (21 GB, UUID 019a3cd8…). It backs Lucille's hidden `/lucy/unfiltered` mode (`LucyServer-go`), `70-scripts/unlock_slick.sh`, the ISO crypttab/fstab and `install_swarm_os.sh`; wiping would destroy whatever is on it; **User decided 2026-10-14: KEEP slick as it is (still LUKS, untouched).** | ✅ DECIDED — no action; the one LUKS exception |
| 2026-10-14 | v6.2.88 | — | LUKS-ALERT (`luks_lock_reminder.sh` and its unit) | ❌ REMOVED — LUKS retired |
| 2026-10-14 | v6.2.88 | — | Secure Boot + TPM auto-unlock of lucy-master | ❌ OBSOLETE — lucy-master LUKS no longer exists |
| 2026-10-14 | v6.2.88 | — | ISO-REBUILD, Ventoy retention/boot tests | ❌ OBSOLETE — live updates from SWARM and Debian replace ISOs. `build_swarm_iso.sh` and `ISO_RELEASE_POLICY.md` are left as-is, not yet retired. The Ventoy stick (sdc, 59 GB, 23 GB of ISOs) is still attached and untouched |
| 2026-10-14 | v6.2.88 | MEDIUM | `sync_lucille_ai.sh` sda4/LUKS leg now dead code; `swarm-snapshot`/Debian live-update path not yet defined | NEW |

### Project A — SWARM hardware key + login (2026-10-14, later)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | Old Ventoy stick (sdc, USB serial 3664251034070005592) → SWARM sudo key | 🟡 BUILT + TESTED, **NOT RUN** (needs your sudo). `sudo 70-scripts/provision_swarm_key.sh` (dry run, verified against the real stick), then `--apply`. Helper `swarm-key-sudo-auth` 15/15 tests; PAM line goes in SWARM's `/etc/pam.d/sudo` only; real proof = `sudo -k; sudo true` on SWARM with the stick in/out |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | Login: auto-login straight to the lock screen, usable with a controller and the key | 🟡 PARTIAL. Desktop already starts with no login prompt (`swarm-ui.service`); lock screen has arrow/A/Y keys and a `GamepadService` exists. **Not done:** show the new stick as a lock-screen key (its secret is on a raw partition the app can't read), confirm the pad really drives the lock screen on SWARM hardware. Web preview built for viewing |
| 2026-10-14 | v6.2.88 | HIGH | Lock screen accepts ANY file ≥6 chars named like a master key on any USB when no token is configured (`usb_master_key_service.dart` `_verifyContent`) | ⚠ FLAGGED, untouched |

### Project A — key provisioned, multi-key, root ownership (2026-10-14, evening)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | SWARM hardware sudo key #1 on the old Ventoy stick | ✅ DONE (user ran `--apply`): key `SWK-X54Z3-4UG4G-3KXA4-NJ272`, PAM line in SWARM `/etc/pam.d/sudo`, helper + registry installed. **Proof still pending:** boot SWARM, `sudo -k; sudo true` stick in/out |
| 2026-10-14 | v6.2.88 | **[HIGH]** | More keys: `provision_swarm_key.sh --device <by-id> --apply`, `--list`, `--revoke SERIAL`, `--list-sticks`; helper accepts ANY registered key (20 tests) | 🟡 BUILT, on branch. The installed helper/registry are still the first generation: run `sudo 70-scripts/provision_swarm_key.sh --upgrade` once (from main after merge) |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | SWARM root has hundreds of system paths owned by the normal user (uid 1000): `/`, `/etc`, `/etc/pam.d`, `/etc/sudoers.d`, `/usr/bin`, `/usr/lib`, `/boot`, `/opt` — anything running as that user can swap PAM/sudoers/binaries, defeating sudo AND the key. Root cause: installer `cp -a` keeps repo ownership | 🟡 `70-scripts/fix_swarm_root_ownership.sh` written (dry-run default, undo list, skips `/etc/swarm_os` + models); NOT run. Installer still needs a fix so new installs are root-owned |
| 2026-10-14 | v6.2.88 | **[HIGH]** | Backup keys on the external drives, usable only after biometric approval on a paired phone | ⏸ DESIGN — see conversation; reuses the existing phone HITL (`BiometricPrompt` in `HitlApprovalActivity`, lucille-core :9091). Needs decisions |

### Project A — backup keys with phone approval (2026-10-14, night; user said "touch lucille-core")

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | **[HIGH]** | `lucille-core` `request_approval` IPC command (the ONLY change; user: "touch lucille-core ... nothing else") | ✅ built + tested: 186 engine tests pass; `70-scripts/tests/e2e_request_approval.py` 7/7 with a stand-in phone (approve / reject / no phone / odd input / wrong token). Not yet deployed to SWARM; not tried with the real phone |
| 2026-10-14 | v6.2.88 | **[HIGH]** | Backup keys (one per external drive: Micron, T7): secret in unlocked `/mnt/slick/swarm-keys/`, tied to the drive's USB serial, armed with `swarm-backup-arm`, phone approves | ✅ BUILT + tested (helper 36 tests; provisioning proven in a sandbox incl. real Micron serial check). **Not provisioned**: `sudo unlock_slick.sh`, then `sudo 70-scripts/provision_swarm_key.sh --backup-key micron --drive /dev/disk/by-id/usb-Micron_CT2000X9SSD9_2523E8D92055-0:0 --apply` and `--backup-key t7 --drive /dev/disk/by-id/usb-Samsung_PSSD_T7_S5SXNJ0NB07155M-0:0 --apply` |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | Installed SWARM `lucille-core.service` has `User=swarm` but no `swarm` account exists → it cannot start, so no phone approvals on SWARM; installed `/usr/bin/lucille-core` is the old Oct-6 build without the new command | 🔴 FOUND, not fixed (needs: unit → `User=i30ltz` like the other units, new binary built on swarmbuild/A, `SWARM_AUTH_TOKEN` present, phone connected) |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | Run `sudo 70-scripts/fix_swarm_root_ownership.sh` (dry run first, review) — SWARM system dirs user-owned. Installers (`install_swarm_os.sh` ×2, `deploy_to_installed.sh`) now write root-owned | 🟡 installers fixed; SWARM itself NOT yet fixed |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | Login: auto-login to lock screen usable with controller + key | ⏸ NOT STARTED this pass (see earlier row) |

Weak spots to remember: approval = whoever holds `SWARM_AUTH_TOKEN` can answer for the phone, and the phone app also accepts the screen PIN, not only biometrics (phone app untouched).

### Project A — backup keys DROPPED, copy on slick instead (user, 2026-10-14)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | — | Phone-approved backup keys (Micron/T7), `swarm-backup-arm`, helper backup tier | ❌ REMOVED at the user's word ("forget the back up key"); rows above are history |
| 2026-10-14 | v6.2.88 | — | `lucille-core` `request_approval` IPC command | ❌ REVERTED — lucille-core is back to its original code (the earlier "touch" no longer applies) |
| 2026-10-14 | v6.2.88 | **[HIGH]** | Read-only copy of key #1's secret in unlocked slick: `sudo unlock_slick.sh`, then `sudo provision_swarm_key.sh --save-copy SWK-X54Z3-4UG4G-3KXA4-NJ272 --apply` (verifies it against the registered hash first; saves `/mnt/slick/swarm-keys/<serial>.secret`, root 0400 + immutable) | 🟡 BUILT + sandbox-tested; NOT run (needs the stick plugged in, slick unlocked, your sudo) |
| 2026-10-14 | v6.2.88 | MEDIUM | Rebuild a lost stick from the copy: `--device <by-id> --from-slick <serial> --apply` (same secret, new stick) | 🟡 BUILT, not exercised on a real stick |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | Installed SWARM `lucille-core.service` `User=swarm` (no such account) | ℹ no longer blocks key work (backup keys dropped); still a broken service on SWARM |

### Project A — login: controller + key on the lock screen (2026-10-14, night)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | Login = auto-start → splash → lock screen, usable with a controller and the key | 🟡 CODE DONE + TESTED, NOT DEPLOYED. Found: the controller only started AFTER unlock (in `swarm_shell.dart`), had no D-pad/stick, and its synthesized keys never reached the lock screen. Now: `pad_navigator.dart` (D-pad/left stick move, A select, B clear, Y shuffle, Start = use key), started by splash + lock screen; any pad button/key/click skips the 11 s splash. 111 frontend tests pass. Not run with a real controller |
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | The SWARM key on the lock screen | 🟡 CODE DONE + TESTED, NOT DEPLOYED: root service `swarm-key-status` (+ udev rule + unit) publishes `/run/swarm_key/status` (no secret); lock screen reads it, shows the key banner, Start/[UNLOCK] uses it. `provision_swarm_key.sh --upgrade` installs the pieces on SWARM |
| 2026-10-14 | v6.2.88 | **[HIGH]** | Deploy: new Flutter bundle to SWARM (build on swarmbuild/A, `70-scripts/deploy_to_installed.sh`) so the lock screen changes actually run there | ⏸ NOT DONE |
| 2026-10-14 | v6.2.88 | MEDIUM | Lock screen still accepts ANY key file ≥6 chars on any USB when no token is configured (`_verifyContent`); not changed | ⚠ FLAGGED |

### Project A — ownership dry run reviewed (2026-10-14, night)

| Date | Version | Priority | Task | Status |
|------|---------|----------|------|--------|
| 2026-10-14 | v6.2.88 | **[CRITICAL]** | `fix_swarm_root_ownership.sh` real dry run (user): 9,631 entries — etc 134, usr 27, boot 36, opt 9,433 (android-studio 4,923; swarm_os 4,530 of which two Flutter bundles ≈4,465). Plan: apply `--only etc,usr,boot` first; `/opt` later (its services run as the user; `GoogleWorkspaceService/google_tokens` is re-chowned to the user by its unit) | ⏸ waiting for the user to run `--apply` (new `--only` option on branch) |
| 2026-10-14 | v6.2.88 | — | `provision_swarm_key.sh --upgrade` (user ran): helper + status pieces installed, 1 key registered | ✅ DONE |

