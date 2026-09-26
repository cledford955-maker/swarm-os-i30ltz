# SWARM OS / Lucille — Master Implementation Checklist

> Rebuilt 2026-09-19 · Updated 2026-09-24 v6.2.72. Completed work is preserved in the **Landed** section so nothing is lost. Open work is re-evaluated and prioritized. New NVIDIA blueprint/skill work is added at the end.

---

## Status Legend

- `[x]` Landed / verified
- `[~]` Partially landed (staged, built, or wired but missing verification/production call site)
- `[ ]` Open / not started
- `[!]` Blocked (reason noted)
- `[>]` **Claimed / in progress by an AI agent** — format: `[>] Item — CLAIMED by <agent> <YYYY-MM-DD HH:MM>`. Other agents: skip claimed items; if a claim is >24h old with no progress, ask the user before taking it over.

---

## 1. Landed — Do Not Rebuild (preserve)

### System Reliability & Boot
- [x] **systemd hardware watchdog drop-in staged**
  - File: `40-iso-profile/swarm_os_iso_profile/airootfs/etc/systemd/system.conf.d/50-watchdog.conf`
  - Contents: `RuntimeWatchdogSec=30s`, `RebootWatchdogSec=5min`, `KExecWatchdogSec=5min`
  - Remaining: ISO boot verification (`systemctl show | grep -i watchdog` on installed system)

- [x] **Landlock LSM filesystem sandboxing**
  - Location: `30-source/lucille-core`
  - Restricts child workers to read-only root, write-only workspace
  - Verified: `cmake --build 30-source/lucille-core/build` + `ctest --test-dir 30-source/lucille-core/build` pass

- [x] **Git-diff checkpoint journaling library**
  - Location: `30-source/lucille-core` (SafetyGate / checkpoint primitives)
  - Builds and tests pass
  - Gap closed 2026-09-24: `SwarmRouter::route_and_execute()` now calls `SafetyGate::checkpoint_and_apply()` — see Landed item below

### ISO / Installer / Boot (from SWARM_AI_FEATURES.md)
- [x] Auto-version bump on every build
- [x] GamingAgent-go, LucyServer-go, Flutter shell, swarm-slint, lucille-core staged into ISO
- [x] `.env` baked into airootfs
- [x] LUCILLE drive + 5 recovery/related drives in live/installed fstab
- [x] `profiledef.sh` cleaned, mkarchiso work-dir ownership trap
- [x] Live sudoers `10-wheel`, auto-login, GRUB theme, Btrfs subvolumes
- [x] Dual GRUB themes prepared (CachyOS + SWARM), activation pending user sudo
- [x] Boot-gate fixes: executable perms, nonblocking secrets, GRUB theme mirroring
- [x] Installed graphical shell handoff via `airootfs.tar`
- [x] Direct graphical install entry on ORIGIN desktop

### Security (2026-09-19 pass)
- [x] Lock-screen bypass fixes (corner-tap + CHANGE CIPHER gated by admin password)
- [x] Rate limiting on `/api/settings/verify_login_password` and `/api/settings/totp/check`
- [x] `.env` gitignored / never tracked
- [x] Real Ed25519 package signing (`cryptography` package), root key in `20-runtime/secrets/`

### AI / Models / UI (2026-09-19)
- [x] Live OpenRouter model catalog + static dead-model filtering
- [x] Default coding swarm → Kimi K2.6, Qwen 2.5 Coder 32B, GLM 5.3, DeepSeek R1
- [x] `defaultSwarmId` actually read by `agentModelProvider`
- [x] `nemotron-swarm` default for gaming/system/eval agents
- [x] Lucille/Forge/Droid client-side coding pipeline verified end-to-end
- [x] swarm-slint Forge tab + real LucyServer `/lucy` SSE; Gaming no longer default
- [x] Real background art wired; hex-tile 3D painter + per-tile images
- [x] Shared-memory sync (`swarm-memory`) built and tested v1.0.0
- [x] **Rich `/api/health` endpoint in LucyServer-go** (2026-09-24) — returns `status`, `version`, `build_date`, `uptime_seconds`, `lucy_mount_gb_used/total`, and `services` map (`lucy_server`, `gaming_agent`, `google_workspace`). Registered at both `/health` and `/api/health`. Fixes offline-fabrication warnings across Companion, wallpaper service, and Lucille Assistant.
- [x] **SHA-256 checksum + optional GPG signature on ISO build** (2026-09-24) — `build_swarm_iso.sh` now generates `<iso>.sha256` after every successful publish; if `swarm-sign@swarmos.dev` GPG key exists, also emits `<iso>.sha256.asc`. Fixes audit finding au7 (no integrity artifact alongside ISO).
- [x] **SwarmHealthService + OSD HUD + Backend page wired to /api/health** (2026-09-25) — new `SwarmHealthService` polls LucyServer's `/api/health` every 10s, parses version/uptime/disk/services into `SwarmHealthSnapshot`, streams via Riverpod. OSD HUD now shows LUCY/GAME backend indicators, LUCILLE disk gauge, and SWARM version badge alongside existing CPU/RAM/temp. Staleness guard: >60s without a response → offline state, never stale numbers. Backend page updated: LucyServer entry corrected from `.NET 8 Kestrel` to `Go`; GamingAgent (port 8401) added; Tailscale port fixed (was 9091, same as lucille_core). 5 unit tests, zero analysis errors. Fixes daily-audit item av-1 (health endpoint unwired) and §3 upgrade #1 + #4.

