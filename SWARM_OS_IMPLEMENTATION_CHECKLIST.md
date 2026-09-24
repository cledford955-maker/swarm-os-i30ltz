# SWARM OS / Lucille — Master Implementation Checklist

> Rebuilt 2026-09-19. Completed work is preserved in the **Landed** section so nothing is lost. Open work is re-evaluated and prioritized. New NVIDIA blueprint/skill work is added at the end.

---

## Status Legend

- `[x]` Landed / verified
- `[~]` Partially landed (staged, built, or wired but missing verification/production call site)
- `[ ]` Open / not started
- `[!]` Blocked (reason noted)

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
  - Gap: no production call site in `SwarmRouter::route_and_execute()` — see open item below

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

### Companion / Android
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
- [ ] **Desktop session cleanup on launcher death** — fault injection left old labwc/Flutter processes in logind scopes. Automatic SIGHUP restart prototype removed to avoid duplicate sessions; needs a tested scope-lifecycle fix.

### 2.1 System Reliability
- [~] **Verify systemd hardware watchdog on installed SWARM OS**
  - File already staged; needs a real boot test and `systemctl show | grep -i watchdog`

- [!] **Gamescope dynamic FSR upscaling**
  - Blocker: `/usr/bin/swarm-session` launcher is absent from the ISO profile
  - Next step: create `airootfs/usr/bin/swarm-session` with the Gamescope launch args, or document where it lives

### 2.2 Change Journaling & Rollback
- [~] **Wire Git-diff checkpoint journaling into production execution path**
  - Library exists; `SafetyGate::checkpoint_and_apply()` has no caller
  - Target: `SwarmRouter::route_and_execute()`
  - On regression-test failure: auto-rollback to checkpoint

### 2.3 Lucille C++ Core Engine
- [ ] **POSIX shared memory telemetry ring buffer**
  - Target: `/dev/shm/swarm_telemetry_shm`
  - Note: shared-memory *sync* is landed; this item is the high-frequency VRAM/CPU/agent ring buffer inside `lucille-core`

- [ ] **Multi-client epoll IPC broker**
  - Refactor `/tmp/lucille_ipc.sock` from blocking to `epoll_wait()`
  - Verify with two concurrent `socat - UNIX-CONNECT:/tmp/lucille_ipc.sock` sessions

### 2.4 Multi-Model Swarm Routing
- [ ] **Pipelined asynchronous speculative execution**
- [ ] **Concurrent safety audit while patch streams**
- [ ] **Triage & metric logging (GLM aggregator)**
- [ ] **Semantic entropy filtering in context ingestion**
- [ ] **Dynamic context pruning via score dropoff**
- [ ] **Dual-model 2-of-2 consensus gating for high-risk diffs**

### 2.5 Companion App & Tailscale Mesh
- [ ] **Background push notifications for HITL approvals**
- [ ] **5-second WebSocket ping/pong heartbeat on Tailscale :9091**
- [ ] **Workspace parity validation (bidirectional rsync manifest check)**
- [ ] **Continuous mirror integrity verification (SHA-256 tree comparisons)**

### 2.6 System Tuning
- [~] **TCP MSS clamping on Tailscale via nftables** — implemented 2026-09-24. IPv4/IPv6 downward-only MSS caps on tunnel ingress/egress cover SYN and SYN-ACK, local traffic and forwarding. Fixed existing interface-index matches that made the full firewall fail to load before `tailscale0` existed; added missing live-ISO firewall startup link (installer already enables it). Full rules load and 56 real-packet/checksum cases pass in an isolated network namespace. Fresh SWARM boot and physical tailnet transfer pending; Tailscale installation remains separate. See `70-scripts/TAILSCALE_MSS.md`.
- [~] **EPP dynamic power script** (`/usr/lib/swarm/epp-tune.sh`) — implemented and wired to boot-enabled `swarm-epp.timer` (2026-09-21). AC/battery policy, advertised-value validation, readback, existing power-manager precedence, configuration and status mode complete. Nine fixture tests and systemd unit validation pass; CachyOS read-only status correctly yields to power-profiles-daemon. Fresh SWARM boot/hardware write verification pending. See `70-scripts/EPP_POWER_POLICY.md`.

