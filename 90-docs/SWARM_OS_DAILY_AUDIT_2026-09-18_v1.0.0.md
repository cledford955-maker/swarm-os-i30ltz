# SWARM OS — Daily Evaluation Audit

| Field | Value |
|---|---|
| **Document** | `SWARM_OS_DAILY_AUDIT_2026-09-18_v1.0.0.md` |
| **Document version** | v1.0.0 |
| **Audit date** | 2026-09-18 (run 14:08–14:30 UTC) |
| **Machine** | LUCILLE — CachyOS/Arch, user `i30ltz`, device `cachyos-i30ltz` |
| **Project** | Luccile-v+ · branding "LLcy Core" · AI persona "Boltz" |
| **Source read** | **Option 1 — the authoritative LUKS tree, unlocked and readable at `/mnt/Lucy`** |
| **Tree VERSION** | `6.2.57` (unchanged since 2026-09-17 11:22 UTC — no build ran today) |
| **Drive mirror** | reachable; newest `modifiedTime` **2026-09-06T17:01:56Z** — **12 days stale**. Used only to re-check two known open items. |
| **Prior audit** | `90-docs/SWARM_OS_DAILY_AUDIT_2026-09-17_v1.0.0.md` — every finding in it was re-verified against disk today, not copied forward |
| **Compiled / built / booted / ran anything?** | **No.** Nothing was compiled, built, booted, executed or modified. Every finding below comes from reading files, file metadata, git state, and logs the machine wrote itself. |

---

## 0. Headline

**The GitHub auto-sync has been dead for 24 hours, and the cause is a stale `.git/index.lock` left at 2026-09-17 14:09 UTC — one minute after the last successful commit.** Every tick since has aborted at `git add -A`. A day of work — including yesterday's audit, the overnight boot-gate logs, and today's bootloader fix — is sitting uncommitted on one encrypted drive with no second copy. The fix is one command.

**Second: the boot gate has been blind the whole time.** The operator did the right thing overnight — re-ran the gate against v6.2.57 with the timeout raised to 1200 s, exactly as yesterday's audit recommended. It failed again, identically. The reason is now clear from the ISO's own bootloader config: **the kernel command line in v6.2.57 carries no `console=ttyS0`**, so QEMU's serial capture goes silent the moment the kernel takes over. The gate was never watching the boot — it was watching a blank screen and waiting on two HTTP probes. That has been true for every gate run to date.

Real progress since yesterday: the AWS boilerplate is gone from `CLAUDE.md`, the boot-gate timeout was raised, and the loader entry was hand-patched with a serial console. Two of yesterday's findings now have exact root causes rather than symptoms.

---

## 1. Inventory

### 1.1 Tree layout — `/mnt/Lucy`, 52 GB used of 250 GB (186 GB free)

Numbered-prefix layout, unchanged from yesterday: `00-CURRENT/`, `10-releases/`, `20-runtime/`, `30-source/`, `40-iso-profile/`, `50-backends/`, `50-boot/`, `60-boltz-brain/`, `70-scripts/`, `80-vm/`, `90-docs/`, `99-archive/`, plus `_to_delete/` quarantine, `images/`, `logs/`, `swarm_flutter/`.

Git tracks a deliberately narrow source-only slice on branch `main`, three remotes (`origin` → `swarm-os-i30ltz`, `i30ltz-recovery`, `i30ltz-swarm-companion`).

### 1.2 Changed in the last 24 h — 8 files, and every one of them matters

| File | mtime (UTC) | What happened |
|---|---|---|
| `90-docs/SWARM_OS_DAILY_AUDIT_2026-09-17_v1.0.0.md` | 09-17 14:18 | Yesterday's audit. **Still untracked (`??`) in git.** |
| `logs/boot-gate-20260917-231246.log` | 09-18 03:13 | Overnight gate re-run, serial capture |
| `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` | 09-18 03:21 | Build engine edited |
| `logs/boot-gate-20260917-231246-qemu.log` | 09-18 03:32 | One line: QEMU killed by SIGTERM from the gate's own timeout |
| `logs/boot-gate-rerun.log` | 09-18 03:32 | Gate console output — **FAILED after 1200 s** |
| `SWARM_AI_FEATURES.md` | 09-18 03:49 | Feature log updated |
| `40-iso-profile/.../efiboot/loader/entries/01-archiso-linux.conf` | 09-18 03:49 | **Serial console + graphical.target + apparmor added to kernel cmdline** |
| `60-boltz-brain/swarm-memory/PROJECT_MEMORY.md` | 09-18 14:00 | Memory mirror — still ticking (see BLOCKER-1) |

