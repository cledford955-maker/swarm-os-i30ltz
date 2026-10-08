# SWARM OS — AI Onboarding Prompt

## ISO releases and desktop tools — user policy (2026-09-19)

**ISO destinations (2026-10-07) — new ISOs go here and nowhere else, keep newest 5 of EACH:**
- SWARM OS → `/mnt/ventoy/ISO/SWARM_OS/`
- Recovery OS → `/mnt/ventoy/ISO/recovery-os/`

**All active SWARM ISO files go ONLY to `/mnt/ventoy/ISO/SWARM_OS/`. Keep the newest 5 SWARM builds (policy 2026-10-06; Recovery OS keeps its own 5). Stable labels do not exempt a build.** Never create local/desktop ISO copies, latest/fallback ISO duplicates, or a separate push-to-Ventoy workflow. Use `70-scripts/build_swarm_iso.sh`; dated build scripts are compatibility forwards only. Missing Ventoy must abort, never fall back locally. Stable is an explicit user decision, not inferred from a passing boot test. Read `ISO_RELEASE_POLICY.md` before changing build, retention, VM, or desktop launch scripts. VM launcher: `70-scripts/launch_swarm_vm.sh`; editor: `70-scripts/open_swarm_code.sh`.



**You are working on SWARM OS, a custom Arch Linux live system built by i30ltz.**

## PROJECT IDENTITY — READ THIS FIRST

**Working directory: `/mnt/Lucy/` (capital L)**

There are several directories that look similar but are NOT this project:
- `/mnt/lucy/` (lowercase) — empty, stale, ignore it
- `/run/media/i30ltz/lucy-master/` — READ-ONLY source mirror, never write here
- `/mnt/lucy_master/` — same read-only mirror, different mount point

If your working directory is anything other than `/mnt/Lucy/`, stop and check with the user.

---

## Mount points — verify BEFORE every session (policy 2026-10-07)

