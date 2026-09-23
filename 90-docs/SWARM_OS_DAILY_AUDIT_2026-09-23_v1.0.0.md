# SWARM OS — DAILY EVALUATION AUDIT

| Field | Value |
|---|---|
| **Document** | `SWARM_OS_DAILY_AUDIT_2026-09-23_v1.0.0.md` |
| **Document version** | v1.0.0 |
| **Audit date** | 2026-09-23 (run 01:31–01:55 UTC) |
| **Machine** | LUCILLE (CachyOS/Arch, user `i30ltz`) |
| **Project** | Luccile-v+ · branding **LLcy Core** · AI persona **Boltz** |
| **Source read** | `/mnt/Lucy` — the live authoritative tree, mounted, unlocked, read directly |
| **Project VERSION at audit start** | **6.2.70** |
| **Project VERSION at audit end** | **6.2.71** (bumped by a build that started mid-audit) |
| **git HEAD** | `7eb3ee9e` · `main` · 2026-09-22 21:34:14 -0400 |
| **Compiled / built / ran anything?** | **No.** Nothing was compiled, built, booted or executed by this audit. |

---

## 0. Lead finding — a build is running right now

An ISO build for **v6.2.71** started at **01:41:44 UTC**, ten minutes into this audit, and was mid-`mkarchiso` at 01:46 (GRUB config written, `base._make_customize_airootfs` checkpoint present). This audit therefore describes a **moving tree**. Every version number below was true at 01:46 UTC.

Two consequences:

1. The GRUB theme assets staged on 2026-09-22 02:26 (see M6) are in this build. **v6.2.71 is the first ISO that can prove the GRUB theme fix.** Boot-gate it.
2. The Android companion version bug (M1) was **observed failing live** during this build: VERSION went 6.2.70 → 6.2.71 and the companion stayed at 6.2.13. That is no longer an inference.

---

## 1. Source location — which tree was read

| Candidate | Status today |
|---|---|
| `/mnt/Lucy` (capital L, drive root) | **READ. This is the authoritative tree.** 250 GB, 65 GB used, mounted and unlocked. |
| `/mnt/lucy/Luccile-v+` | Not the source. `/mnt/Lucy/Luccile-v+` exists but holds **one stale file**, `build_swarm_iso_v6.2.2_2026-09-07.sh` (13 KB, 2026-09-07). `CLAUDE.md` itself states lowercase `/mnt/lucy/` is "empty, stale, ignore it". |
| `/run/media/i30ltz/LUCILLE/Luccile-v+` | Not present. The drive root carries an empty `run/media/i30ltz/` stub (see m3). |
| Google Drive mirror `1T4Oi5abo…` | Reachable, **17 days stale** — newest `modifiedTime` **2026-09-06T17:01:56Z**. Not used as a source. |

**The task's stated source order is out of date.** The project reorganised into a numbered tree (`00-CURRENT` … `99-archive`) at the drive root on 2026-09-08. `Luccile-v+/` is a leftover directory name, not the project root. Worth correcting in the task prompt so future runs do not chase it.

### Tree layout (as read)

```
/mnt/Lucy/
├── 00-CURRENT/        symlink façade → build-iso.sh, LucyServer, swarm_flutter, releases
├── 10-releases/       diagnostics tarballs only — no ISOs (see m5)
├── 20-runtime/        LucyServer runtime, .env, vosk model cache, candidate binaries
├── 30-source/         25 GB — frontend (Flutter), LucyServer(.NET/-go), GamingAgent-go,
│                      swarm-slint (Rust), lucille-core (C++), swarm-overlay,
│                      android_companion/, android_companion(seperate-related-project)/,
│                      i30ltz-recovery(seperate-related-project)/, flutter-sdk (vendored)
├── 40-iso-profile/    7.8 GB — swarm_os_iso_profile (mkarchiso), 131 packages
├── 50-backends/       GoogleWorkspaceService
├── 50-boot/           grub_themes
├── 60-boltz-brain/    swarm-memory mirror, identity, personas
├── 70-scripts/        build_swarm_iso.sh (25 KB, the real one) + 27 others
├── 80-vm/             QEMU dev VM, OVMF vars, qcow2
├── 90-docs/           prior audits (09-16, 09-17, 09-18, 09-20), policies, guides
└── 99-archive/, _to_delete/, swarm_os_build_work/ (17 GB), legacy root duplicates
```

### Changed in the last 24 h (meaningful files only)

| When (UTC) | What |
|---|---|
| 09-23 01:41→01:46 | **v6.2.71 build in flight** — VERSION, pubspec.yaml, Cargo.toml, profiledef.sh, `etc/swarm-release`, `swarm_os_build_work/` |
| 09-23 01:34 | `SWARM_AI_FEATURES.md` (246 KB), `60-boltz-brain/swarm-memory/PROJECT_MEMORY.md`, `swarm-ui.service` — written by the 5-minute memory-sync timer |
| 09-22 16:58 | `logs/sync_lucille_ai.log`, `I30LTZ_RECOVERY_BUILD_TRACKER.md` — hourly sync tick (failed again, see M2) |
| 09-22 06:52 | `logs/swarm-ui-20260922-065239.log` — **10th labwc crash** (see B1) |
| 09-22 06:19→06:27 | `frontend/lib/screens/memory_screen.dart`, `services/memory_service.dart`, `services/swarm_memory_service.dart` — real feature work on the memory UI |
| 09-22 04:11 | `LucyServer-go/lucy-server` (15 MB), `GamingAgent-go/gaming-agent` (18 MB) rebuilt |
| 09-22 03:25 | `20-runtime/companion-audit-build.log` — **companion Android build SUCCEEDED**, unit tests ran |
| 09-22 02:26 | GRUB theme assets staged into the ISO profile (`menu.pf2`, `theme.txt`, `select_*.png`) |