No ISO was built today. `VERSION` was not bumped. The overnight session was diagnosis, not release work.

### 1.3 Git state

```
Last commit:  1e9963b  auto-sync: 2026-09-17T10:08:35-04:00   (= 2026-09-17 14:08 UTC)
Now:          2026-09-18 14:10 UTC          →  exactly 24 h, 2 min of silence
HEAD == origin/main  (0 commits ahead — nothing pending push)
Working tree: 4 modified, 1 untracked — all uncommitted
```

Prior to the stall, `auto-sync:` commits landed every ~11 minutes without a gap. The cadence did not degrade; it stopped dead.

### 1.4 Build & operations scripts — `70-scripts/`

The live build engine is still `build_swarm_iso_6.2.19_2026-09-08.sh` (30,321 bytes, edited 03:21 today) — the filename says 6.2.19 while it produces 6.2.57. Its near-twin `build_swarm_iso_v6.2.19_2026-09-07.sh` (one character apart, `v`) is superseded and still present. `vm_boot_gate.sh` ran overnight and failed. `auto_sync_github.sh` is running but aborting (BLOCKER-1). `sync_lucille_ai.sh` has not run since 2026-09-17 05:10 and has never succeeded. `generate_manifest_v1.0.0_2026-09-07.sh` still exists and is still invoked by nothing.

### 1.5 Release artifacts & checksums

| Artifact | Bytes | Built | Checksum | Gate |
|---|---|---|---|---|
| `swarm-os-v6.2.57.iso` | 3,561,799,680 | 09-17 11:43 | **none** | **FAILED twice** (480 s, then 1200 s) |
| `swarm-os-v6.2.50-cc49de3a-2026.09.13-x86_64.iso` | 3,377,790,976 | 09-13 23:35 | **none** | assumed pass — it is what `latest` points to |
| `swarm-os-v6.2.49-cc49de3a-2026.09.13-x86_64.iso` | 3,377,790,976 | 09-13 10:30 | **none** | unknown |
| `swarm-os-latest.iso` → `…v6.2.50…` | symlink | repointed 09-17 11:51 | — | — |

A tree-wide search found **zero** `.sha256`, `SHA256SUMS`, or release-manifest files. The only `manifest.json` hits are Flutter/web scaffolding inside the vendored SDK.

**Nothing has passed a boot gate since v6.2.50 on 2026-09-13 — five days.**

### 1.6 Version labelling across the stack

| Surface | Value today | Correct? |
|---|---|---|
| `VERSION` | `6.2.57` | source of truth |
| `profiledef.sh` `iso_name` / `iso_application` | `swarm-os-v6.2.57-88154714` / `SWARM OS · Lucille v6.2.57` | ✅ |
| `airootfs/etc/swarm-release` | `SWARM_VERSION=6.2.57 SWARM_COMMIT=88154714 SWARM_DATE=20260917` | ✅ |
| Flutter `pubspec.yaml`, `top_bar.dart`, Slint `Cargo.toml` | stamped by build script lines 114–118 | ✅ (script-verified — see Scope ledger) |
| **`efiboot/loader/entries/01-archiso-linux.conf`** | **`title SWARM OS v6.2.19`** | ❌ **38 releases stale — MAJOR-4** |
| **Companion `app/build.gradle.kts`** | **`versionName = "6.2.12"`, `versionCode = 72`** | ❌ **never stamped — BLOCKER-3, root cause now known** |
| `README.md` (4 refs), `CLAUDE.md:72` | `6.2.19` | stale docs — MINOR-9 |

---

## 2. Evaluation

### BLOCKER-1 — a stale `.git/index.lock` has silently killed the GitHub sync for 24 h · **CONFIRMED**

```
-rw------- 1 i30ltz i30ltz 0 Sep 17 14:09 /mnt/Lucy/.git/index.lock
```

Zero bytes, created **2026-09-17 14:09 UTC** — sixty seconds after commit `1e9963b` at 14:08. No git process has held it since; it is orphaned, almost certainly from a timer tick that was interrupted mid-commit.

`auto_sync_github.sh` runs under `set -euo pipefail`. Its sequence is: mirror `/mnt/brains/swarm-memory` into the repo → test `git status --porcelain` → `git add -A` → commit → `git push origin main` → two `git subtree push`es. The memory-mirror step still runs and still works — `PROJECT_MEMORY.md` has an mtime of **14:00 UTC today**, ten minutes before this audit. So the timer is alive and firing. It then reaches `git add -A`, which fails with `Unable to create '.git/index.lock': File exists`, and `set -e` kills the script before the commit, the push, and both subtree pushes.

