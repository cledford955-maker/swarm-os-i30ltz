# SWARM OS / Lucille — Master Implementation Checklist

> Consolidated from planning sessions. Use this as a working checklist with Claude Code — check items off as they land, and reference the file paths / verify commands directly when implementing each item.

---

## 1. System Reliability & Display Subsystem

- [~] **Enable systemd hardware watchdog** *(source staged; ISO boot verification pending)*
  - Create `/etc/systemd/system.conf.d/50-watchdog.conf`:
    ```ini
    [Manager]
    RuntimeWatchdogSec=30s
    RebootWatchdogSec=5min
    KExecWatchdogSec=5min
    ```
  - Apply: `sudo systemctl daemon-reexec`
  - Verify: `systemctl show | grep -i watchdog`

- [ ] **Configure Gamescope dynamic FSR upscaling**
  - Update launch args in `/usr/bin/swarm-session`:
    ```
    -W 1920 -H 1080 -w 1600 -h 900 -F fsr --fsr-sharpness 5 -r 60
    ```
  - Verify: launch session, then `journalctl --user -u swarm-session -e`

---

## 2. Kernel-Level Sandboxing (lucille-core, C++)

* [x] **Landlock LSM filesystem sandboxing**
  - Restrict child worker processes (Hermes Agent, OpenClaw) to read-only access across root
  - Write access permitted strictly inside the designated workspace directory
  - Layer on top of existing Seccomp + unprivileged namespace restrictions (not a replacement)
  - Verified: `cmake --build 30-source/lucille-core/build` and `ctest --test-dir 30-source/lucille-core/build` passed

---

## 3. Change Journaling & Rollback

- [~] **Atomic Git-diff checkpoint journaling** *(library implemented; production wiring pending)*
  - Before executing any mutating shell command or agent-suggested code modification, auto-create a lightweight Git commit/stash checkpoint in `lucille-core`
  - Wire into regression-test-failure path for instant rollback
  - Gap found 2026-09-19: `SafetyGate::checkpoint_and_apply()` has no production call site; `SwarmRouter::route_and_execute()` still uses placeholder tool execution.

---

## 4. Lucille C++ Core Engine — Shared Memory & IPC

- [ ] **POSIX shared memory telemetry ring buffer**
  - Allocate via `shm_open()` + `mmap()` → `/dev/shm/swarm_telemetry_shm`
  - High-frequency hardware metrics (VRAM, CPU, agent status), read directly by local telemetry daemon — no kernel context switches or socket serialization
  - Build: `g++ -std=c++20 -O3 lucille_core.cpp -o lucille-core -lsqlite3 -lpthread -lrt`
  - Verify: `ls -la /dev/shm/swarm_telemetry_shm`

- [ ] **Multi-client epoll IPC broker**
  - Refactor `/tmp/lucille_ipc.sock` handler from blocking to non-blocking `epoll_wait()`
  - Verify: connect two concurrent sessions via `socat - UNIX-CONNECT:/tmp/lucille_ipc.sock`

---

## 5. Multi-Model Swarm Routing & Speculative Verification

- [ ] **Pipelined asynchronous speculative execution**
  - Kimi 2.6 Coder streams a multi-file patch; `lucille-core` buffers completed method blocks as they land

- [ ] **Concurrent safety audit**
  - Pipe individual code blocks to DeepSeek-R1 for invariant checking and security boundary analysis *while* the patch is still streaming — don't wait for full completion

- [ ] **Triage & metric logging**
  - GLM 5.6 aggregates compiler logs and tracks context token density in parallel

- [ ] **Semantic entropy filtering in context ingestion**
  - Strip repetitive compiler warning strings, progress bars, and trailing log noise before storing terminal runs into `sqlite-vec`
  - Goal: minimize prompt token overhead

- [ ] **Dynamic context pruning via score dropoff**
  - When retrieving embeddings from `sqlite-vec`, filter context nodes using a dynamic threshold: discard chunks where cosine distance > `mean − 1.5 × std_dev`

- [ ] **Dual-model 2-of-2 consensus gating for high-risk diffs**
  - Trigger: patch modifies systemd services, firewall configs, or kernel parameters
  - Kimi 2.6 Coder → audits syntactic validity, code format, library dependencies
  - DeepSeek-R1 / V4-Flash → evaluates permission escalation risk, race conditions, rollback safety
  - Patch proceeds to Companion HITL approval queue **only** after both models validate

---

## 6. Companion App (DR.-I30LTZ-Companion) & Tailscale Sync Mesh

- [ ] **Background push notifications for HITL approvals**
  - Emergency webhook payload sends mobile push alerts via the Companion daemon when a restricted command (`systemctl`, `mkfs`, `dd`) requires authorization while the app is backgrounded

- [ ] **5-second WebSocket ping/pong heartbeat**
  - Bind to Tailscale port 9091 (`100.x.y.z:9091`)
  - On cellular drop: mobile client reconnects and requests missed telemetry events using monotonic sequence numbers (no duplicates, no gaps)

- [ ] **Workspace parity validation**
  - Scheduled bidirectional sync cycles verify directory manifests across physical drives before running `rsync`
  - Adhere to non-destructive two-way sync parameters in `SYNC-OPTIONS.md`

- [ ] **Continuous mirror integrity verification**
  - Periodic SHA-256 tree comparisons across partitions and remote workstations to confirm workspace parity

---

## 7. System Tuning

- [ ] **TCP MSS clamping on Tailscale**
  - Add MSS clamping rule to `nftables` to stabilize high-bandwidth mobile telemetry streams

- [ ] **EPP dynamic power script**
  - Deploy `/usr/lib/swarm/epp-tune.sh`
  - Ramps CPU clock profiles during multi-model compilation jobs

---

## 8. Developer Grants & Cloud GPU Compute

- [ ] **AMD AI Developer Program**
  - Perk: $100 in AMD Developer Cloud credits (AMD Instinct™ GPU clusters, ROCm testing, model fine-tuning), plus partner credit opportunities
  - Action: register and manage allocations via the AMD AI Developer Program portal

- [ ] **NVIDIA Inception Startup Program**
  - Perk: cloud partner compute credits (AWS/GCP), preferred pricing on developer GPUs, technical training tracks
  - Action: apply and track onboarding via the NVIDIA Inception Startup Program portal

---

## Suggested Build Order

1. Systemd watchdog + Gamescope FSR (quick, isolated wins)
2. Landlock sandbox in `lucille-core` (C++)
3. Git-diff checkpoint journaling
4. POSIX shared memory telemetry ring buffer
5. Multi-client epoll IPC broker
6. Speculative pipeline + semantic entropy filtering + dynamic context pruning
7. Dual-model consensus gating
8. Companion heartbeat / push notifications / sync integrity
9. TCP MSS clamping + EPP power script
10. Grant applications (parallel — no code dependency)

---

*Generated for the SWARM OS project. Update this file as items are completed — consider committing it to the repo root or `lucille-core/docs/` so Claude Code can track progress across sessions.*