**Before doing anything else, run `70-scripts/check_mounts.sh`.** If any mount is MISSING, fix it: `sudo 70-scripts/check_mounts.sh --fix` (adds the entry to **this OS's** `/etc/fstab` and mounts it). If you cannot sudo, tell the user the exact command — do not work around a missing mount by writing elsewhere. Never mount anything under `/media`; the canonical points are all `/mnt/...`.

Each installed OS (Debian, SWARM OS, Recovery OS; CachyOS/Endeavor is decommissioned and its partition is reserved for Recovery OS, see below) has its own `/etc/fstab`, so the check/fix must run on every OS. Device names can shift between OSes and boots, so entries use `UUID=`/`LABEL=`, never `/dev/sdX`.

| Mount point | Device (as seen from Debian) | Source | Role |
|---|---|---|---|
| `/mnt/Lucy` | nvme0n1p4 ext4 "Swarm Build" | `UUID=62f0e009-43c2-4760-8d6c-d7c445f5f3df` | Live project / source of truth |
| `/mnt/swarmbuild` | sda4 ext4 `swarm-build` | `LABEL=swarm-build` | Build drive — **all building happens here**; sync with `70-scripts/sync_lucy_swarmbuild.sh to-build` before building and `to-lucy` after (VERSION, source edits). `build_swarm_iso.sh` refuses to run outside it |
| `/mnt/brains` | nvme0n1p5 ext4 `i30ltz-brains` | `UUID=fba1b27f-407b-4385-9dfa-851833f249db` | Shared swarm memory |
| `/mnt/ventoy` | sdc1 exfat `Ventoy` | `UUID=5ABB-83DF` | ISO output (policy above) |
| `/mnt/recoverybuild` | sda6 btrfs `Recovery-build` | `UUID=a409250b-3973-4448-aeda-94a911538eb4` | Recovery OS build |
| `/mnt/lucy_master` | sda3 ext4 `lucy-master-bak` | `UUID=c400a0ee-6710-4fe7-ad7a-c80dc3f402ca` | READ-ONLY mirror (`ro`) |
| `/mnt/endeavor` (legacy name; Recovery OS root will be `/mnt/recoveryos`) | sda3 btrfs `Cachy OS` (230 GB) | `UUID=ef9acba2-3816-4fd7-bdd7-a9526816d3f0` | Decommissioned (formerly CachyOS root). **Reserved for Recovery OS root** — see "Recovery OS placement" below |
| `/mnt/boltz` | (optional, not always attached) | `UUID=689e6547-b439-4e7f-93c9-a6dcfabed46b` | Shared archive |

Not auto-mounted (LUKS-encrypted, unlock manually): the `lucy-master` LUKS volume (`UUID=a24202ce-4d76-4eb7-8923-8e8ddbacdaa7`, ext4 `lucy-master`; sda4 on the 2026-10-07 Debian boot, mounted there as `/mnt/storage`), nvme0n1p6 → `Slick` (`/mnt/slick`).

**Recovery OS placement (user decision 2026-10-07):** Recovery OS is installed on the 931.5 GB disk — **root on the former CachyOS partition** (`sda3`, btrfs, `UUID=ef9acba2-3816-4fd7-bdd7-a9526816d3f0`) and **EFI on that disk's ESP** (`sda1`, vfat `EFI`, `UUID=A367-87E3`, the old CachyOS ESP) — directly beside the `lucy-master` LUKS volume (`sda4`). This supersedes the earlier RC-11 plan (portable 1.8 TB drive, sharing Debian's ESP `362A-E48F`, `\EFI\i30ltz`). **Not installed yet:** `lsblk` on 2026-10-07 still showed the old `Cachy OS` btrfs, and the install is the Recovery AI's job (`/mnt/recoverybuild`, RC-11). `sda4` (lucy-master) must never be touched by it (`70-scripts/uninstall_cachyos.sh` only targets `sda3`/optionally `sda1`). Until it is installed, GRUB entries and the SWARM installer's CachyOS chainload (`A367-87E3`) still point at the old layout. Drive letters swap between boots — always target by UUID. **Recovery OS root filesystem: btrfs** (user decision 2026-10-07; `70-scripts/uninstall_cachyos.sh` now finds the partition by PARTUUID and, after a typed-device-path confirmation, formats it btrfs with label `Recovery-OS`). **Verified 2026-10-07 (`sudo blkid -p /dev/sda3`, run by the user): `sda3` is still the original btrfs, label `Cachy OS`, UUID `ef9acba2-3816-4fd7-bdd7-a9526816d3f0`, 230 GiB — it was NOT reformatted to ext4** (an earlier report said it was; that was wrong). Nothing has been erased, so the old CachyOS data may still be on it. Formatting it btrfs (Recovery install, or `uninstall_cachyos.sh`) will change the filesystem UUID — update it here then. These identifiers survive a reformat (GPT PARTUUID): `sda1` ESP `e25e5715-f3b8-4ddb-9796-d1c270804140`, `sda3` `993d0098-1b2f-44a2-b51d-11c2bfeddc40` (sectors 37750784–520095743, ends exactly where `sda4` begins), `sda4` lucy-master `20a96573-0c80-4393-ba95-40a64964b39e`.

**Per-OS differences:** the table above was captured from Debian. On another OS the *same mount points* must exist, but if its own root/partitions differ (e.g. its own root is not under `/mnt`, or a disk enumerates differently), record the difference here under that OS's name — do not silently diverge. Known so far: none beyond the device names, except **Debian**: the `lucy-master-bak` partition (UUID `c400a0ee…`) is mounted at `/mnt/archive` (rw, automount) rather than `/mnt/lucy_master`, so `check_mounts.sh` reports it as `ELSEWHERE` with a rw warning — remount it read-only (`sudo mount -o remount,ro /mnt/archive`) or move its fstab entry to `/mnt/lucy_master` with `ro`. All Debian mounts are `x-systemd.automount`; `check_mounts.sh` handles that (checked 2026-10-07).

## Your first actions, every session

0. **Run `70-scripts/check_mounts.sh`** (see above).
1. **Read `SWARM_AI_FEATURES.md`** — living record of what is done, in progress, and planned. Do not ask the user what exists; read the file.
2. **Update `SWARM_AI_FEATURES.md`** when you add, remove, or change anything. Move items between DONE / IN PROGRESS / IDEAS. Do not let it go stale.

---

## Current architecture (as of 2026-09-11)