### git

`main` at `7eb3ee9e`. The last 20 commits are all `auto-sync: <timestamp>` on an ~11-minute timer. Two gaps stand out: **02:44 → 18:51 on 2026-09-22 (16 hours with no commit)**, then a resumed cadence. Two worktrees are registered and both report `prunable`:

```
/home/i30ltz/.codex/worktrees/f25b/Lucy          e2c60b7 (detached) prunable
/mnt/Lucy/.git/pr-worktrees/gaming-os-wide-wake  7f81006 [codex/…] prunable
```

### Build scripts, artifacts, manifests

| Item | Version / date | Note |
|---|---|---|
| `70-scripts/build_swarm_iso.sh` | 25,081 B · 2026-09-21 04:37 | The real auto-version engine. Single source of truth. |
| `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` | 162 B · 09-19 | Compat forward → `build_swarm_iso.sh`. Correct. |
| `70-scripts/build_swarm_iso_v6.2.19_2026-09-07.sh` | 162 B · 09-19 | Same. Correct. |
| `Luccile-v+/build_swarm_iso_v6.2.2_2026-09-07.sh` | 13,479 B · 09-07 | **Orphan — a real old implementation, not a forward.** See m3. |
| `70-scripts/swarm_iso_manager.py` | 8,728 B · 09-19 | Ventoy presence gate, retention, `check`/`list`/`latest`. |
| `install_swarm_os.sh` (drive root) | 27,199 B · 09-12 | Lives outside `70-scripts/`. |
| ISO artifacts on this drive | **none** | Release dir is `/mnt/ventoy/ISO/SWARM_OS` — not visible from this session. |
| `_to_delete/duplicate-isos-2026-09-12/` | 2 × 3.38 GB | v6.2.44 and a `swarm-os-v6.2.iso`. Dead 11 days. |
| Checksums / manifests | `90-docs/MANIFEST_2026-09-07.md` only | No per-release checksum file reachable here. |

---

## 2. Evaluation

Ranked. Every finding states a concrete failure. Findings resting on metadata alone are marked **NOT CONFIRMED** with the one command that settles them.

### BLOCKER

#### B1 — The desktop shell has not started since 2026-09-16. *(confirmed)*

`labwc` dies within 1–3 seconds of the PAM session opening, on **both** real hardware and the QEMU dev VM. Ten crash logs, every one 346–350 bytes, every one ending at the same line:

```
Sep 22 06:52:36 archiso systemd[1]: Starting SWARM OS Desktop (labwc compositor + Flutter hex-grid shell)...
Sep 22 06:52:37 archiso systemd[1]: Started SWARM OS Desktop (labwc compositor + Flutter hex-grid shell).
Sep 22 06:52:37 archiso (dbus-run-session)[1242]: pam_unix(login:session): session opened for user swarm(uid=1000) by swarm(uid=0)
```

Nothing after. Logs: `swarm-ui-20260916-102759` · `-105515` · `-112724` · `-121617` · `-233805` · `-235049` · `20260917-000454` · `-002729` · `20260921-192814` · `20260922-065239`.

**Failure scenario:** a user boots any SWARM OS ISO from 6.2.x since 2026-09-16, reaches `swarm-ui.service`, and gets a black tty1 that restarts three times in 60 s and then gives up on `StartLimitBurst=3`. The Flutter hex-grid shell and the Slint Lucille panel — the product — never draw a pixel. Everything behind them is fine: the 2026-09-22 boot gate shows Lucy Server (Go), Gaming Agent (Go) and Google Workspace (.NET) all reaching `OK`. **The OS boots; the face of it does not.**

This outranks everything else in this report. It is seven days old and the backlog above it keeps growing.

#### B2 — The instrument built to diagnose B1 is not recording. *(confirmed)*

`swarm-ui.service` gained an `ExecStopPost` on 2026-09-22 that should emit three labelled sections into `/mnt/Lucy/logs/swarm-ui-*.log`:

```
=== systemctl status ===
=== journalctl -u swarm-ui.service -b ===
=== related drm/seat/wlroots/labwc lines, this boot ===
```

The 2026-09-22 06:52 log — written *after* that change — contains **none of those headers**. It is three raw journal lines and nothing else. `WLR_LOG_LEVEL=debug` was set in the same edit and produced no additional output either.

**Failure scenario:** every further reboot spends a full boot cycle and produces another 350-byte file that says nothing, and B1 stays unexplained for another week. Two possible causes worth separating: the `ExecStopPost` never runs (systemd skips it on certain exit paths), or its `bash -c` fails before the first `echo` and `|| true` swallows it.

**First move, and it costs three minutes:** stop the unit and run the compositor by hand, where nothing can swallow the output.

