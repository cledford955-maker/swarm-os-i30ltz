# AMD AI Developer Program — Application Draft

> Program: AMD AI Developer Program ($100 cloud credits for ROCm/Instinct workloads)
> Applicant: SWARM OS Project
> Date drafted: 2026-09-25

---

## Project Name

SWARM OS — Multi-Agent AI Operating System

## Project URL

https://github.com/swarm-os-i30ltz (private; can grant read access on request)

## One-line Description

A custom Arch Linux live operating system with a native C++20 AI engine that orchestrates multiple LLM agents through a speculative streaming pipeline with hardware-accelerated consensus gating.

## Project Description

SWARM OS is a purpose-built Linux distribution designed as a local-first AI workstation. It ships as a bootable ISO with a custom labwc Wayland compositor, a Flutter hex-grid desktop shell, a Rust+Slint companion panel, and a native C++20 AI engine called Lucille Core.

Lucille Core implements a speculative multi-model pipeline: Kimi K2 streams code diffs, DeepSeek-R1 audits each block concurrently as it arrives, and GLM triages compiler diagnostics in parallel. A 2-of-2 consensus gate blocks high-risk changes (systemd units, firewall rules, capability grants) until two independent model auditors approve. Human-in-the-loop approval is enforced via WebSocket to companion Android phones over a Tailscale mesh.

The system includes:
- POSIX shared memory telemetry ring buffer (256-slot lock-free seqlock)
- Git-diff checkpoint journaling with automatic rollback on regression
- Landlock LSM filesystem sandboxing for child workers
- SIMD-accelerated (AVX2/FMA) vector operations for local embeddings
- Entropy filtering and dynamic context pruning for efficient token usage

## How AMD/ROCm Credits Would Be Used

1. **Local model inference benchmarking on ROCm**: Profile DeepSeek-R1 and Kimi K2 inference on AMD Instinct MI-series GPUs via ROCm to compare latency against current OpenRouter cloud routing. SWARM OS's pipeline is latency-sensitive (each streaming block audit must complete before the next block is assembled).

2. **SIMD → ROCm migration path**: Lucille Core's `simd_quant.cpp` currently uses AVX2/FMA for vector quantization and dot-product similarity. AMD credits would let us benchmark a HIP/ROCm port of these kernels on Instinct hardware to determine if local GPU acceleration is viable for the embedding pipeline.

3. **CI/CD on AMD hardware**: Use cloud Instinct instances to validate that Lucille Core's 180-test suite (including ThreadSanitizer runs) passes on ROCm-enabled builds, establishing AMD as a first-class target alongside Intel (current dev hardware: 16 GB Intel UHD).

## Technical Stack

- **OS**: Arch Linux (CachyOS kernel), mkarchiso-built ISO
- **Engine**: C++20 (GCC 14), CMake 3.20+, libcurl, OpenSSL, SQLite3
- **Desktop**: labwc compositor, Flutter (Dart), Slint (Rust)
- **Backend**: Go (LucyServer, GamingAgent)
- **Android**: Kotlin (companion app with biometric HITL approval)
- **Models**: OpenRouter API (Kimi K2, DeepSeek-R1, GLM-Z1-Flash, Nemotron)
- **Security**: Landlock LSM, nftables, sealed secrets (AES-256-GCM → tmpfs), AppArmor

## Team Size

Solo developer/operator

## Contact

cledford955@gmail.com
