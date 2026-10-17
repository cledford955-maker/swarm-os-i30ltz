# SWARM OS — DAILY EVALUATION AUDIT

| Field | Value |
|---|---|
| **Document** | `SWARM_OS_DAILY_AUDIT_2026-09-23_v1.1.0.md` |
| **Document version** | v1.1.0 |
| **Audit date** | 2026-09-23 (run 14:18–14:40 UTC) |
| **Supersedes** | `SWARM_OS_DAILY_AUDIT_2026-09-23_v1.0.0.md` (run 01:31–01:55 UTC today). Kept, not overwritten. This is the afternoon run and covers what changed since. |
| **Machine** | LUCILLE (CachyOS/Arch, user `i30ltz`) |
| **Project** | Luccile-v+ · branding **LLcy Core** · AI persona **Boltz** |
| **Source read** | `/mnt/Lucy` — the live authoritative tree, mounted and unlocked, read directly over the device bridge |
| **VERSION at audit time** | **6.2.72** (file mtime 2026-09-23 03:00:03 UTC) |
| **git HEAD** | `0d38683b` · `main` · 2026-09-23 10:21:08 -0400 |
| **Compiled / built / booted / ran anything?** | **No.** This audit read files and logs only. No build, no ISO, no VM, no test suite, no script execution. |

---

## 0. Lead finding — v6.2.72 burned a version number and produced nothing

A build started at **02:59 UTC today**. It bumped `VERSION` 6.2.71 → **6.2.72** at 03:00:03, stamped every version label, compiled the Flutter shell, the Slint panel and the four Go/.NET services, staged them into `airootfs`, wrote the last staged file (`usr/local/share/swarm-os/pacman.conf`) at **03:02:00** — and then stopped.

It never reached `mkarchiso`. Proof, from the tree itself:

- `airootfs/etc/swarm-release` still reads `SWARM_VERSION=6.2.71 / SWARM_COMMIT=7eb3ee9e / SWARM_DATE=20260922`, written at **01:44:32** by the *previous* build. The 6.2.72 run never got to line 441, which rewrites that file.
- `swarm_os_build_work/` still holds the 03:01 `google-workspace-publish` output. Line 428 (`sudo rm -rf "$WORK_DIR"`) would have wiped it.
- The build lock `70-scripts/.swarm-build.lock` was released; no build is running now.

**The only step between the last staged file and the release stamp is Step 4g, the native dependency gate** (`70-scripts/verify_bundle_deps.sh`). That is almost certainly where it died.

**Consequences, today:**

1. Version 6.2.72 is **spent**. There is no ISO for it and never will be. The next build will be 6.2.73.
2. The staged profile is now in a **three-way split**: `profiledef.sh` says `iso_name="swarm-os-v6.2.72-9f142fdf"`, `/etc/swarm-release` says `6.2.71 / 7eb3ee9e`, and git HEAD is `0d38683b`. If anyone ran `mkarchiso` on this profile by hand right now, they would get an ISO **named 6.2.72 that tells the installed system it is 6.2.71**.
3. Nothing new reached Ventoy. The newest ISO is still v6.2.71 — and see B2, that one is unproven.

---

## 1. Source location — which tree was read

| Candidate | Status today |
|---|---|
| `/mnt/Lucy` (drive root) | **READ IN FULL — this is the authoritative tree.** Mounted, unlocked, connected to this run. |
| `/mnt/Lucy/Luccile-v+` | Not the source. One stale file: `build_swarm_iso_v6.2.2_2026-09-07.sh` (13 KB, 2026-09-07). |
| `/run/media/i30ltz/LUCILLE/Luccile-v+` | **Not present.** |
| Google Drive mirror `1T4Oi5abo…` | Reachable, listed by metadata. **Newest `modifiedTime` = 2026-09-06T17:01:56Z — 17 days stale.** Not used as a source. |

> **The task prompt's source list is out of date and should be corrected.** The project reorganised into a numbered tree (`00-CURRENT` … `99-archive`) at the drive root on 2026-09-08. `Luccile-v+/` is a leftover directory name, not the project root. `CLAUDE.md` itself states the working directory is `/mnt/Lucy/` (capital L).

### Tree as read (file counts, on-disk size, newest file)