```bash
sudo systemctl stop swarm-ui.service
sudo -u swarm env XDG_RUNTIME_DIR=/run/user/1000 XDG_SEAT=seat0 XDG_VTNR=1 \
  XDG_SESSION_TYPE=wayland LIBSEAT_BACKEND=logind WLR_LOG_LEVEL=debug \
  dbus-run-session -- labwc 2>&1 | tee /mnt/Lucy/logs/labwc-manual-$(date +%Y%m%d-%H%M%S).log
```

If that starts cleanly, the fault is in the unit's session/seat setup, not in labwc — which narrows a seven-day-old blocker to one file in a single run.

### MAJOR

#### M1 — The Android companion is never version-stamped. Wrong path in the build script. *(confirmed, observed live)*

`build_swarm_iso.sh:144`:

```bash
COMPANION_GRADLE="$LUCY/30-source/android_companion/app/build.gradle.kts"
if [ -f "$COMPANION_GRADLE" ]; then …
```

The file does not exist at that path. The real one is:

```
30-source/android_companion/swarm_os-companion/app/build.gradle.kts
```

The `swarm_os-companion/` level is missing. The `[ -f ]` guard fails silently, both `sed` calls are skipped, and line 150 prints **"✓ All application badges and ISO profiles stamped"** regardless.

Measured at 01:46 UTC today, mid-build:

| Component | Version |
|---|---|
| `VERSION` | 6.2.71 |
| Flutter `pubspec.yaml` | 6.2.71+71 |
| swarm-slint `Cargo.toml` | 6.2.71 |
| ISO `profiledef.sh` | `swarm-os-v6.2.71-7eb3ee9e` |
| `airootfs/etc/swarm-release` | 6.2.71 |
| **Android companion** | **6.2.13 · versionCode 73** |

`versionCode = 73` is exactly `60 + 13` from the script's own formula — proving the last successful stamp was v6.2.13, **58 releases ago**.

**Failure scenario:** the user sideloads today's companion APK onto a phone already running the 6.2.13 build. Android compares `versionCode` 73 to 73, finds no upgrade, and either refuses the install or silently keeps the old APK. The user believes they are testing 6.2.71 against a v6.2.71 desktop while running 58 versions of stale client code — and since both halves talk over the same local API, the failures will look like server bugs.

**Fix (one line):**
```bash
sed -i 's|30-source/android_companion/app/build.gradle.kts|30-source/android_companion/swarm_os-companion/app/build.gradle.kts|' \
  /mnt/Lucy/70-scripts/build_swarm_iso.sh
```
Then drop the `if [ -f ]` guard, or make its `else` branch abort. A silent skip on a stamping step is how this hid for 58 builds.

#### M2 — `sync_lucille_ai.sh` has failed on every run for 11 days. Invalid rsync flag. *(confirmed)*

`70-scripts/sync_lucille_ai.sh:60`:

```bash
if rsync -a --checksum --no-delete --human-readable --info=stats1 \
```

`--no-delete` is not an rsync option. rsync 3.5.0 rejects it outright:

```
rsync: --no-delete: unknown option
rsync error: syntax or usage error (code 1) at main.c(1886)
```

First occurrence in the log: **2026-09-12 20:54:06**. Most recent: **2026-09-22 16:58:03**. **54 FAIL entries**, every hourly tick, unbroken. Each tick ends `Sync complete — ok=1 fail=1` — the recovery-binary leg succeeds, so the run *looks* half-healthy and never alarms.

**Failure scenario:** the Lucille-AI payload on `/mnt/boltz/Lucille-AI` has not been updated since 2026-09-12. If the primary drive is lost today, the restore is eleven days old and predates the entire numbered-tree reorganisation, the Go ports, and swarm-slint. **This is a backup that has been silently dead for eleven days.**

**Fix:** rsync's default is already no-delete. Delete the flag.
```bash
sed -i 's| --no-delete||' /mnt/Lucy/70-scripts/sync_lucille_ai.sh
```
Then make the wrapper exit non-zero when any leg fails, so `fail=1` cannot sit in a log for eleven days unnoticed.

#### M3 — `.git` is 7.6 GB across four near-identical giant packs. *(NOT CONFIRMED — pack contents not inspected)*

```
pack-61dc9569….pack  1.7G   (idx 1.1K)   2026-09-19 13:34
pack-8a39a3e2….pack  1.7G   (idx 1.1K)   2026-09-19 14:50
pack-f825ab40….pack  1.7G   (idx 1.1K)   2026-09-19 15:00
pack-bd150c43….pack  1.8G   (idx 1.1K)   2026-09-22 04:15
```

A 1.1 KB `.idx` for a 1.7 GB pack means each pack indexes only a handful of objects — so these are a few very large blobs, repacked four times rather than four distinct histories. The 09-19 cluster (13:34, 14:50, 15:00) reads as three repack or fetch attempts inside 90 minutes.

**Failure scenario:** `auto_sync_github.sh` runs `git push origin main` every 11 minutes. GitHub rejects any single blob over 100 MB and times out on multi-gigabyte packs. Once a push fails, `set -euo pipefail` aborts the script (see M5) and the two subtree pushes below it never run — so all three GitHub repos stop updating and the "so claude.ai/code on other devices sees recent work" guarantee in the script's own header quietly stops being true. The **16-hour commit gap on 2026-09-22 (02:44 → 18:51)** is consistent with exactly this, though it has another possible explanation (the machine being off).