### Companion / Android
- [x] **Four private project repositories with ten-minute autosync** (2026-09-24): SWARM OS, I30LTZ Recovery OS, I30LTZ Companion, and Lucille Assistant each have their own GitHub destination. All four pushes verified; backup-file and oversized-unpublished-archive blockers repaired. See `70-scripts/GITHUB_AUTOSYNC.md`.

### Wire-up pass (2026-09-25, Opus 4.7)
- [x] **OTA update check end-to-end** — LucyServer-go `handlers/updates.go` exposes `GET /api/updates/check`; scans `/mnt/ventoy/ISO/SWARM_OS` and `/mnt/Lucy/10-releases` for the newest semver ISO (defeats a stale `latest.txt`), pulls `.sha256` sidecar when present, never fabricates when no store is mounted. 8 Go tests. Flutter `SwarmUpdateService` polls every 15 min via `swarmUpdateProvider`; `top_bar` renders a `↑ v<latest>` pill (GiB + reboot hint tooltip) when `update_available`. 4 Flutter tests, `flutter analyze` clean.
- [x] **Waybar taskbar for labwc** — `waybar` added to `packages.x86_64`; `airootfs/etc/xdg/waybar/{config,style.css}` staged (bottom-anchored, wlr/taskbar, workspaces, clock, network, battery, temperature, tray, transparent dark-cyan theme); labwc autostart launches it before the Flutter shell; `swarm-ui-cleanup.sh` pkills it. `test_desktop_boot_contract` now guards both autostart line and package presence. 12 boot-contract tests pass.
- [x] **Google Workspace OAuth proxied through LucyServer** — `handlers/google_oauth.go` on LucyServer-go proxies `/api/google/auth/{status,url,upload_credentials,exchange,logout}` to the .NET service on 8402. Preserves upstream status codes and multipart Content-Type for `credentials.json` upload, forwards query strings, returns 503 + structured JSON when upstream is unreachable. Flutter `GoogleWorkspaceService` client covers the full flow with an `offline` sentinel. 6 Go tests + 5 Flutter tests, analyze clean.
- [x] **Steam library persistence** — `services/steam_cache.go` wraps GetSteamLibrary with atomic JSON writes at `BaseDir()/steam_library.json`. When upstream returns error/empty and cache exists, the response carries `cached=true`, `cached_at` (RFC3339) and `upstream_error` so the dashboard keeps rendering during the 2026-09-20 Steam API key revocation. No fabrication when no cache exists. 7 Go tests cover roundtrip, missing/corrupt files, `isSteamPayloadUsable` table, upstream-fail-with-cache, upstream-fail-no-cache, atomic rewrite.
- [x] **Additional gaming news sources** — `services/news.go` now pulls GamingOnLinux + Phoronix RSS in both `GetNews()` and `GetNewsFeed()` alongside GameSpot/Boiling Steam/Linux Gaming News. No API keys required; feeds public. Closes the "GamingOnLinux RSS, Phoronix" backlog item.
- [x] **Lucille deals-aware context** — `GamesService.GetTopDeals(n)` fetches the current cheapest CheapShark Steam deals; `LucilleService.WithGamesService()` injects it and `buildContextMessages` appends a "Current Steam deals" block so Lucille can quote specific sale prices when recommending games. Best-effort — deals fetch failure doesn't block chat. Wired in `GamingAgent-go/main.go`.
- [x] **Lucille cross-agent calendar context** — `fetchUpcomingCalendarSummary()` queries GoogleWorkspaceService `/cal/events` (7-day, 6-event limit); `buildContextMessages` appends "Upcoming calendar events" system message so Lucille avoids suggesting a long gaming session before something scheduled. 5 unit tests. Service-down / unauthenticated / empty / malformed JSON all silently skip — chat never blocks on the calendar. Weather context still open.
- [x] Monitor tab device selector, actions, pooled fleet resources
- [x] Dr. Boltz avatar screen
- [x] IDE back-navigation, live terminal over WebSocket
- [x] `SwarmConnection.kt` created and wired
- [x] Cross-origin RCE closed on both Go servers
- [x] Mock/fake-data purge across Flutter, Kotlin, Go, Rust

---

## 2. Open / Partial Work (re-evaluated)

