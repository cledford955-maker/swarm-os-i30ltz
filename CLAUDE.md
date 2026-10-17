# SWARM OS — AI Onboarding Prompt

## What this project is, and the quality bar (user, 2026-10-10)

SWARM OS, Lucille, Recovery OS and the two phone apps are a **personal hobby project**, built out of passion by one person (i30ltz). They are **not a company product and not for enterprise customers.** When the user says "enterprise level" they mean **enterprise quality**: careful engineering, tests, safe defaults, honest docs, nothing that loses data or breaks quietly. They do **not** mean enterprise features or process (no multi-tenant, compliance paperwork, SLAs, committees). The goal is that if anyone ever does look at it, it is **as polished and as cool as possible**. The money behind it is personal and limited, so prefer solutions that are cheap to run and easy for one person to maintain, and do not burn paid API calls, compute or tokens on wasteful experiments.

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
| `/mnt/swarmbuild` | sda4 ext4 `A. swarm-build` (relabeled 2026-10-09; the old `LABEL=swarm-build` no longer matches, so use the UUID) | `UUID=5c84ef0e-d7b8-4b36-b1c4-58817b483dda` | SWARM OS build drive — **all SWARM ISO building happens here**; sync with `70-scripts/sync_lucy_swarmbuild.sh to-build` before building and `to-lucy` after (VERSION, source edits). `build_swarm_iso.sh` refuses to run outside it |
| `/mnt/brains` | nvme0n1p5 ext4 `i30ltz-brains` | `UUID=fba1b27f-407b-4385-9dfa-851833f249db` | Shared swarm memory |
| `/mnt/ventoy` | sdc1 exfat `Ventoy` | `UUID=5ABB-83DF` | ISO output (policy above) |
| `/mnt/recoverybuild` | sda6 btrfs `B. Recovery-build` | `UUID=a409250b-3973-4448-aeda-94a911538eb4` | Recovery OS build (ISO / live-build) |
| `/mnt/lucillebuild` | sda8 ext4 `C. Lucille build` (163 GB) | `UUID=93037d5a-5b82-484c-ac20-28211c09e1c0` | **Lucille Assistant app build** (Go service + Android app) — source, toolchains, caches and `dist/` all live here. See "App build partitions" |
| `/mnt/boltzbuild` | sda9 ext4 label `Boltz Built` (163 GiB) — created NTFS by mistake (`UUID=67C2E9F8241FD7AE`, empty), **reformatted ext4 by the user 2026-10-09** (GNOME Disks, not the script, so identity changed) | `UUID=6f7c7656-2984-4fb0-81c8-bfc11ca81461`, PARTUUID `61b76036-5814-43fa-80b2-84ce5164f3d4` (the earlier planned `e195839a…` / `52545158…` never existed on disk). If fstab/automount still name the old NTFS UUID: `sudo 70-scripts/fix_boltzbuild_mount.sh` | **Boltz Recovery phone-app build** (Android; the I30LTZ Companion, repo `I30LTZ-Recovery-companion`) — the ONLY place that app may live (user, 2026-10-09). Not the Recovery OS: that is B `/mnt/recoverybuild`, and the Rust `i30ltz-recovery` kiosk program belongs to B too |
| `/mnt/recoveryos` | sdb3 btrfs `Recovery OS` (230 GB, Samsung T7) | `UUID=490b9e60-afb2-45c6-91ce-2c6b1ea5a2f3` | **Recovery OS installed root / home** (formerly the CachyOS partition; reformatted, new UUID). Not on the 1.8 TB build drive |
| `/mnt/lucy_master` | sda3 ext4 `lucy-master-bak` | `UUID=c400a0ee-6710-4fe7-ad7a-c80dc3f402ca` | READ-ONLY mirror (`ro`) |
| `/mnt/endeavor` (legacy name — superseded by `/mnt/recoveryos` above) | formerly btrfs `Cachy OS`, `UUID=ef9acba2-3816-4fd7-bdd7-a9526816d3f0` | gone | That filesystem no longer exists: the partition was reformatted and is now `/mnt/recoveryos` (UUID `490b9e60…`). Ignore any doc or GRUB entry still naming `ef9acba2…` |
| `/mnt/boltz` | (optional, not always attached) | `UUID=689e6547-b439-4e7f-93c9-a6dcfabed46b` | Shared archive |