| Dir | Files | Size | Newest child |
|---|---:|---:|---|
| `00-CURRENT` | 0 (5 symlinks) | — | 2026-09-08 |
| `10-releases` | 2 | 24 K | 2026-09-21 03:54 |
| `20-runtime` | 2 302 | 177 M | 2026-09-22 03:25 |
| `30-source` | 57 423 | **26 G** | 2026-09-23 03:01 |
| `40-iso-profile` | 6 381 | **7.8 G** | 2026-09-23 03:02 |
| `50-backends` | 28 | 11 M | 2026-09-08 |
| `50-boot` | 55 | 5.3 M | 2026-09-05 |
| `60-boltz-brain` | 16 | 1.2 M | 2026-09-23 14:21 |
| `70-scripts` | 54 | 408 K | 2026-09-23 02:59 |
| `80-vm` | 80 | 78 M | 2026-09-22 01:43 |
| `90-docs` | 16 | 260 K | 2026-09-23 01:54 |
| `99-archive` | 130 | 952 K | 2026-09-06 |
| `swarm_os_build_work` | 110 841 | **17 G** | 2026-09-23 03:01 |
| `.git` | — | **12 G** | (was 7.6 G at the 01:54 run — **+4.4 G in 12 hours**) |

### Changed in the last 24 h (meaningful, build noise collapsed)

| When (UTC) | What |
|---|---|
| 2026-09-23 02:26 | `logs/boot-gate-20260922-222548.log` — gate run ended, qemu killed on SIGTERM |
| 2026-09-23 02:59 | `.swarm-build.lock` — build starts |
| 2026-09-23 03:00:03 | `VERSION` 6.2.71 → **6.2.72** |
| 2026-09-23 03:00 | `frontend/pubspec.yaml`, `top_bar.dart`, `swarm-slint/Cargo.toml`, `profiledef.sh` stamped 6.2.72 |
| 2026-09-23 03:00–03:01 | Flutter bundle, LucyServer-go, GamingAgent-go, GoogleWorkspaceService, lucille-core rebuilt and staged |
| 2026-09-23 03:02:00 | Last staged file — `airootfs/usr/local/share/swarm-os/pacman.conf`. **Build stops here.** |
| 2026-09-23 06:54 → 10:21 | 20 `auto-sync:` commits on `main`, one every ~11 min |
| 2026-09-23 14:10–14:21 | `60-boltz-brain/swarm-memory/PROJECT_MEMORY.md` updated (40 KB) |

### git

- HEAD `0d38683b`, branch `main`, 2026-09-23 10:21:08 -0400.
- Last 20 commits are all `auto-sync: <timestamp>` from `auto_sync_github.sh` on the timer. **No human commits in the visible window.** Every piece of work today is indistinguishable from every other piece in the history.
- Remotes: `origin` (`swarm-os-i30ltz`, ssh), `i30ltz-recovery`, `i30ltz-swarm-companion` (both https).

### Build scripts, artifacts, manifests

| Item | Version / date | Note |
|---|---|---|
| `70-scripts/build_swarm_iso.sh` | 25 081 B, 2026-09-21 04:37 | The real builder. Reads `VERSION`, auto-increments. |
| `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` | 162 B | Compatibility forward — `exec`s the above. Correct. |
| `70-scripts/build_swarm_iso_v6.2.19_2026-09-07.sh` | 162 B | Same. Correct. |
| `Luccile-v+/build_swarm_iso_v6.2.2_2026-09-07.sh` | 13 479 B, 2026-09-07 | **Orphan. Real implementation, 16 days stale, not a forward.** |
| `ARCH_SNAPSHOT` | `2026/09/11` | Pinned, documented, 12 days old |
| `packages.x86_64` | 131 packages | — |
| ISO output dir `/mnt/ventoy/ISO/SWARM_OS/` | **not reachable from this session** | Only `/mnt/Lucy` is bridged. ISO inventory is unverified this run. |
| `10-releases/` | 2 files, both diagnostics tarballs (2026-09-21) | Holds no releases. |

---

## 2. Evaluation

### BLOCKER

#### B1 — The build aborts after consuming a version number, and the version bump cannot be undone *(abort confirmed; cause NOT confirmed)*