### Urgent boot blockers — 2026-09-24
- [~] **Kiosk terminal collision and non-executable Flutter binary** — reproduced in an existing ISO VM and repaired in source/staging. ReserveVT moved from tty1 to tty6, getty/Plymouth handoff ordered, missing executable modes added to profiledef. Modified guest rendered Flutter splash and both backends returned HTTP 200. Fresh canonical ISO and physical boot pending; see `70-scripts/DESKTOP_BOOT_REPAIR.md`.
- [x] **Desktop session cleanup on launcher death** — `KillMode=control-group`, `KillSignal=SIGTERM`, `TimeoutStopSec=10` added to `swarm-ui.service`; `ExecStartPre` pkill clears stale labwc/swarm_flutter before restart; `ExecStopPost` mirrors cleanup. `ExecStart` updated to `dbus-run-session -- /usr/bin/swarm-session`. Scope-lifecycle fix landed 2026-09-24. **Superseded 2026-09-25:** `pkill -u swarm` lines replaced by `/usr/lib/swarm/swarm-ui-cleanup.sh` which reads the desktop user from the unit (so it works for both `swarm` and `i30ltz`), terminates the tty1 logind session scope (catching swarm-slint, which the old lines missed), and escalates to SIGKILL after 3s. 11 boot-contract tests.

### 2.1 System Reliability
- [~] **Verify systemd hardware watchdog on installed SWARM OS**
  - File already staged; needs a real boot test and `systemctl show | grep -i watchdog`
  - **ISO staging audit 2026-09-25 (Opus 4.6):** `50-watchdog.conf` verified in `airootfs/etc/systemd/system.conf.d/` with correct `RuntimeWatchdogSec=30s`, `RebootWatchdogSec=5min`, `KExecWatchdogSec=5min`. `lucille-core` binary re-staged with HTTP/SSE client code (1.3 MiB, linked against libcurl). All 19 systemd units in `multi-user.target.wants` verified (incl. lucille-core.service). 4 timers in `timers.target.wants`. No dangerous symlinks to lucy-master. `swarm_os.env.gpg` absent (expected — generated at seal time, not in repo). Runtime deps (libcurl, libcrypto, libssl, libsqlite3) satisfied via transitive deps of `curl` in `packages.x86_64`. All 4 Go/Flutter/Slint/Rust binaries present in `/opt/swarm_os/`. GRUB theme, fstab (6 mounts), nftables, AppArmor profiles, containers config, sudoers, labwc autostart all present. Remaining: `sudo mkarchiso` + physical boot

- [~] **Gamescope dynamic FSR upscaling**
  - `airootfs/usr/bin/swarm-session` created 2026-09-24; **rewritten 2026-09-25** — Gamescope is now opt-in (`SWARM_GAMESCOPE=1`), not auto-enabled when present. Original flags (`--width`, `--nested`) are invalid in gamescope 3.16.25; replaced with real flags (`--nested-width`, `--expose-wayland`). Default path runs labwc directly — no Gamescope wrapper by default.
  - `profiledef.sh` updated: `["/usr/bin/swarm-session"]="0:0:755"` ensures executable bits survive mkarchiso `--no-preserve`.
  - Remaining: fresh ISO build + physical boot verification that FSR is active when `SWARM_GAMESCOPE=1`

### 2.2 Change Journaling & Rollback
- [x] **Router regression fixed 2026-09-25 (Claude Code):** `test_swarm_router_two_tier_speculation` had 2 failures. Two causes: the mock Kimi patch had a corrupt hunk header (`@@ -1,5 +1,6 @@` over 2→3 lines), and with empty `workspace_dir` `verify_git_apply_check()` ran `git apply --check` against the current directory. Empty workspace now does a syntax-only `git apply --stat` (no files touched); mock hunk corrected.
- [x] **IpcServer shutdown race fixed 2026-09-25 (Claude Code):** `shutdown()` closed epoll/wake/client fds while `run_event_loop()` still used them. The loop now owns the fds and closes them on exit; `shutdown()` only signals and waits (or cleans up itself if no loop ran). ThreadSanitizer clean.
- [x] **Wire Git-diff checkpoint journaling into production execution path** — landed 2026-09-24
  - `SwarmTaskRequest` extended with `workspace_dir` field; `SwarmTaskResponse` extended with `checkpoint_id`
  - `SwarmRouter::route_and_execute()` now calls `SafetyGate::checkpoint_and_apply()` when `workspace_dir` is non-empty: snapshot → dry-run → apply → auto-rollback on regression failure
  - `resp.checkpoint_id` carries the git SHA; callers must confirm via `CheckpointJournal::confirm_checkpoint()` after tests pass or `rollback_to_checkpoint()` on failure

### 2.3 Lucille C++ Core Engine
- [x] **POSIX shared memory telemetry ring buffer** — landed 2026-09-24
  - `shm_telemetry.hpp/.cpp` verified in `lucille-core`: 256-slot lock-free seqlock ring buffer over `/dev/shm/swarm_telemetry_shm`
  - `SwarmRouter` opens writer on construction; posts cpu_load/agents/ram/vram snapshot via `sysinfo()` after every `route_and_execute()` call
  - `test_shm_telemetry_ring_buffer()` in `tests/test_engine.cpp`: write×3 → read_latest → value-check → ring wrap-around (kShmCapacity+1 writes), all passing

