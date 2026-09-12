# SWARM OS / Lucille — Master Implementation Checklist

## 1. System Reliability & Display Subsystem

* [x] Enable systemd hardware watchdog
  * `/etc/systemd/system.conf.d/50-watchdog.conf` — `RuntimeWatchdogSec=30s`
  * Applied: `sudo systemctl daemon-reexec` ✓

* [x] Configure Gamescope dynamic FSR upscaling
  * `/usr/bin/swarm-session` — `-F fsr --fsr-sharpness 5 -r 60` ✓

## 2. Kernel-Level Sandboxing (lucille-core, C++)

* [x] Landlock LSM filesystem sandboxing
  * `lucille-core/src/security_sandbox.cpp` — `apply_landlock_sandbox()`
  * `lucille-core/src/process_manager.cpp` — wired into child spawn path
  * Layers on top of seccomp + prctl, does not replace them ✓

## 3. Change Journaling & Rollback

* [x] Atomic Git-diff checkpoint journaling
  * `lucille-core/include/checkpoint_journal.hpp`
  * `lucille-core/src/checkpoint_journal.cpp` — `create_checkpoint()` / `rollback_to_checkpoint()`
  * `lucille-core/src/safety_gate.cpp` — `checkpoint_and_apply()` wired in ✓

## 4. Lucille C++ Core Engine — Shared Memory & IPC

* [x] POSIX shared memory telemetry ring buffer
  * `lucille-core/include/shm_telemetry.hpp` — 256-slot seqlock ring buffer
  * `lucille-core/src/shm_telemetry.cpp` — `shm_open()` + `mmap()` → `/dev/shm/swarm_telemetry_shm`
  * `lucille-core/src/telemetry_daemon.cpp` — writes every 200ms after `collect_system_metrics()`
  * `CMakeLists.txt` — linked with `-lrt` ✓

* [x] Multi-client epoll IPC broker
  * `lucille-core/src/ipc_server.cpp` — edge-triggered epoll loop with eventfd wakeup
  * `lucille-core/include/ipc_server.hpp` — `run_event_loop()`, `drain_accept_queue()`, `drain_client()`
  * Verify: `socat - UNIX-CONNECT:/tmp/lucille_ipc.sock` ✓

## 5. Multi-Model Swarm Routing & Speculative Verification

* [x] Pipelined asynchronous speculative execution (Kimi 2.6 Coder streaming)
  * `lucille-core/include/speculative_pipeline.hpp` — `StreamingBlockBuffer` + `SpeculativePipeline`
  * `lucille-core/src/speculative_pipeline.cpp` — brace-depth block detector, feeds chunks as they land ✓

* [x] Concurrent safety audit (DeepSeek-R1 parallel invariant checking)
  * Each completed block dispatched via `std::async` immediately — audits run while Kimi is still streaming ✓

* [x] Triage & metric logging (GLM 5.6)
  * `mock_glm_triage()` runs in a third `std::async` thread from t=0, reports warnings/errors/token density ✓
  * `SwarmRouter::route_speculative_pipeline()` orchestrates all three threads ✓
* [x] Semantic entropy filtering in context ingestion
  * `lucille-core/include/entropy_filter.hpp` + `src/entropy_filter.cpp`
  * Strips ANSI codes, CMake progress lines, bare-CR overwrites, duplicate lines, path-only noise
  * `VectorMemoryEngine::insert_chunk_filtered()` runs filter before embedding ✓

* [x] Dynamic context pruning via score dropoff (cosine distance > mean − 1.5×std_dev)
  * `EntropyFilter::prune_by_distance_dropoff<T>()` — templated, works on any result type with `.cosine_distance`
  * Applied inside `hybrid_search()` when `prune_by_distance=true` (default) ✓
* [ ] Dual-model 2-of-2 consensus gating for high-risk diffs

## 6. Companion App & Tailscale Sync Mesh

* [ ] Background push notifications for HITL approvals
* [ ] 5-second WebSocket ping/pong heartbeat (Tailscale port 9091)
* [ ] Workspace parity validation
* [ ] Continuous mirror integrity (SHA-256 tree comparisons)

## 7. System Tuning

* [ ] TCP MSS clamping on Tailscale (nftables)
* [ ] EPP dynamic power script `/usr/lib/swarm/epp-tune.sh`

## 8. Developer Grants

* [ ] AMD AI Developer Program ($100 Instinct GPU credits)
* [ ] NVIDIA Inception Startup Program

---

## Build Order Progress

| # | Item | Status |
|---|------|--------|
| 1 | Systemd watchdog + Gamescope FSR | ✅ Done |
| 2 | Landlock sandbox | ✅ Done |
| 3 | Git-diff checkpoint journaling | ✅ Done |
| 4 | POSIX shm telemetry ring buffer | ✅ Done |
| 5 | Multi-client epoll IPC broker | ✅ Done |
| 6 | Entropy filter + dynamic context pruning | ✅ Done |
| 6b | Speculative pipeline (Kimi/DeepSeek/GLM routing) | ✅ Done |
| 7 | Dual-model consensus gating | ⬜ |
| 8 | Companion heartbeat / push / sync integrity | ⬜ |
| 9 | TCP MSS clamping + EPP power script | ⬜ |
| 10 | Grant applications | ⬜ |