**Failure scenario:** LUCILLE's drive fails, or the LUKS header is damaged, or the machine is simply not to hand. The most recent state recoverable from GitHub is 2026-09-17 14:08 — before yesterday's audit was written, before the overnight boot-gate diagnosis, and before today's bootloader fix. All of that exists in exactly one place. Meanwhile `claude.ai/code` sessions on other devices, and the two subtree repos, keep serving day-old code with no indication anything is stale. The sync's own design goal — "so other devices see recent work" — has been silently inverted for a full day, and nothing anywhere reports an error.

> **The one command that settles it and fixes it:** `rm /mnt/Lucy/.git/index.lock && /mnt/Lucy/70-scripts/auto_sync_github.sh`
> Then confirm with `git log -1 --format=%ci` that a fresh commit landed.

*Not done in this run — removing a lock file is a write to the repository, and this was an unattended audit.*

---

### BLOCKER-2 — the boot gate cannot see the boot; every gate result to date is uninformative · **CONFIRMED**

The overnight re-run did exactly what yesterday's audit asked for:

```
ISO:     /mnt/Lucy/10-releases/swarm-os-v6.2.57.iso
Timeout: 1200s          KVM: enabled      Firmware: UEFI (OVMF)
✗ LucyServer never answered /health on :5000
✗ GamingAgent never answered /health on :8401
✗ BOOT GATE FAILED — timed out after 1200s of 1200s
```

The serial log reaches the UEFI menu, renders the 15→1 s countdown, emits a screen-clear — and then **nothing at all**, for twenty minutes.

That silence is not a hang. It is the expected result of the kernel command line that shipped in v6.2.57. The committed version of `01-archiso-linux.conf` — the one baked into the ISO — reads:

```
options archisobasedir=%INSTALL_DIR% archisosearchuuid=%ARCHISO_UUID% quiet loglevel=3 i915.enable_psr=0 i915.enable_dc=0
```

No `console=ttyS0`. Firmware writes to the serial port; the Linux kernel, once it takes over, writes only to `tty0`. `quiet loglevel=3` suppresses most of it even there. So the gate's serial scrape is structurally incapable of seeing a single line of kernel or userspace output, and its pass/fail verdict rests entirely on two HTTP probes with no diagnostic context when they fail.

The operator diagnosed this correctly at 03:49 today and patched the source profile:

```
+ ... quiet loglevel=3 i915.enable_psr=0 i915.enable_dc=0 systemd.unit=graphical.target apparmor=1 security=apparmor console=tty0 console=ttyS0,115200
```

**The trap:** that fix is in `40-iso-profile/`, not in any ISO on disk. Re-running the gate against `swarm-os-v6.2.57.iso` will reproduce the identical blind failure, because that ISO still has the old cmdline. The fix only takes effect after a rebuild — which bumps `VERSION` to 6.2.58 and produces a different artifact.

**Failure scenario:** the next person to pick this up re-runs the gate against v6.2.57 — the newest ISO, the one that failed — sees the same blank serial log and the same two timeouts, and concludes the OS is hard-broken. It may be entirely healthy; nobody can tell, because the instrument reads zero either way. Hours go into debugging a boot that was never observed.

**Ruled out this run:** the payload is intact. `/opt/swarm_os/LucyServer/lucy-server` (14,722,100 bytes) and `/opt/swarm_os/GamingAgent/gaming-agent` (18,059,600 bytes) are both staged in `airootfs` and both executable, restaged 09-17 11:23. `lucy-server.service` and `gaming-agent.service` are both in `multi-user.target.wants/`. Missing binaries and unenabled units are not the cause.

**Not confirmed — needs the rebuild to settle:** whether the services actually start in the guest. Also untested is the newly added `systemd.unit=graphical.target`, which changes the boot target for the first time; `graphical.target.wants/` contains only `swarm-ui.service`, and if that unit fails to come up the boot may stall somewhere the gate still cannot see.

> **The one command that settles it:** rebuild first, then gate the new artifact —
> `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` then read the serial log, which will finally contain kernel output.

---

### BLOCKER-3 — companion version stamping points at a path that does not exist · **CONFIRMED (root cause found today)**

Yesterday this was "stamping silently does nothing." The reason is line 126 of the build script:

```bash
COMPANION_GRADLE="$LUCY/30-source/android_companion/app/build.gradle.kts"
if [ -f "$COMPANION_GRADLE" ]; then
    sed -i "s|versionName = \".*\"|versionName = \"${NEW_VER}\"|" "$COMPANION_GRADLE"
    sed -i "s|versionCode = [0-9]\+|versionCode = $((60 + NEW_PATCH))|" "$COMPANION_GRADLE"
fi
```