- [x] **Multi-client epoll IPC broker** — landed 2026-09-24
  - `ipc_server.cpp` uses `epoll_create1` + `EPOLLET` + `drain_accept_queue()` + `drain_client()` + eventfd shutdown; N clients with zero per-client threads
  - `test_ipc_epoll_multi_client()` in `tests/test_engine.cpp`: two concurrent AF_UNIX clients send PING_A/PING_B simultaneously and receive correct PONG replies; shutdown + unlink verified, all 4 assertions pass

### 2.4 Multi-Model Swarm Routing
- [x] **Pipelined asynchronous speculative execution** — Claude Code (Opus 5.5), landed in lucille-core 2026-09-25
  - `SwarmRouter::set_pipeline_backends()` injects real Kimi/DeepSeek/GLM clients; unconfigured router falls back to simulated models and sets `PipelineResult::used_mock_backends` so mock output can't pass as real
  - `StreamingBlockBuffer` rewritten: literal/comment-aware brace lexer (state survives chunk splits); Python mode fixed (was emitting every line as a block) — splits at top-level def/class, decorators stay with their def
  - Fail-closed: throwing auditor rejects its block; throwing stream → `pipeline_complete=false` + error, in-flight audits still drained
  - Tests: `test_speculative_pipeline_entropy_and_pruning()` (21 assertions) pass; ThreadSanitizer clean for pipeline code
  - **Engine wiring landed 2026-09-25 (Opus 4.6):** `LucilleEngine` now owns `SwarmRouter`; `start()` creates the router and injects the HITL approver from `request_human_approval()`. IPC commands `route_task` and `run_pipeline` (JSON over the Unix socket) forward to the router. `engine.route_task()` and `engine.run_pipeline()` are the public C++ API.
  - **Real HTTP/SSE model clients landed 2026-09-25 (Opus 4.6):** `http_client.hpp/.cpp` (libcurl wrapper: `post_json()` + `post_sse()` with SSE line parser surviving chunk splits); `openrouter_backends.hpp/.cpp` (5 backends: Kimi streaming via `post_sse()`, DeepSeek audit + GLM triage via `post_json()`, 2 consensus voters). Thread-safe (each call creates its own HTTP request). `OpenRouterBackends` constructed from `OpenRouterConfig` (API key, model IDs); injected into `SwarmRouter` via `set_pipeline_backends()` + `set_consensus_backends()`. Engine auto-wires when `OPENROUTER_API_KEY` env var is set. 180 tests pass / 0 fail
- [x] **Concurrent safety audit while patch streams** — Claude Code (Opus 4.6) 2026-09-25
  - New `SwarmRouter::route_pipeline_full()` runs the complete streaming pipeline end-to-end: Kimi streams → DeepSeek audits each block concurrently → assemble approved blocks → 2-of-2 consensus gate on the assembled patch → HITL phone approval for high-risk targets → checkpoint/apply with auto-rollback
  - Bridges the gap between the streaming pipeline (which only audited blocks) and the safety chain (which only ran in the legacy sequential path)
  - All blocks rejected by audit → early exit; high-risk assembled patch blocked without consensus voters; consensus alone insufficient without HITL; full chain passes only when all layers approve
  - 17 new test assertions covering the full pipeline chain, 172 pass / 0 fail, TSan clean (2 pre-existing ProcessManager warnings only)
- [x] **Triage & metric logging (GLM aggregator)** — Claude Code (Opus 4.6) 2026-09-25
  - `SwarmRouter::log_pipeline_metrics()` emits structured JSON to stdout on every pipeline run: task ID, block counts (total/passed/rejected), pipeline latency, GLM report, compiler warnings/errors/token density, consensus/HITL/mock flags, success status
  - Same method pushes a telemetry snapshot to the POSIX shared memory ring (`/dev/shm/swarm_telemetry_shm`) so the Flutter OSD HUD can display pipeline activity
  - Logging fires on every exit path (success, audit failure, consensus block, HITL denial, checkpoint failure) so no pipeline run goes unrecorded
- [x] **Semantic entropy filtering in context ingestion** — Claude Code (Opus 5.5) 2026-09-25
  - `route_speculative_pipeline()` now runs compiler logs through `EntropyFilter::clean()` before GLM ingests them (diagnostics via `SwarmRouter::last_log_filter()`); `VectorMemoryEngine::insert_chunk_filtered()` already filters memory chunks
  - `clean()` fixes: `[1] error:` no longer dropped as a progress bar; blank separators no longer deduped (paragraphs were merging); `lines_out` counts emitted lines after `max_chars` cap
- [x] **Dynamic context pruning via score dropoff** — Claude Code (Opus 5.5) 2026-09-25
  - `EntropyFilter::prune_by_distance_dropoff()` replaced: old rule kept only hits closer than mean−1.5σ (usually just 1 of 5 — discarded relevant context). Now cuts at the largest outlier gap between sorted distances; evenly spread results all kept
  - Preserves RRF order (old code re-sorted by distance); `hybrid_search()` exempts keyword-only hits (placeholder distance 1.0) so sparse recall isn't thrown away