### 2.7 Developer Grants
- [ ] **AMD AI Developer Program** ($100 credits)
- [ ] **NVIDIA Inception Startup Program** (cloud credits, GPU pricing, training)

---

## 3. Suggested Build Order

1. Publish/boot the desktop repair; fix session cleanup on launcher death; verify watchdog on real hardware before Gamescope FSR work
2. Wire Git-diff checkpoint journaling into `SwarmRouter::route_and_execute()`
3. POSIX shared memory telemetry ring buffer
4. Multi-client epoll IPC broker
5. Speculative pipeline + semantic entropy filtering + dynamic context pruning
6. Dual-model consensus gating
7. Companion heartbeat / push notifications / sync integrity
8. TCP MSS clamping + EPP power script
9. NVIDIA blueprints & skills (parallel with above)
10. Grant applications (parallel — no code dependency)

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
- [~] **Implemented inside `SkillRouter`**
  - `transcribe(File audio)` → Parakeet CTC via OpenRouter `/audio/transcriptions`
  - `synthesize(String text)` → Riva FastPitch TTS via OpenRouter `/audio/speech`
  - Cache results in app temp dir
  - Remaining: wire into Lucille chat voice input/output and add dedicated `nvidia_voice_service.dart` facade

### 4.5 Blueprint: NVIDIA Embedding/Rerank RAG
- [~] **Implemented inside `SkillRouter`**
  - `embed(List<String> chunks)` → NV-Embed-QA 4
  - `rerank(String query, List<String> chunks)` → NV Rerank Large
  - Remaining: store embeddings in `sqlite-vec` (existing) and add dedicated `nvidia_rag_service.dart` facade

### 4.6 Blueprint: NVIDIA Image Generation Skill
- [~] **Implemented inside `SkillRouter`**
  - `generateImage(String prompt)` → SDXL Turbo NIM
  - Remaining: add dedicated `nvidia_image_service.dart` facade and display in UI Tandem / Forge preview panel

### 4.7 Blueprint: NVIDIA cuOpt Optimization Skill
- [~] **Implemented inside `SkillRouter`**
  - Wrap cuOpt NIM for scheduling / resource allocation problems
  - Remaining: add dedicated `nvidia_cuopt_service.dart` facade and first use case (agent task queue ordering)

### 4.8 Blueprint: NVIDIA Cosmos / Omniverse Reasoning
- [~] **Implemented inside `SkillRouter`**
  - `simulateWorld(String description)` → Cosmos World Model NIM
  - `reasonUsdAsset(String usdSnippet)` → Omniverse Asset Reasoner
  - Remaining: add dedicated `lib/skills/physics_ai_skill.dart` facade and expose as tools for Antigravity / UI Tandem

### 4.9 Blueprint: NVIDIA NIM Health & Cost Dashboard
- [ ] **Add NVIDIA NIM panel to `models_page.dart`**
  - Show free-tier quota status, latency per NIM, last-used skill
  - Surface when a skill falls back to paid OpenRouter

### 4.10 Blueprint: ISO / Runtime Staging
- [ ] **Document NVIDIA runtime dependencies**
  - CUDA / cuDNN / TensorRT not required for NIM cloud endpoints, but local NIM containers need them
  - Add optional `nvidia-container-toolkit` to ISO packages if local NIMs are desired later
  - Keep cloud-NIM-first to avoid ISO bloat

---

## 5. Notes & Safety

- **Do not write to `/run/media/i30ltz/lucy-master/`** — it is a read-only reference mirror. All edits go to `/mnt/Lucy/`.
- Before mutating code, create a Git checkpoint if the repo is dirty.
- Update this file as items land; keep the **Landed** section so completed work is never accidentally re-done.

---

*Rebuilt 2026-09-19 from prior `SWARM_OS_IMPLEMENTATION_CHECKLIST.md` and `SWARM_AI_FEATURES.md`.*