Two Wayland clients run under **labwc** compositor, started by `swarm-ui.service`:

| Component | Language | Location | Role |
|---|---|---|---|
| Flutter shell | Dart (Flutter) | `30-source/frontend/` | Full desktop: wallpaper, app drawer, floating windows, voice HUD |
| Lucille panel | Rust + Slint | `30-source/swarm-slint/` | Companion window: gaming, chat, monitor tabs |
| GamingAgent | Go | `30-source/GamingAgent-go/` | Port 8401 — Steam/GFN/NVIDIA NIM API |
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
  CLAUDE.md                                      ← this file
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
  lucille-companion/                             ← CANONICAL Android companion (com.swarm.lucille, v1.0.0)
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

- **Never write to `/run/media/i30ltz/lucy-master/`** — read-only reference mount. All writes go to `/mnt/Lucy/`.
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

All OSes, the companion phones and Claude share one append-only memory log at `/mnt/brains/swarm-memory/` (git copy: `60-boltz-brain/swarm-memory/`). Read `/mnt/brains/swarm-memory/PROJECT_MEMORY.md` at session start; record lasting decisions with `swarm-memory add -kind decision -key <topic> "text"`. Spec: `90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md`.

## Key services and ports

| Service | Port | Active location |
|---|---|---|
| GamingAgent | 8401 | `30-source/GamingAgent-go/` |
| LucyServer | 5000 (+ 8402 memory sync, LAN) | `30-source/LucyServer/` (.NET, being replaced by `LucyServer-go/`) |

---

## API keys available (from `/mnt/Lucy/20-runtime/.env`)

All services read these at runtime via `EnvironmentFile=/etc/swarm_os.env`:

- `STEAM_API_KEY`, `STEAM_ID64` — Steam Web API
- `NVIDIA_API_KEY` — NVIDIA NIM (`https://integrate.api.nvidia.com/v1`) — not currently used by GamingAgent's Lucille chat (see "Lucille's chat backend" below), but still a valid key for direct NIM calls elsewhere
- `ANTHROPIC_API_KEY`, `CLAUDE_API_KEY` — Anthropic Claude
- `OPENROUTER_API_KEY` — OpenRouter multi-model
- `GROQ_API_KEY` — Groq fast inference
- `GEMINI_API_KEY` — Google Gemini
- `OLLAMA_API_KEY`, `OLLAMA_CLOUD_API_KEY` — Ollama local/cloud
- `ELEVEN_API_KEY` — ElevenLabs TTS

---

## Lucille's chat backend

Lucille is the SWARM OS AI. GamingAgent calls a chat-completions API for gaming evaluations and chat — which
provider and model is **not stable enough to name here**: it changed three times in one day (2026-09-20):
NVIDIA NIM's `nvidia/llama-3.3-nemotron-super-49b-v1` (retired by NVIDIA, HTTP 410) → NIM's
`nvidia/nemotron-3.5-lightning-30b-a3b` (fixed) → NIM's `moonshotai/kimi-k3` (user-requested swap, but NIM's
hosting of it was severely slow — 105s for a 64-token reply, verified directly) → OpenRouter's
`moonshotai/kimi-k2.5` (current, ~8.8s for an equivalent call). The three constants in
`services/lucille_service.go` — `chatEndpoint`, `chatModel`, `chatAPIKeyEnv` — are named provider-agnostically
on purpose, precisely so a future switch doesn't leave stale identifiers *and* a stale doc both pointing at
the wrong thing at once. **Read those three constants for what's actually live. Do not trust this section,
its header, or any other doc for the current model/provider/key — update this note if you change them, but
verify from source regardless.**

- **GamingAgent routes:** `GET /api/lucille/eval`, `POST /api/lucille/chat`, `POST /api/lucille/chat/stream`

---

## Artifact

The gaming dashboard lives at:
`https://claude.ai/code/artifact/5c970c82-aed8-4cb2-83c0-ed3c459fc7d9`

---

## When you finish a session

Before leaving, update `SWARM_AI_FEATURES.md`:
- Mark completed items DONE
- Add any new ideas you thought of
- Note anything broken or partial
- Update the "Last updated" line at the bottom

The user loses work between sessions when this file is not kept current. **Don't let that happen.**