- [x] **Dual-model 2-of-2 consensus gating for high-risk diffs** — Claude Code (Opus 5.5), landed in lucille-core 2026-09-25
  - Security fix: `ConsensusGate::classify_high_risk()` lowercased the diff but not the patterns, so `ExecStart=`, `CAP_SYS_ADMIN`, `INPUT DROP` etc. never matched — a capability grant in a non-obvious path bypassed the gate. Now case-insensitive; removed lines are checked too (deleting a DROP policy is flagged)
  - `consensus_gate.cpp` was missing from CMakeLists (never compiled) — added
  - Wired into `SwarmRouter::route_and_execute()` after the DeepSeek audit, before checkpoint/apply; classifies `target_file` as well as the diff. Response carries `high_risk`, `consensus_approved`, `consensus_triggers`
  - Fail closed: no voters configured → high-risk diffs blocked; throwing voter = reject. Real voters via `SwarmRouter::set_consensus_backends()` — now wired to OpenRouter Kimi/DeepSeek via `openrouter_backends.cpp`
  - Tests: `test_consensus_gate_high_risk_diffs()` 13 assertions pass; suite 129 pass / 2 pre-existing fail

### 2.5 Companion App & Tailscale Mesh
- [x] **Companion GitHub sync fixed 2026-09-25 (Claude Code, user-approved):** `git subtree push` (which after the archive/restore produced a commit carrying the whole SWARM OS history) replaced in `auto_sync_github.sh` by snapshot sync for all three app repos: fetch remote `main`, skip if trees match, else one `commit-tree HEAD:<prefix> -p <remote tip>` pushed fast-forward. Never force-pushes; missing folder fails loudly. Verified: companion remote 14→15 commits (parent = old tip 7a60f48), recovery and assistant up to date.
- [~] **Background push notifications for HITL approvals** — Claude Code (Opus 5.5) 2026-09-25; user chose an Android foreground service over FCM. Built and unit-tested end to end; phone install + SWARM launch pending
  - **Companion restored:** `30-source/android_companion/swarm_os-companion` (current 09-21 copy, 71 .kt) moved back from `99-archive/companion-legacy-2026-09-25/` (the 06:49 archive took both copies; the stale 09-15 `(seperate-related-project)` copy stays archived)
  - **Phone:** `HitlApprovalService` (specialUse foreground service) holds an authenticated OkHttp WebSocket to `ws://<host>:9091` (X-Swarm-Auth = same token as LucyServer), 15 s client pings, 2→60 s reconnect backoff, instant retry when the network returns, 401 → "update token" + 5 min retry. `hitl_challenge` → high-priority notification (lock screen hides the command) with **Deny** (one tap) and **Review**; `HitlApprovalActivity` requires biometric/screen lock to **Approve**, refuses with no screen lock, and closes on expiry. Toggle + live status under Remote PC; restarts after boot or app update. `./gradlew assembleDebug` OK; merged manifest verified
  - **PC (lucille-core):** `LucilleEngine` owns `HitlSecurityManager` + `TelemetryDaemon`, starts :9091 when `SWARM_AUTH_TOKEN` is set, and adds `request_human_approval()` (fails closed). `SwarmRouter::set_hitl_approver()` — high-risk diffs now need 2-of-2 consensus **and** a human; unset approver blocks. Pending challenges replayed to phones that reconnect; command JSON-escaped; challenge IDs 96-bit random (were counter+`rand()`); daemon also refuses the public `swarm-token-2026` token. Smoke test: engine binds the Tailscale IP only. Suite 155 pass / 0 fail ×3, TSan clean
  - **Installed 2026-09-25** as 6.2.21 (versionCode 81 — phones had an older 09-07 build numbered 80) on A67L Gen2 (USB) and Samsung SM-S176V (wireless adb, 192.168.1.116). Same debug key → in-place update; Room 1→2 migration verified with all rows kept; DB backups in `99-archive/companion-phone-backup-2026-09-25/`. Also fixed another agent's duplicate `MainViewModel.onCleared()` that broke the build
  - **SWARM launch:** new `airootfs/etc/systemd/system/lucille-core.service` (enabled; User=swarm; reads `/run/swarm_os.env` → real SWARM_AUTH_TOKEN; waits ≤30 s for tailscale0; IPC socket in /run/lucille). Existing nftables already allows :9091 only on tailscale0
  - Remaining: turn on **Remote PC → Approval alerts** on each phone (token must be the real SWARM_AUTH_TOKEN, not `swarm-token-2026`); rebuild ISO + boot test
- [x] **5-second WebSocket ping/pong heartbeat on Tailscale :9091** — Claude Code (Opus 5.5), lucille-core `TelemetryDaemon` 2026-09-25
  - Ping every 5 s (`set_heartbeat()`), client dropped with close 1001 after 3 missed pongs; client pings answered; stalled handshakes dropped after 5 s. OkHttp/browser clients answer pings automatically
  - **Security fixes (the socket accepts HITL approve, process freeze and Btrfs rollback):** auth token was stored but never checked — upgrades now require `Authorization: Bearer`, `X-Swarm-Auth` or `?token=` (constant-time compare), and `start()` refuses empty/default tokens; failed Tailscale bind fell back to `0.0.0.0` — now loopback; Tailscale IP detection narrowed from any `100.*` to 100.64.0.0/10
  - Rewritten as one `poll()` thread owning all sockets (was detached per-client threads that could outlive the object, and a stop()/loop fd race); RFC 6455 frame parser (masking required, 64 KiB cap, no fragments); a malformed command no longer terminates the daemon
  - Tests: 17 assertions with a real WebSocket client; suite 146 pass / 0 fail; ThreadSanitizer clean ×3