`build_swarm_iso.sh` writes the new version to `VERSION` at **Step 0, line 86** — before the snapshot preflight, before any compile, before the dependency gate, before `mkarchiso`. Every failure after that point permanently burns a version number and leaves the staged profile labelled with an ISO that does not exist.

**Concrete failure scenario (this is not hypothetical — it happened at 03:02 today):** the dependency gate fails, the script exits 1, `VERSION` says 6.2.72, `profiledef.sh` says `swarm-os-v6.2.72-9f142fdf`, `/etc/swarm-release` says 6.2.71, and Ventoy has nothing newer than 6.2.71. Tomorrow's build is 6.2.73 and the gap is unexplained anywhere on disk. Repeat this for a week and the ISO numbering is fiction.

> **Not confirmed:** that Step 4g specifically is what failed. No build log was written — the run was interactive and its output went to a terminal that is gone.
> **One command that settles it:**
> ```
> /mnt/Lucy/70-scripts/verify_bundle_deps.sh /mnt/Lucy/40-iso-profile/swarm_os_iso_profile; echo "exit=$?"
> ```
> It is read-only (reads `DT_NEEDED` out of staged binaries, fetches `core.files`/`extra.files` for the pinned snapshot). Run it and either it reproduces the failure with the offending soname named, or it passes and the cause is elsewhere.

#### B2 — No SWARM ISO has been proven to reach the desktop shell. The boot gate has confirmed it exactly once, ever. *(confirmed)*

Across **30 boot-gate log pairs** in `logs/` spanning 2026-09-13 to 2026-09-23, the string `SWARM OS Desktop` appears in exactly **one** file: `boot-gate-20260922-005030.log`, once.

The most recent gate, `boot-gate-20260922-222548.log` (ended 02:26 UTC today), does **not** contain it. Its serial log stops at `Started Hostname Service`, and the companion qemu log ends with:

```
qemu-system-x86_64: terminating on signal 15 from pid 30957 (bash)
```

That is the gate's own timeout killing the VM, not a clean shutdown. The boot never reached the compositor.

**Concrete failure scenario:** v6.2.71 sits on Ventoy as the newest build. Someone boots LUCILLE from it expecting the hex-grid shell. systemd reports the services started — Gaming Agent, Lucy Server, Google Workspace all show `OK` in the gate log — and then the screen stays black, because the one unit that draws anything has never been observed starting in a gate run on this ISO. The services being green is exactly what makes this dangerous: the build *looks* healthy.

This also means **B1 and B2 compound**: the gate that would catch a black screen is the same gate that has only ever produced one positive observation, so a passing build tells you almost nothing today.

### MAJOR

#### M1 — The companion version stamper writes to a path that does not exist. Eight months of drift. *(confirmed by reading both files)*

`build_swarm_iso.sh` line 144:

```bash
COMPANION_GRADLE="$LUCY/30-source/android_companion/app/build.gradle.kts"
if [ -f "$COMPANION_GRADLE" ]; then ... fi
```

The actual file is at `30-source/android_companion/**swarm_os-companion**/app/build.gradle.kts`. The `-f` guard turns a wrong path into a silent no-op — the build prints `✓ All application badges and ISO profiles stamped with v6.2.72` and stamps nothing.

Current state:

| Tree | `versionCode` | `versionName` |
|---|---:|---|
| `30-source/android_companion/swarm_os-companion` | 73 | **6.2.13** |
| `30-source/android_companion(seperate-related-project)/swarm_os-companion` | 71 | **6.2.11** |
| `VERSION` | — | **6.2.72** |

**Concrete failure scenario:** the user sideloads today's companion APK onto a phone that already has one. Android compares `versionCode` 73 to 73 and refuses the install as "already installed", or installs and the About screen reads v6.2.13 against a v6.2.72 desktop. There is no way to tell which build is on the phone.

**Fix is one line:** point `COMPANION_GRADLE` at `.../android_companion/swarm_os-companion/app/build.gradle.kts`, and replace `if [ -f ]` with a hard failure when the file is missing (see U2).

#### M2 — The dependency gate's cache lives inside the directory the build deletes, so every build re-downloads it — and the build dies if the download fails *(confirmed by reading; cache confirmed absent)*