The real file is at `30-source/android_companion/`**`swarm_os-companion/`**`app/build.gradle.kts`. One path segment is missing. The `if [ -f ]` guard turns the miss into a silent no-op — no warning, no non-zero exit, and the build prints `✓ All application badges and ISO profiles stamped` regardless.

Consequence on disk: `versionCode = 72`, `versionName = "6.2.12"` — untouched through 45 releases.

**Failure scenario:** a user side-loads the companion from the ISO, opens About, and reads **6.2.12** while the desktop shell beside it reads **6.2.57**. Any bug report filed from the phone names a version that has not existed since 2026-09-04, and pairing logic or telemetry that compares the two version strings sees a 45-release mismatch that is pure fiction.

Compounding it: the APK staged into the ISO is 28,703,773 bytes and byte-identical in size to `30-source/frontend/assets/companion/SWARM_OS_Companion.apk` dated **2026-09-04 23:55**. Meanwhile freshly built debug APKs sit unused at `30-source/android_companion/swarm_os-companion/app/build/outputs/apk/debug/app-debug.apk` (36,517,997 bytes, **2026-09-16**). The ISO is shipping a two-week-old binary while a current build sits two directories away. (APK internal timestamps are zeroed to 1981-01-01 by Gradle's reproducible-build setting, so the mtime and byte-size match are the evidence — *not confirmed* byte-for-byte.)

> **The one command that settles the APK question:** `cmp 40-iso-profile/swarm_os_iso_profile/airootfs/opt/swarm_os/swarm_flutter/data/flutter_assets/assets/companion/SWARM_OS_Companion.apk 30-source/frontend/assets/companion/SWARM_OS_Companion.apk`

**Fix:** correct the path on line 126, and replace the `if [ -f ]` guard with a hard failure — a stamp target that has gone missing is a build error, not a thing to skip quietly.

---

### MAJOR-4 — the UEFI boot menu has said "SWARM OS v6.2.19" for 38 releases · **CONFIRMED (observed a third time)**

`title SWARM OS v6.2.19` is still line 1 of `01-archiso-linux.conf`, and it rendered as such in the overnight serial capture — visible proof it reaches the screen. The build script's stamping block (lines 114–128) touches `pubspec.yaml`, `top_bar.dart`, `Cargo.toml`, `profiledef.sh` and the companion gradle. There is **no `sed` for any file under `efiboot/loader/entries/`**. The operator edited this file by hand today for the serial console and left the title untouched, which is the whole problem: nothing automated will ever correct it.

**Failure scenario:** the first thing anyone sees when booting SWARM OS from a stick — before any UI, on a machine with no other version indicator — is a five-week-old version number. Someone verifying they flashed the right build reads v6.2.19 on a v6.2.58 ISO and reflashes, or files a bug against the wrong release. This is the most-seen version label in the product and the only one nothing maintains.

> **Fix (one line, in the stamping block):** `sed -i "s|^title .*|title    SWARM OS v${NEW_VER}|" "$PROFILE_DIR/efiboot/loader/entries/01-archiso-linux.conf"`

---

### MAJOR-5 — no checksums and no manifests for any release · **CONFIRMED**

Three ISOs totalling 10.3 GB, zero integrity files. `generate_manifest_v1.0.0_2026-09-07.sh` exists, reads `VERSION` correctly, and is called by nothing.

v6.2.49 and v6.2.50 are **byte-for-byte the same size** and carry the **same commit hash `cc49de3a`**. Nothing on disk distinguishes them.

**Failure scenario:** a 3.5 GB ISO is copied to a USB stick and one sector is bad. It boots far enough to enter the installer, then fails mid-install with a squashfs error on a machine that now has a wiped partition table. A `.sha256` beside the file turns that into a five-second check before flashing. There is also no way to answer "which commit is this ISO?" for v6.2.57 — it has no companion metadata at all, and the two v6.2.x ISOs that do carry a hash carry the *same* one.

> **The one command that would have settled the 49-vs-50 question:** `cmp swarm-os-v6.2.49-*.iso swarm-os-v6.2.50-*.iso` (yesterday's run showed they diverge from byte 441 — an ISO-header timestamp, not content).

---

### MAJOR-6 — `VERSION` is a build counter, not a release pointer · **CONFIRMED**

`VERSION` increments on every invocation of the build script, whether or not the result is shippable. It reached 6.2.57 on a build that failed its gate; 6.2.51 through 6.2.56 produced no surviving artifact at all. The number that looks like a release version is really "how many times has the script been run."

**Failure scenario:** `swarm-os-latest.iso` points at v6.2.50 while `VERSION`, `swarm-release`, `profiledef.sh` and the Flutter title bar all say 6.2.57. A user runs the shell, reads 6.2.57 in the top bar, and reports a bug against a build that was never installed anywhere. The version in the UI describes the source tree, not the running system.

---

### MINOR-7 — one `*.bak-$(date +%s)` file remains on LUCILLE, two more in the Drive mirror · **CONFIRMED (steady at 1 locally)**

Local: `40-iso-profile/swarm_os_iso_profile/profiledef.sh.bak-$(date +%s)` — a literal filename from an unexpanded command substitution inside single quotes.
Drive mirror: `install_swarm_os.sh.bak-$(date +%s)` and `build_swarm_iso.sh.bak-$(date +%s)`.

Down from three locally on 09-16, unchanged at one since 09-17. Harmless until a script does `rm *.bak-*` unquoted, at which point the shell expands `$(date +%s)` and the glob misses.

### MINOR-8 — the Android companion tree has multiplied from two to three, and one name breaks shell scripts · **CONFIRMED (worse than yesterday)**

```
30-source/android_companion/swarm_os-companion/
30-source/android_companion(seperate-related-project)/swarm_os-companion/
```

The parenthesised directory is new since yesterday's two-tree finding. Its name contains `(` and `)`, which are shell metacharacters: any unquoted path expansion touching it is a syntax error, and it holds four loose APKs (v6.1.0, v6.2.0, v6.2.20, and an undated `SWARM_OS_Companion.apk`) plus its own `app-debug.apk` from 09-15. The misspelling "seperate" makes it harder to grep for. Precedence is de-facto settled — `auto_sync_github.sh` subtree-pushes `30-source/android_companion/swarm_os-companion` — but nothing states it in writing, and the build script's broken path (BLOCKER-3) points at neither.

### MINOR-9 — stale version strings in docs · **CONFIRMED**

`README.md` carries `SWARM OS v6.2.19` in its header plus three references to a build script and ISO naming scheme that no longer exist. `CLAUDE.md:72` names the build script by its 6.2.19 filename.

### MINOR-10 — 12 `.pdb` debug-symbol files tracked in git · **CONFIRMED**

.NET debug symbols for LucyServer, GamingAgent and GoogleWorkspaceService, tracked under `bin/Release/` and `obj/Release/` paths that `.gitignore` is clearly meant to exclude. No `.o`, `.class`, `.jar`, `.so` or `.qcow2` files are tracked — the local mirror-hygiene problem is now `.pdb`-only.

### MINOR-11 — the Drive mirror is 12 days stale and still holds VM images · **CONFIRMED**

Newest `modifiedTime` in the mirror root: **2026-09-06T17:01:56Z**. Its `VERSION` file dates to 2026-09-03. It still contains `swarm_vm_disk.qcow2`, `OVMF_VARS.fd` and `swarm_ovmf_vars.fd` — build/run artifacts in a source mirror — alongside the two `.bak-$(date +%s)` files. It also carries a flat layout (`swarm_os_iso_profile/`, `frontend/`, `LucyServer/`) that the local tree abandoned for the numbered-prefix scheme. **As a fallback source it is no longer trustworthy**; anyone who reads it during a LUKS outage gets a pre-reorganisation snapshot, 45 releases behind.

### MINOR-12 — two build scripts one character apart · **CONFIRMED**

`build_swarm_iso_6.2.19_2026-09-08.sh` (live, 30 KB) and `build_swarm_iso_v6.2.19_2026-09-07.sh` (superseded, 8 KB). The live script's own line 380 refers readers to the dead one for a fix it already contains.

### Clean — verified today, no action needed

- **`CLAUDE.md` AWS boilerplate — resolved.** Grep for `aws`/`bedrock`/`s3 bucket` returns nothing. It now opens with correct SWARM OS project identity and the `/mnt/Lucy` vs `/mnt/lucy` warning. **Closing this open item.**
- **Compiled `.o` / `.class` / `.qcow2` artifacts in git — clean locally.** Only `.pdb` remains (MINOR-10). The `.qcow2` and `.fd` files exist solely in the stale Drive mirror.
- **ISO service payload — clean.** Both backend binaries staged, executable, current as of the 09-17 build; both units enabled in `multi-user.target.wants/`.
- **Version stamping across Flutter / Slint / profiledef / swarm-release — consistent at 6.2.57.** Four independent surfaces agree.
- **Git repository integrity — clean.** `HEAD == origin/main`, no divergence, no hooks, identity configured, three remotes intact. The stall is the lock file alone, not repo damage.
- **Disk headroom — clean.** 186 GB free of 250 GB (22 % used).

---

## 3. Upgrades — ranked by value

### U1. Make the sync fail loudly instead of silently — and self-clear a stale lock

**Why it matters:** BLOCKER-1 cost 24 hours of off-machine durability, and the only reason it surfaced is that this audit compared a commit timestamp to the clock. A timer that dies quietly is worse than no timer, because everyone believes it is working. This is the single highest-value change in the list: it converts an invisible failure into a visible one.

**First step:** at the top of `auto_sync_github.sh`, before `git add`, add a staleness check — if `.git/index.lock` exists and no `git` process holds it (`fuser`/`lsof`, or an mtime older than ~5 minutes), remove it and log the removal. Then wrap the body in a trap: `trap 'echo "auto-sync FAILED at line $LINENO" >> /mnt/Lucy/logs/auto_sync.log' ERR`. There is currently **no** `auto_sync.log` — the script writes no record of its own runs at all, which is why 130-odd consecutive failures left no trace.

### U2. Rebuild, then gate — and never gate an ISO whose cmdline lacks a serial console

**Why it matters:** BLOCKER-2 means the project's one automated quality gate has produced no information since it was written. Fixing the cmdline turns every future gate run from a binary timeout into an actual boot trace, which is what makes the other blockers debuggable.

**First step:** run `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` to produce v6.2.58 carrying today's loader fix, then gate that artifact. Add a preflight to `vm_boot_gate.sh` that greps the ISO's loader entry for `console=ttyS0` and refuses to run — with a clear message — if it is absent, so a blind gate can never again be mistaken for a failed boot.

### U3. One stamper, driven by a manifest — with the boot menu and the companion in it

**Why it matters:** MAJOR-4 and BLOCKER-3 are the same bug twice: version stamping is a hand-maintained list of `sed` lines, and a target that is missing or misspelled fails silently. Two surfaces are already wrong; the next one added will be too.

**First step:** replace lines 114–128 with a loop over a declared table of `(file, pattern, replacement)` tuples that **exits non-zero if any target file is absent or any `sed` matches zero lines**. Seed it with the five current targets plus `efiboot/loader/entries/01-archiso-linux.conf` (title) and the corrected companion gradle path. A stamp that matches nothing must fail the build.

### U4. Turn `10-releases/` into a real release directory

**Why it matters:** MAJOR-5 and MAJOR-6 together mean there is no answer on disk to "what is this ISO, what commit built it, and did it pass." Three ISOs, two of them indistinguishable, none verifiable.

**First step:** call the existing `generate_manifest_v1.0.0_2026-09-07.sh` from the build script's success path, and emit `swarm-os-v<ver>.iso.sha256` beside each artifact. Then split the version concepts: keep `VERSION` as the build counter, add `RELEASE` containing the last gate-passing version, and point `swarm-os-latest.iso` at `RELEASE` rather than at whatever ran last.

### U5. Consolidate the companion trees and fix the shell-hostile directory name

**Why it matters:** MINOR-8 went from two trees to three in one day. The parenthesised name is an active hazard, and with BLOCKER-3's path bug pointing at neither tree, nobody can say from the code which one is authoritative.

**First step:** rename `android_companion(seperate-related-project)` to `android_companion_archive` (no parens, correct spelling), move it under `99-archive/`, and write the precedence rule into `CLAUDE.md` in one sentence: the subtree-pushed `30-source/android_companion/swarm_os-companion/` is the product; everything else is history.

---

## 4. Tooling — packages worth adding to SWARM OS

Current `packages.x86_64`: **126 packages**. The GPU stack is in good shape — `vulkan-icd-loader`, `vulkan-radeon`, `vulkan-intel`, `intel-media-driver`, `libva-mesa-driver`, `mesa`, full `pipewire`. Containers are covered (`podman`, `podman-docker`, `crun`, `fuse-overlayfs`, `slirp4netns`, `netavark`). Hardening is real (`apparmor`, `firejail`, `ufw`, `nftables`).

### 4.1 Coding — the OS cannot currently rebuild itself

This is the sharpest gap against the stated "an OS that can code itself" goal. The ISO ships `aspnet-runtime-10.0` — **runtime only, no SDK** — and no Dart, no Flutter, no Rust toolchain. SWARM OS can *run* LucyServer, GamingAgent and the Flutter shell; it cannot *build* any of them.

| Package | What it enables / replaces |
|---|---|
| `dotnet-sdk` | Builds LucyServer, GamingAgent, GoogleWorkspaceService on-device. Today only `aspnet-runtime-10.0` is present — the OS runs its own backends but cannot recompile one after an edit. This is the single package that most directly serves "code itself." |
| `base-devel` | `gcc`, `make`, `autoconf`, `pkgconf`, `fakeroot`. `clang`, `cmake`, `ninja` are present but `base-devel` is not, so most `./configure && make` projects, any AUR build, and `cargo` crates with C dependencies fail on a fresh boot. |
| `android-tools` | `adb` and `fastboot`. The project builds an Android companion APK and ships `install_companion_apk_v1.0.0_2026-09-16.sh`, yet **the ISO has no `adb`** — the install script cannot run on the OS it ships with. For a distro aimed at Android development this is the most conspicuous omission in the list. |
| `gdb` + `lldb` | No debugger of any kind is installed. `clang` is present, so `lldb` is the natural pair; `gdb` covers .NET native crashes and core-dump inspection. Currently a segfault on SWARM OS can only be investigated by adding print statements and rebuilding — on a machine that cannot rebuild (see `dotnet-sdk`). |
| `rustup` (or `rust`) | `swarm-slint` and `i30ltz-recovery` are Rust. Both are cross-compiled on LUCILLE and copied in as binaries; the OS cannot touch its own Lucille panel source. |
| `jdk17-openjdk` + `gradle` | Companion APK builds. Pairs with `android-tools` to make the Coder Droid story end-to-end on-device rather than host-dependent. |
| `ripgrep` + `fd` | Fast code search across the 20 GB `30-source/` tree. `grep -r` over the vendored Flutter SDK is slow enough to discourage searching at all — `rg` respects `.gitignore` by default and skips it. |
| `github-cli` | The three GitHub remotes are HTTPS; `gh auth` gives credential handling and lets the OS file its own issues and PRs — directly on the "code itself" path. |
| `python` (explicit) | Currently pulled in only *transitively*, as a dependency of `reflector`. If `reflector` is ever dropped, Python vanishes from the image and any script depending on it breaks. Declare it. |

### 4.2 Gaming — `gaming-agent.service` is enabled and has nothing to drive

`gaming-agent` is built, staged at `/opt/swarm_os/GamingAgent/gaming-agent`, enabled in `multi-user.target.wants/`, and health-checked on port 8401 by the boot gate. The Vulkan drivers are in place. **But the package list contains no game, no launcher, no compatibility layer, and no gaming utility whatsoever** — not `steam`, `lutris`, `wine`, `gamemode`, `mangohud` or `gamescope`.

| Package | What it enables / replaces |
|---|---|
| `steam` | The obvious anchor. Requires `multilib` enabled in `pacman.conf` — check that first; it is the one prerequisite that will bite. |
| `gamescope` | Valve's micro-compositor. Runs games in an isolated Wayland session with independent resolution and scaling — which matters here because the shell is a `labwc` kiosk, and `gamescope` is how a fullscreen game coexists with a compositor that owns the seat. |
| `gamemode` | On-demand CPU governor and I/O priority switching for the duration of a game. Pairs naturally with `gaming-agent` — it is exactly the kind of system-level toggle an agent should be driving. |
| `mangohud` | In-game FPS, frametime, CPU/GPU telemetry overlay. Gives `gaming-agent` something real to *read* — a performance feed rather than a health endpoint that only proves it is alive. |
| `wine` + `wine-gecko` + `wine-mono` | Non-Steam Windows titles and tools. |
| `lutris` | Launcher and install-script manager for GOG, Epic, emulators and standalone titles; covers everything Steam does not. |
| `goverlay` | GUI front-end for configuring MangoHud and vkBasalt without hand-editing config files. |

### 4.3 Daily life & operations

| Package | What it enables / replaces |
|---|---|
| `zoxide` + `fzf` | Frecency-ranked `cd` and fuzzy history/file selection. In a kiosk shell where `alacritty`/`foot` is the main entry point, these change navigation more than any other two packages. |
| `eza` + `bat` | `ls`/`cat` with git status, tree view and syntax highlighting. Cheap, immediately visible quality-of-life. |
| `zellij` | Persistent terminal sessions that survive a `swarm-ui.service` restart — the shell restarts on `StartLimitBurst=3`, and today that takes every open terminal with it. `tmux` is already installed; `zellij` is the friendlier default for a non-expert user, and they coexist. |
| `imv` + `zathura` + `zathura-pdf-mupdf` | Image and PDF viewing. The ISO has `thunar` for files and `mpv` for video, but **no way to open a PDF or a photo** — a user can browse to a document and not open it. |
| `file-roller` or `xarchiver` | Archive extraction from the file manager. `unzip` is present for the command line; `thunar` has no GUI handler. |
| `gvfs` + `gvfs-mtp` | Mounts phones and USB media in `thunar`. Directly relevant given the Android companion — plug the phone in and it appears. |
| `pavucontrol` | Per-application volume. `pipewire` and `wireplumber` are installed with no GUI mixer at all. |
| `timeshift` or `snapper` | `btrfs-progs` is installed and `swarm-snapshot.service` exists; neither snapshot tool is. Adding one makes the existing snapshot unit a recoverable rollback rather than a bare filesystem operation. |
| `nvtop` | GPU process and memory monitor. `btop` covers CPU; on a machine positioned for gaming and local AI work, GPU visibility is the missing half. |
| `syncthing` | The Drive mirror is 12 days stale (MINOR-11) and `sync_lucille_ai.sh` has never succeeded. `setup_syncthing.sh` already exists in the Drive mirror, unused — this is a path the project started and abandoned, and it would solve the off-machine-copy problem that BLOCKER-1 just exposed. |

---

## 5. Scope ledger

**Read in full (contents parsed):**
`VERSION`; `CLAUDE.md` (head + full grep for AWS/bedrock/s3); `40-iso-profile/swarm_os_iso_profile/efiboot/loader/entries/01-archiso-linux.conf` and its committed-vs-working `git diff`; `airootfs/etc/swarm-release`; `profiledef.sh` (version lines); `packages.x86_64` (all 126 entries); `70-scripts/auto_sync_github.sh` (complete); `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` lines 100–135 plus a full grep of its stamping and version logic; `logs/boot-gate-20260917-231246.log` (tail); `logs/boot-gate-20260917-231246-qemu.log` (complete, 1 line); `logs/boot-gate-rerun.log` (tail); `logs/sync_lucille_ai.log` (tail); `30-source/android_companion/swarm_os-companion/app/build.gradle.kts` (version lines); `gaming-agent.service`, `lucy-server.service`, `swarm-ui.service` (ExecStart/unit config); prior audit `90-docs/SWARM_OS_DAILY_AUDIT_2026-09-17_v1.0.0.md` (header, inventory, first finding, all section headings).

**Seen by metadata only (size, mtime, permissions, path — contents not read):**
All four ISO artifacts in `10-releases/` (~10.3 GB; **not** hashed, **not** mounted, **not** diffed this run); the staged `SWARM_OS_Companion.apk` (central-directory listing only — internal timestamps are zeroed by Gradle, so the 09-04 attribution rests on byte-size and mtime correlation, **not confirmed**); the ten source-tree APKs; `lucy-server` and `gaming-agent` binaries (existence, size, exec bit); the 12 tracked `.pdb` files (path and extension via `git ls-files`); every file in the 24-hour change list; the full `logs/` directory listing; `.git/index.lock` (existence, size, mtime — **the 0-byte size and 14:09 mtime are the direct evidence for BLOCKER-1; no process table was inspected to prove no git process holds it**).

**Read remotely, metadata only:** the Google Drive mirror root (44 entries — titles, sizes, `modifiedTime`). No Drive file contents were downloaded. Subfolders were not walked; the 12-day staleness figure is the newest `modifiedTime` in the root listing.

**Not reachable / not attempted:**
`systemctl --user` status for the sync timer — the device shell has no session D-Bus (`$DBUS_SESSION_BUS_ADDRESS` unset), so **the timer's schedule, last-run time and failure count could not be read**; the 24-hour stall is inferred from commit timestamps and the live memory-mirror mtime, not from systemd. `crontab -l` — permission denied. No `~/.config/systemd/user/` visible from this mount. `/run/media/i30ltz/LUCILLE/Luccile-v+` (staged copy) — not present; not needed, since the authoritative tree was available. Remote GitHub state — no fetch was performed; `HEAD == origin/main` is read from the local ref, which was last updated 2026-09-17 14:08, so **whether the three remotes actually hold that commit is not confirmed**.

**Explicitly not done:**
Nothing was compiled. No ISO was built. No VM was booted. The boot gate was not run. No file was created, modified, moved or deleted anywhere on LUCILLE during this audit, including the stale `.git/index.lock` — it was left in place, since removing it is a write to the repository and this run was unattended. No git command that mutates state (`add`, `commit`, `push`, `fetch`) was executed; every git invocation was read-only.

---

*SWARM OS Daily Evaluation Audit · document v1.0.0 · generated 2026-09-18 · machine LUCILLE · tree v6.2.57*
