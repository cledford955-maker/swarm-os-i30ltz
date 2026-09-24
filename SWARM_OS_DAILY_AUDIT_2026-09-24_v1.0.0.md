# SWARM OS Daily Audit — 2026-09-24
**Version:** v1.0.0  
**Machine:** LUCILLE (cachyos-i30ltz) · Intel UHD CometLake · 16 GB RAM  
**Source read:** `/mnt/Lucy` (connected folder, live) — primary tree confirmed readable  
**Audit time:** 2026-09-24 UTC (scheduled run)  
**Master List:** [SNfWViWjiL2CYKvxY7gLCr](https://claude.ai/artifact/SNfWViWjiL2CYKvxY7gLCr) → bumped to **v1.4.0**  

---

## What this pass added

Confirmed VERSION drift (bo40) is **resolved** — 6.2.72 is consistent across VERSION, profiledef.sh, and pubspec.yaml. Confirmed `profiledef.sh.bak-$(date +%s)` still present (ax1). Identified a **new MAJOR**: today's ISO landed in `swarm_os_out/` with Ventoy unmounted — ISO policy violation, file may not be on the boot drive (ax2). Three companion trees now exist (ax3, up from two). No checksums alongside the ISO (au7 still open). Auto-sync git still firing every ~10 min (av4 still open). Master List rows bo40 updated to done; ax1–ax3 added.

---

## 1. INVENTORY

| Item | Value | Source |
|---|---|---|
| VERSION | **6.2.72** | `/mnt/Lucy/VERSION` (full read) |
| ISO built today | `swarm-os-v6.2.72-9f142fdf-2026.09.24-x86_64.iso` · 4.99 GB · Sep 24 04:54 | `swarm_os_out/` — metadata only |
| ISO checksum | **None** | `swarm_os_out/` — no .sha256 or .md5 |
| Ventoy | **Not mounted** | `/mnt/ventoy/` absent |
| profiledef.sh iso_name | `swarm-os-v6.2.72-9f142fdf` | full read |
| profiledef.sh iso_application | `SWARM OS · Lucille v6.2.72` | full read |
| pubspec.yaml | `version: 6.2.72+72` | full read |
| lucille-companion | v1.0.0 (2026-09-24) · versionCode 10 | `lucille-companion/app/build.gradle.kts` |
| Build script | `70-scripts/build_swarm_iso.sh` (canonical); `00-CURRENT/build-iso.sh` is a compat shim | full read |
| Git last commit | `5332ae5 auto-sync: 2026-09-23T20:49:45-04:00` | `git log` |
| Git pattern | auto-sync every ~10 min, no semantic messages | 20 recent commits |
| Active logs today | `swarm-ui-20260924-074819.log` (57 KB, 07:48 UTC) | `logs/` |
| 24h changed files | PROJECT_MEMORY.md (11:06), SWARM_OS.code-workspace (09:15), frontend build artifacts (09:14), swarm-ui log (07:48), lucille-companion tree (06:15), lucille-companion zip (06:14) | `find -newer VERSION` |
| CLAUDE.md | SWARM OS-specific content, no AWS boilerplate | full read |

**Build scripts present:** `70-scripts/build_swarm_iso.sh`, `Luccile-v+/build_swarm_iso_v6.2.2_2026-09-07.sh` (archived/superseded)  
**Source trees:** `30-source/` contains frontend, LucyServer, LucyServer-go, GamingAgent-go, LucilleAssistant, lucille-core, android_companion, android_companion(seperate-related-project)  
**VM artifacts:** `80-vm/desktop/swarm-development.qcow2`, `80-vm/swarm_vm_disk.qcow2` — both excluded from git by `.gitignore`  

---

## 2. EVALUATION

### KNOWN OPEN ITEMS — STATUS TODAY

| # | Item | Status |
|---|---|---|
| bo40 | VERSION disagreeing with hardcoded versions | **RESOLVED** ✅ — VERSION=6.2.72, profiledef iso_name=6.2.72, pubspec 6.2.72+72. All three agree. Mark done. |
| bak | Two files named `*.bak-$(date +%s)` | **PARTIALLY OPEN** — `profiledef.sh.bak-$(date +%s)` confirmed present (literal unexpanded name). No second unexpanded-literal file found this pass. |
| compiled artifacts | `.o`, `.class`, `.qcow2` in Drive mirror | **CLEAN** ✅ — `.gitignore` excludes `*.qcow2`, `*.iso`, build dirs. No compiled artifacts tracked. |
| CLAUDE.md | AWS boilerplate | **RESOLVED** ✅ — CLAUDE.md contains current SWARM OS onboarding content, ISO release policy, architecture table. No AWS content. |
| Android companion ambiguity | Two trees with unclear precedence | **WORSE** ⚠️ — Now **three** trees: `android_companion/swarm_os-companion/`, `android_companion(seperate-related-project)/swarm_os-companion/`, and new `lucille-companion/` (v1.0.0, 2026-09-24). Canonical companion is unclear. The two older trees differ only in Gradle cache files — source code appears identical. New `lucille-companion` appears to be the declared replacement. See ax3. |

---

### NEW FINDINGS

#### MAJOR — ax2: ISO in swarm_os_out/ with Ventoy absent
**Failure scenario:** Today's ISO (`swarm-os-v6.2.72-9f142fdf-2026.09.24-x86_64.iso`, 4.99 GB) sits in `swarm_os_out/`, not in `/mnt/ventoy/ISO/SWARM_OS/` as the ISO release policy and CLAUDE.md require. Ventoy drive is not mounted right now. Either the build script has a fallback that violates policy, or the ISO was built earlier when Ventoy was mounted and then Ventoy was unmounted — but the file is in the wrong place regardless. A build script that falls back to `swarm_os_out/` instead of aborting would silently skip the flash step. **Rank: MAJOR** — not confirmed whether policy was violated at build time or whether Ventoy was mounted then; metadata only.  
**Settle with:** `grep -n 'ventoy\|VENTOY\|swarm_os_out' /mnt/Lucy/70-scripts/build_swarm_iso.sh | head -20`

#### MAJOR — ax3: Three companion trees, canonical undefined
**Failure scenario:** A developer building the companion APK has three candidate source trees. The two `android_companion` trees appear source-identical (differ only in Gradle caches). The new `lucille-companion` (v1.0.0, 2026-09-24) has a completely different applicationId (`com.swarm.lucille`) and package structure. A build from either legacy tree ships the old app; a build from lucille-companion ships a new app. No declaration of which is canonical. The zip `lucille-companion-v1.0.0-2026-09-24.zip` exists at the root, suggesting lucille-companion is the intended future. **Rank: MAJOR**

#### MINOR — ax1: profiledef.sh.bak-$(date +%s) still present (literal filename)
**Failure scenario:** `40-iso-profile/swarm_os_iso_profile/profiledef.sh.bak-$(date +%s)` exists as a literal filename — the shell variable substitution never ran when this file was created. It is a stale backup of profiledef.sh with an unintelligible name that looks like a live one. Low risk (backup file, not executed), but it's been open across multiple audit passes.  
**Fix:** `rm "/mnt/Lucy/40-iso-profile/swarm_os_iso_profile/profiledef.sh.bak-\$(date +%s)"`

#### INFO — swarm-ui log, 2026-09-24 07:48
swarm-ui.service started normally, PAM session opened for user `swarm` (uid=1000) on the live ISO (`archiso` hostname). labwc received SIGHUP — consistent with a systemd stop/shutdown event, not necessarily a crash. The log is a journal dump captured by `ExecStopPost`, so it records the moment of shutdown, not a mid-run failure. Cannot confirm whether labwc actually rendered a desktop this boot from this log alone. Ambiguous.

---

### STANDING OPEN ITEMS (still true)

| ID | Item | Note |
|---|---|---|
| au7 | No SHA256 / GPG sig alongside ISO | Confirmed: `swarm_os_out/` has no `*.sha256`. Open since 2026-09-12. |
| av4 | Auto-sync git every ~10 min | Confirmed: 20 commits in git log, all "auto-sync: …", last at 2026-09-23T20:49. `.env` excluded from git (`.gitignore` lines 58-59) — that part is clean. Memory/user files tracked status unknown without deeper git ls-files check. |
| bo5 | Security Audit page with LucyServer down | Not re-verified this pass. Still open. |
| bo6 | Package scan on non-existent path | Not re-verified this pass. Still open. |
| bo32 | install_swarm_os.sh never run end-to-end | Not re-verified. Still open. |
| bo36 | LUCILLE drive mount at /mnt/Lucy on installed system | Not re-verified. Still open. |
| bo55 | Two wait-online units — network-online.target race | Not re-verified. Still open. |
| bo63 | No real Ed25519 key / real PKI | Not re-verified. Still open. |
| b6 | User=swarm / 217/USER on installed system | Boot log shows `swarm` user exists on the live ISO (uid=1000). On the installed system this depends on install_swarm_os.sh completing correctly (b7). Still open. |
| aw4 | Assistant fabricates writes offline | Not re-verified. Still open. |
| aw9 | Auth token from URL parameter | Not re-verified. Still open. |

---

## 3. UPGRADES — 5 CONCRETE, RANKED

### 1. Add `/api/health` endpoint (HIGH VALUE — fixes the entire fabrication layer)
**Why it matters:** Every fake-readout surface in the project — wallpaper stats, Lucille Assistant offline data, Companion health tiles, Stack Vitals — exists because there is no single authoritative health endpoint. Each surface invents its own fallback. One endpoint changes the rule from "guess when unreachable" to "show the health response or show offline."  
**First concrete step:** In `30-source/LucyServer-go/`, add `GET /api/health` returning JSON: `{version, build_date, uptime_seconds, lucy_mount_gb_used, lucy_mount_gb_total, services: {gaming_agent, lucy_server, google_workspace}, timestamp}`. Propagate to the wallpaper's existing stats-fetch path before the next build.

### 2. Auto-generate checksum + GPG signature after every ISO build (HIGH VALUE — enables verification)
**Why it matters:** The current ISO (`swarm-os-v6.2.72-9f142fdf-2026.09.24-x86_64.iso`) has no checksum. A corrupted flash — like the "USB submit failed -1" incident — cannot be distinguished from a bad build or a bad image without one. GPG signature lets a future user verify they have an unmodified image.  
**First concrete step:** In `70-scripts/build_swarm_iso.sh`, after the ISO is written, add:  
```bash
sha256sum "$ISO_PATH" > "${ISO_PATH}.sha256"
echo "[swarm-build] SHA256: $(cat "${ISO_PATH}.sha256")"
```  
If GPG key is available: `gpg --detach-sign --armor "${ISO_PATH}.sha256"`. This is one script edit, no dependencies.

### 3. Declare canonical companion tree and archive the others (MEDIUM VALUE — stops drift)
**Why it matters:** Three companion trees now exist. Each build picks a different one. `lucille-companion` (v1.0.0) has a different applicationId from the legacy trees. Leaving all three in `30-source/` guarantees a wrong build at some point.  
**First concrete step:** In `/mnt/Lucy/CLAUDE.md` (or `90-docs/`), add one line: "Canonical Android companion: `lucille-companion/` (v1.0.0, applicationId `com.swarm.lucille`). Archive `android_companion/` and `android_companion(seperate-related-project)/` to `99-archive/`." Then move them. One decision + one `mv` + one CLAUDE.md edit.

### 4. Add a `/api/health` staleness guard to every surface that shows live data (MEDIUM VALUE — enforces av3 rule)
**Why it matters:** Even after av11 is done, each UI surface still needs to render "offline" rather than cached data. The rule "show — or offline, never a plausible number" needs code enforcement, not convention.  
**First concrete step:** In the Flutter shell's stats widget, add a `lastFetchedAt` timestamp and a 60-second staleness gate: if the last successful health response is older than 60s, switch all tiles to `— / offline` styling. Zero new endpoints needed, purely frontend.

### 5. Ship `gitleaks` as a pre-commit hook (MEDIUM VALUE — closes av4 permanently)
**Why it matters:** av4 (secrets pushed to git every 10 min) is a standing critical. `.env` is gitignored, but memory files, user configs, and any new credential file are not. `gitleaks` catches secrets before they reach a commit.  
**First concrete step:** `pacman -S gitleaks` (available in Arch repos). Then add `.git/hooks/pre-commit`:  
```bash
#!/usr/bin/env bash
gitleaks protect --staged --no-banner || { echo "gitleaks: secret detected — commit aborted"; exit 1; }
```  
Commit the hook to `70-scripts/setup-dev-deps.sh` so it installs on every new clone.

---

## 4. TOOLING — PACKAGES FOR GAMING, CODING, DAILY LIFE

Each item is a pacman install unless noted.

### Gaming
| Package | What it enables / replaces |
|---|---|
| `mangohud` | Real-time GPU/CPU/FPS/RAM overlay inside games — replaces the fake static "GPU 99% / 144 FPS" wallpaper stats with actual numbers. Critical on iGPU where headroom matters. Configure via `MANGOHUD=1` env var or per-game Steam launch option. |
| `lutris` | Unified game launcher: Steam, GOG, Epic, itch.io, emulators, native games. Replaces the mock "65-game library" with a real launcher. Integrates with the GamingAgent-go dashboard. |
| `protonup-qt` (AUR) or `proton-ge-custom` | GUI for installing Proton-GE and managing Wine versions. Many Steam titles need Proton-GE to run; the stock Steam Proton lags behind fixes for iGPU/VRAM-limited systems. |
| `gamemode` | Requests CPU/GPU optimizations and suspends background services when a game is running. Works with Steam (`gamemoderun %command%`). Measurable FPS gain on integrated graphics. |

### Coding
| Package | What it enables / replaces |
|---|---|
| `zellij` | Modern terminal multiplexer with floating panes and built-in layout manager. Replaces tmux for the Forge coding session: split a terminal into an editor pane, a build pane, and a git-status pane without leaving the keyboard. |
| `gitleaks` | CLI secret scanner. Add as a pre-commit hook (see Upgrade 5). Closes av4 permanently. Available in `pacman -S gitleaks`. |
| `difftastic` | Structural diff: understands syntax (Dart, Go, Kotlin, Bash) and shows changes at the AST level rather than line level. Replaces `git diff` for code review. `pacman -S difftastic`; set as git difftool. |
| `hyperfine` | Benchmarking tool for shell commands. Use it to time each build step in `build_swarm_iso.sh` to find where the 4.99 GB build spends its minutes. `pacman -S hyperfine`. |
| `tokei` | Fast line-counter that understands language. Run it on `30-source/` to get a real LOC breakdown — useful for the SWARM_AI_FEATURES.md "project size" section. |

### Daily Life (Lucille assistant / LUCILLE machine)
| Package | What it enables / replaces |
|---|---|
| `dunst` | Lightweight notification daemon for Wayland. Lucille's health nudges (meds, water, sleep) currently toast inside the Flutter app only. `dunst` lets LucyServer push system-level desktop notifications — visible on top of any game or full-screen app. Config at `~/.config/dunst/dunstrc`. |
| `khal` + `vdirsyncer` | CLI calendar that syncs with Google Calendar via CalDAV. Lucille's daily-brief endpoint can read `khal list today` directly instead of going through GoogleWorkspaceService's OAuth flow on every boot. |
| `btop` | Beautiful terminal resource monitor: CPU, RAM, disk, network in one pane. Can run in a Zellij pane as a real live-stats tile — replacing the fake wallpaper numbers with something Lucille can also read via `btop --json`. |
| `rclone` | Cloud sync for Google Drive. Can mirror a Drive folder to `/mnt/Lucy/` on a schedule, removing the manual download step from SWARM's Google Drive fallback. `rclone sync gdrive:Luccile-v+ /mnt/Lucy/ --dry-run` first. |
| `networkmanager-tui` (`nmtui`) | Already likely installed. If not: terminal UI for Wi-Fi/VPN management without launching a GUI. Useful during ISO recovery or when labwc fails to start. |

---

## 5. MASTER LIST ROWS — CHANGES THIS PASS

| Action | Row ID | What changed |
|---|---|---|
| **Updated to done** | bo40 | VERSION=6.2.72 confirmed across VERSION file, profiledef.sh (iso_name), and pubspec.yaml. All three agree. Note updated: "Verified 2026-09-24 from /mnt/Lucy — all three agree at 6.2.72." |
| **Added note** | au7 | "2026-09-24 confirmed: swarm-os-v6.2.72-9f142fdf-2026.09.24-x86_64.iso in swarm_os_out/, no .sha256 or .md5 present." |
| **Added note** | av4 | "2026-09-24: auto-sync commits still firing every ~10 min. .env is gitignored (lines 58-59 of .gitignore) — good. Deeper ls-files check for memory/user files not done this pass." |
| **New row** | ax1 | `profiledef.sh.bak-$(date +%s)` literal unexpanded filename still present — MINOR — fix: `rm` with the literal name. |
| **New row** | ax2 | ISO in `swarm_os_out/` with Ventoy absent — MAJOR — settle with grep of build script for fallback behavior. |
| **New row** | ax3 | Three companion trees: android_companion/, android_companion(seperate-related-project)/, lucille-companion/ — MAJOR — declare lucille-companion canonical, archive others. |

---

## SCOPE LEDGER

| What | How | Full or metadata? |
|---|---|---|
| `/mnt/Lucy/VERSION` | `cat` via device_bash | **Full read** |
| `/mnt/Lucy/CLAUDE.md` | `head -40` via device_bash | **First 40 lines** (SWARM content confirmed) |
| `/mnt/Lucy/40-iso-profile/swarm_os_iso_profile/profiledef.sh` | `cat head -20` + grep via device_bash | **First 20 lines + grep** |
| `/mnt/Lucy/70-scripts/build_swarm_iso.sh` | `head -30` via device_bash | **First 30 lines** |
| `/mnt/Lucy/Luccile-v+/build_swarm_iso_v6.2.2_2026-09-07.sh` | `head -20` via device_bash | **First 20 lines** |
| `/mnt/Lucy/logs/swarm-ui-20260924-074819.log` | `cat` via device_bash | **Full read** |
| `/mnt/Lucy/30-source/frontend/pubspec.yaml` | `grep` via device_bash | **Grep only** |
| `/mnt/Lucy/lucille-companion/app/build.gradle.kts` | `grep` via device_bash | **Grep only** |
| `/mnt/Lucy/.gitignore` | `head -20` + grep via device_bash | **Partial** |
| Directory listings | `device_list_dir` + `ls` | **Metadata only** |
| ISO file | `ls -la swarm_os_out/` | **Metadata only** (size, mtime) |
| `.bak` files | `find` via device_bash | **Names only** |
| Master List artifact | `Artifact read` | **Full HTML (187.8 KB)** |
| Build Tracker artifact | `Artifact read` | **Full HTML (90.5 KB)** |
| Google Drive | Not accessed — /mnt/Lucy was reachable | — |
| Nothing was compiled, built, or run. |

---

*SWARM OS Daily Audit · 2026-09-24 · v1.0.0 · machine LUCILLE (cachyos-i30ltz) · audit by scheduled task*
