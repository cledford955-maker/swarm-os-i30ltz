# SWARM OS — AI Onboarding Prompt

## What this project is, and the quality bar (user, 2026-10-10)

SWARM OS, Lucille, Recovery OS and the two phone apps are a **personal hobby project**, built out of passion by one person (i30ltz). They are **not a company product and not for enterprise customers.** When the user says "enterprise level" they mean **enterprise quality**: careful engineering, tests, safe defaults, honest docs, nothing that loses data or breaks quietly. They do **not** mean enterprise features or process (no multi-tenant, compliance paperwork, SLAs, committees). The goal is that if anyone ever does look at it, it is **as polished and as cool as possible**. The money behind it is personal and limited, so prefer solutions that are cheap to run and easy for one person to maintain, and do not burn paid API calls, compute or tokens on wasteful experiments.

## ISO releases and desktop tools — user policy (2026-09-24)

**Keep ten current operating-system ISOs total on Ventoy, across all OSes. No stable-label exceptions. Archive at most one new boot-verified SWARM build per calendar week under `/mnt/boltz/ISO/SWARM_OS/weekly/`; these historical archives are the exception to the active ten.** Use `70-scripts/build_swarm_iso.sh` as the normal user; it builds directly into Ventoy, prunes the total to ten, and never falls back to local copies. Verify both mount UUIDs before writes. Archive only recorded boot passes with verified SHA-256; never copy an unchanged build again or write into an unmounted Boltz directory. Read `ISO_RELEASE_POLICY.md` before changing build, retention, VM or launch scripts. The old ten-plus-stable rule is superseded. VM launcher: `70-scripts/launch_swarm_vm.sh`; editor: `70-scripts/open_swarm_code.sh`.



**You are working on SWARM OS, a custom Arch Linux live system built by i30ltz.**

## PROJECT IDENTITY — READ THIS FIRST

**Working directory: `/mnt/Lucy/` (capital L)**

There are several directories that look similar but are NOT this project:
- `/mnt/lucy/` (lowercase) — empty, stale, ignore it
- `/run/media/i30ltz/lucy-master/` — READ-ONLY source mirror, never write here
- `/mnt/lucy_master/` — same read-only mirror, different mount point

If your working directory is anything other than `/mnt/Lucy/`, stop and check with the user.

---

## Your first two actions, every session

1. **Read `SWARM_AI_FEATURES.md`** — living record of what is done, in progress, and planned. Do not ask the user what exists; read the file.
2. **Update `SWARM_AI_FEATURES.md`** when you add, remove, or change anything. Move items between DONE / IN PROGRESS / IDEAS. Do not let it go stale.

---

## Current architecture (as of 2026-09-11)

Two Wayland clients run under **labwc** compositor, started by `swarm-ui.service`:

| Component | Language | Location | Role |
|---|---|---|---|
| Flutter shell | Dart (Flutter) | `30-source/frontend/` | Full desktop: wallpaper, app drawer, floating windows, voice HUD |
| Lucille panel | Rust + Slint | `30-source/swarm-slint/` | Companion window: gaming, chat, monitor tabs |
| GamingAgent | Go | `30-source/GamingAgent-go/` | Port 8401 — Steam/GFN/Nemotron API |
| LucyServer | .NET 10 → Go (in progress) | `30-source/LucyServer/` + `LucyServer-go/` | Primary agent, ~100 endpoints |
| lucille-core | C++20 | `30-source/lucille-core/` | Native AI engine — do not modify |

labwc config lives at:
- `40-iso-profile/swarm_os_iso_profile/airootfs/home/swarm/.config/labwc/autostart` — launches both Flutter + swarm-slint
- `40-iso-profile/swarm_os_iso_profile/airootfs/home/swarm/.config/labwc/rc.xml` — floating WM rules

---

## Project layout

**LUCILLE is self-contained.** On a new machine: mount the drive, run `70-scripts/setup-dev-deps.sh` to install pacman packages (Go, Rust, dotnet), and build. Flutter SDK is already on the drive.

