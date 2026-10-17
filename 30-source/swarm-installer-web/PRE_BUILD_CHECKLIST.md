# SWARM OS — Pre-Build Readiness Checklist

**Version:** 1.0.0 · **Date:** 2026-10-05 · **Target:** v6.2.73 (next bump from 6.2.72)
**Goal:** Ventoy-bootable live ISO that installs SWARM OS via a full GUI.

> Do not run the builder until every **GATE** below passes.
> `build_swarm_iso.sh` auto-bumps `VERSION` and writes straight into Ventoy,
> so a failed build still consumes a version number and a release slot.

---

## Corrected baseline (read this first)

The build log previously said *"Ubuntu 24.04 + live-build, ready to build."*
**That was wrong.** Verified state as of 2026-10-05:

| | Actual |
|---|---|
| Base | **Arch Linux archiso** |
| Build engine | `mkarchiso` inside an Arch Docker container (`70-scripts/mkarchiso-docker.sh`) |
| Canonical builder | `70-scripts/build_swarm_iso.sh` (run as normal user, **never** sudo) |
| Profile | `40-iso-profile/swarm_os_iso_profile/` |
| Current VERSION | `6.2.72` |
| Ventoy | **already set up** — `/mnt/ventoy`, UUID `5ABB-83DF` |
| Release dir | `/mnt/ventoy/ISO/SWARM_OS/` |
| Installer (before today) | CLI only — `install_swarm_os.sh`, no GUI |

`setup-swarm-iso-ubuntu.sh` in `/mnt/Lucy` is an **unused Ubuntu detour**.
It was never executed and there is no `swarm-iso-ubuntu/` workspace.
Decision 2026-10-05: stay on Arch. Archive or delete that script.

---

## GATE 1 — Host build dependencies

- [ ] `docker --version` works and the daemon is running
- [ ] current user is in the `docker` group (`id -nG | grep docker`)
- [ ] `docker pull archlinux:latest` succeeds (the builder pulls this)
- [ ] `python3 --version` ≥ 3.9
- [ ] `git -C /mnt/Lucy rev-parse --short HEAD` works (build stamps the commit)

## GATE 2 — Media and storage

- [ ] Ventoy mounted at `/mnt/ventoy`, UUID `5ABB-83DF`
      → `findmnt -no UUID /mnt/ventoy` must print exactly that
- [ ] `python3 70-scripts/swarm_iso_manager.py check` passes
- [ ] Free space on Ventoy ≥ **12 GiB** (one ISO + `.incoming` staging)
- [ ] Free space on `/mnt/Lucy` ≥ **25 GiB** (mkarchiso work dir)
- [ ] ISO count at or under the 10-image cap
      → `python3 70-scripts/swarm_iso_manager.py prune --dry-run`
- [ ] Boltz archive disk present if a weekly archive is due
      (UUID `689e6547-b439-4e7f-93c9-a6dcfabed46b`)

## GATE 3 — Graphical installer wired in

- [ ] `30-source/swarm-installer-web/` present on `/mnt/Lucy`
- [ ] Dry run passes on the dev host:
      `SWARM_INSTALLER_DRYRUN=1 python3 30-source/swarm-installer-web/server.py`
      → all 6 screens reachable, disk picker lists real disks, log streams,
        finish screen appears
- [ ] **The live USB does not appear in the disk list.** Boot-medium exclusion
      only engages on a live boot, so confirm again during GATE 7.
- [ ] `bash install-to-profile.sh --dry-run` reports no errors
- [ ] `bash install-to-profile.sh` applied
- [ ] `packages.x86_64` contains `python`, `chromium`, `cage`
- [ ] `airootfs/usr/local/bin/install_swarm_os.sh` still present and executable
- [ ] sudoers rule present, mode `0440`
      → `stat -c %a airootfs/etc/sudoers.d/21-swarm-installer-gui` = `440`
- [ ] autostart line added to `airootfs/etc/sway/config`, **or** you accept
      launching from the desktop entry

## GATE 4 — Profile sanity

- [ ] `profiledef.sh` present, `iso_name` / `iso_label` sane
- [ ] `packages.x86_64` has no duplicate lines
      → `sort packages.x86_64 | grep -v '^#\|^$' | uniq -d` prints nothing