Not auto-mounted (LUKS-encrypted, unlock manually): the `lucy-master` LUKS volume (`UUID=a24202ce-4d76-4eb7-8923-8e8ddbacdaa7`, ext4 `lucy-master`; sda4 on the 2026-10-07 Debian boot, mounted there as `/mnt/storage`), nvme0n1p6 → `Slick` (`/mnt/slick`).

**Recovery OS placement (user decision 2026-10-07):** Recovery OS is installed on the 931.5 GB disk — **root on the former CachyOS partition** (`sda3`, btrfs, `UUID=ef9acba2-3816-4fd7-bdd7-a9526816d3f0`) and **EFI on that disk's ESP** (`sda1`, vfat `EFI`, `UUID=A367-87E3`, the old CachyOS ESP) — directly beside the `lucy-master` LUKS volume (`sda4`). This supersedes the earlier RC-11 plan (portable 1.8 TB drive, sharing Debian's ESP `362A-E48F`, `\EFI\i30ltz`). **Not installed yet:** `lsblk` on 2026-10-07 still showed the old `Cachy OS` btrfs, and the install is the Recovery AI's job (`/mnt/recoverybuild`, RC-11). `sda4` (lucy-master) must never be touched by it (`70-scripts/uninstall_cachyos.sh` only targets `sda3`/optionally `sda1`). Until it is installed, GRUB entries and the SWARM installer's CachyOS chainload (`A367-87E3`) still point at the old layout. **Recovery OS must be standalone** (user, 2026-10-08): it boots with the Debian disk unplugged, so it gets its own complete bootloader on its own ESP (`sda1`) — fallback `\EFI\BOOT\BOOTX64.EFI`, `\EFI\i30ltz`, and a firmware boot entry appended after the existing boot order — and never depends on Debian's GRUB or ESP (`sdb1`, `362A-E48F`, which is what Debian itself boots from). Installer: `/mnt/recoverybuild/70-scripts/install-recovery-from-debian.sh` (run with `sudo`, not yet run). Drive letters swap between boots — always target by UUID. **Recovery OS root filesystem: btrfs** (user decision 2026-10-07; `70-scripts/uninstall_cachyos.sh` now finds the partition by PARTUUID and, after a typed-device-path confirmation, formats it btrfs with label `Recovery-OS`). **Verified 2026-10-07 (`sudo blkid -p /dev/sda3`, run by the user): `sda3` is still the original btrfs, label `Cachy OS`, UUID `ef9acba2-3816-4fd7-bdd7-a9526816d3f0`, 230 GiB — it was NOT reformatted to ext4** (an earlier report said it was; that was wrong). Nothing has been erased, so the old CachyOS data may still be on it. Formatting it btrfs (Recovery install, or `uninstall_cachyos.sh`) will change the filesystem UUID — update it here then. These identifiers survive a reformat (GPT PARTUUID): `sda1` ESP `e25e5715-f3b8-4ddb-9796-d1c270804140`, `sda3` `993d0098-1b2f-44a2-b51d-11c2bfeddc40` (sectors 37750784–520095743, ends exactly where `sda4` begins), `sda4` lucy-master `20a96573-0c80-4393-ba95-40a64964b39e`.

**Update 2026-10-09 (supersedes the "NOT reformatted" / `ef9acba2` statements above):** the Recovery OS partition has been reformatted by the user. On the 2026-10-09 Debian boot it is `sdb3` (Samsung T7, 931.5 GB disk), btrfs, label `Recovery OS`, **`UUID=490b9e60-afb2-45c6-91ce-2c6b1ea5a2f3`**, 230 GB, beside the `lucy-master` LUKS volume (`sdb4`) and the old-CachyOS ESP (`sdb1`, `A367-87E3`, unchanged). Mount point **`/mnt/recoveryos`** = Recovery OS root / home. Whether Recovery OS is *installed* on it is still unverified (mount it and look); the install remains the Recovery AI's job.