- [x] **LucyServer companion WebSocket heartbeat** — Claude Code (Opus 4.6) 2026-09-25
  - New `/api/companion/ws` endpoint on LucyServer-go (:5000): companion phones connect, send a JSON hello (`device_id`, `device_name`), server pings every 5s, OkHttp auto-pongs; 10s read deadline closes stale connections. CompanionHub tracks connected companions in-memory
  - `/api/companion/status` REST endpoint: returns connected count and device list
  - Health response gains `companions_connected` field; Flutter OSD HUD shows "PHONE ×N" or "PHONE ✗"
  - Android client: `CompanionHeartbeat.kt` in data/service, started by MainViewModel, 2→60s exponential backoff reconnect, network-loss aware
  - 5 Go tests (hello, hub tracking, status ack, ping receipt, REST status endpoint), all pass
  - Complementary to the lucille-core TelemetryDaemon heartbeat on :9091 (HITL approval socket)
- [~] **Workspace parity validation (bidirectional manifest check)** — implemented 2026-09-25. `70-scripts/swarm_workspace_parity.py` performs a read-only SHA-256 comparison in both directions and reports changed, source-only and mirror-only paths. It excludes secrets, SDKs and generated artifacts, never follows symlinks, and writes private atomic manifests outside both trees. Five fixture tests pass. Actual `/mnt/Lucy` versus reference-mirror comparison pending because `/run/media/i30ltz/lucy-master` was not mounted.
- [~] **Continuous mirror integrity verification (SHA-256 tree comparisons)** — staged 2026-09-25 as a hardened oneshot service and six-hour persistent timer. It requires both roots to be real mountpoints and cleanly reports `skipped` when the encrypted mirror is absent, preventing an empty mount directory from becoming a false pass. Unit validation passes; fresh ISO boot/timer execution and a mounted-mirror result remain pending. See `70-scripts/WORKSPACE_PARITY.md`.

### 2.6 System Tuning
- [~] **TCP MSS clamping on Tailscale via nftables** — implemented 2026-09-24. IPv4/IPv6 downward-only MSS caps on tunnel ingress/egress cover SYN and SYN-ACK, local traffic and forwarding. Fixed existing interface-index matches that made the full firewall fail to load before `tailscale0` existed; added missing live-ISO firewall startup link (installer already enables it). Full rules load and 56 real-packet/checksum cases pass in an isolated network namespace. Fresh SWARM boot and physical tailnet transfer pending; Tailscale installation remains separate. See `70-scripts/TAILSCALE_MSS.md`.
- [~] **EPP dynamic power script** (`/usr/lib/swarm/epp-tune.sh`) — implemented and wired to boot-enabled `swarm-epp.timer` (2026-09-21). AC/battery policy, advertised-value validation, readback, existing power-manager precedence, configuration and status mode complete. Nine fixture tests and systemd unit validation pass; CachyOS read-only status correctly yields to power-profiles-daemon. Fresh SWARM boot/hardware write verification pending. See `70-scripts/EPP_POWER_POLICY.md`.

### 2.7 Developer Grants
- [~] **AMD AI Developer Program** ($100 credits) — drafted 2026-09-25 (Opus 4.6). Application at `90-grants/AMD_AI_DEVELOPER_PROGRAM.md`. Covers ROCm benchmarking for speculative pipeline latency, AVX2→HIP migration path, and CI on Instinct hardware. Remaining: user review, submit via AMD portal
- [~] **NVIDIA Inception Startup Program** (cloud credits, GPU pricing, training) — drafted 2026-09-25 (Opus 4.6). Application at `90-grants/NVIDIA_INCEPTION_STARTUP_PROGRAM.md`. Highlights 8 NIM skills already integrated, consensus pipeline, Landlock sandboxing, companion ecosystem. Covers DGX Cloud credits, preferred GPU pricing, NIM early access, co-marketing. Remaining: user review, submit via NVIDIA Inception portal

---

## 3. Suggested Build Order

> Updated 2026-09-24 v6.2.72 — items 1–2 and NVIDIA 4.1–4.8 are **done**