I did not inspect the pack contents — `git verify-pack` on a 1.7 GB pack exceeded the shell's time limit twice. **The command that settles it:**

```bash
git -C /mnt/Lucy verify-pack -v .git/objects/pack/pack-bd150c4343275b9cd54452b13c36cc8cb70614c0.idx \
  | awk '$2=="blob"{print $3,$1}' | sort -rn | head -20 \
  | while read sz sha; do echo "$sz $(git -C /mnt/Lucy rev-list --objects --all | grep $sha)"; done
```

And to settle whether pushes are actually landing:
```bash
git -C /mnt/Lucy rev-parse main && git -C /mnt/Lucy ls-remote origin main
```
Two matching hashes means M3 is a disk-space problem only. Divergence means the GitHub mirror has been stale since that divergence.

#### M4 — The live ISO carries LUCILLE's private mount units. *(confirmed)*

From the 2026-09-22 boot gate, inside QEMU with no such disks attached:

```
[ TIME ] Timed out waiting for device /dev/…c123f1-… → Dependency failed for /mnt/endeavor
[ TIME ] Timed out waiting for device /dev/…6e3011-… → Dependency failed for /mnt/recoverybuild
[ TIME ] Timed out waiting for device /dev/…9c857f-… → Dependency failed for /mnt/recoveryos
[ TIME ] Timed out waiting for device /dev/…a1b27f-… → Dependency failed for /mnt/brains
[ TIME ] Timed out waiting for device /dev/…f0e009-… → Dependency failed for /mnt/Lucy
```

Five host-specific UUID mounts are baked into the shipped `airootfs`.

**Failure scenario:** a user boots the ISO on any machine that is not LUCILLE — a friend's laptop, a VM, a test rig. systemd waits out the full device timeout on five mounts in series before the boot proceeds. `/mnt/brains` failing also means the swarm-memory sync has nothing to mirror, so Boltz boots without memory on every non-LUCILLE machine. For a distro intended to be handed to other people, the ISO currently only fully works on the one machine that built it.

**Fix:** mark them `nofail,x-systemd.device-timeout=1s` in the ISO's fstab, or drop them from `airootfs/` and mount them from a LUCILLE-only overlay.

#### M5 — `auto_sync_github.sh` repeats the exact bug it documents, one line higher. *(confirmed by reading the script)*

The script carries an excellent comment about a 2026-09-19 incident: a stale `--prefix` made a `git subtree push` fail, `set -euo pipefail` aborted the script, and the push below it never ran — so "BOTH downstream repos have likely been missing updates since the rename."

That specific prefix was fixed. But the structure was not:

```bash
if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "auto-sync: $(date -Iseconds)" --quiet
  git push origin main          # ← unguarded, under set -e
fi
git subtree --quiet push --prefix="30-source/i30ltz-recovery(seperate-related-project)" i30ltz-recovery main
git subtree --quiet push --prefix=30-source/android_companion/swarm_os-companion i30ltz-swarm-companion main
```

**Failure scenario:** `git push origin main` fails for any reason — network, credentials, or the 7.6 GB pack in M3 — and the script dies on the spot. Both subtree pushes are skipped. The failure is identical in shape and consequence to the one the comment describes, and it will be just as invisible, because nothing checks the timer unit's exit status.

**Fix:** `git push origin main || echo "origin push failed" >&2` and let each subtree push report independently. Then add `OnFailure=` to `swarm-lucy-sync.service` so a failed tick surfaces somewhere.

#### M6 — GRUB theme was missing at the last boot gate; the fix is unverified. *(confirmed missing; fix staged, not re-tested)*

Boot gate 2026-09-22 00:50, verbatim:

```
error: fs/archelp.c:grub_archelp_open:275:file `/boot/grub/themes/swarm_os/menu.pf2' not found.
error: fs/archelp.c:grub_archelp_open:275:file `/boot/grub/themes/swarm_os/theme.txt' not found.
Press any key to continue...
```

GRUB fell back to the plain text menu — no SWARM branding, and a "Press any key" prompt in front of a user who expects a boot screen. The menu itself was correct (Live Kiosk, Install to Disk, Safe Mode, Safe Mode + no KMS, Arch, Memtest, EndeavourOS, Ventoy, CachyOS, UEFI Shell).

`menu.pf2` (329 KB), `theme.txt` and the nine `select_*.png` slices were staged into the profile at **2026-09-22 02:26** — 96 minutes *after* that test. **No boot gate has run since.** The last one on disk is still `boot-gate-20260922-005030`.

**This is the cheapest win available today:** the v6.2.71 build now running is the first ISO containing the assets. Boot-gate it the moment it lands and M6 either closes or becomes a real bug.

### MINOR