**Update 2026-10-09, later (Recovery OS installed from Debian):** `install-recovery-from-debian.sh all` (run by the user with sudo) formatted the partition again and installed Recovery OS. The partition's filesystem is now btrfs `Recovery OS`, **`UUID=71287bbf-81bf-4074-9619-4180b5a15742`** (supersedes `490b9e60…` above; subvolumes `@`, `@home`, `@snapshots`; PARTUUID `993d0098-…` unchanged). Bootloader: its own ESP `A367-87E3` — `\EFI\i30ltz\grubx64.efi` plus the standalone fallback `\EFI\BOOT\BOOTX64.EFI` (the previous fallback loader was backed up as `BOOTX64.EFI.bak-<date>`), and firmware entry `Boot0001 I30LTZ Recovery OS` appended LAST in `BootOrder` (Debian `Boot0003` stays first). Pending: set the root password (the script's last step), **boot test with the Debian drive unplugged** (the real standalone proof), update Debian's `/etc/fstab` line for `/mnt/recoveryos` (it still pins `490b9e60…`), and the first boot has not been tried. The install mount point is `/mnt/recoveryos-install` (temporary).

## App build partitions (user decision 2026-10-09)

The 1.8 TB Micron drive (`sda` on the 2026-10-09 Debian boot; `usb-Micron_CT2000X9SSD9_2523E8D92055`) now carries **four build partitions, one per product**, lettered A–D:

| Letter | Mount | Builds | Primary tooling |
|---|---|---|---|
| A | `/mnt/swarmbuild` | SWARM OS ISO | archiso, Flutter, Go, Rust, .NET (unchanged) |
| B | `/mnt/recoverybuild` | Recovery OS ISO (live-build) | live-build, Debian tools (unchanged) |
| C | `/mnt/lucillebuild` | **Lucille Assistant** — Go service `lucille-assistant` (:8403) + Android app `com.lucille.app` | Go 1.24, JDK 21, Gradle 8.7, Android SDK 35 |
| D | `/mnt/boltzbuild` | **Boltz Recovery** — phone app (Android): the I30LTZ Companion (`I30LTZ-Recovery-companion`, `com.aistudio.sysopt.app`); connects to both SWARM OS (A) and Recovery OS (B) | JDK 21 (Temurin), Gradle 9.6.1, Android SDK 36.1 — all on D (`env.sh`, `scripts/build.sh`; verified 2026-10-09: builds with a clean env, signed with the phones' key) |

Rules:
- **Everything needed to build an app lives on its own partition**: source, toolchains (Go / JDK / Android SDK / cargo+rustup), package caches (`GOPATH`, `GRADLE_USER_HOME`, `CARGO_HOME`) and the build output. Nothing builds from `/home`, `/tmp`, `/mnt/Lucy` or another app's partition. Each partition has an `env.sh` that points every tool at itself, so a build needs only that partition mounted (plus the OS packages for compilers/libs that can't be relocated).
- **Built apps must stand alone**: the output in `dist/` runs with no build tree, no `/mnt/Lucy`, no `/mnt/swarmbuild`, no other app's partition, and no tool from the build partition. Config and secrets come from the app's own config dir or an `.env` next to the install — never a path into a build tree. Never put secrets in `dist/`; ship `.env.example`.
- `/mnt/Lucy` stays the SWARM OS source of truth. The Lucille Assistant and Boltz Recovery (phone app) sources are no longer built from it (see the move log in `SWARM_AI_FEATURES.md`).
- `/mnt/recoveryos` is **not** a build partition — it is the installed Recovery OS root.
- **`/mnt/boltzbuild` was created NTFS by mistake** (user, 2026-10-09: "it was a mistake") and the user reformatted it ext4 themselves in GNOME Disks, so its real identity is the one in the mount table above (`UUID=6f7c7656-2984-4fb0-81c8-bfc11ca81461`, not the `e195839a…` earlier notes planned). If fstab/automount still name the old NTFS UUID: `sudo 70-scripts/fix_boltzbuild_mount.sh`. Locate these partitions by **PARTUUID** where scripting.
- **Product map (user, 2026-10-09 — read this before touching C or D):** **A SWARM OS** and **B Recovery OS** are the two *operating systems* (B is a kiosk OS; its Rust/Raylib `i30ltz-recovery` program, native workspace, first-boot kits, node agent and SSE bridge live on B). **C Lucille Assistant** and **D Boltz Recovery** are the two *phone apps*, and both connect to both OSes. The Android companion (I30LTZ Companion, `/mnt/recoverybuild/I30LTZ-Recovery-companion` until moved) is **part of Boltz Recovery**, i.e. D. Earlier wording here and in B's docs (`MOUNTS.md`, `mounts.manifest`, `fstab.canonical`, `CLAUDE.md`) calling D "the i30ltz Recovery app (Rust)" was wrong.
- Debian's `/etc/fstab` currently carries these three mounts as local lines using `/dev/disk/by-id/usb-…-partN` paths (written by GNOME Disks). `check_mounts.sh` knows the UUIDs; by-id is acceptable only because the drive is USB and the ids are stable, prefer the UUID form when editing.

