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
- [~] **Pipelined asynchronous speculative execution** — Claude Code (Opus 5.5), landed in lucille-core 2026-09-25
  - `SwarmRouter::set_pipeline_backends()` injects real Kimi/DeepSeek/GLM clients; unconfigured router falls back to simulated models and sets `PipelineResult::used_mock_backends` so mock output can't pass as real
  - `StreamingBlockBuffer` rewritten: literal/comment-aware brace lexer (state survives chunk splits); Python mode fixed (was emitting every line as a block) — splits at top-level def/class, decorators stay with their def
  - Fail-closed: throwing auditor rejects its block; throwing stream → `pipeline_complete=false` + error, in-flight audits still drained
  - Tests: `test_speculative_pipeline_entropy_and_pruning()` (21 assertions) pass; ThreadSanitizer clean for pipeline code
  - Remaining: real HTTP/SSE clients for Kimi/DeepSeek/GLM (lucille-core has no HTTP client) and an IPC command in `LucilleEngine::handle_ipc_command()` to reach it — engine owns no `SwarmRouter` yet
- [ ] **Concurrent safety audit while patch streams**
- [ ] **Triage & metric logging (GLM aggregator)**
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
  - Fail closed: no voters configured → high-risk diffs blocked; throwing voter = reject. Real voters via `SwarmRouter::set_consensus_backends()` (needs the same real HTTP clients as 2.4 pipeline)
  - Tests: `test_consensus_gate_high_risk_diffs()` 13 assertions pass; suite 129 pass / 2 pre-existing fail

### 2.5 Companion App & Tailscale Mesh
- [>] **Background push notifications for HITL approvals** — CLAIMED by Claude Code (Opus 5.5) 2026-09-25 09:51 — user chose Android foreground service (no FCM)
  - `hitl_challenge` events already broadcast on :9091; now only to authenticated, heartbeat-verified clients (see heartbeat below)
  - Not done: (1) nothing launches `TelemetryDaemon` — `LucilleEngine` doesn't own one; (2) the phone client lives in the separate I30LTZ Companion repo (the /mnt/Lucy copy was archived 2026-09-25). **User decision needed:** FCM push (needs Google/Firebase, works when app is killed) vs. an Android foreground service holding the Tailscale WebSocket (no Google, persistent notification, more battery)
- [x] **5-second WebSocket ping/pong heartbeat on Tailscale :9091** — Claude Code (Opus 5.5), lucille-core `TelemetryDaemon` 2026-09-25
  - Ping every 5 s (`set_heartbeat()`), client dropped with close 1001 after 3 missed pongs; client pings answered; stalled handshakes dropped after 5 s. OkHttp/browser clients answer pings automatically
  - **Security fixes (the socket accepts HITL approve, process freeze and Btrfs rollback):** auth token was stored but never checked — upgrades now require `Authorization: Bearer`, `X-Swarm-Auth` or `?token=` (constant-time compare), and `start()` refuses empty/default tokens; failed Tailscale bind fell back to `0.0.0.0` — now loopback; Tailscale IP detection narrowed from any `100.*` to 100.64.0.0/10
  - Rewritten as one `poll()` thread owning all sockets (was detached per-client threads that could outlive the object, and a stop()/loop fd race); RFC 6455 frame parser (masking required, 64 KiB cap, no fragments); a malformed command no longer terminates the daemon
  - Tests: 17 assertions with a real WebSocket client; suite 146 pass / 0 fail; ThreadSanitizer clean ×3
- [~] **Workspace parity validation (bidirectional manifest check)** — implemented 2026-09-25. `70-scripts/swarm_workspace_parity.py` performs a read-only SHA-256 comparison in both directions and reports changed, source-only and mirror-only paths. It excludes secrets, SDKs and generated artifacts, never follows symlinks, and writes private atomic manifests outside both trees. Five fixture tests pass. Actual `/mnt/Lucy` versus reference-mirror comparison pending because `/run/media/i30ltz/lucy-master` was not mounted.
- [~] **Continuous mirror integrity verification (SHA-256 tree comparisons)** — staged 2026-09-25 as a hardened oneshot service and six-hour persistent timer. It requires both roots to be real mountpoints and cleanly reports `skipped` when the encrypted mirror is absent, preventing an empty mount directory from becoming a false pass. Unit validation passes; fresh ISO boot/timer execution and a mounted-mirror result remain pending. See `70-scripts/WORKSPACE_PARITY.md`.

### 2.6 System Tuning
- [~] **TCP MSS clamping on Tailscale via nftables** — implemented 2026-09-24. IPv4/IPv6 downward-only MSS caps on tunnel ingress/egress cover SYN and SYN-ACK, local traffic and forwarding. Fixed existing interface-index matches that made the full firewall fail to load before `tailscale0` existed; added missing live-ISO firewall startup link (installer already enables it). Full rules load and 56 real-packet/checksum cases pass in an isolated network namespace. Fresh SWARM boot and physical tailnet transfer pending; Tailscale installation remains separate. See `70-scripts/TAILSCALE_MSS.md`.
- [~] **EPP dynamic power script** (`/usr/lib/swarm/epp-tune.sh`) — implemented and wired to boot-enabled `swarm-epp.timer` (2026-09-21). AC/battery policy, advertised-value validation, readback, existing power-manager precedence, configuration and status mode complete. Nine fixture tests and systemd unit validation pass; CachyOS read-only status correctly yields to power-profiles-daemon. Fresh SWARM boot/hardware write verification pending. See `70-scripts/EPP_POWER_POLICY.md`.

### 2.7 Developer Grants
- [ ] **AMD AI Developer Program** ($100 credits)
- [ ] **NVIDIA Inception Startup Program** (cloud credits, GPU pricing, training)

---

## 3. Suggested Build Order

> Updated 2026-09-24 v6.2.72 — items 1–2 and NVIDIA 4.1–4.8 are **done**

1. ~~Publish/boot the desktop repair; fix session cleanup on launcher death~~ **DONE (2026-09-24)** → verify watchdog + Gamescope FSR on fresh ISO boot
2. ~~Wire Git-diff checkpoint journaling into `SwarmRouter::route_and_execute()`~~ **DONE (2026-09-24)**
3. ~~POSIX shared memory telemetry ring buffer~~ **DONE (2026-09-24)**
4. ~~Multi-client epoll IPC broker~~ **DONE (2026-09-24)**
5. ~~Speculative pipeline + semantic entropy filtering + dynamic context pruning~~ **DONE (2026-09-25)** — real model HTTP clients + engine IPC entry point still open (see 2.4)
6. ~~Dual-model 2-of-2 consensus gating~~ **DONE (2026-09-25)** — real voter clients pending with 2.4
7. **Companion** — heartbeat DONE (2026-09-25); parity/integrity staged (other agent); push notifications need FCM-vs-foreground-service decision + engine to launch TelemetryDaemon
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