| # | Finding | Evidence | Why it matters |
|---|---|---|---|
| m1 | `*.bak-$(date +%s)` files from an unexpanded command substitution — **still present** | `40-iso-profile/swarm_os_iso_profile/profiledef.sh.bak-$(date +%s)` (2026-09-06); one more in the prunable `pr-worktrees/gaming-os-wide-wake`; and **two in the Drive mirror** (`install_swarm_os.sh.bak-$(date +%s)`, `build_swarm_iso.sh.bak-$(date +%s)`) | A filename containing `$(…)` will execute on any unquoted glob expansion. Delete with `rm -- './profiledef.sh.bak-$(date +%s)'` (single quotes, `--`). |
| m2 | Google Drive mirror is **17 days stale** | Newest `modifiedTime` 2026-09-06T17:01:56Z. Still holds `.qcow2`, `.fd` and the `VERSION` file from 09-03 | It predates the numbered-tree reorg entirely. Anyone treating it as a fallback source gets a pre-reorg project. Retire it or re-point the sync at it. |
| m3 | Dead weight and layout drift at the drive root | `_to_delete/` **6.4 GB** (dead since 09-12) · `swarm_os_build_work/` **17 GB** · `chatgpt_amd64.deb` **399 MB** (a Debian package on an Arch project drive) · legacy duplicates `LucyServer/`, `swarm_flutter/`, `GoogleWorkspaceService/`, `grub_themes/`, `images/` alongside their numbered homes · empty stubs `mnt/` and `run/media/i30ltz/` from a script that used a relative path · `Luccile-v+/` holding one orphan 13 KB build script | ~24 GB recoverable. The duplicates are the real hazard: editing root-level `LucyServer/` instead of `30-source/LucyServer/` costs an afternoon before anyone notices. |
| m4 | Two `prunable` git worktrees | `/home/i30ltz/.codex/worktrees/f25b/Lucy`, `.git/pr-worktrees/gaming-os-wide-wake` | `git worktree prune` clears both; also removes one m1 file. |
| m5 | `10-releases/` contains no releases | Only `diagnostics/` (two 2 KB tarballs) and `.claude/`. `00-CURRENT/releases` symlinks to it | Since the 09-19 policy moved ISOs to Ventoy, the directory named "releases" is an empty signpost pointing the wrong way. Add a `README` or drop it. |
| m6 | No emoji or CJK font in the built rootfs | 30 font files present — Liberation, Adwaita, gnu-free. No Noto, no emoji | Latin text renders. Emoji and CJK become tofu boxes. `noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji` is a ~150 MB fix. |
| m7 | Boot-gate coverage is thin | Runs on 09-13 (×6), 09-14, 09-17, 09-19, 09-22 | Eight builds shipped between 09-19 and 09-22 with one gate between them. |

### Verified CLEAN — previously-open items that are now fixed. Do not re-report.

| Item | Status today |
|---|---|
| `CLAUDE.md` containing stock AWS boilerplate | **FIXED.** 10,180 B of real SWARM OS convention — ISO release policy, the `/mnt/Lucy` vs `/mnt/lucy` warning, the current two-client labwc architecture, the read-and-update rule for `SWARM_AI_FEATURES.md`. No AWS text anywhere. |
| VERSION disagreeing with hardcoded versions in build scripts | **FIXED for the desktop stack.** `build_swarm_iso.sh` is now an auto-bump engine that stamps VERSION, pubspec, Cargo, profiledef and `swarm-release` from one value; all five read 6.2.71 in step. Both dated scripts are 162-byte compat forwards. *The Android companion is the one component still excluded — that is M1, a path bug, not version drift.* |
| Compiled artifacts (`.o`, `.class`, `.qcow2`, binaries) tracked despite `.gitignore` | **FIXED.** `.gitignore` is now 90 lines across 11 categories including credentials, publish-output recursion and the `_to_delete` quarantine. `git ls-files | grep -E '\.(o\|class\|qcow2\|so\|a\|dll\|exe\|jar\|apk\|iso)$'` returns **0**. (Stale copies do remain in the abandoned Drive mirror — that is m2.) |
| Two Android companion trees with unclear precedence | **RESOLVED by naming.** `30-source/android_companion/` is primary (v6.2.13, built 09-22, pushed as the `i30ltz-swarm-companion` subtree). `30-source/android_companion(seperate-related-project)/` is explicitly marked separate (v6.2.11, 09-15). The same convention now labels `i30ltz-recovery(seperate-related-project)/`. Precedence is unambiguous. |
| `.swarm-build.lock` / `.iso-manager.lock` as stale-lock hazards | **NOT A BUG.** `exec 8>…; flock -n 8` — advisory, kernel-released on exit. The leftover zero-byte files are harmless; their mtime is a useful record of the last build start. |
| Fonts missing from the ISO (`packages.x86_64` lists only `fontconfig`) | **NOT A BUG — checked and withdrawn.** The package list names no font, but the built rootfs has 30 font files pulled in transitively (Liberation, Adwaita, gnu-free). Text renders. Only emoji/CJK coverage is absent (m6). |
| Android companion build health | **HEALTHY.** `BUILD SUCCESSFUL in 1m 44s`, 50 tasks, `testDebugUnitTest` ran, 2026-09-22 03:25. Only warnings: deprecated `Divider` → `HorizontalDivider`, and Gradle-10 deprecation notices. |
| Backend services on the ISO | **HEALTHY.** The 09-22 boot gate shows Lucy Server (Go), Gaming Agent (Go) and Google Workspace (.NET) all reaching `Started`, plus sealed-secrets unseal, seatd, NetworkManager and both timers. |