- [ ] every package resolves in current Arch repos (a single dropped package
      fails the whole build **after** the version bump)
      → `docker run --rm archlinux:latest bash -c \
         "pacman -Sy >/dev/null 2>&1; pacman -Sp $(grep -v '^#\|^$' \
         40-iso-profile/swarm_os_iso_profile/packages.x86_64 | tr '\n' ' ') \
         >/dev/null" && echo RESOLVED`
- [ ] `airootfs/etc/fstab` entries use `nofail` (boot must survive a missing drive)
- [ ] no stale `swarm_os_build_work/` from an interrupted run
      → remove it, or mkarchiso may reuse dirty state
- [ ] `70-scripts/.swarm-build.lock` not held by a dead process

## GATE 5 — Security (do these, they are open findings)

- [ ] 🔴 **Rotate the leaked keys.** `.env.local` with live OpenAI / OpenRouter /
      NVIDIA / Google keys was in a shipped tarball. Rotate at each provider,
      then confirm no secret is in the profile:
      → `grep -rIl "sk-\|api[_-]key\|OPENAI\|OPENROUTER" 40-iso-profile/ | head`
- [ ] 🔴 Confirm `root:swarm` / `lucy:swarm` with NOPASSWD sudo is **intended**
      for this live image, and that the image is not shared publicly
- [ ] Confirm `tailscaled` + sentinel (`/remote`, `/sse`) auto-enabling on live
      boot is intended; disable if this ISO leaves your hands
- [ ] `seal_secrets.sh` run if it applies to this release

## GATE 6 — Build

- [ ] `python3 70-scripts/tests/test_desktop_boot_contract.py` passes
      (the builder runs this and aborts before version stamping if it fails)
- [ ] `python3 -m unittest discover -s 70-scripts/tests -p 'test_iso_*.py'` passes
- [ ] Run as **normal user, not sudo**:

```sh
cd /mnt/Lucy
./70-scripts/build_swarm_iso.sh
```

- [ ] Build completes; ISO lands in `/mnt/ventoy/ISO/SWARM_OS/`
- [ ] `VERSION` bumped to `6.2.73`
- [ ] Record the SHA-256 of the published ISO

## GATE 7 — Boot gate (before trusting the image)

- [ ] VM gate passes: `70-scripts/vm_boot_gate.sh`
- [ ] Real hardware boot from Ventoy — **both** firmware modes if your box
      supports them (UEFI and Legacy/CSM)
- [ ] Live session reaches the desktop / gamescope session
- [ ] **Install SWARM OS** launches and renders the Lucille theme
- [ ] Disk list is correct **and the Ventoy USB is absent from it**
- [ ] Flags appear on removable / LUKS / mounted disks
- [ ] Typed-confirmation gate blocks the install button until the path matches
- [ ] Record `boot_gate=pass` metadata so weekly archiving becomes eligible

## GATE 8 — Install test (use a scratch disk, not your daily driver)

- [ ] Install to a spare disk end to end
- [ ] Live log streams through to completion, exit code 0
- [ ] Reboot button works
- [ ] Installed system boots unaided
- [ ] `i30ltz` login works with the password set in the GUI
- [ ] `/etc/swarm-release` carries the right version / commit / date
- [ ] `fstab` on the installed system uses `nofail`
- [ ] Machine boots with **only** the SWARM disk attached (portability rule)
- [ ] Lucille / LLcy starts

---

## Known gaps, deliberately not blocking

| Gap | Note |
|---|---|
| BORE scheduler | Needs a custom kernel build. Phase 2. |
| `sentinel:build` | Missing in `electron/build.mjs` — only `main.ts` + `preload.ts` bundled. Separate issue. |
| Locale / keyboard / timezone in GUI | Backend takes no such flags. Add there first. |
| I30LTZ Recovery OS | Separate build, separate tracker. |

## If the build fails

1. A failed build **already consumed** a version bump. Expect `6.2.74` next.
2. `build_swarm_iso.sh` removes its in-progress ISO on normal failure; the next
   locked build clears interrupted output.
3. Clear `swarm_os_build_work/` before retrying.
4. Ventoy GRUB problems: `70-scripts/diagnose_ventoy_grub.sh`,
   and `70-scripts/DESKTOP_BOOT_REPAIR.md`.
5. If Ventoy normal mode will not boot the ISO, try Ventoy **Compatible Mode**
   (press `c` at its menu) before suspecting the image.