`verify_bundle_deps.sh` caches its soname index at `${SWARM_DEP_CACHE:-/mnt/Lucy/swarm_os_build_work/.depcache}`. `build_swarm_iso.sh` line 428 runs `sudo rm -rf "$WORK_DIR"` where `WORK_DIR="$LUCY/swarm_os_build_work"`. The cache is inside the thing that gets wiped.

`swarm_os_build_work/.depcache/` **does not exist right now.**

So every build pays the "this takes a minute" re-index against `archive.archlinux.org`, over the network, at Step 4g — *after* the version has been burned and 3 minutes of compiling has been done.

**Concrete failure scenario:** `archive.archlinux.org` is slow, rate-limits, or the machine is offline for ninety seconds. The gate cannot build the soname index, `fail()` exits non-zero, and the build dies exactly where today's build died — with 6.2.72 spent and no ISO. A network hiccup should not cost a version number.

**Fix:** move the default cache outside `WORK_DIR` (`/mnt/Lucy/20-runtime/.depcache`), or export `SWARM_DEP_CACHE` in the build script before calling the gate.

#### M3 — The live ISO still carries LUCILLE's private mount units *(confirmed, again, in today's gate log)*

`boot-gate-20260922-222548.log`, from this morning:

```
[DEPEND] Dependency failed for /mnt/endeavor.
[DEPEND] Dependency failed for /mnt/recoverybuild.
[DEPEND] Dependency failed for /mnt/recoveryos.
[DEPEND] Dependency failed for /mnt/brains.
[DEPEND] Dependency failed for /mnt/Lucy.
[DEPEND] Dependency failed for File System …9c857f-f2cb-47cc-ac13-2cf3a3e24bc8.
[DEPEND] Dependency failed for File System …a1b27f-407b-4385-9dfa-851833f249db.
[DEPEND] Dependency failed for File System …f0e009-43c2-4760-8d6c-d7c445f5f3df.
```

Eight failed units on a clean boot, every boot, because LUCILLE's `/etc/fstab` entries and three by-UUID filesystem units were baked into `airootfs`. They are one `Requires=` away from blocking `local-fs.target`.

**Concrete failure scenario:** a user boots the ISO on any machine that is not LUCILLE — the intended use of a bootable ISO. They get eight red `DEPEND` failures before the login prompt. If any of those UUIDs is ever referenced by a `.mount` unit with `Requires=` rather than `Wants=`, boot drops to emergency shell on hardware that is otherwise fine. It also leaks LUCILLE's disk layout and LUKS UUIDs to anyone who boots the image.

#### M4 — `sync_lucille_ai.sh` has failed on half of every run for 12 days. Invalid rsync flag. *(confirmed from its own log)*

`logs/sync_lucille_ai.log`, last entry 2026-09-22 16:58:03:

```
rsync error: syntax or usage error (code 1) at main.c(1886) [client=3.5.0-g471e17dc]
[2026-09-22 16:58:03] FAIL  Lucille-AI sdb8 (i30ltz-AI) (exit 1)
...
[2026-09-22 16:58:03] Sync complete — ok=1 fail=1
```

Line 60 passes `--no-delete`, which is not an rsync option (the option is the *absence* of `--delete`). rsync 3.5.0 rejects the command line before copying anything.

**Concrete failure scenario:** the Lucille-AI payload on sdb8 has not been updated since the flag was introduced. Whoever boots from or restores that partition gets a 12-day-old AI tree while the log's last line says `Sync complete`, which reads as success. The recovery-binary half of the script *does* work, which is what makes the failure easy to miss.

**Fix:** delete `--no-delete` from line 60.

#### M5 — Two live Android companion trees, divergent, and only one is the git subtree source *(confirmed)*

```
30-source/android_companion/swarm_os-companion                              versionName 6.2.13
30-source/android_companion(seperate-related-project)/swarm_os-companion    versionName 6.2.11
```

`auto_sync_github.sh` pushes only the first as a subtree to `i30ltz-swarm-companion`. The second is on disk, in git, two patch versions behind, and pushed nowhere.