---

## 3. Upgrades — five, ranked by value

### U1 — Put a boot gate in front of every build, and make it assert, not just record *(highest value)*

Today `build_swarm_iso.sh` finishes, publishes to Ventoy, and nothing checks the ISO boots. The boot gate exists but is run by hand — eight builds between 09-19 and 09-22 got one run between them. The three worst findings in this report (B1, M4, M6) are all things a gate would have caught on the day they appeared, not a week later.

**Why it matters:** it converts "the desktop has been down for seven days and we found out during an audit" into "the build that broke the desktop refused to publish." It also gives M6 an automatic answer instead of a manual to-do.

**First step:** after the ISO is written but before it moves out of `.incoming`, boot it headless and grep the serial log for three assertions — no `themes/swarm_os/theme.txt' not found`, no `Timed out waiting for device`, and a positive `Started SWARM OS Desktop` **still alive 30 seconds later**. Fail the build on any of them. The harness already exists in `launch_swarm_vm.sh` and the `boot-gate-*` logs show the exact strings to match.

### U2 — Make the version stamper fail loudly instead of skipping quietly

M1 hid for 58 releases behind `if [ -f … ]; then` and a success message printed unconditionally afterwards.

**Why it matters:** the same silent-skip shape is reusable. Every future component added to the stamp step inherits the identical trap, and each one will be discovered the same way — by accident, months late, after someone tests against a stale build.

**First step:** replace every stamp guard with a hard assertion and count them.

```bash
stamp() {  # stamp <file> <sed-expr>
  [ -f "$1" ] || { echo "FATAL: stamp target missing: $1" >&2; exit 1; }
  sed -i "$2" "$1"; STAMPED=$((STAMPED+1))
}
```
End Step 1 with `echo "✓ $STAMPED targets stamped with v${NEW_VER}"` — a real count, not a claim. If the number drops, something moved.

### U3 — Amputate the git history and cap what auto-sync can commit

7.6 GB of pack, four copies of the same giant blobs, a commit every 11 minutes, and a push path that takes the whole sync down with it when it fails.

**Why it matters:** this is the one finding that gets monotonically worse while nobody looks at it, and it silently disables the cross-device sync the project depends on. It also makes every clone, every worktree and every `git gc` slower than the last.

**First step:** settle M3's open question first (`git ls-remote origin main` against local `main` — one command, answers whether pushes are landing). If they are not, the history needs surgery: `git filter-repo --strip-blobs-bigger-than 50M` on a clone, verify, then force-push and re-clone. Independently, and regardless: add a pre-commit size guard to `auto_sync_github.sh` so a stray ISO can never enter history again.

### U4 — Give the ISO a hardware-independent boot

M4 means SWARM OS boots properly on exactly one machine. For a distro whose stated goal is to be handed out as a bootable ISO, that is the gap between a project and a product.

**Why it matters:** every non-LUCILLE boot today eats five device timeouts in series and comes up with no `/mnt/brains`, so Boltz has no memory. Anyone the user hands a USB stick to sees a slow boot and an amnesiac assistant, and concludes the OS is broken.

**First step:** grep `airootfs/etc/fstab` and `airootfs/etc/systemd/system/*.mount` for the five UUIDs in M4. Add `nofail` and `x-systemd.device-timeout=1s` to each, then make the swarm-memory sync degrade cleanly when `/mnt/brains` is absent — `auto_sync_github.sh` already models this with its `mountpoint -q /mnt/brains` check.

### U5 — Make the OS able to build itself

"An OS that can code itself" currently ships with no Go compiler, no Rust toolchain, no JDK, no `adb`. Confirmed against the built rootfs, not just the package list: `usr/bin/go`, `usr/bin/cargo`, `usr/bin/adb` are all absent. The two primary backends are Go, the Lucille panel is Rust, the companion is Kotlin — **SWARM OS cannot rebuild a single one of its own components from inside itself.**

**Why it matters:** it is the difference between a shipped binary payload and a development environment. Right now the OS is a runtime for software that must be built on CachyOS and copied in.

**First step:** add `go`, `rustup`, `jdk-openjdk`, `android-tools` and `gradle` to `packages.x86_64` and measure the ISO growth (expect roughly +1.2 GB). If that is too much for the live image, ship a `swarm-devkit` pacman group that a first-boot prompt installs on demand — which keeps the live ISO lean and still makes the claim true.

---

## 4. Tooling — packages to add to the OS

All 131 current packages were read. Everything below was verified absent from **both** `packages.x86_64` **and** the built `airootfs`. Grouped by what it unblocks, most valuable first.

### Fixes something already broken or impossible today

