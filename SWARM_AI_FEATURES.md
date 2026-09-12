# SWARM OS — Living Feature Tracker

> **EVERY AI THAT TOUCHES THIS PROJECT MUST READ AND UPDATE THIS FILE.**
> When you add a feature, mark it done here and add any new ideas you think of.
> When you remove or refactor something, update the relevant entry.
> This is the single source of truth for what exists, what's broken, and what's next.
> Humans: same rule. If you think of something, add it to IDEAS below.

---

## ⚠️ ARCHITECTURE PIVOT (2026-09-11) — READ THIS BEFORE TOUCHING THE UI

**The Slint kiosk direction (tasks #1–9 below) is SUPERSEDED. Do not extend it as a kiosk.**

What happened: the Slint UI was built using `backend-linuxkms` — direct DRM/KMS rendering,
no compositor, ONE app owns the whole screen. This was the wrong call. The user's actual
vision, stated directly and confirmed: **a real desktop** — Lucille's panel plus real
windowed apps (Chrome, Antigravity, Claude desktop, agent windows) running together,
switchable, with desktop icons that snap to a hexagon/"wasp nest" grid and are draggable.
This requires an actual window manager. `backend-linuxkms` architecturally cannot do this —
there is no compositor for a second app to draw into.

**Hard constraints driving every decision here (do not lose these):**
- Integrated graphics, limited RAM. **No Electron/Chromium-based shell** — the user has
  explicitly, repeatedly rejected a browser/web-shell approach (a prior Gemini session
  pushed them toward one against direct instructions; do not repeat that mistake).
- Wants to run local LLM models on this hardware — every layer of the shell competes with
  that RAM/compute budget. Favor native, lightweight, compiled tools over anything web-based.
- Wants CachyOS-like: Arch-based, performance-tuned, lean — not a heavy DE (no GNOME/KDE).
- "Mobility" (working from other devices via Tailscale/web) is a REMOTE-ACCESS feature
  layered on top (e.g. WayVNC, the existing device-mirror stub in LucyServer), NOT a reason
  to build the local UI as a web app. Keep these two concerns separate.

**Corrected direction:**
- Compositor: **labwc** (wlroots-based, floating-window, lightest of the realistic options —
  Sway is tiling-first which fights "draggable icons", Hyprland is heavier/animation-focused).
  Swappable later if it's wrong — this is a package + config choice, not a rewrite.
- Slint UI: switch from `backend-linuxkms` to `backend-winit` (Wayland client mode) — Lucille
  keeps her exact current look, becomes one ordinary window among others instead of owning
  the whole screen. Most of tasks #1–5's actual UI code is reusable as-is.
- New work: a desktop-shell layer — hexagon-tessellation wallpaper, icon grid that snaps to
  hex positions, draggable/replaceable icons, launches real apps as separate windows.
- `GamingAgent-go` and `LucyServer-go` (tasks #10–16) are UNAFFECTED — pure HTTP APIs,
  frontend-agnostic. Nothing there needs to change because of this pivot.
- Reference material found on `i30ltz-brains` partition (`/run/media/i30ltz/i30ltz-brains/`,
  mount it with `udisksctl mount -b /dev/nvme0n1p5` if not mounted): `BoltMatrixAI_UI` is a
  React/web prototype of a similar windowed-desktop idea — useful for UX/feature reference
  (window list, taskbar layout, persona concept) but explicitly NOT to be used as the actual
  implementation (it's the web-shell approach the user rejected). Don't copy its stack, only
  its ideas. There is also a `lucy-master` reference drive (`/dev/sda4`, LUKS-encrypted, not
  currently unlocked) that may have more prior design work — ask the user to unlock it
  (`sudo cryptsetup open /dev/sda4 lucy_master`) if more context is ever needed; never attempt
  to unlock it yourself or ask for the passphrase in chat.

---

## How to update this file

- Move items from **IDEAS** → **IN PROGRESS** when you start them
- Move items from **IN PROGRESS** → **DONE** when they're wired end-to-end and tested
- Add new ideas to **IDEAS** as you discover them — don't lose them
- If something is broken or partially done, note it inline with `[BROKEN]` or `[PARTIAL]`
- Keep entries short — one line each, with the file(s) affected in parentheses

---

## DONE ✓

### ISO Build System
- [x] Auto-version bump on every build (patch++) (`70-scripts/build_swarm_iso_*.sh`, `40-iso-profile/swarm_os_iso_profile/profiledef.sh`)
- [x] Version stamped across Flutter pubspec, top_bar.dart, profiledef.sh, companion gradle — **will migrate to Cargo.toml when Slint rewrite lands**
- [x] GamingAgent compiled and staged into ISO at `/opt/swarm_os/GamingAgent/` (step 4b2 in build script)
- [x] LucyServer staged at `/opt/swarm_os/LucyServer/`
- [x] Flutter Linux shell staged at `/opt/swarm_os/swarm_flutter/` — desktop shell, still active
- [x] swarm-slint Lucille panel staged at `/opt/swarm_os/swarm-slint/` — companion panel, runs alongside Flutter under labwc
- [x] lucille-core C++ binary staged at `/usr/bin/lucille-core`
- [x] `.env` baked into `airootfs/etc/swarm_os.env` (line-continuation stripped for `set -a`)
- [x] `deploy_swarm_os_foundation.sh` auto-detects correct AIROOTFS path (30-source vs 40-iso-profile)
- [x] LUCILLE drive (UUID `62f0e009-43c2-4760-8d6c-d7c445f5f3df`) baked into `airootfs/etc/fstab` → `/mnt/Lucy` with `nofail` (live ISO mounts it automatically)
- [x] Install script adds Lucy entry to installed system fstab — guarded, no duplicate on reinstall (`30-source/install_swarm_os.sh`)
- [x] `profiledef.sh` cleaned — no more `/mnt/Lucy` file_permissions causing mkarchiso rejection
- [x] `gaming-agent.service` systemd unit created and symlinked into multi-user.target.wants
- [x] GRUB theme: SWARM branded splash — files in `airootfs/boot/grub/themes/swarm_os/`
- [x] Auto-login to swarm user on first boot — `getty@tty1.service.d/autologin.conf` in airootfs
- [x] Install script — auto-detects target disk via `lsblk`, derives partitions, confirms before touching anything (`30-source/install_swarm_os.sh`)
- [x] Btrfs subvolumes — installer creates `@`, `@home`, `@snapshots` with `noatime,compress=zstd` mounts; GRUB gets `rootflags=subvol=@`

### GamingAgent (fully migrated .NET → Go, tasks #10–14 all complete — runs from `GamingAgent-go/`)
- [x] `GET /api/gfn/catalog` — full NVIDIA GFN catalog (12h cache)
- [x] `GET /api/steam/library` — user's full Steam library via API key
- [x] `GET /api/games/intersection` — Steam ∩ GFN with enrichment (playtime, images, genres, favorites)
- [x] `GET /api/games/genres` — genre list from GFN catalog
- [x] `GET /api/games/prices/{appId}` — CheapShark cross-store prices
- [x] `POST /api/games/favorite` — set favorite/pin state in SQLite at `/etc/swarm_os/gaming.db`
- [x] `GET /health`
- [x] CORS open for dashboard
- [x] GFN catalog warmed on startup
- [x] `GET /api/lucille/eval` — real Nemotron AI analysis of play patterns → dashboard actions + system suggestions
- [x] `POST /api/lucille/chat` — multi-turn non-streaming chat, injects Steam/GFN context
- [x] `POST /api/lucille/chat/stream` — SSE streaming chat; Nemotron chunks forwarded word-by-word
- [x] `GET /api/lucille/history?sessionId=&limit=` — chat history from SQLite
- [x] `chat_history` SQLite table — persists user + Lucille turns per sessionId

### Gaming Dashboard (Artifact — stays as-is, connects to GamingAgent API regardless of language)
- [x] Dark gaming UI (Rajdhani + Inter, NVIDIA green #76b900 accent)
- [x] Three tabs: GFN Games / My Library / ❤ Favorites
- [x] GFN tab: genre chips, daily shuffle, pinned rail, On Sale Now rail, deal modal
- [x] Library tab: compact card grid (~65 demo games / full Steam in LIVE mode), ♥ to favorite
- [x] Favorites tab: all hearted games, compact grid
- [x] Deal modal: CheapShark prices per store, click → cheapshark redirect
- [x] Favorites persist in localStorage + sync to GamingAgent SQLite
- [x] LIVE/DEMO mode indicator
- [x] Lucille button → calls `/api/lucille/eval` (Nemotron) → real AI suggestions → mutates dashboard state
- [x] Lucille tools: `set_genre_filter`, `pin_games`, `set_sort_order`, `favorite_games`
- [x] Lucille reset button restores pre-Lucille state
- [x] Action badges show in real-time as Nemotron tools fire
- [x] System suggestions panel below Lucille response (SWARM OS improvement ideas from Nemotron)
- [x] Stats bar: On GFN count / Library count / Favorites count / On Sale count

### Android Companion App
- [x] **Monitor tab: device selector** — chips for "This Phone" + all Tailscale/fleet devices; per-device CPU/RAM/storage/battery/ping telemetry (`SystemMonitorScreen.kt`)
- [x] **Monitor tab: per-device actions** — Optimize, Malware Scan, Process Killer with live kill (non-system processes only) per chosen device (`SystemMonitorScreen.kt`)
- [x] **Monitor tab: Pooled Fleet Resources** — bottom card aggregates avg CPU, avg RAM, online count, total fleet storage across all devices (`SystemMonitorScreen.kt`)
- [x] **Dr. Boltz avatar screen: phone body diagram** — Canvas-drawn phone silhouette with animated RAM/Storage/Battery bars inside screen, percentages, buttons, glow (`DrI3oltzFullAvatarScreen.kt`)
- [x] **Dr. Boltz avatar screen: device selector + telemetry** — same per-device picker and mini-tiles (CPU/RAM/Battery/Ping/Processes) + Optimize + Malware Scan + Process Killer (`DrI3oltzFullAvatarScreen.kt`)
- [x] **IDE back-navigation fix** — `BackHandler` in CoderDroidScreen: back closes terminal first, then sidebar, then goes to Dashboard (`CoderDroidScreen.kt`)
- [x] `ViewModel.runMalwareScanOnDevice(Long)` — per-device malware scan with Dr. Boltz speech update
- [x] `ViewModel.optimizeSingleDevice(-1L)` — routes phone optimize to existing supercharger
- [x] **`SwarmConnection.kt` actually created and wired (2026-09-12)** — the 2026-09-07 `COMPANION-SETUP.md` doc claimed this was already done, but it wasn't: `RemotePcScreen.kt`/`InteractiveTerminalScreen.kt` were byte-identical to their archived `_pre-config.kt` originals, and `SwarmConnection.kt` didn't exist anywhere in the tree. Created `data/config/SwarmConnection.kt` (SharedPreferences-backed host/port/token) and wired it into `RemotePcScreen.kt` (real SAVE button + auth-token field + unusable-connection warning, replacing the fake "SET" button that never persisted anything), `InteractiveTerminalScreen.kt`, `AppRepository.kt` (also fixed: its `/api/run_command` call sent **zero auth header**, so the phone-to-PC antivirus bridge had been silently 401'ing) and `MainViewModel.kt`. Verified with a real `./gradlew assembleDebug` — **BUILD SUCCESSFUL** (prior session couldn't check this at all: no Android SDK/Gradle reachable). Also confirmed `LucyServer-go` builds clean (`go build`).
- [x] **Cross-origin RCE closed on both Go servers (2026-09-12)** — `swarmAuthMiddleware` treats every loopback connection as authenticated, and **a browser's request to `127.0.0.1` is a loopback connection**. Combined with `AllowedOrigins: ["*"]`, any web page the user happened to be visiting could POST to `127.0.0.1:5000/api/run_command` and get arbitrary shell execution. CORS could not prevent it — CORS only decides whether the attacking page may *read* the response, never whether the server executes the request.
  - **The WebSocket path was worse**: `/api/terminal/ws` attaches a live shell, and browser WebSocket connections are not subject to CORS at all, so `new WebSocket("ws://127.0.0.1:5000/api/terminal/ws")` from a hostile page bypassed the CORS config entirely. An `Origin` check is the only defence, which is why the gate runs on **every** path — `/lucy` and `/webauthn/*` sit outside `/api/` and are equally browser-reachable.
  - **Fix**: new `originGate` middleware runs *before* `swarmAuthMiddleware` and rejects any request carrying a browser `Origin` that isn't allowlisted. Native clients (Flutter's `dart:io`, the companion's OkHttp, curl) send no `Origin` and are unaffected; browsers always send one on cross-origin requests and WebSocket handshakes, so the hostile case is exactly the case caught. CORS also tightened to an explicit allowlist with named headers. Allowlist overridable via `SWARM_ALLOWED_ORIGINS`.
  - **Why the loopback bypass was kept**: the entire Flutter shell — including `cyber_stone_lock_screen.dart`'s `verify_login_password` call — sends no token and depends on it. Removing it outright would have broken the unlock path. Making the shell authenticate is tracked as follow-up.
  - **GamingAgent-go** had the identical pattern on 8401 (quota burn via `/lucille/eval`, history leak via `/lucille/history`). Gated the protected group only; read-only catalog routes stay open by design, and `https://claude.ai` is allowlisted so the dashboard artifact keeps working. **If the dashboard's Lucille panels 403, the artifact is rendering from a different origin — add it to `SWARM_ALLOWED_ORIGINS`, don't restore the wildcard.**
  - **Verified by running both servers and replaying the attack**: hostile-origin POST to `run_command` → 403; hostile WebSocket handshake → 403; hostile origin *with a valid token* → 403 (gate wins); native client with no `Origin` → 200 (bypass intact); allowlisted origin → 200; hostile preflight → 204 with **no** `Access-Control-Allow-Origin`, so the browser blocks the real request too. Both servers `go build` + `go vet` clean.
- [x] **Mock/fake-data purge across all three apps (2026-09-12)** — audited Flutter shell (163 dart files), Kotlin companion, both Go servers and the Rust panel for fabricated data. swarm-slint came back clean. Everything below was code that presented invented values to the user as if measured:
  - **Trust bypass (critical)** — `package_signing_service.dart` granted `verifiedOfficial` in **two** places (`SignedPackage.fromJson` and `verifyPackage`) based on attacker-controlled strings inside the package: any bundle declaring `publisher: "swarm.io"` displayed as officially verified with zero cryptography. Both now fail closed; trust requires recomputing the MAC against a known key. Same class of bug as the 2026-09-11 lock-screen corner-tap bypass.
  - **Fake signing** — the "signature" was `sha256(digest::privateKeyHex)` labelled `ED25519-SIG-`. Now a real `Hmac(sha256)` labelled honestly, with constant-time comparison and real tamper detection. Legacy `ED25519-SIG-` bundles now report `invalidSignature`. True Ed25519 publisher identity still needs a crypto dep (`crypto` has none) — tracked.
  - **Publisher portal** picked a keystore then hashed only its **path**, so the key material never affected the output; now keys a real HMAC off the keystore bytes and refuses to sign with no key.
  - **`advanced_ecosystem_service.dart`** — 14 swallowed catches in 359 lines, every one returning invented success: a malware scan verdict of `CLEAN` claiming "signature verified against trusted developer authority" when the scanner was unreachable, an audit-log entry asserting a privilege elevation that never happened, "Root Authority" developers, `$4580.50` revenue, fake cloud hosts, and `syncCloudWorkspace` returning `true` from its exception handler. Rewritten to throw `EcosystemUnavailable`; all 5 consumer pages gained real error/retry states (they previously had no try/catch at all).
  - **Coin-flip malware scan** — `MainViewModel.runMalwareScanOnDevice` slept 1.8s then decided infected-or-clean with `(1..10).random() > 2`. Now calls the real `runAntivirusScan()`.
  - **Invented optimisation numbers** — `performSuperchargeOptimization()` returned `(180..420).random()` MB "RAM freed" and `(350..1200).random()` MB "junk cleaned" behind a bare `System.gc()`. Now measures real `availMem` deltas across real `killBackgroundProcesses` calls and reports real bytes reclaimed from real cache dirs. `optimizeSingleDevice` fabricated 340MB/820MB and claimed it "verified firewall rules" for a device it never contacted — now polls `/api/system/stats` and reports what came back, or returns null. Added `getDeviceById` to the DAO for this.
  - **Fake device telemetry** — `DeviceSyncEntity` *defaults* were cpu 24% / ram 42% / 128GB / 12ms, so unpolled devices were indistinguishable from real ones; now 0 = not measured. The Tailscale seed no longer ships invented load figures or an unearned "Connected & Secure".
  - **Go: always-CLEAN scanner** — `SecurityScanPackage` returned `ThreatScore 15` + `CLEAN (Developer Tools Package)` unconditionally with a fixed list of permissions it never looked for, and for a **non-existent path** invented a 4MB size plus the SHA-256 of the empty string and still said CLEAN. Now: missing/unreadable file is an explicit `NOT SCANNED` verdict, real hash/size, permissions actually found in the bytes, derived score, and wording that says it's a permission-surface audit rather than implying an AV database.
  - **Go: fake marketplace + financials** — seeded templates with invented download counts (4820/3150/6210) and ratings, reviews from invented users, and two `BillingRecord`s marked `PaymentStatus: "Settled"` with fake license keys and payouts — which `/api/marketplace/analytics` summed into fake revenue. Store now starts empty. `MarketplaceGetReviews` also returned *other* extensions' reviews when one had none; removed.
  - **Go: fake PKI + crash + analytics** — removed two `IsVerified` "Root Authority"/"Enterprise Gold" developers with literal-string fingerprints, and a seeded crash citing `/src/compositor.c:412` (a file that doesn't exist here). `AppAnalytics` no longer returns hardcoded 2150 DAU / 12400 MAU / 99.85%. The audit log's SHA-256 hash chaining is genuinely real and was kept.
  - **Fake sandbox** — `runExtensionLifecycle` slept 60ms and logged "completed cleanly" without executing anything; now says hooks are skipped because no sandboxed runtime host exists.
  - **Fake per-core CPU** — `telemetry_page.dart` synthesised per-core load with a jitter formula off core index and wall-clock seconds, and derived overall CPU from loadavg (a run-queue length, not utilisation). Both now come from real `/proc/stat` jiffy deltas. RAM/ZRAM there were already real.
  - **Coder Droid IDE terminal** was a placeholder printing "coming soon"; now a live shell over `/api/terminal/ws` using `SwarmConnection`.
  - Verified: `flutter analyze` **0 errors**, 58 warnings (29 unique — `swarm_flutter/lib` is a symlink to `lib`, so every count doubles) all pre-existing and none in the changed files; `gradlew assembleDebug` BUILD SUCCESSFUL; `go build ./...` + `go vet ./...` clean on both LucyServer-go and GamingAgent-go.
- [x] **Syncthing was broken, not just unconfigured (2026-09-12)** — daemon wasn't even running; its config still pointed both folders at `/run/media/i30ltz/LUCILLE/...`, a mount that no longer exists now that LUCILLE lives at `/mnt/Lucy`. Repointed both folder paths, recreated the `.stfolder` marker for `SWARM_OS` (lost when the mount moved), and enabled+started the service. Found the `30-source/.stignore` (the Coder Droid workspace ignore file — the one the setup doc says cuts 1.25GB→40MB) **didn't exist at all** at the current path; created it, then found it still missed `swarm-slint/target` (11GB of Rust build artifacts) and `flutter-sdk` (1.6GB) — added both. Folder now syncs clean: idle, no errors, ~75MB / 553 files.

---

## DONE ✓ (continued)

### swarm-slint + labwc Wayland pivot (tasks #1–9, superseded and corrected in same phase)
The kiosk/linuxkms direction (tasks #1–9) produced all the real UI code — gaming, chat, monitor views, GamingAgent wiring, SSE streaming, process kill — but was built on `backend-linuxkms` which cannot support multiple windows. The pivot to labwc+winit happened in the same phase. **All UI code is reused as-is; only the backend and kiosk-specific window flags changed.**

Architecture (final — dual Wayland clients under labwc):
- `swarm-ui.service` — starts labwc; `~/.config/labwc/autostart` launches BOTH apps
- **Flutter shell** (`30-source/frontend/`, 161 files) — full desktop: wasp wallpaper, floating window manager, app drawer, settings drawer, voice HUD, overlays. Staged to `/opt/swarm_os/swarm_flutter/`. Maximized, no compositor decoration.
- **swarm-slint Lucille panel** (`30-source/swarm-slint/`, Rust + Slint `backend-winit`) — gaming dashboard, AI chat, system monitor. Staged to `/opt/swarm_os/swarm-slint/`. Floating companion window, no compositor decoration.
- `packages.x86_64` — labwc, wayland, wayland-protocols, egl-wayland, xorg-xwayland, seatd, libinput, libdrm, mesa, vulkan-intel
- `~/.config/labwc/rc.xml` — Alt+F4/Tab shortcuts; Flutter: maximize+no decoration; Lucille: floating+no decoration
- Build script: Step 2 builds BOTH (flutter + cargo); Step 4a stages Flutter bundle, Step 4a2 stages slint binary

18 real bugs found+fixed across GamingAgent-go, LucyServer-go, and the Slint codebase (SSE session-id leak, CPU-stat accuracy, WS close handshake, fabricated API fields, dead racing launchers, 35-level .NET publish nesting, etc.). See git log for full details.

### GamingAgent Go Rewrite (.NET → Go) — tasks #10–14 ALL COMPLETE
Compiles clean (`go build`, `go vet`, `gofmt -l`, zero issues). Runtime-tested: no.
- [x] **Task #10** Scaffold `30-source/GamingAgent-go` — go.mod, models, db (WAL sqlite, schema), services (cache, gfn, steam, games, lucille), handlers, main.go with all routes
- [x] **Task #11** GFN catalog + Steam library — real fetch, 12h cache, stale-on-error fallback
- [x] **Task #12** Intersection + prices + favorites — Steam∩GFN join by appId+normalised title, CheapShark proxy, SQLite upsert
- [x] **Task #13** Lucille eval + chat + SSE stream + history — full Nemotron integration, context injection, SQLite persistence
- [x] **Task #14** `gaming-agent.service` now runs `/opt/swarm_os/GamingAgent/gaming-agent` (Go binary) instead of dotnet. Build script step 4b2 (`70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh`) now does `go build` from `30-source/GamingAgent-go` instead of `dotnet publish`. **`dotnet-runtime-10.0`/`aspnet-runtime-10.0` intentionally left in `packages.x86_64`** — LucyServer (task #23) still needs them until its own Go rewrite lands. **Found+fixed a real bug:** nothing anywhere provisioned `/etc/swarm_os/` (the SQLite DB directory), and the service runs as unprivileged `User=swarm` — would have failed with a permission/missing-dir error on first boot. Added `ExecStartPre=+mkdir -p /etc/swarm_os` + `chown swarm:swarm` to `gaming-agent.service`.

---

## IN PROGRESS 🔧

### Active: LucyServer Go Rewrite (.NET → Go, tasks #15–23)
LucyServer is large (~50 services, 100+ endpoints) — phased in 3 sprints:
- Phase 1 (unblock Slint + Android): system integration, filesystem, orchestrator, chat
- Phase 2: RAG/vector memory, TTS, WebAuthn, settings, Ollama mgmt, news/games
- Phase 3: developer platform, VMs, marketplace, telemetry, security, sandbox

- [x] **Task #15** Scaffold `30-source/LucyServer-go` — go.mod (chi, cors; gorilla/websocket added back by task #16 when it's actually used), `main.go` (full accurate route table — every real route from `Program.cs` + `DeveloperPlatformEndpoints.cs` + `VirtualizationEndpoints.cs` + `AdvancedEcosystemEndpoints.cs`, ~100 routes, each an honest `501 {"track":"task-N"}` stub rather than a fake 200 or an indistinguishable-from-a-typo 404), `handlers/stub.go`, `storage/storage.go`. Compiles clean (`go build`/`go vet`/`gofmt -l`), and runtime-smoke-tested (not just compiled): started the server, curled `/health` (200), `/api/system/stats` from loopback with no token (correctly bypasses auth → 501 task-16), a nested route group `/api/vms/` (correctly resolves → 501 task-22), `/webauthn/list` (correctly exempt from `/api/` auth middleware → 501 task-20).
  - **Replicated the .NET auth middleware exactly** (`Program.cs` lines 77-96) — every `/api/*` route except `/api/tts/*` requires a loopback connection, an exact `X-Swarm-Auth` match, or an `Authorization` header that *contains* the token. Getting this wrong (e.g. forgetting it entirely) would have shipped an unauthenticated version of an authenticated API.
  - **Found: LucyServer's core services don't use SQLite at all** — `ChatService`, `WebAuthnService`, `SettingsService` are all flat JSON files / `.env` text manipulation. The original task plan assumed `mattn/go-sqlite3`; that would have been wrong. `storage/storage.go` mirrors the real flat-file approach instead.
  - **Found a real latent bug in the .NET source**: `ChatService.cs` hardcodes chat history to `/mnt/i30ltz-brains/AI/memory.json` — verified this mount **does not exist anywhere on this system** (not in fstab, not created by `install_swarm_os.sh`, not in CLAUDE.md's documented mounts, `grep` found the string nowhere else). Chat history has likely been silently failing to persist (or throwing) on every real boot. The Go port uses `/etc/swarm_os/lucy/` instead (env-overridable via `LUCY_STATE_DIR`), consistent with GamingAgent-go's `/etc/swarm_os/gaming.db` convention — this is a deliberate deviation from the original, not a faithful port of broken behavior.
  - **Found two service groups missing from the original 9-task plan** — Ollama local-model management (`/api/local_models`, `/api/pull_model`, `/api/pull_status`) and `NewsAndGamesService` (`/api/news`, `/api/deals`, `/api/gfn/games`, Steam/game-price lookups, etc.) both exist in `Program.cs` and weren't accounted for. Folded both into task #19. **Note:** the IDEAS section's "News & Gaming Agent (SEPARATE from LucyServer / GamingAgent)" entry describes this as future/separate work — it already exists inside LucyServer today; reconcile that IDEA note when #19 actually starts.
  - **`lucy-server.service` intentionally NOT touched yet** — it still runs `.NET`, which doesn't read `/etc/swarm_os/lucy` at all (uses the broken hardcoded path + app-local `.env` instead). Adding `ExecStartPre` provisioning for a path the running service doesn't use would be dead configuration. **Task #23 must add it** when the service actually switches to the Go binary (same `mkdir -p` + `chown swarm:swarm` pattern already in `gaming-agent.service`) — noting this now so it isn't missed later.
- [x] **Task #16** System integration — `models/models.go` (CommandResult/ProcessInfo/SystemStats matching .NET JSON shape exactly), `services/system.go`, `services/terminal.go` (real WebSocket terminal via `gorilla/websocket`), `handlers/system.go`. All 9 routes wired and **runtime-tested end-to-end**, not just compiled: `run_command` (real bash exec, verified stdout/exitCode), `system/stats` (verified real CPU%/memory numbers), `system/processes` (verified /proc walk returns real sorted process list), `packages/list` (verified pacman detection + real package list), and the WebSocket terminal (wrote a throwaway Go WS client, sent a command, received the real output back, verified graceful close).
  - **Found+fixed a real accuracy bug while porting `GetSystemStats`**: the .NET original's CPU% parsing (`cpuParts[1].Replace("%us,","").Replace("%us","")`) was written for an older `top` output format. Verified against this system's actual `top -bn1 | grep Cpu(s)` output — the Replace() calls are silent no-ops on the current format, so the .NET code has been returning **user-mode CPU% only** (excluding sy/ni/wa/hi/si/st, excluding idle) under a field literally named `CpuUsagePercentage`. Fixed to compute the standard `100 - idle%` instead — a deliberate accuracy improvement, not a silent behavior change, called out in code comments since nothing else depends on this metric's exact semantics (monitoring-only).
  - **Previously flagged forward-compatibility problem — now resolved**: `SetClipboardTextAsync` shells out to `wl-copy`, which needs a running Wayland compositor. labwc (the pivot from the kiosk direction) IS a Wayland compositor, so `wl-copy` works inside its session. No code change needed here.
  - **Fixed a WS close-handshake gap found via actual testing, not just code review**: initial port only did `conn.Close()` on cleanup; the .NET original sends a proper WS Close control frame in its `finally` block. First test run showed the client receiving an abnormal 1006 close instead of a clean 1000 — added `conn.WriteControl(CloseMessage, ...)` and re-verified with the same test client that it now closes `1000 (normal)`.
- [x] **Task #17** Phase 1: filesystem + code endpoints — `/api/fs` (list dir), `/api/fs/analyze` (du -sh), `/api/code/files` (walk + ext filter), `/api/code/read`, `/api/code/save`, `/api/code/apply_upgrade`, `/api/recovery/mount` — all wired and runtime-tested. New files: `services/filesystem.go`, `handlers/filesystem.go`; added `FileItemInfo`/`FsAnalyzeRequest`/`FileReadRequest`/`FileSaveRequest` models. Code-extension list expanded with `.go`/`.dart`/`.rs`/`.toml`/`.yaml`/`.yml` (supersets the .NET list without removing any). Compile clean, all 7 endpoints return correct JSON on live server test.
- [x] **Task #18** Phase 1: chat management + Lucy orchestrator — `POST /lucy` (SSE streaming, routes by modelId: NVIDIA/Groq/OpenRouter/Ollama), `GET /api/chats`, `POST /api/chats/{new,delete,rename,select,toggle_pin,toggle_privacy}`. New: `services/chat.go` (mutex-protected JSON store, LUCY_STATE_DIR env override), `services/llm.go` (OpenAI-compat SSE streaming for all providers), `handlers/chat.go`. Chat storage uses `/etc/swarm_os/lucy/memory.json` — corrects the .NET original's broken `/mnt/i30ltz-brains/AI/memory.json` hardcode. RAG/memory/TTS are no-ops (placeholder hooks ready for task #19). Compile clean, all 8 endpoints runtime-tested end-to-end.
- [x] **Task #19** Phase 2: TTS (`/api/tts/generate` — ElevenLabs primary, Fish Audio alt, edge-tts CLI fallback), Ollama mgmt (`/api/local_models`, `/api/pull_model`, `/api/pull_status` — async pull with progress), NewsAndGamesService (`/api/news`, `/api/deals`, `/api/news-feed`, `/api/dev-news`, `/api/steam-library`, `/api/game-prices`, `/api/game-info`, `/api/gfn/games`, `/api/gfn/optimize` — RSS + CheapShark + Steam API, 3h cache), RAG (`/api/rag/ingest`, `/api/rag/ingest/file`, `/api/rag/documents`, `/api/rag/document` DELETE, `/api/rag/clear` — chunking, Ollama `nomic-embed-text` embeddings, cosine similarity at ≥0.35, store at `{LUCY_STATE_DIR}/rag_store.json`). RAG now plugged into `/lucy` orchestrator (live vector context injected per request). New: `services/tts.go`, `services/ollama.go`, `services/news.go`, `services/rag.go`, `handlers/media.go`. Compile clean; runtime-tested (Ollama offline gracefully degrades, GFN/RAG/Ollama status endpoints all 200, TTS needs live key).
- [x] **Task #20** Phase 2: WebAuthn auth + admin settings — `/webauthn/register/options`, `/webauthn/register/verify`, `/webauthn/login/options`, `/webauthn/login/verify`, `/webauthn/list`, `/webauthn/clear` (all exempt from /api/ auth, use `go-webauthn/webauthn` v0.10.2; credentials stored as JSON at `{LUCY_STATE_DIR}/webauthn_credentials.json`; RPID/origins configurable via `WEBAUTHN_RP_ID`/`WEBAUTHN_ORIGINS` env); `/api/settings/voice/get` + `/api/settings/voice` (in-memory, default `en-GB-SoniaNeural`); `/api/settings/login_password` (bcrypt hash → `{LUCY_STATE_DIR}/login_password.txt`); `/api/settings/sudo_password` (validates with `sudo -S -k true`, stores at `{LUCY_STATE_DIR}/sudo_password.txt`, empty arg clears); `/api/admin/save-keys` (allowlist of 8 keys, updates both in-process env and `LUCY_ENV_FILE` file, defaults to `/etc/swarm_os.env`); `/api/google/brief` (parallel: GoogleWorkspaceService@8399 for Gmail+Calendar with graceful degradation, devNews from existing service, Open-Meteo weather with `WEATHER_LAT`/`WEATHER_LON` env overrides); `/api/search` (DDG Instant Answer API + DDG lite HTML scrape fallback, always returns `[]` not `null`). New: `services/webauthn.go`, `services/settings.go`, `services/search.go`, `handlers/settings.go`; deps: `github.com/go-webauthn/webauthn@v0.10.2`, `golang.org/x/crypto` (bcrypt). Compile clean, all 13 routes runtime-tested.
- [x] **Task #21** Phase 3: developer platform — all 29 routes wired. New: `services/devplatform.go` (ExtensionDevService, AppReleaseService, GitAndCiService, OAuthAndAnalyticsService, AiCodingAgentService, CloudWorkspaceService, MarketplaceManagementService — all in-memory with mutexes, seeded data, async CI goroutine, `git init --bare` via exec.Command, artifact file streaming, OAuth redirect, 15%/85% platform/developer split, SWARM-KEY license generation); `handlers/devplatform.go` (all HTTP handlers). Compile clean.
- [x] **Task #22** Phase 3: VMs, device mirror, telemetry, security audit, sandbox execution — all 24 routes wired. New: `services/virtualization.go` (VmManagerService: qemu-img create + qemu-system-x86_64 launch with UEFI/KVM auto-detect, SIGTERM/SIGSTOP/SIGCONT/SIGKILL lifecycle, JSON metadata persistence at `{LUCY_STATE_DIR}/vms/`; VmTelemetryService: live CPU from /proc/pid/stat, memory from /proc/pid/status, disk I/O from /proc/pid/io, 60-point rolling history; SnapshotService: qemu-img snapshot -c/-a/-d/-l; EnvironmentTemplateService: 6 seeded templates; DeviceAndScreenMirrorService: scrcpy launch + kill, /sys/class/thermal, /sys/devices cpufreq, /proc/uptime; TelemetryAndCrashService: crash report ingestion with symbolication; SecurityAndComplianceService: SHA-256 chained audit log, malware scan, 2 seeded verified developers; SandboxService: script-to-file exec with timeout via goroutine + Kill, prlimit optional); `handlers/virtualization.go` (all HTTP handlers). Compile clean.
- [x] **Task #23** Flip `lucy-server.service` to Go binary + update build script. Service unit (`40-iso-profile/.../etc/systemd/system/lucy-server.service`): `ExecStart` now runs `/opt/swarm_os/LucyServer/lucy-server` (Go binary); added `ExecStartPre=+mkdir -p /etc/swarm_os/lucy` + `ExecStartPre=+chown swarm:swarm /etc/swarm_os/lucy` (same pattern as `gaming-agent.service`); dropped `ASPNETCORE_ENVIRONMENT` (not used by Go); description updated. Build script (`70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh`): Step 3 now does `go build -o lucy-server .` from `30-source/LucyServer-go/` instead of `dotnet publish`; Step 4b stages the single Go binary instead of the entire .NET publish/ directory; `SERVER_DIR` variable removed, `LUCY_SERVER_GO_DIR` added. Go binary 14 MB (`go build` verified clean). **Note:** `dotnet-runtime-10.0`/`aspnet-runtime-10.0` can now be removed from `packages.x86_64` — LucyServer was the last .NET service. Not removed here to let the user confirm before the next ISO build.

**Also fixed while investigating LucyServer's build step (unrelated to #15 itself but found along the way):**
- `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` Step 3 ran `dotnet publish -o "$SERVER_DIR/publish"` with no cleanup first. Since the output dir sits inside the project dir, every build copied the previous `publish/` into the new one — found a **35-level-deep `publish/publish/publish/...` chain, 46MB**, that was getting shipped into every ISO via `cp -a`. Same rot existed in the now-dead `GamingAgent/publish` from before its Go migration (6 levels, 34MB). Added `rm -rf "$SERVER_DIR/publish"` before the publish call; cleaned both stale trees (80MB reclaimed, source code untouched — only regeneratable build output removed).

### Active: Flutter Lock Screen + Garden Mode (2026-09-11)
All code written and `flutter analyze` clean (0 errors, 0 warnings). Not yet tested on real hardware.
- [x] **CyberStoneLockScreen redesign** — 3×4 grid (3 cols, 4 rows), big square stones, `_StoneLightningPainter` (zigzag bolts from center, glow tips, pulse-animated), auto-shuffle every 2.8–4.6 s (2 random stones swap positions so pattern is glyph-not-position), `AnimatedOpacity` flash on swap, `AnimatedSwitcher` cross-fade, ornate stone columns left+right (`_StoneColumnPainter`: fluted shaft, capitals, edge-glow, animated lightning). File: `30-source/frontend/lib/screens/cyber_stone_lock_screen.dart`
- [x] **Hidden garden cipher** — second optional cipher (4–6 glyphs, must differ from main). Setup flows: main cipher → prompted for garden cipher (skippable). At login: main → `/`, garden → `/garden`. Reset wipes both.
- [x] **`CannabisModeScreen`** — `30-source/frontend/lib/screens/cannabis_mode_screen.dart`. Procedural grow-room: 5 LED beam colors, drifting spotlight, 18 floating buds/leaves, central bud cluster with trichome sparkles, 16-strain database rotating every 7 s with cross-fade. Route: `/garden` (standalone, no shell chrome).
- [ ] **Test on real hardware** — verify cipher setup flow, both unlock paths, garden animations at full frame rate
- [ ] **Real bud photos** — load actual strain images from `/opt/swarm_os/garden/` on-device folder; fall back to procedural art if folder empty. Rotate image per strain cycle. (Currently 100% procedural — no actual photos yet.)
- [ ] **Settings page: reconfigure garden cipher** without resetting main cipher — add "Garden Cipher" row in settings that lets user change only the garden pattern
- [ ] **Garden content updater** — cron/service that periodically pulls new strain images into `/opt/swarm_os/garden/` from a local or LAN source (not internet — keep it offline-first)

### Active: Desktop Shell (hex icon grid / app launcher under labwc)
- [x] **Hex wallpaper** — Flutter shell now uses `swarm_wasp_nest_v5.jpg` as the full-screen wasp-nest background (swarm_shell.dart)
- [x] **Infinite circular desktop** — `HexDesktopPage` (`lib/pages/hex_desktop_page.dart`): multiple swipeable desktop spaces (ORIGIN → SYSTEM → GAMING & MEDIA → … → FULL CIRCLE ↩ ORIGIN). PageView with loop sentinel at end that auto-returns to page 0. ⭐ ORIGIN badge (gold), SPACE N badge (cyan), loop icon. + button adds blank spaces. Long-press × removes non-origin spaces. Bottom ring indicator (gold origin dot, cyan active dot, loop icon). Fully persistent via `shared_preferences` — space count, names, last active page all survive restart. Icon tiles are nearly transparent so wasp-nest wallpaper shows through.
- [x] **App launcher** — `HexAgent.execCommand` → `SystemLauncher.launch()` (native process); `HexAgent.routePath` → go_router navigation; floating Flutter window fallback for terminal/monitor
- [x] **Router** — `/` now routes to `HexDesktopPage`; `/hub` kept as alias for the old `HubPage`
- [x] **`HexAgent` extended** — added `execCommand` (native process) and `routePath` (router nav) fields
- [x] **`HexGrid` extended** — added `showSlotBackgrounds` param (default true, false for wallpaper-overlay desktop mode)
- [x] labwc autostart already had Flutter shell — no change needed
- [ ] **Test on real hardware** — verify icons over wallpaper, drag-snap, native app launch, scrolling
- [ ] Waybar taskbar — labwc has no panel; add `waybar` to packages.x86_64 + config for window switcher strip
- [ ] App definitions file — hardcoded in `HexDesktopPage`; make editable from settings

### Active: Boot / ISO Verification
- [ ] Full ISO boot test — ISO builds but boot + install flow not yet verified on real hardware
- [x] **Ventoy install path fixed** — live ISO now stages `packages.x86_64` beside `install_swarm_os.sh`; the installer no longer depends on the source profile tree being mounted. Boot the ISO from Ventoy, switch to a TTY, and run `sudo /usr/local/bin/install_swarm_os.sh` (`30-source/install_swarm_os.sh`, `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh`)
- [x] **Install tile in live desktop** — SYSTEM space exposes an Install tile that opens the real installer in a terminal; it remains a harmless unavailable message on an installed system (`30-source/frontend/lib/pages/hex_desktop_page.dart`, `30-source/frontend/lib/services/system_launcher.dart`)
- [x] **Fixed NVMe install target** — the desktop Install tile passes `--disk /dev/nvme0n1`, producing `/dev/nvme0n1p1` EFI and `/dev/nvme0n1p2` SWARM OS root (`30-source/frontend/lib/services/system_launcher.dart`)
- [x] **Installer manifest included in profile** — tracked `/usr/local/share/swarm-os/packages.x86_64` fallback prevents the live installer from failing when build-time staging is absent (`40-iso-profile/swarm_os_iso_profile/airootfs/usr/local/share/swarm-os/packages.x86_64`)
- [x] **Installer Mesa conflict fixed** — `pacstrap` now uses the ISO profile's official Arch `core`/`extra` pacman configuration instead of inheriting the CachyOS live host config, preventing `mesa` versus `mesa-git` conflicts (`30-source/install_swarm_os.sh`, build staging)
- [x] **Installer mount cleanup hardened** — unmounts EFI, subvolumes, and root explicitly before formatting, then refuses to run if `/dev/nvme0n1p2` remains mounted (`30-source/install_swarm_os.sh`)
- [x] **Installer chroot output fixed** — replaces outer-shell `banner`/`info` function calls inside the `arch-chroot` heredoc with portable `echo` output (`30-source/install_swarm_os.sh`)
- [x] **Ollama pull script path fixed** — creates `/opt/swarm_os` inside the target before writing `swarm-ollama-pull.sh`, avoiding the chroot `No such file or directory` failure (`30-source/install_swarm_os.sh`)
- [x] Toolchains installed and both projects compile clean. `GamingAgent-go`: clean `go build`/`go vet`/`gofmt -l`. `swarm-slint`: clean `cargo build`/`cargo clippy` (verified 2026-09-11 after backend-winit pivot — `backend-linuxkms` removed, `no-frame`/preferred-size kiosk props removed, confirmed no warnings).

### Active: Security Hardening — **PRIORITY #1** (Journey reordered 2026-09-12: Security → Boot → Gaming → Coding)
#### Previously completed (2026-09-11): Journey Task #2 (Podman rootless) + #3 (harden baseline)
Config/code fully wired; **not runtime-verified** — this dev host isn't the target OS, so `podman`/`apparmor_parser`/`ufw` aren't installed here to test against. TOML syntax on the new container configs was validated with Python's `tomllib`; AppArmor profile syntax was hand-checked against upstream grammar only. Real verification needs the next ISO boot test.

- [x] **Real bug found+fixed**: `gaming-agent.service`/`lucy-server.service` are baked with `User=swarm` (the live-ISO user), but `install_swarm_os.sh` only ever creates `i30ltz` on an installed system — it patched `swarm-ui.service`'s user but not these two. Every installed (non-live) SWARM OS would have had both backend daemons fail to start at boot. Fixed: `install_swarm_os.sh` now patches all three units the same way. (`30-source/install_swarm_os.sh`)
- [x] **Podman rootless containers** — `packages.x86_64` adds podman, podman-docker, crun, fuse-overlayfs, slirp4netns, netavark, aardvark-dns, catatonit (shadow/base already ships newuidmap/newgidmap, no separate uidmap pkg needed). `/etc/subuid`+`/etc/subgid` seed `swarm:100000:65536` on the live ISO; `install_swarm_os.sh` now double-checks `i30ltz` actually got a range from useradd's auto-allocation and falls back to an explicit one if not. `/etc/containers/registries.conf` + `storage.conf` baked (overlay + fuse-overlayfs fallback). `swarm-podman-linger.service` (new, enabled) runs `loginctl enable-linger` on whoever holds uid 1000 — looked up dynamically so the same unit works unmodified as `swarm` on the live ISO and `i30ltz` post-install — so the rootless `podman.socket` user unit (pre-enabled via a baked `~/.config/systemd/user/sockets.target.wants/podman.socket` symlink) actually comes up without a login session. `/etc/profile.d/swarm-podman-docker.sh` exports `DOCKER_HOST` using `$(id -u)`, same reason. (`40-iso-profile/swarm_os_iso_profile/{packages.x86_64,airootfs/etc/{subuid,subgid,containers/*,profile.d/*,systemd/system/swarm-podman-linger.service},profiledef.sh}`)
- [x] **Firejail sandboxing** — `firejail` added to packages.x86_64; `SystemLauncher` (`30-source/frontend/lib/services/system_launcher.dart`) now wraps every browser-launching fallback command (`browserCmd`, and the browser fallbacks in `claudeDesktopCmd`) with a `firejail` prefix resolved at shell-time (`command -v firejail`), so it degrades to an unsandboxed launch instead of failing closed if firejail is ever missing. Terminal/file-manager/IDE launches are untouched — sandboxing local dev tools would break their filesystem access for no security benefit. `flutter analyze` clean.
- [x] **Tailscale wired to the firewall it was already promised to** — found `nftables.conf` (`airootfs/etc/nftables.conf`) already had a live `iif "tailscale0" accept` trust rule, but `tailscale` was never in `packages.x86_64` and `tailscaled.service` was never enabled — the rule was a no-op referencing an interface that could never exist. Added the package and enabled the service (both live-ISO symlink and `install_swarm_os.sh`).
- [x] **AppArmor** — package added; kernel params `apparmor=1 security=apparmor` added to both custom GRUB menu entries (`grub/grub.cfg`) and to `install_swarm_os.sh`'s `GRUB_CMDLINE_LINUX`; `apparmor.service` enabled (live-ISO symlink + install script). Two profiles written to `airootfs/etc/apparmor.d/`:
  - `opt.swarm_os.GamingAgent.gaming-agent` — **enforcing**. Checked the actual Go source (`db/db.go`): its entire filesystem footprint is its own binary, `/etc/swarm_os.env`, and `/etc/swarm_os/gaming.db` (+WAL/SHM/journal). Confined to exactly that plus outbound network.
  - `opt.swarm_os.LucyServer.lucy-server` — **complain-mode, deliberately not enforcing**. LucyServer's actual feature set (task #21/#22 in the LucyServer-go rewrite log below) includes arbitrary shell exec, a filesystem browser rooted wherever the caller points it, QEMU VM management, and `git init --bare` — a tight enforcing profile would have to special-case most of the filesystem to avoid breaking those on purpose-built features. Complain mode logs every access for later `aa-logprof` tightening without risking a silently-broken feature, which is worse than an unconfined-but-working one.
- [x] **GamingAgent-go had zero auth on any endpoint** — found while comparing against LucyServer-go's existing `swarmAuthMiddleware` (loopback bypass or `X-Swarm-Auth`/`Authorization` token match). Since `nftables.conf` fully trusts `tailscale0`, any device on the tailnet could flip favorites in the SQLite DB or spam `/api/lucille/chat`+`/eval` — burning the owner's `NVIDIA_API_KEY` quota — with zero credential. Added the identical middleware to `GamingAgent-go/main.go`, gated **only** on the mutating/key-costing/history-leaking routes (`POST /games/favorite`, `/lucille/eval`, `/lucille/chat`, `/lucille/chat/stream`, `/lucille/history`); left the read-only catalog routes (GFN catalog, Steam library, intersection, genres, prices) open exactly as before so the dashboard artifact keeps working unmodified from whatever origin it's loaded from. Reused the same `swarm-token-2026` fallback the Android companion app and old .NET LucyServer already hardcode — **did not** generate a fresh random `SWARM_AUTH_TOKEN`, because the companion app has no way to discover a new value and would have broken. Compiles clean (`go build`/`go vet`/`gofmt -l`) and runtime-tested: confirmed a protected route (`POST /games/favorite`) still returns 200 with no token from loopback (bypass intact), and the open route (`/games/genres`) is unaffected.
- [x] **Critical bug found+fixed mid-session (user caught it live): lock screen had a full, zero-verification auth bypass.** `CyberStoneLockScreen._onStoneTapped` had a hidden "admin bypass" gesture — tap the top-left grid stone 3×, then the bottom-right one 3× — that called `_unlockSuccess(isAdminBypass: true)` **directly, with no password/fingerprint/anything checked**. Six taps in two corners fully unlocked the device for anyone who found it, garden-cipher content included. Fixed in two parts:
  - `LucyServer-go`: added `services.VerifyLoginPassword` + `POST /api/settings/verify_login_password` (`handlers/settings.go`, `main.go`) — bcrypt-compares against the existing `login_password.txt` set by `/api/settings/login_password` (task #20). **Fails closed** if no password was ever configured (returns 401, does not treat "no hash on disk" as a pass — that would just reopen the same hole on a fresh install). Runtime-tested all four paths: no-password-configured → 401, wrong password → 401, correct password → 200, and the write endpoint still works.
  - `cyber_stone_lock_screen.dart`: the corner gesture now opens a "Cipher Recovery" dialog (`_attemptRecoveryUnlock`) that POSTs the entered password to the endpoint above over loopback and unlocks **only** on an explicit 200. Wrong password, no password configured, and LucyServer being unreachable (e.g. not up yet at boot) all leave the screen locked with an error message — no silent-success fallback on any error path. `flutter analyze` clean (pre-existing style-lint infos only, none in the new code).
  - Net effect: the gesture is now what the user described wanting — a "forgotten password" recovery path — instead of an unconditional login bypass.
- [ ] **Not done — needs real hardware**: WebAuthn hardware test (journey task #3's other listed item; the WebAuthn *implementation* itself was already completed in LucyServer-go task #20 — this is specifically about testing an actual authenticator device against it).
- [ ] **Not done — no local copy exists to check**: verify the hosted gaming-dashboard Artifact actually fetches GamingAgent from loopback (not a LAN IP) so the new auth gate on `/lucille/*` doesn't surprise it on next real use.
- [ ] AppArmor profiles are hand-written from source-reading, not from `aa-logprof` observed-behavior logs — re-generate/tighten LucyServer's profile after real usage once boot-tested.
- [ ] `ufw` package left installed but intentionally **not enabled** — `nftables.conf` is the real firewall (default-drop policy, already existed before this session) and running both would fight over the same netfilter tables. Documented in `packages.x86_64` so a future AI doesn't "helpfully" enable it.

#### New security work (2026-09-12): Rate limiting, security headers, SSH hardening
- [x] **Rate limiting middleware added to both Go servers** — `rateLimiter(max, window)` per-IP fixed-window counter (no external deps, sync.Map + time). Applied to:
  - `LucyServer-go`: `/lucy` (15/min — LLM provider quota), `/api/tts/generate` (10/min — ElevenLabs cost), `/api/run_command` (30/min — shell exec abuse prevention)
  - `GamingAgent-go`: `/api/lucille/eval` (5/min — heavy Nemotron call), `/api/lucille/chat` + `/chat/stream` (20/min each)
  - Both servers compile clean (`go build`) after changes. (`30-source/LucyServer-go/main.go`, `30-source/GamingAgent-go/main.go`)
- [x] **Security headers middleware added to both servers** — `securityHeaders` middleware emits `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer` on every response. Belt-and-suspenders on top of the existing `originGate`. Applied at the router root so all routes are covered. Both servers verified compile-clean.
- [x] **SSH restricted to Tailscale mesh** — `nftables.conf` changed from `tcp dport 22 accept` (open to internet) to `iif "tailscale0" tcp dport 22 accept`. Every device on the tailnet can still SSH in; the public-SSH brute-force surface is now gone. (`40-iso-profile/swarm_os_iso_profile/airootfs/etc/nftables.conf`)

#### Journey reorg + new security/boot hardening (2026-09-12)
- [x] **Journey reordered: Security → Boot → Gaming → Coding** — user confirmed security hardening should run before boot verification. Artifact updated (phases swapped), memory updated.
- [x] **cloud-init disabled** — five `cloud-init.target.wants/` symlinks removed. No cloud datasource on a personal bare-metal OS; they only added boot delay. (`40-iso-profile/swarm_os_iso_profile/airootfs/etc/systemd/system/cloud-init.target.wants/`)
- [x] **systemd-networkd disabled, NetworkManager sole manager** — removed `multi-user.target.wants/systemd-networkd.service`, `network-online.target.wants/systemd-networkd-wait-online.service`, `sockets.target.wants/systemd-networkd.socket`, and the `dbus-org.freedesktop.network1.service` alias. Added `conf.d/wifi-backend.conf` configuring NM to use iwd as the WiFi backend (modern, lighter than wpa_supplicant). Eliminates the NM+networkd+iwd three-way conflict. (`40-iso-profile/.../airootfs/etc/systemd/system/`, `40-iso-profile/.../airootfs/etc/NetworkManager/conf.d/wifi-backend.conf`)
- [x] **Flutter shell now sends real auth tokens — ALL callers wired** — new `SwarmConfig` (`30-source/frontend/lib/services/swarm_config.dart`) reads `SWARM_AUTH_TOKEN` from `Platform.environment` (baked into ISO via `/etc/swarm_os.env`, falls back to `swarm-token-2026`). Every Flutter service file now sends `X-Swarm-Auth` on every request: `SentinelClient`, `LucyServerClient`, `CyberStoneLockScreen` (all 4 calls incl. `_setRecoveryPassword`), `AdvancedEcosystemService`, `AuthService` (WebAuthn calls), `SentinelSseClient` (SSE connect), `VirtualizationService`, `DeveloperPlatformService`. Also fixed `LucyServerClient` and both `VirtualizationService`/`DeveloperPlatformService` which were hardcoded to port 5237 (the old .NET port) — now use `SwarmConfig.httpBase`. `flutter analyze` zero errors.
- [x] **SWARM_AUTH_TOKEN generated at install time** — `install_swarm_os.sh` now appends a unique 64-char hex token to `/etc/swarm_os.env` via `openssl rand -hex 32` if none is set. Live ISO boots with the fallback; installed systems each get a distinct credential.

#### First boot checklist + voices + Dr. Boltz memory (2026-09-12)
- [x] **`FIRST_BOOT_CHECKLIST.md`** — 14-step command reference saved at `/mnt/Lucy/FIRST_BOOT_CHECKLIST.md`: services, LUCILLE mount, Tailscale install, lock password, TOTP setup, Claude Code install, firewall verify, AppArmor, GamingAgent test, Ollama, Vulkan, Syncthing, auth token rotation, health check.
- [x] **OpenRouter TTS** — `openRouterTTS()` added to `services/tts.go`. Routes `openrouter/<voice>` prefix to `https://openrouter.ai/api/v1/audio/speech` with `openai/tts-1-hd` model and `OPENROUTER_API_KEY`. Persona voice constants: `BOLTZ_TTS_VOICE` defaults to `openrouter/onyx` (deep authoritative male), `LUCILLE_TTS_VOICE` defaults to `eleven/EXAVITQu4vr4xnSDxMaL` (ElevenLabs Bella — sultry female). OS agents and Android companion both call `/api/tts/generate` with `voiceName="boltz"` or `"lucille"` and get the right voice. Fallback chain: OpenRouter → ElevenLabs → Fish Audio → edge-tts CLI. LucyServer-go `go build` clean.
- [x] **Dr. Boltz cheatsheet card** — `BoltzCheatsheet()` composable added to `DrI3oltzFullAvatarScreen.kt`. Tap to expand: 14-step boot steps with step number badges, command in monospace green, note text, plus voice info panel (Boltz=onyx, Lucille=Bella). Default speech updated to reference the cheatsheet. `BOLTZ_FIRST_BOOT_MEMORY` and `BOLTZ_VOICE_MEMORY` data objects encoded in the companion for offline access.

#### TOTP phone 2FA — wired (2026-09-12)
User has 3 Android phones and no FIDO2 key. TOTP (RFC 6238) is the right fit: scan the **same QR code** on all 3 phones once, and any of them generates valid unlock codes forever. No hardware to buy.

- [x] **`services/totp.go`** — pure stdlib (crypto/hmac, crypto/sha1, encoding/base32), no new deps. `TOTPSetup()` generates 20-byte random secret + `otpauth://` URI; `TOTPConfirm(secret, code)` verifies first code then persists; `TOTPCheck(code)` validates ±1 window (30 s clock skew); `TOTPDisable()` clears. Stored at `{LUCY_STATE_DIR}/totp.json` (0600). (`30-source/LucyServer-go/services/totp.go`)
- [x] **5 new LucyServer routes** — `GET /api/settings/totp/status`, `POST /api/settings/totp/setup`, `POST /api/settings/totp/confirm`, `POST /api/settings/totp/check`, `DELETE /api/settings/totp`. All under `/api/` auth middleware. Handlers in `handlers/settings.go`, routes in `main.go`.
- [x] **Lock screen TOTP challenge** — `_checkTotpStatus()` called at `initState`; polls `GET /api/settings/totp/status` (fails open if LucyServer not up — cipher is still required). `_validateAndUnlock()` made async; on cipher match, if `_totpEnabled`, calls `_showTotpChallenge()` — a 6-digit input dialog (auto-submits at 6 chars, shows error on wrong code, fails closed on network error). Only calls `_unlockSuccess` after the code is accepted. (`30-source/frontend/lib/screens/cyber_stone_lock_screen.dart`)
- [x] LucyServer-go `go build` clean; `flutter analyze` 0 errors (16 pre-existing style infos, none in new code).

**Setup flow (when on real hardware):**
1. `POST /api/settings/totp/setup` → get `uri` field
2. Open the `otpauth://…` URI or scan its QR on each phone with Aegis / Google Authenticator
3. `POST /api/settings/totp/confirm` with `{secret, code}` where code is from any phone
4. Lock screen now requires cipher + 6-digit phone code at every login

WebAuthn endpoints stay in place — they work if a FIDO2 key is ever added later.
- [x] **First real build attempt after this session's changes failed twice — both fixed**:
  1. Added `tailscale` to `packages.x86_64` without checking it's AUR-only on vanilla Arch (only resolved when I checked it because this dev host is CachyOS with a `cachyos-extra-v3` repo). Broke `pacstrap` with "failed to install packages to new root". Removed it; the `nftables.conf` `tailscale0` trust rule goes back to being a no-op until it's installed some other way (e.g. a first-boot script running tailscale's own `install.sh`, same pattern as `swarm-ollama-pull.sh`) — not worth AUR build tooling in the pipeline for.
  2. Same "target not found" list persisted (`labwc`, `seatd`, `libxkbcommon-x11`, `egl-wayland`, `xorg-xwayland`, `podman-docker`, `firejail`, `apparmor`, `ufw`) across two more attempts, through two wrong theories before the real one:
     - First guess: bad mirror. This build host's `/etc/pacman.d/mirrorlist` (CachyOS-flavored) lists `archlinux.cachyos.org` first — confirmed incomplete vs. upstream by downloading `extra.db` straight from Arch's own official mirror and finding every "missing" package genuinely in it. Fixed by adding a project-local `40-iso-profile/swarm_os_iso_profile/mirrorlist` pointing at `geo.mirror.pkgbuild.com` (Arch's own official geo-redirector, `mirrors.kernel.org` fallback), decoupling the build from whatever mirror the host has configured. Genuinely a real improvement (portability), but **not actually the failure's cause** — same errors persisted after this fix, mirror log even showed a fresh successful 8.5MiB download from the new mirror.
     - (Tried adding a `[cachyos]` repo as an even earlier guess — user correctly rejected it: "CachyOS-like" is the performance/lean design goal, not a literal dependency on CachyOS's repo infra. Reverted.)
     - Next theory: `Architecture = auto` expands, on this CachyOS host, into **three** lines (`x86_64`/`x86_64_v2`/`x86_64_v3`) inside mkarchiso's generated `iso.pacman.conf` — confirmed by reading that file directly after a failed run. Pinned `Architecture = x86_64` explicitly. **Also did not fix it** — same 9 packages, same error, verified again by directly extracting the real `extra.db` and checking each package's `%ARCH%` field is plain `x86_64` (or `any` for `ufw`) — no mismatch. Kept this fix anyway (it's still correct and removes an unwanted CachyOS behavior), but it wasn't the cause either.
     - At the user's direction, re-added `[cachyos]` as a fourth attempt — still same 9 errors (proof it was never a repo problem at all).
     - **Actual root cause, finally confirmed**: `grep -n '^[A-Za-z0-9][^#]*#' packages.x86_64` matched **exactly those same 9 lines** — every one of them had a trailing inline comment on the same line as the package name (`labwc          # lightweight wlroots floating-window compositor`). `mkarchiso`'s `packages.x86_64` reader only strips lines that *start* with `#` (confirmed by `install_swarm_os.sh`'s own parser using the identical convention: `grep -v '^#'`) — a trailing comment after a real package name is not recognized as a comment at all, so the whole line including the comment text was being fed to pacman as one bogus target string. Zero packages without a trailing comment failed; all 9 with one did. Fixed by moving every trailing comment in `packages.x86_64` to its own preceding line. Removed the now-unnecessary `[cachyos]` repo again — this bug had nothing to do with mirrors, architecture, or repos, so keep `pacman.conf` at plain `[core]`+`[extra]` going forward. **Lesson for future edits to this file: never put a comment after a package name on the same line — always on its own `#`-prefixed line above.**
- [x] **File-permissions audit found a real secrets leak**: `airootfs/opt/swarm_os/GoogleWorkspaceService/.env` was a full duplicate of the *entire* root `.env` — every API key in the project, not just Google's — sitting inside the ISO with no `profiledef.sh` permission entry (so its final mode on a built ISO was whatever the build host's ambient filesystem happened to leave it at, not a deliberate 600). Confirmed nothing reads it: `google-workspace.service` already gets everything via `EnvironmentFile=/etc/swarm_os.env`, the .NET source has no local-`.env` loader, and the build script never references `GoogleWorkspaceService` at all (separately worth noting — see IDEAS). Deleted the file; nothing regenerates it since it wasn't build-script-generated.

---

## IDEAS / TODO 💡

### GamingAgent (implement in Go rewrite, not .NET)
- [ ] Price alert: poll CheapShark daily, write to gaming.db when a game drops below threshold, surface in dashboard
- [ ] Add IGDB or SteamSpy API for richer genre/description data (GFN catalog has sparse genres)
- [ ] Cache Steam library to SQLite so dashboard loads offline
- [ ] Webhook endpoint so external services can push events to the dashboard

### Gaming Dashboard (Artifact — no language changes needed)
- [ ] Drag-and-drop reorder pinned cards
- [ ] "Recently Played" section — pull from Steam API recent playtime delta
- [ ] Per-game notes field (localStorage) — let user annotate games
- [ ] Keyboard shortcut: `/` focuses search, `Esc` clears
- [ ] Infinite scroll / virtualized list for large libraries (400+ games)
- [ ] Export favorites list as JSON or share link
- [ ] Dark/light toggle persisted in localStorage

### News & Gaming Agent
**CORRECTION (found 2026-09-10 while scaffolding LucyServer-go, task #15):** this already exists — `NewsAndGamesService` inside LucyServer (`/api/news`, `/api/deals`, `/api/news-feed`, `/api/dev-news`, `/api/steam-library`, `/api/game-prices`, `/api/game-info`, `/api/gfn/games`, `/api/gfn/optimize`), not a separate future agent. It's in scope for LucyServer Go rewrite task #19. The ideas below (RSS sources, update notifications) are still real gaps in that EXISTING service, not justification for a new one.
- [ ] Sources: GamingOnLinux RSS, Phoronix, Steam news API per owned game — check what `NewsAndGamesService` already sources before assuming gaps
- [ ] Surface "your games got updates" notification in dashboard

### Desktop Shell (hex grid — LARGELY DONE 2026-09-11)
- [x] Hex wallpaper background (swarm_wasp_nest_v5.jpg in swarm_shell)
- [x] Hex icon grid with drag-to-reorder, app launching, scrollable desktop
- [ ] Taskbar / window-switcher strip (labwc has no panel — needs `waybar` pkg + config)
- [ ] App definitions file (name, icon, exec command) editable from Lucille settings tab

### SWARM OS / ISO
- [ ] **`GoogleWorkspaceService` is never staged by the build script** — found 2026-09-11 while auditing file permissions: `70-scripts/build_swarm_iso_*.sh` has no step that builds/copies it, yet the full published .NET binary+DLLs are already sitting hand-copied in `airootfs/opt/swarm_os/GoogleWorkspaceService/` (dated Sep 8, untouched by any script), alongside `google-workspace.service` baked and enabled in `multi-user.target.wants/`. Works *today* only because someone manually staged it once. A clean checkout of the repo without that pre-staged directory, or any future rebuild of the service, has no automated path back into the ISO. Wire real staging into the build script (mirroring the `GamingAgent`/`LucyServer` steps) so it isn't silently relying on stale hand-copied binaries forever.
- [ ] Google OAuth flow for GoogleWorkspaceService in LucyServer
- [ ] Android Companion app — build.gradle.kts version stamp wired but app not tested
- [ ] Snapshot/restore: btrfs subvolume snapshot before each build run so bad builds are recoverable
- [ ] OTA update mechanism: check `/mnt/Lucy/10-releases/` version file vs running version

### Lucille AI
- [x] Nemotron SSE streaming — `/api/lucille/chat/stream` streams word-by-word via Server-Sent Events
- [x] SQLite chat history — persists all Lucille conversations to `gaming.db` (chat_history table)
- [x] "Ask Lucille" free-text — `POST /api/lucille/chat` takes arbitrary message history
- [ ] Lucille aware of current deals — reference specific prices in suggestions
- [ ] Lucille cross-agent: can query LucyServer for calendar/weather context when suggesting gaming sessions

---

## Architecture Notes (for new AIs coming in cold)

```
/mnt/Lucy/                          ← LIVE working drive (read/write freely here)
  10-releases/                      ← built ISOs land here
  20-runtime/                       ← .env with all API keys
  30-source/                        ← all source code
    frontend/                       ← Flutter Linux shell (BEING REPLACED — see swarm-slint)
    swarm-slint/                    ← [IN PROGRESS] Rust + Slint kiosk UI (replaces Flutter)
    LucyServer/                     ← .NET 10 main agent (BEING REPLACED — see LucyServer-go)
    LucyServer-go/                  ← [IN PROGRESS] Go rewrite of LucyServer
    GamingAgent/                    ← .NET 10 gaming service port 8401 (BEING REPLACED)
    GamingAgent-go/                 ← [IN PROGRESS] Go rewrite of GamingAgent
    lucille-core/                   ← C++20 native engine — KEEP AS-IS (already optimal)
    deploy_swarm_os_foundation.sh   ← stages configs into airootfs
    install_swarm_os.sh             ← target machine installer
  40-iso-profile/
    swarm_os_iso_profile/           ← mkarchiso profile
      airootfs/                     ← chroot that becomes the live system
        opt/swarm_os/               ← apps staged here by build script
        etc/swarm_os.env            ← baked .env (set -a safe)
        etc/systemd/system/         ← service units
  70-scripts/
    build_swarm_iso_*.sh            ← THE build script (run as user, not root)

/run/media/i30ltz/lucy-master/      ← READ-ONLY source mirror — NEVER write here
```

**Target stack (post-rewrite):**

| Component | Language | Notes |
|---|---|---|
| Kiosk UI | **Rust + Slint** | Direct DRM/KMS, no compositor |
| GamingAgent | **Go** | Port 8401, same JSON API |
| LucyServer | **Go** | Same port, same API surface |
| lucille-core | **C++20** | SIMD/shared-mem — do not touch |
| Build scripts | bash | Unchanged |

Key rules:
- Build script runs as normal user; only `mkarchiso` step uses sudo
- Never `rm -rf` anything in airootfs without checking it's not a symlink to lucy-master
- `.env` is at `/mnt/Lucy/20-runtime/.env` — never commit it
- GamingAgent SQLite lives at `/etc/swarm_os/gaming.db` inside the running ISO
- Nemotron endpoint: `https://integrate.api.nvidia.com/v1/chat/completions`, model `nvidia/llama-3.3-nemotron-super-49b-v1`, key from `NVIDIA_API_KEY` env var
- Go rewrites must expose identical JSON API shapes — dashboard artifact and Android companion must require zero changes

---

*Last updated: 2026-09-12 — **Android Companion persona rename & Syncthing confirmation (2026-09-12)**: All `DR_BOLTZ` / "DR. Boltz" references replaced with `DR_I30LTZ` / "DR. I30LTZ" throughout the companion app (`TtsVoiceManager.kt`, `AiLabScreen.kt`, `GeminiAiService.kt`, `MainViewModel.kt`, `CoderDroidScreen.kt`, `DrI3oltzFullAvatarScreen.kt`, `AppRepository.kt`, `AntivirusScreen.kt`, `OsDeploymentScreen.kt`, `DashboardScreen.kt`, `TaskSyncScreen.kt`, `MainActivity.kt`). Persona roles divided: **DR. I30LTZ** = Optimization · Eval · Security; **Lucille** = Assistant/Coder · SWARM OS Orchestrator. Nav bar "DR Boltz AI" → "DR. I30LTZ". Companion identity header now shows "SWARM OS COMPANION  •  i30ltz". Syncthing confirmed already covers `30-source/i30ltz-recovery/` via the existing `SWARM_OS` folder (path `/mnt/Lucy/30-source`, all 3 phones as devices, `target/` excluded in `.stignore`). CoderDroidScreen folder picker hardened: `takePersistableUriPermission`, robust SAF URI path extraction for `primary:` and `home:` prefixes, Syncthing fallback path search. New "DR. I30LTZ Recovery · tap to open project" quick-open row in CoderDroid top bar (searches `Syncthing/SWARM_OS/i30ltz-recovery` on phone). — Previous: **DR. I30LTZ Recovery** (official name, exact capitalization everywhere): `30-source/i30ltz-recovery/` — Rust + Raylib, 2.7 MB binary (`/opt/swarm_os/i30ltz-recovery`, SHA256: `6599791bc1c391b710fb7a76ecc8052bb13655cc5d3a1f00c7484fdd98bbba98`). Full-body 3D animated UGA bulldog avatar (breathing/tail-wag/blink/holographic orbit rings), carbon-fiber UI. Tabs: System, Boot, Disk, Services, I30LTZ Chat. `i30ltz-recovery.service` in airootfs (on-demand). **Checksum-verified sync**: `sync_lucille_ai.sh` updated — `rsync --checksum` on both Lucille-AI and I30LTZ-Recovery syncs; sha256 manifest + BUILD_STAMP.txt written to each destination. Sync targets: sdb8 (`/mnt/boltz/I30LTZ-Recovery/`) and sda4 (`/mnt/lucy-master-backup/I30LTZ-Recovery/`). sdb8 is shared across SWARM OS, Endeavor, and CachyOS — one PC, one OS at a time, each mounts sdb8 for its persistent DR. I30LTZ Recovery binary. **Build tracker**: `/mnt/Lucy/I30LTZ_RECOVERY_BUILD_TRACKER.md` at project root. DR. I30LTZ is a SEPARATE AI identity from Lucille. — Previous: Dr. Boltz wired: `/boltz` endpoint in LucyServer-go uses Lucille's streaming core with Dr. Boltz identity (eval/optimization/recovery). Core prompt at `/mnt/brains/Dr_Boltz_Core_Prompt.md`. When `/mnt/boltz` is mounted (sdb8, from SWARM OS or Endeavor), `Lucille-AI/` sync is listed as reference context. `BOLTZ_CORE_PROMPT`, `BOLTZ_DRIVE`, `BOLTZ_LUCILLE_AI` in `swarm_os.env`. sdb8 mount renamed from `/mnt/ai-backup` → `/mnt/boltz` everywhere. Storage/memory architecture wired: `/mnt/brains` (nvme0n1p5) is now Lucille's live identity — `LUCY_STATE_DIR=/mnt/brains`, `Lucy_Core_Prompt.md` + `llcy_memory.md` injected as system prompt on every `/lucy` call. Slick (nvme0n1p6, LUKS) added to crypttab+fstab as `noauto`; new `/lucy/unfiltered` endpoint in LucyServer-go reads exclusively from `/mnt/slick` — regular `/lucy` NEVER touches slick. Unlock via `sudo unlock_slick.sh`. Lucille-AI sync (rsync → sdb8 + sda4, additive, no deletes) runs at boot+1h via `lucille-ai-sync.timer`; sdb8 auto-mounted, sda4 syncs only when LUKS already unlocked. All installer fstab/crypttab entries added. `go build` clean. Boot blockers fixed: `systemd-time-wait-sync.service` removed from `sysinit.target.wants/` (TimeoutStartSec=infinity hung boot indefinitely offline); `aspnet-runtime-10.0` added to `packages.x86_64` so `google-workspace.service` no longer crash-loops. Both cloud-init and systemd-networkd already cleared. Boot chain is now clean. Completed full Flutter auth token sweep: all 8 remaining service files wired to `SwarmConfig.authHeaders`/`SwarmConfig.httpBase` — `AdvancedEcosystemService`, `AuthService`, `SentinelSseClient`, `VirtualizationService`, `DeveloperPlatformService`, `SentinelClient` constructor, `CyberStoneLockScreen._setRecoveryPassword`. Old .NET port 5237 eliminated from `VirtualizationService` and `DeveloperPlatformService`. `flutter analyze` zero errors. Next: rebuild ISO (P2), hardware boot test, remove loopback bypass for mutating routes. First boot checklist (`FIRST_BOOT_CHECKLIST.md`, 14 steps); OpenRouter TTS added to LucyServer-go (Dr. Boltz=`openrouter/onyx` deep male, Lucille=ElevenLabs Bella seductive female, voice name `boltz`/`lucille` reusable by OS agents); Dr. Boltz cheatsheet card + first-boot memory wired into companion app (`DrI3oltzFullAvatarScreen.kt`). TOTP 2FA: `services/totp.go` (RFC 6238, pure stdlib), 5 LucyServer routes, lock screen TOTP challenge dialog wired in — scan same QR on all 3 phones. Journey reordered: Security → Boot → Gaming → Coding. Security pass: rate limiting (per-IP fixed-window, no new deps) added to LucyServer-go (3 endpoints) and GamingAgent-go (3 Nemotron endpoints); security headers middleware (X-Content-Type-Options, X-Frame-Options, Referrer-Policy) on all routes in both servers; nftables SSH hardened to tailscale-only. Both Go servers build clean. Prior work (Android Companion + Syncthing pass): Android Companion + Syncthing pass: `SwarmConnection.kt` (host/port/token single source of truth) actually created and wired into RemotePcScreen/InteractiveTerminalScreen/AppRepository/MainViewModel for real this time (the 2026-09-07 doc claimed this was done; it wasn't — files matched their pre-fix archive byte-for-byte). Also fixed AppRepository's `/api/run_command` call sending zero auth header. Verified the whole app with a real `./gradlew assembleDebug` (BUILD SUCCESSFUL) and `LucyServer-go` with `go build` — both previously unverifiable in-session. Separately, Syncthing was not running at all and its config pointed at the now-gone `/run/media/i30ltz/LUCILLE` mount; repointed to `/mnt/Lucy`, recreated the missing `.stfolder` marker, and rebuilt `30-source/.stignore` (missing entirely — was letting 11GB of Rust `target/` + 1.6GB `flutter-sdk` toward phone sync instead of the intended ~40MB). Folder now syncs clean at idle/~75MB. Systemd boot spam and multi-monitor blinking under investigation on physical hardware this session — swarm-ui/gaming-agent/lucy-server.service given `StartLimitBurst=3`/`StartLimitIntervalSec=60` (previously unbounded restart loop); root cause of the crash-loop itself still unconfirmed, pending journalctl output from the actual boot. Prior work (2026-09-11 security pass, desktop shell, lock screen) unchanged — still remaining: hardware boot test, waybar taskbar, garden real photos, garden cipher settings page, WebAuthn hardware test, GoogleWorkspaceService build-script staging.*