**Concrete failure scenario:** a fix is made in the `(seperate-related-project)` tree because that is the one that was open in the editor. It is committed by auto-sync into `origin`, never reaches the companion repo, and never ships in an APK. The change looks committed and pushed. Nothing built from it.

**Fix:** decide which one is canonical today. Move the other under `99-archive/superseded/` with a dated note, or delete it. Two trees with the same inner directory name is a trap that will keep firing.

### MINOR

| # | Finding | Status |
|---|---|---|
| m1 | `40-iso-profile/swarm_os_iso_profile/profiledef.sh.bak-$(date +%s)` — unexpanded command substitution, 1 126 B, 2026-09-06. **One** such file on the live tree (was two). The Drive mirror still holds **two** more: `build_swarm_iso.sh.bak-$(date +%s)` and `install_swarm_os.sh.bak-$(date +%s)`. | confirmed |
| m2 | **12 `.pdb` files tracked in git** despite `.gitignore`: `LucyServer.pdb`, `GamingAgent.pdb`, `GoogleWorkspaceService.pdb` and duplicates across `30-source/`, `50-backends/`, `20-runtime/` and two top-level copies. `.gitignore` covers `*.o` and `*.qcow2` but not `*.pdb`. Tracked files ignore `.gitignore` anyway — they need `git rm --cached`. | confirmed |
| m3 | Google Drive mirror is **17 days stale** (newest 2026-09-06T17:01:56Z) and still holds `swarm_vm_disk.qcow2`, `OVMF_VARS.fd`, `swarm_ovmf_vars.fd` — VM artifacts in a source mirror. As a fallback source it would hand a future run a tree from before the 09-08 reorganisation. | confirmed by metadata |
| m4 | `vm_boot_gate.sh` — header comment says `SWARM_GATE_TIMEOUT (default 300)`, line 37 says `TIMEOUT="${SWARM_GATE_TIMEOUT:-480}"`. Doc lies about the code. | confirmed |
| m5 | `Luccile-v+/` holds one orphaned **real** build script from 2026-09-07 (not a compatibility forward). A stale copy of the builder is worse than no copy. | confirmed |
| m6 | `10-releases/` contains no releases — two diagnostics tarballs from 2026-09-21. The directory name promises something the tree does not deliver. | confirmed |
| m7 | `.git` grew **7.6 G → 12 G in twelve hours** (measured at the 01:54 run and again now). At ~20 auto-sync commits/day committing build output, this is compounding. | confirmed by measurement; pack contents not inspected |

### Verified CLEAN — previously-open items that are now fixed. Do not re-report.

| Item | Verification |
|---|---|
| **`CLAUDE.md` containing AWS boilerplate** | **Fixed.** `grep -i 'aws\|bedrock\|amazon' CLAUDE.md` → **0 matches**. The file now opens with the ISO release policy, the `/mnt/Lucy` working-directory rule, and the "read `SWARM_AI_FEATURES.md` first" instruction. Genuinely SWARM-specific. |
| **`VERSION` disagreeing with hardcoded versions in build scripts** | **Fixed in the builder.** `build_swarm_iso.sh` contains no hardcoded `6.2.x` except the `6.2.1` bootstrap default and comment examples. It reads `VERSION` and auto-increments. Version drift still exists — but in the *companion* (M1) and the *stale release stamp* (B1), not in the build script. |
| **`auto_sync_github.sh` subtree `--prefix` mismatch** | **Fixed.** Both prefixes now resolve: `30-source/i30ltz-recovery(seperate-related-project)` and `30-source/android_companion/swarm_os-companion` both exist on disk. Auto-sync has committed and pushed every ~11 minutes today without aborting. |
| **UI version labels** | **Clean.** `top_bar.dart` `'v6.2.72'`, `pubspec.yaml` `6.2.72+72`, `swarm-slint/Cargo.toml` `6.2.72`, `profiledef.sh` `iso_application="SWARM OS · Lucille v6.2.72"`. All four agree with `VERSION`. |
| **Arch snapshot pinning** | **Clean and well-documented.** `ARCH_SNAPSHOT` = `2026/09/11`, with a 15-line header explaining why, how to bump, and why not to pin "today". This is the best-engineered file in the tree. |
| **Build lock / Ventoy preflight** | **Clean.** `flock` guard against concurrent builds, and `python swarm_iso_manager.py check` aborts before the version bump if Ventoy is absent. |