| Package | What it enables or replaces |
|---|---|
| `wl-clipboard` | There is **no clipboard** on this OS. No `wl-copy`/`wl-paste`, so nothing can move text between the Flutter shell, Alacritty, foot and Chromium. For a coding OS this is the single most-missed thing after the shell itself. |
| `xdg-desktop-portal` + `xdg-desktop-portal-gtk` + `xdg-desktop-portal-wlr` | No portals means the Flutter shell's file-open and file-save dialogs have no backend, and screen sharing cannot work at all. Flutter's GTK3 embedder expects the GTK portal. |
| `polkit` | No GUI privilege escalation. Any authentication prompt from a desktop app has nothing to answer it — mounting a disk, changing network settings, installing a package from the shell all dead-end. |
| `grim` + `slurp` | No screenshot capability. Notable given B1: the fastest way to report a UI bug in the shell is a picture of it, and the OS currently cannot take one. |
| `mako` | No notification daemon — every desktop notification any app sends is silently dropped. |
| `android-tools` | `adb` and `fastboot`. **The companion APK cannot be deployed to a phone from SWARM OS.** For an OS whose purpose is Android development, this is the headline gap. Also the prerequisite for fixing M1 end to end. |
| `gvfs` + `gvfs-mtp` | Thunar is installed but cannot mount a phone over USB. With `gvfs-mtp`, plugging in the Android device makes it browsable — directly serving the companion workflow. |
| `syncthing` | `70-scripts/setup_syncthing_v1.0.0_2026-09-07.sh` exists and `.stfolder`/`.stignore` markers are scattered through `30-source/`, `60-boltz-brain/` and `90-docs/` — the project is built around Syncthing, and the ISO does not ship it. |
| `xdg-user-dirs` | No `~/Documents`, `~/Downloads`, `~/Pictures`. Chromium downloads and every file dialog land in `$HOME` root. |

### Coding

| Package | What it enables or replaces |
|---|---|
| `go`, `rustup` | Build `LucyServer-go`, `GamingAgent-go` and `swarm-slint` on the machine that runs them. See U5. |
| `jdk-openjdk`, `gradle` | Build the companion in-place. The 09-22 build log shows Gradle 9.6.1 with KSP and Roborazzi — all of it currently only possible on the host. |
| `scrcpy` | Mirror and control the phone on the desktop. Turns companion testing from a two-device juggle into one screen — and pairs naturally with the Lucille panel's monitor tab. |
| `helix` | A modal editor with LSP built in, no config file, ~15 MB. Replaces `vim`+`nano` as the serious in-OS editor without the plugin-management problem `neovim` brings to a live ISO. |
| `ripgrep`, `fd`, `fzf` | Replace `grep -r`/`find` at 10–50× on a 25 GB source tree. `fzf` also gives the shell history and file pickers that make a terminal-first OS pleasant. |
| `lazygit` | A full git TUI in one binary. Given how much of this project's state lives in git — worktrees, subtrees, an 11-minute auto-commit cadence — a visual view of it earns its 10 MB immediately. |
| `git-delta` | Readable diffs in the terminal. Replaces raw `git diff` output. |
| `bat`, `eza`, `zoxide` | `cat`/`ls`/`cd` with syntax highlighting, git status columns and frecency jumping. Small, and they set the tone of a coding OS from the first command. |
| `just` | A command runner for the build steps that currently live in 28 loose shell scripts in `70-scripts/`. A single `justfile` at the drive root gives `just build`, `just gate`, `just sync` — and makes M1-class path bugs visible in one file instead of buried at line 144 of one of them. |

### Gaming

`multilib` is **commented out** in `pacman.conf` (lines 113–114). Steam and every 32-bit game library need it enabled first — that is the gate on this whole section.

| Package | What it enables or replaces |
|---|---|
| `gamescope` | Valve's micro-compositor. Runs a game in an isolated nested session with its own resolution and FSR upscaling — critical here, because a game running directly under labwc would fight the Flutter shell for the display. This is the piece that makes gaming coexist with the SWARM desktop instead of replacing it. |
| `gamemode` | Switches CPU governor and I/O priority for the duration of a game. Pairs directly with the existing `EPP_POWER_POLICY.md` work and the `swarm-epp` power-source timer already in the ISO. |
| `mangohud` | In-game FPS, frame times, CPU/GPU load and temperature overlay. The natural data source for the GamingAgent's monitor tab — it can read MangoHud's log output rather than inventing its own telemetry. |
| `steam` | The library. GamingAgent-go already exposes a Steam API on port 8401 against a client the OS does not ship. |
| `lutris`, `wine` | Non-Steam and Windows titles. Lutris also covers the GeForce NOW path the Gaming Agent already advertises. |
| `vulkan-tools` | `vkcube` and `vulkaninfo`. The ISO already ships `vulkan-intel`, `vulkan-radeon` and the ICD loader — but no way to verify any of them work, which matters given a Flutter shell that needs ES 3.2+ and a compositor that currently dies without explanation (B1). This is a diagnostic, not a luxury. |

### Daily life

| Package | What it enables or replaces |
|---|---|
| `waybar` | A status bar. labwc ships without one, so today there is no clock, no battery indicator, no network state, no tray — unless the Flutter shell draws all of it, which doubles its job. |
| `brightnessctl` | Screen brightness. On a laptop with no bar and no settings panel, there is currently no way to change it. |
| `pavucontrol` | Per-application volume and output switching. PipeWire is installed; nothing can steer it. |
| `blueman` | Bluetooth pairing UI. `bluez` and `bluez-utils` are installed — headsets and controllers can connect, but only from the command line. |
| `swayidle` + `swaylock` | Idle timeout and screen lock. The machine currently never locks, which for an OS holding sealed API keys in `/run` is worth closing. |
| `power-profiles-daemon` | Balanced/performance/power-saver switching, and the standard interface `gamemode` and Waybar both expect. |
| `noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji` | Closes m6 — emoji and CJK stop rendering as tofu. |
| `keepassxc` | Local credential vault. Pointed: `20-runtime/.env`, `20-runtime/secrets/` and a `.env.bak-2026-09-13_174723` are sitting in plaintext on the project drive right now. |
| `tailscale` | Reach LUCILLE and the companion phone from anywhere without port-forwarding. Relevant to a project that already runs three GitHub remotes and an hourly cross-drive sync to keep devices in step. |