1. ~~Publish/boot the desktop repair; fix session cleanup on launcher death~~ **DONE (2026-09-24)** → verify watchdog + Gamescope FSR on fresh ISO boot
2. ~~Wire Git-diff checkpoint journaling into `SwarmRouter::route_and_execute()`~~ **DONE (2026-09-24)**
3. ~~POSIX shared memory telemetry ring buffer~~ **DONE (2026-09-24)**
4. ~~Multi-client epoll IPC broker~~ **DONE (2026-09-24)**
5. ~~Speculative pipeline + semantic entropy filtering + dynamic context pruning~~ **DONE (2026-09-25)** — engine IPC entry point wired; real HTTP/SSE model clients landed (2026-09-25 Opus 4.6); libcurl-backed OpenRouter backends for all 5 model functions
6. ~~Dual-model 2-of-2 consensus gating~~ **DONE (2026-09-25)** — real voter clients landed with 2.4 HTTP/SSE clients (Opus 4.6)
7. **Companion** — heartbeats DONE (lucille-core :9091 + LucyServer :5000/api/companion/ws); HITL approvals built end to end (foreground service, 2026-09-25) — phone install + launching lucille-core on SWARM pending; parity/integrity staged (other agent); GitHub subtree-sync hazard needs decision
8. ~~TCP MSS clamping + EPP power script~~ **DONE (2026-09-21/24 — boot verification pending)**
9. ~~NVIDIA blueprints & skills~~ **DONE (4.1–4.8 confirmed 2026-09-24); 4.9–4.10 open**
10. **Grant applications** (parallel — no code dependency)

---

## 4. NVIDIA Blueprints & Skills (new work)

> Goal: turn the existing NVIDIA NIM catalog into first-class, reusable agent capabilities inside Swarm OS, not just a list of model IDs.

### 4.1 Blueprint: NVIDIA NIM Skill Registry
- [x] **Create `lib/skills/nvidia_nim_skill.dart`**
  - Declarative skill definitions for each NIM category:
    - `nvidia/parakeet-ctc-1.1b:free` → speech-to-text
    - `nvidia/riva-tts-fastpitch:free` → text-to-speech
    - `nvidia/embeddings-nv-embed-qa-4:free` → embeddings
    - `nvidia/reranking-nv-embed-rerank-large:free` → reranking
    - `nvidia/cuopt-v1:free` → combinatorial optimization
    - `nvidia/diffusers-sdxl-turbo:free` → image generation
    - `nvidia/cosmos-nemotron-340b:free` → physical AI / world model
    - `nvidia/omniverse-asset-reasoner-70b:free` → USD asset reasoning
  - Each skill: input schema, output schema, default model, fallback model, cost tier

### 4.2 Blueprint: Agent Skill Assignment
- [x] **Extend `Agent` model with `skillIds`**
  - Add `List<String> skillIds` to `lib/models/agent.dart`
  - Assign relevant skills:
    - Lucille/Forge/Droid: coding + file-write
    - Dr. Boltz / system agents: Nemotron eval + system optimization
    - GamingAgent: NVIDIA gaming/eval pipeline (already direct)
    - UI Tandem: image generation + vision
    - Antigravity: planning + tool use + subagent orchestration

### 4.3 Blueprint: Skill Router
- [x] **Create `lib/services/skill_router.dart`**
  - Maps a requested skill + agent context to a concrete `SwarmModel`
  - Respects `ProviderId.nvidia` free tier first, then OpenRouter fallback
  - Uses `LiveModelCatalogService` to validate the model still exists before calling

### 4.4 Blueprint: NVIDIA STT/TTS Voice Pipeline
- [x] **Fully implemented** (confirmed 2026-09-24)
  - `transcribe(File audio)` → Parakeet CTC via OpenRouter `/audio/transcriptions`
  - `synthesize(String text)` → Riva FastPitch TTS via OpenRouter `/audio/speech`
  - Cache results in app temp dir; dedicated `lib/services/nvidia_voice_service.dart` facade exists and is wired

### 4.5 Blueprint: NVIDIA Embedding/Rerank RAG
- [x] **Fully implemented** (confirmed 2026-09-24)
  - `embed(List<String> chunks)` → NV-Embed-QA 4
  - `rerank(String query, List<String> chunks)` → NV Rerank Large
  - Embeddings stored in `sqlite-vec`; dedicated `lib/services/nvidia_rag_service.dart` facade exists

### 4.6 Blueprint: NVIDIA Image Generation Skill
- [x] **Fully implemented** (confirmed 2026-09-24)
  - `generateImage(String prompt)` → SDXL Turbo NIM
  - Dedicated `lib/services/nvidia_image_service.dart` facade exists

### 4.7 Blueprint: NVIDIA cuOpt Optimization Skill
- [x] **Fully implemented** (confirmed 2026-09-24)
  - cuOpt NIM wired for scheduling / resource allocation problems
  - Dedicated `lib/services/nvidia_cuopt_service.dart` facade exists; agent task queue ordering use case included

### 4.8 Blueprint: NVIDIA Cosmos / Omniverse Reasoning
- [x] **Fully implemented** (confirmed 2026-09-24)
  - `simulateWorld(String description)` → Cosmos World Model NIM
  - `reasonUsdAsset(String usdSnippet)` → Omniverse Asset Reasoner
  - Dedicated `lib/services/physics_ai_service.dart` facade exists and is exposed to Antigravity / UI Tandem