```
/mnt/Lucy/                                       ← LIVE working drive — read and write here
  AGENTS.md                                      ← this file
  SWARM_AI_FEATURES.md                           ← living feature tracker — KEEP IT UPDATED
  VERSION                                        ← current build version (auto-bumped by build script)
  10-releases/                                   ← non-ISO artifacts only (ISOs on Ventoy)
  20-runtime/.env                                ← ALL API keys (never commit this file)
  30-source/
    flutter-sdk/                                 ← Flutter SDK (self-contained on LUCILLE, 1.6GB)
    frontend/                                    ← Flutter Linux desktop shell (161 dart files)
    swarm-slint/                                 ← Rust + Slint Lucille panel (backend-winit)
    LucyServer/                                  ← .NET 10 primary agent (being ported → LucyServer-go)
    LucyServer-go/                               ← Go rewrite in progress (tasks #15–23)
    GamingAgent/                                 ← .NET 10 (replaced — do not use)
    GamingAgent-go/                              ← Go rewrite, fully active on port 8401
    lucille-core/                                ← C++20 native engine — do not touch
    deploy_swarm_os_foundation.sh                ← stages configs into airootfs
    install_swarm_os.sh                          ← installer run from live USB
  40-iso-profile/swarm_os_iso_profile/
    airootfs/                                    ← the chroot that becomes the live system
      opt/swarm_os/                              ← compiled apps staged here
      etc/swarm_os.env                           ← baked .env (set -a safe)
      etc/systemd/system/                        ← service units
      home/swarm/.config/labwc/                 ← labwc compositor config
  70-scripts/
    build_swarm_iso.sh                           ← THE build script (run as normal user)
    setup-dev-deps.sh                            ← install pacman build tools on a new machine
  80-vm/                                         ← QEMU/OVMF VM for testing the ISO
  images/                                        ← wallpapers, icons, GRUB assets

  ── Orphaned dirs (do not edit, ask user before touching) ──
  00-CURRENT/      ← old build outputs, superceded by 30-source/
  LucyServer/      ← old .NET publish output at root, superceded by 30-source/LucyServer/
  GoogleWorkspaceService/  ← stale copy
  Luccile-v+/      ← old build script archive
  50-backends/     ← old backend copy
  60-boltz-brain/  ← Lucille AI memory/identity store (unknown if active)
  90-docs/         ← historical session notes
  99-archive/      ← archived old work

/run/media/i30ltz/lucy-master/               ← READ-ONLY source mirror — NEVER write here
/mnt/lucy/                                   ← EMPTY / STALE — not this project
```

## Toolchain locations

| Tool | Location | How to get |
|---|---|---|
| Flutter SDK | `/mnt/Lucy/30-source/flutter-sdk/` | Already on LUCILLE |
| Go | `/usr/bin/go` | `pacman -S go` |
| Rust/cargo | `/usr/bin/cargo` | `pacman -S rust` |
| dotnet 10 | `/usr/bin/dotnet` | `pacman -S dotnet-sdk-10.0` |

Run `70-scripts/setup-dev-deps.sh` on any new machine after mounting LUCILLE.

---

## Hard rules — do not break these

- **Never write to `/run/media/i30ltz/lucy-master/`** — read-only reference mount. All writes go to `/mnt/Lucy/`. **One exception (user, 2026-10-10): `70-scripts/sync_lucy_master.sh` two-way syncs a chosen folder of the encrypted lucy-master volume with `/mnt/Lucy` (new data is copied, only real deletions are carried over, deletions go to a trash, the first run deletes nothing). Nothing else writes to lucy-master, and `/mnt/archive` (= `lucy-master-bak`, c400a0ee) has no sync job.**
- **Never write to `/mnt/lucy/`** — lowercase, different path, not this project.
- **Never `rm -rf` anything in `airootfs/` without checking for symlinks to lucy-master.** Use `ls -la` first.
- **Never commit `.env`** — it contains production API keys.
- **The build script runs as a normal user.** Only the `mkarchiso` step uses sudo.
- **Version is auto-bumped** on every build run. Do not manually edit `VERSION` unless recovering from a broken state.
- **`set -euo pipefail`** is active in all shell scripts. Any error aborts the build. Be precise.
- **Do not touch `30-source/GamingAgent/`** — the old .NET version, replaced by `GamingAgent-go/`.
- **Do not touch `30-source/lucille-core/`** — C++20 native engine, already optimal.