**Per-OS differences:** the table above was captured from Debian. On another OS the *same mount points* must exist, but if its own root/partitions differ (e.g. its own root is not under `/mnt`, or a disk enumerates differently), record the difference here under that OS's name — do not silently diverge. Known so far: none beyond the device names, except **Debian**: the `lucy-master-bak` partition (UUID `c400a0ee…`) is mounted at `/mnt/archive` (rw, automount) rather than `/mnt/lucy_master`, so `check_mounts.sh` reports it as `ELSEWHERE` with a rw warning — remount it read-only (`sudo mount -o remount,ro /mnt/archive`) or move its fstab entry to `/mnt/lucy_master` with `ro`. All Debian mounts are `x-systemd.automount`; `check_mounts.sh` handles that (checked 2026-10-07).

## Lucy ↔ swarmbuild sync (user, 2026-10-10)

`/mnt/Lucy` (source of truth) and `/mnt/swarmbuild` (build tree) are kept in sync **two ways**, and the tool tells a file *created* on one side from one *deleted* on the other:

```
70-scripts/sync_lucy_swarmbuild.sh both            # show the plan, changes nothing
70-scripts/sync_lucy_swarmbuild.sh both --apply    # do it
```

- A file on only one side is **new** (copied over) if it was never in the history, or **deleted on the other side** (deleted here too) if it was. After every run the tool stores what both sides looked like (`/mnt/Lucy/.swarm-sync/manifest.sqlite`).
- Edited on both sides: the newer wins, the other copy goes to trash. Edited on one side and deleted on the other: **the edit wins**.
- Nothing is destroyed: deletions and overwrites go to `<root>/.sync-trash/<run>/` (kept 30 days, always the last 5 runs); every run is logged in `/mnt/Lucy/.swarm-sync/runs/`.
- Never synced either way: `.git`, build output (`target/`, `frontend/build`, `ephemeral/`, `obj/`), `swarm_os_build_work/`, `install-env/`, `flutter-sdk/`, the Go binaries the build compiles into the source tree, root-owned grub backups, `LucilleAssistant/` (own partition). The list is `70-scripts/swarm_sync.exclude`: add build products there so they can never be mistaken for a deletion.
- It **refuses** when a root is not mounted or is not the filesystem the history was made with, while an ISO build holds the build lock, or when the plan deletes suspiciously many files (an unmounted or emptied side looks exactly like "everything was deleted": `--allow-mass-delete` only if the deletions are real). An unreadable folder is treated as unknown, never as deleted.
- Never run plain `rsync` between the two trees, and do not use the older one-way `to-build`/`to-lucy` modes for routine work: they cannot tell created from deleted. After reformatting either partition on purpose, run `swarm_twoway_sync.py --rebaseline` once.
- Engine + tests: `70-scripts/swarm_twoway_sync.py`, `70-scripts/tests/test_twoway_sync.py` (`cd 70-scripts/tests && python3 -m unittest test_twoway_sync`). The first real run happened 2026-10-10 (14 stale images that had been moved on Lucy were trashed on swarmbuild instead of being copied back).

## SWARM OS runs standalone from the internal NVMe (user decision 2026-10-09)