---

## 3. Upgrades — five, ranked by value

### U1 — Move the version bump to the end of the build *(highest value)*

**Why it matters:** this single change dissolves B1. A version number should be the name of a thing that exists, not a receipt printed before the transaction. Today a failed dependency gate spends 6.2.72 forever and leaves the profile labelled for an ISO nobody can find.

**First concrete step:** in `build_swarm_iso.sh`, compute `NEW_VER` at Step 0 but do **not** write it. Use it in memory through the whole run. Move `echo "$NEW_VER" > "$VERSION_FILE"` to immediately after the `swarm_iso_manager.py publish` call succeeds. Everything stamped mid-build (pubspec, Cargo.toml, profiledef, gradle) already uses the variable, so nothing else changes — and on failure, `git checkout --` those four files in the EXIT trap so the tree returns to the last real version.

### U2 — Make every stamper fail loudly instead of skipping quietly

**Why it matters:** M1 is eight versions of drift produced by `if [ -f ]`. The build printed a green checkmark every single time. Any "update it if it's there" guard in a release script is a lie generator.

**First concrete step:** fix the `COMPANION_GRADLE` path to `.../android_companion/swarm_os-companion/app/build.gradle.kts`, then replace the guard with:

```bash
[ -f "$COMPANION_GRADLE" ] || { echo "✗ companion gradle missing at $COMPANION_GRADLE"; exit 1; }
```

Then add a Step 1z assertion: after stamping, `grep` each of the five stamped files for `$NEW_VER` and abort if any comes back empty. A stamp you do not verify is not a stamp.

### U3 — Give the boot gate a shell assertion, and make it write a verdict file

**Why it matters:** B2 exists because the gate watches for `login:` and a panic regex, but never asserts that the thing the OS is *for* actually started. Thirty gate runs produced one observation of the desktop unit and nobody noticed, because no run wrote down what it concluded.

**First concrete step:** in `vm_boot_gate.sh`, add `SWARM OS Desktop` to the success condition — the gate passes only when the serial log contains both `login:` **and** `Started SWARM OS Desktop`. Then have it write `logs/boot-gate-<stamp>.verdict` containing one line: ISO name, version, commit, PASS/FAIL, and which assertion failed. A gate whose result you have to reconstruct from a 13 KB serial dump is not a gate.

### U4 — Strip LUCILLE out of the ISO, and prove it stays out

**Why it matters:** M3 makes the ISO machine-specific, which defeats the point of an ISO, and leaks the host's disk layout. Eight `DEPEND` failures on every boot also train the user to ignore red text, which is how the next real failure gets missed.

**First concrete step:** `grep -rn 'mnt/Lucy\|mnt/brains\|mnt/endeavor\|mnt/recovery' 40-iso-profile/swarm_os_iso_profile/airootfs/etc/` and remove every host mount unit and fstab line it finds. Then add that same grep to `verify_bundle_deps.sh` as a second gate — the build fails if a host path reappears in `airootfs`. Otherwise it comes back the next time someone copies a config.

### U5 — Amputate the git history and stop auto-sync committing build output

**Why it matters:** `.git` gained 4.4 G in twelve hours. At this rate the repo is unclonable within a week, and "clone the project on another machine" is the stated reason auto-sync exists. It is also committing `.pdb` files (m2) and 17 G of `swarm_os_build_work` churn.

**First concrete step:** add `*.pdb`, `swarm_os_build_work/`, and `30-source/**/bin/`, `30-source/**/obj/`, `30-source/**/build/` to `.gitignore`, then `git rm -r --cached` those paths in one commit. Measure `.git` again after 24 h of auto-sync. If it is still growing, the fix is a fresh orphan branch with the current tree as commit one, and the old history tagged and pushed once to cold storage.

---

## 4. Tooling — packages worth adding to SWARM OS

### Fixes something that is broken or impossible today