---

## Shared memory (2026-09-16)

All OSes, the companion phones and Codex share one append-only memory log at `/mnt/brains/swarm-memory/` (git copy: `60-boltz-brain/swarm-memory/`). Read `/mnt/brains/swarm-memory/PROJECT_MEMORY.md` at session start; record lasting decisions with `swarm-memory add -kind decision -key <topic> "text"`. Spec: `90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md`.

## Key services and ports

| Service | Port | Active location |
|---|---|---|
| GamingAgent | 8401 | `30-source/GamingAgent-go/` |
| LucyServer | 5000 (+ 8402 memory sync, LAN) | `30-source/LucyServer/` (.NET, being replaced by `LucyServer-go/`) |

**Network (Tailscale): the Debian dev PC is `100.82.1.19`** (changed 2026-10-09 by the user; it was `100.82.1.21`, and `.19` had been Cachy's address). `100.82.1.21` no longer exists on the tailnet. Never hardcode it: `tailscale ip -4` prints the current address. The LucyServer drop-in `~/.config/systemd/user/swarm-lucy-dev.service.d/listen.conf` (`ASPNETCORE_URLS`) was changed to `http://127.0.0.1:5000;http://100.82.1.19:5000` on 2026-10-09 (backup `listen.conf.bak-20261009-202628`; the `swarm-lucy-dev` user unit is not enabled at boot, but the user started it at 20:27 and it now listens on `127.0.0.1:5000` and `100.82.1.19:5000`). The only thing still pinned to `.21` is the frozen copy under `30-source/LucilleAssistant` (do not edit it), plus any companion app with a saved node address of `.21`. Lucille Assistant already listens on `100.82.1.19:8403` (`LUCILLE_ASSISTANT_LISTEN` in `~/.config/lucille-assistant/.env`) and its phone app tries `100.82.1.19:8403`.

---

## API keys available (from `/mnt/Lucy/20-runtime/.env`)

All services read these at runtime via `EnvironmentFile=/etc/swarm_os.env`:

- `STEAM_API_KEY`, `STEAM_ID64` — Steam Web API
- `NVIDIA_API_KEY` — NVIDIA NIM / Nemotron (`https://integrate.api.nvidia.com/v1`)
- `ANTHROPIC_API_KEY`, `CLAUDE_API_KEY` — Anthropic Codex
- `OPENROUTER_API_KEY` — OpenRouter multi-model
- `GROQ_API_KEY` — Groq fast inference
- `GEMINI_API_KEY` — Google Gemini
- `OLLAMA_API_KEY`, `OLLAMA_CLOUD_API_KEY` — Ollama local/cloud
- `ELEVEN_API_KEY` — ElevenLabs TTS

---

## Nemotron / Lucille

Lucille is the SWARM OS AI. GamingAgent calls Nemotron for gaming evaluations:

- **Endpoint:** `https://integrate.api.nvidia.com/v1/chat/completions`
- **Model:** `nvidia/llama-3.3-nemotron-super-49b-v1`
- **Key:** `NVIDIA_API_KEY` from environment
- **GamingAgent route:** `GET /api/lucille/eval`

---

## Artifact

The gaming dashboard lives at:
`https://Codex.ai/code/artifact/5c970c82-aed8-4cb2-83c0-ed3c459fc7d9`

---

## When you finish a session

Before leaving, update `SWARM_AI_FEATURES.md`:
- Mark completed items DONE
- Add any new ideas you thought of
- Note anything broken or partial
- Update the "Last updated" line at the bottom

The user loses work between sessions when this file is not kept current. **Don't let that happen.**