SWARM OS must boot and run **completely off the internal NVMe** (`nvme0n1`): ESP `p1` (`FE19-A70F`), root `p2` (btrfs `swarm-root`, `UUID=f6f706d0-236a-4f7f-9c6d-948a90a509c5`, subvols `@`/`@home`/`@snapshots`) and swap `p3`. With **every external drive unplugged** (the Micron build/Debian drive, the Samsung T7, Ventoy, ...) it must still boot and work. Rules:
- Nothing SWARM OS needs at boot or runtime may live on an external drive, and nothing may `Requires=`/`RequiresMountsFor=` another mount. The internal extras `p4` `/mnt/Lucy`, `p5` `/mnt/brains`, `p6` `/mnt/slick` are **optional** (`nofail`); build partitions, `lucy-master`, Recovery OS and Ventoy are never referenced by the OS image (the live `airootfs/etc/fstab` no longer lists the old `/mnt/endeavor`, `/mnt/recoverybuild`, `/mnt/recoveryos` entries).
- Apps run from `/opt/swarm_os` and `/usr/bin` inside the image. Logs go to `/var/log/swarm-ui/` (copied to `/mnt/Lucy/logs` only if Lucy is mounted). Dev-only timers (`swarm-workspace-parity`, `lucille-ai-sync`) carry `Condition*` lines so they skip silently when the dev drives are absent.
- Verify with `70-scripts/check_swarm_standalone.sh` (read-only; `sudo` adds the ESP / grub.cfg / UEFI-entry checks). Apply the fixes to an already-installed system with `sudo 70-scripts/make_installed_swarm_standalone.sh` (targeted edits, backs up, idempotent) — the installed `swarm-ui.service` has `User=i30ltz`, so never overwrite it with the repo copy.
- Known, accepted: the GRUB menu has a *Debian* entry chainloading external ESP `362A-E48F` (only that entry fails without the drive); Dr. Boltz's persona prompt and the shared memory log live on `p5` `/mnt/brains` (internal, separate partition) with a built-in fallback prompt; Go binaries carry build-tree source paths (no `-trimpath`) — cosmetic, not a dependency.
- Not yet boot-tested with all externals unplugged — that is the real proof and only the user can do it.

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

## "Do not touch" means: ask first — the user says "touch" or "no" (user, 2026-10-14)

Every "do not touch / do not modify" in this file and in the docs (`30-source/lucille-core/`, `30-source/GamingAgent/`, the orphaned dirs, the phone apps on partitions C and D, and so on) is a lock the **user** holds, not a permanent ban. Leave those things unchanged **until the user says "touch"** about that specific thing; "no" (or silence) keeps it locked. When a task needs one, ask once, plainly: *"Touch <thing> to do <change>? touch / no."* A "touch" covers that thing for that change only. Do not hunt for ways around a lock (a workaround that changes a locked thing's behaviour is touching it).

## Hard rules — do not break these

- **Never write to `/run/media/i30ltz/lucy-master/`** — read-only reference mount. All writes go to `/mnt/Lucy/`. No sync job targets lucy-master or `/mnt/archive` (`lucy-master-bak`, c400a0ee): the Lucy ↔ lucy-master two-way sync (`sync_lucy_master.sh`) was removed on 2026-10-11 at the user's request. The one remaining writer is the older, additive `70-scripts/sync_lucille_ai.sh` (runs from the ISO's `lucille-ai-sync` unit; its sda4 leg only runs if the LUKS volume is already unlocked).
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

**Network (Tailscale): the Debian dev PC is `100.82.1.19`** (changed 2026-10-09 by the user; it was `100.82.1.21`, and `.19` had been Cachy's address). `100.82.1.21` no longer exists on the tailnet. Never hardcode it: `tailscale ip -4` prints the current address. The LucyServer drop-in `~/.config/systemd/user/swarm-lucy-dev.service.d/listen.conf` (`ASPNETCORE_URLS`) was changed to `http://127.0.0.1:5000;http://100.82.1.19:5000` on 2026-10-09 (backup `listen.conf.bak-20261009-202628`; the `swarm-lucy-dev` user unit is not enabled at boot, but the user started it at 20:27 and it now listens on `127.0.0.1:5000` and `100.82.1.19:5000`). The only thing still pinned to `.21` is the frozen copy under `30-source/LucilleAssistant` (do not edit it), plus any companion app with a saved node address of `.21`. Lucille Assistant already listens on `100.82.1.19:8403` (`LUCILLE_ASSISTANT_LISTEN` in `~/.config/lucille-assistant/.env`) and its phone app tries `100.82.1.19:8403`.

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