### 4.9 Blueprint: NVIDIA NIM Health & Cost Dashboard
- [x] **Add NVIDIA NIM panel to `models_page.dart`** (2026-09-25)
  - Shows live default/fallback route availability from the OpenRouter catalog and the account balance; per-skill quota is explicitly provider-managed because OpenRouter exposes no trustworthy per-model remaining-call count.
  - `SkillRouter` records the last completed call per skill with measured latency, selected model, success/failure, and free/paid fallback state. Prompts, outputs, audio and credentials are never recorded.
  - Dashboard cards surface paid/free fallback before a call and the actual route after a call. Two telemetry tests pass; targeted Flutter analysis is clean.

  - Re-verified 2026-09-25 by Claude Code (Opus 5.5): `nim_skill_telemetry_test.dart` 2/2 pass on repeat runs (one earlier load failure was transient, coincided with a running Flutter daemon); `flutter analyze` clean on models_page, skill_router, nvidia_nim_skill.

### 4.10 Blueprint: ISO / Runtime Staging
- [x] **Document NVIDIA runtime dependencies** (2026-09-25)
  - Added `70-scripts/NVIDIA_RUNTIME.md` with the direct NVIDIA and OpenRouter cloud paths, credentials, local-host prerequisites, and deployment boundary.
  - Recorded the actual target: 16 GB RAM, Intel UHD integrated graphics, no NVIDIA GPU. CUDA / cuDNN / TensorRT / NVIDIA Container Toolkit are not required for hosted calls and remain intentionally absent from the ISO.
  - Local NIM is a future separate-host profile only after model-specific GPU/VRAM and platform validation; cloud-first remains the supported mode on this machine.

---

## 5. Notes & Safety

- **Do not write to `/run/media/i30ltz/lucy-master/`** — it is a read-only reference mirror. All edits go to `/mnt/Lucy/`.
- Before mutating code, create a Git checkpoint if the repo is dirty.
- Update this file as items land; keep the **Landed** section so completed work is never accidentally re-done.

---

*Rebuilt 2026-09-19 from prior `SWARM_OS_IMPLEMENTATION_CHECKLIST.md` and `SWARM_AI_FEATURES.md`.*
*Updated 2026-09-24 v6.2.72 — session work: checkpoint wiring, Gamescope session wrapper, desktop scope-lifecycle fix, rich /api/health, ISO SHA-256/GPG, NVIDIA facade audit.*
*Updated 2026-09-25 — Claude Code (Opus 5.5): speculative pipeline hardened + backend injection, entropy filtering in log ingestion, gap-based context pruning; test suite compile fix (missing socket/mman/cstring headers, TEST_ASSERT msg parens) — 116 pass / 2 pre-existing fail.*
*Updated 2026-09-25 — Claude Code (Opus 4.6): desktop session teardown via logind scope termination; Gamescope launcher made opt-in with valid flags; usr/lib/swarm scripts tracked; SwarmHealthService + OSD HUD + Backend page wired to /api/health; stale profiledef backup removed; ax1/ax2 audit items resolved.*
*Updated 2026-09-25 — Claude Code (Opus 5.5): 2-of-2 consensus gate fixed (case-insensitive classifier bypass), compiled, wired into route_and_execute, fail-closed; 129 pass / 2 pre-existing fail.*
*Updated 2026-09-25 — Claude Code (Opus 5.5): router regression + IpcServer race fixed; :9091 TelemetryDaemon rewritten with auth, heartbeat, loopback fallback; lucille-core 146 pass / 0 fail, TSan clean.*
*Updated 2026-09-25 — Claude Code (Opus 4.6): LucyServer companion WebSocket heartbeat (/api/companion/ws + /api/companion/status), CompanionHub tracking, health.companions_connected, Flutter OSD HUD phone indicator, Android CompanionHeartbeat.kt client; 5 Go + 5 Flutter tests pass.*
*Updated 2026-09-25 — Claude Code (Opus 5.5): companion restored; HITL approval push via Android foreground service + lucille-core engine/router wiring; subtree sync hazard logged.*
*Updated 2026-09-25 — Claude Code (Opus 5.5): companion 6.2.21 installed on both phones; snapshot GitHub sync; lucille-core.service added to ISO.*
*Updated 2026-09-25 — Claude Code (Opus 4.6): "Wire up everything" — LucilleEngine now owns SwarmRouter; HITL approver injected from engine→router; route_pipeline_full() chains streaming audit + consensus + HITL + checkpoint; log_pipeline_metrics() writes structured JSON + SHM telemetry; IPC commands route_task/run_pipeline added. 172 pass / 0 fail, TSan clean.*
*Updated 2026-09-25 — Claude Code (Opus 4.7): OTA update check (`/api/updates/check` scans Ventoy/10-releases, top-bar pill on Flutter shell); waybar taskbar staged into ISO + boot-contract guarded; Google Workspace OAuth proxied through LucyServer with Flutter client + offline sentinel; Steam library persistence cache; GamingOnLinux + Phoronix news sources; Lucille deals-aware context; Lucille cross-agent calendar context via GoogleWorkspaceService. 26 new Go tests + 9 new Flutter tests + 12 boot-contract tests all pass. `flutter analyze` clean on new files.*