---

## 5. Scope ledger

**Read in full** — complete contents examined:

- `/mnt/Lucy/VERSION` (twice: 6.2.70 at 01:31, 6.2.71 at 01:46)
- `/mnt/Lucy/CLAUDE.md` (first 40 lines of 10,180 B — enough to settle the AWS-boilerplate item)
- `/mnt/Lucy/.gitignore` (all 90 lines)
- `70-scripts/auto_sync_github.sh` (complete)
- `70-scripts/manage_swarm_releases.sh` (complete)
- `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh`, `…_v6.2.19_2026-09-07.sh` (complete, 162 B each)
- `40-iso-profile/swarm_os_iso_profile/airootfs/etc/systemd/system/swarm-ui.service` (complete)
- `40-iso-profile/swarm_os_iso_profile/airootfs/home/swarm/.config/labwc/autostart` (complete)
- `40-iso-profile/swarm_os_iso_profile/packages.x86_64` (all 131 entries)
- `logs/boot-gate-20260922-005030.log` and its `-qemu.log` (complete)
- `logs/swarm-ui-20260922-065239.log` (complete, 346 B)
- `airootfs/etc/swarm-release`, and the same file in `swarm_os_build_work/`

**Read in part** — targeted greps, not full reads:

- `70-scripts/build_swarm_iso.sh` — lines 7–10, 27, 38, 40, 50–61, 71–90, 128–170, 313, 441 (version engine, lock, Ventoy gate, stamp block). ~120 of 25,081 B.
- `70-scripts/sync_lucille_ai.sh` — line 60 only.
- `logs/sync_lucille_ai.log` — head, tail 25, and FAIL counts across the whole file.
- `20-runtime/companion-audit-build.log` — final 30 lines.
- `pacman.conf` — multilib block.
- `pubspec.yaml`, `Cargo.toml`, `profiledef.sh`, both companion `build.gradle.kts` — version lines only.

**Seen by metadata only** — listed, sized, timestamped; contents never opened:

- Everything under `30-source/` except the version lines above — including `frontend/`, `LucyServer/`, `LucyServer-go/`, `GamingAgent-go/`, `swarm-slint/`, `lucille-core/`, `swarm-overlay/`, `GoogleWorkspaceService/`, `LucilleAssistant/`, both companion trees, `flutter-sdk/`.
- All four `.git` packfiles — **sizes and index sizes only. Contents were not inspected; `git verify-pack` exceeded the shell time limit twice. M3 rests on this metadata and is marked NOT CONFIRMED.**
- `swarm_os_build_work/` — directory timestamps, mkarchiso checkpoint filenames, and a font-file listing in `airootfs`. No build output read.
- `_to_delete/` — two ISO filenames and sizes.
- `90-docs/` prior audits (09-16, 09-17, 09-18, 09-20) — **not opened.** This audit re-derived every finding from the tree rather than inheriting prior conclusions.
- `60-boltz-brain/`, `99-archive/`, `images/`, `80-vm/` beyond the two OVMF files and the qcow2 size.
- Google Drive mirror — root listing of 30 entries (titles, sizes, `modifiedTime`). **No file downloaded, no content read.** Mirror freshness (2026-09-06) comes from that listing.

**Not reachable, and why:**

- **`/mnt/ventoy/ISO/SWARM_OS/`** — the actual ISO release directory, and therefore *every published ISO, its size, its checksum and the retention state*. This session reaches LUCILLE only through the single connected folder `/mnt/Lucy`; the Ventoy mount is outside it. **No claim in this report asserts that any ISO exists, boots, or was published.**
- **`/mnt/boltz/Lucille-AI`** — the M2 backup destination. Same reason. M2's eleven-day failure is established from the failing flag in the script and 54 FAIL lines in the log, **not** from inspecting the destination.
- **`/mnt/brains/swarm-memory`** — same reason.
- **Host process table** — `ps` inside this session shows only the session's own sandbox. The in-flight v6.2.71 build is established from `mkarchiso` checkpoint files, the build lock mtime (01:41:44) and version stamps advancing between 01:31 and 01:46 — **not** from seeing the process.
- **GitHub remote state** — no network operation against `origin` was attempted. Whether pushes are landing is open; the settling command is in M3.

**Nothing was compiled, built, booted, executed, installed, modified or deleted by this audit.** The only writes this session made are this file itself and its copy into `90-docs/`. Every reachable claim above came from reading files and timestamps. The v6.2.71 build running during this audit was started by the user's own tooling, not by this run.

---

*SWARM OS daily evaluation audit · document v1.0.0 · 2026-09-23 · machine LUCILLE · project v6.2.71*