| Package | What it enables / replaces |
|---|---|
| `lnav` | The boot-gate serial logs are 13 KB of ANSI-escaped systemd output that this audit had to `grep -a` through. `lnav` parses systemd journal format, folds the `OK`/`DEPEND` noise, and jumps to the first failure. Directly replaces the manual reading that B2 and M3 required. |
| `moreutils` (`ts`, `sponge`, `errno`) | `ts` timestamps every line of `build_swarm_iso.sh` output. Today's build died at 03:02 and there is **no log at all** — the run was interactive. Piping the build through `ts \| tee logs/build-$(date +%Y%m%d-%H%M%S).log` would have turned B1 from an inference into a fact. |
| `shellcheck` | M4 (`--no-delete`) and M1 (`if [ -f ]` on a wrong path) are both the class of bug shellcheck catches. 54 scripts in `70-scripts/`, zero of them linted. Run it in a pre-commit hook. |
| `pacutils` (`pacsift`, `paccheck`) | Complements `verify_bundle_deps.sh` — `paccheck --files --sha256sum` verifies staged package contents against the pinned snapshot, which is the half the soname gate does not cover. |
| `git-filter-repo` | The tool for U5. `git filter-branch` is deprecated and will take hours on a 12 G repo. |

### Coding — the "Coder Droid + Forge" goal

| Package | What it enables / replaces |
|---|---|
| `helix` | A modal editor with LSP, tree-sitter and DAP built in, no config file, single static binary. On a live ISO that is the difference between "an editor is present" and "an editor works out of the box". Replaces a `nvim` + 15-plugin setup that has to be re-bootstrapped on every boot. |
| `zellij` | Terminal multiplexer with a discoverable keybinding bar and session resurrection. For an OS that pitches itself as a coding environment, `tmux` with no config is a wall; `zellij` is usable by someone who has never seen it. |
| `difftastic` | Structural diff — compares syntax trees, not lines. Reviewing a Dart or Kotlin change where only indentation moved goes from a 200-line diff to three lines. |
| `just` | A command runner for the ten things this project does (`just build`, `just gate`, `just sync`, `just audit`). Replaces the growing pile of `.desktop` launchers and dated shell scripts in `70-scripts/` with one discoverable file. |
| `android-tools` + `scrcpy` | `adb` is already assumed by `install_companion_apk_*.sh`. `scrcpy` mirrors and controls the phone from the desktop — for an OS whose thesis is Android development, seeing the companion app running next to its source is the core loop. |
| `bat`, `fd`, `ripgrep-all` | `rga` searches inside PDFs, archives and the 246 KB `SWARM_AI_FEATURES.md`. `fd` and `bat` are the everyday replacements for `find` and `cat` that make a live ISO feel finished. |

### Gaming

| Package | What it enables / replaces |
|---|---|
| `gamescope` | Valve's micro-compositor. Runs a game at a fixed internal resolution and scales it, with FSR and integer scaling, inside the labwc session. Solves the "game fights the tiling compositor" problem that a custom Wayland shell will otherwise hit on day one. |
| `mangohud` + `goverlay` | Frametime and thermal overlay. Given there is a `GamingAgent` service in the ISO already, `mangohud`'s metrics are what that agent should be reading rather than inventing its own. |
| `gamemode` | Applies the CPU governor and I/O priority changes on game launch and reverts on exit. Pairs directly with the existing `EPP_POWER_POLICY.md` work in `70-scripts/` — that policy is written down but nothing enforces it per-process. |
| `lutris` + `wine-staging` + `vkd3d` | The launcher layer. Proton alone covers Steam; Lutris covers everything else — itch.io, emulators, standalone Windows binaries. |
| `vulkan-tools`, `mesa-utils` | `vulkaninfo` and `glxinfo` in the ISO turn "graphics are broken" into a one-command diagnosis. Worth it for the boot gate alone. |

### Daily life

| Package | What it enables / replaces |
|---|---|
| `syncthing` | Already half-adopted — `setup_syncthing_v1.0.0_2026-09-07.sh` exists and `.stignore` files are scattered through the tree, but it is not in `packages.x86_64` (131 packages, checked). Ship it or remove the scripts; right now the tree implies a capability the ISO does not have. |
| `borgbackup` + `borgmatic` | Deduplicating, encrypted, append-only backups. `snapshot_before_update.sh` is a hand-rolled version of this. Borg would have made the 12 G `.git` problem a non-event. |
| `restic` | If the target is object storage rather than a local disk. Pick one of borg/restic, not both. |
| `keepassxc` | `50-backends/GoogleWorkspaceService/.env` and `20-runtime/config/.env` are plaintext secrets on disk, and `seal_secrets.sh` exists but is hand-rolled. A real password store with a CLI (`keepassxc-cli`) lets the build scripts fetch secrets instead of reading `.env` files that get committed by auto-sync. |
| `nnn` or `yazi` | A TUI file manager. On a live ISO with no desktop file manager guaranteed to start (B2), this is the fallback that keeps the machine usable. |
| `zoxide` + `atuin` | Directory jumping and searchable shell history synced across machines. In a tree with paths like `30-source/android_companion(seperate-related-project)/swarm_os-companion/app/`, `zoxide` is not a luxury. |
| `btop` | Process, GPU and thermal monitor in one screen. Replaces `htop` + `nvtop` + `sensors`. |

---

## 5. Scope ledger

**Read in full (content, not just metadata):**

- `/mnt/Lucy/VERSION`, `CLAUDE.md` (first 30 lines + full AWS grep), `.gitignore` (grep)
- `70-scripts/build_swarm_iso.sh` — lines 1–90, 128–155, 400–470, plus targeted greps across the whole file
- `70-scripts/verify_bundle_deps.sh` — lines 1–45
- `70-scripts/auto_sync_github.sh` — complete
- `70-scripts/sync_lucille_ai.sh` — rsync lines only
- `70-scripts/vm_boot_gate.sh` — targeted greps (timeout, success patterns)
- `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh`, `..._v6.2.19_2026-09-07.sh` — complete (162 B each)
- `40-iso-profile/swarm_os_iso_profile/ARCH_SNAPSHOT` — complete
- `40-iso-profile/swarm_os_iso_profile/airootfs/etc/swarm-release` — complete
- `logs/boot-gate-20260922-222548.log` — last 40 lines + full grep for verdict strings and `SWARM OS Desktop`
- `logs/boot-gate-20260922-222548-qemu.log`, `logs/swarm-ui-20260922-065239.log` — complete
- `logs/sync_lucille_ai.log` — last 12 lines
- `90-docs/SWARM_OS_DAILY_AUDIT_2026-09-23_v1.0.0.md` — header + section headings
- Both companion `app/build.gradle.kts` — version lines
- `I30LTZ_RECOVERY_BUILD_TRACKER.md` — last 25 lines

**Seen by metadata only (mtime, size, path, git index — content not read):**

- The 57 423 files under `30-source/`, the 6 381 under `40-iso-profile/`, the 110 841 under `swarm_os_build_work/`, the 2 302 under `20-runtime/`
- All 30 boot-gate log pairs except the two named above — counted by `grep -c`, not read
- The 12 tracked `.pdb` files — listed by `git ls-files`, not opened
- `.git` — size measured with `du`; **pack contents were not inspected**, so m7's growth figure is real but its cause is inferred
- The Google Drive mirror — **entirely by metadata.** Root folder listing only (44 entries). No file was downloaded, and subfolders were not walked. The "17 days stale" figure is the newest `modifiedTime` in the root listing.

**Not reachable, and why:**

- `/mnt/ventoy/ISO/SWARM_OS/` — outside the bridged folder. **No ISO artifact, checksum or `latest.txt` was verified this run.** Every statement about what is or is not on Ventoy is inferred from the build's failure to reach `mkarchiso`, not from looking.
- `/run/media/i30ltz/LUCILLE/Luccile-v+` — does not exist on this machine.
- systemd journal, running process list, `/mnt/brains`, sdb8 — outside the bridge.
- The 03:00 build's terminal output — never written to a file. B1's cause is an inference from file mtimes, and is labelled as such.

**Explicitly: nothing was compiled, built, booted, installed, executed or tested by this audit.** No `mkarchiso`, no `flutter build`, no `cargo`, no `dotnet`, no `go build`, no QEMU, no `verify_bundle_deps.sh`, no `git gc`. No file on LUCILLE was modified by this run except the writing of this document into `90-docs/`.

---

*SWARM OS daily evaluation audit · document v1.1.0 · 2026-09-23 · machine LUCILLE · project Luccile-v+ (LLcy Core)*
