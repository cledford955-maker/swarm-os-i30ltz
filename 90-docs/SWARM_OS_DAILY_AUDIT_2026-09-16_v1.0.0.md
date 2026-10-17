# SWARM OS — Daily Evaluation Audit

| Field | Value |
|---|---|
| **Document** | `SWARM_OS_DAILY_AUDIT_2026-09-16_v1.0.0.md` |
| **Document version** | v1.0.0 |
| **Audit date** | 2026-09-16 |
| **Machine** | LUCILLE (`cachyos-i30ltz`, CachyOS/Arch, user `i30ltz`) |
| **Project** | Luccile-v+ · branding "LLcy Core" · persona "Boltz" |
| **Source read** | **`/mnt/Lucy` — the authoritative LUKS tree, unlocked and mounted.** Not the staged copy, not the Drive mirror. |
| **Tree VERSION** | **6.2.54** |
| **Git HEAD at read** | `ab3a0351` on `main`, working tree clean, level with `origin/main` |
| **Newest ISO** | `swarm-os-v6.2.50-cc49de3a-2026.09.13-x86_64.iso` (2026-09-13) |
| **Anything compiled/built/run?** | **No.** Nothing was compiled, built, booted, or executed. See Scope ledger. |

---

## 0. Headline

One directory rename — `30-source/i30ltz-recovery/` → `30-source/i30ltz-recovery(seperate-related-project)/` — silently broke three automation scripts. Two of them fail on every run and have been failing for days. Separately, the ISO's UEFI boot menu has been printing **`SWARM OS v6.2.19`** on every build since 6.2.19, which is visible in your own boot-gate capture from 2026-09-14.

Four of the five known open items were re-checked. **Two are fixed** and are not repeated below.

---

## 1. Inventory

### 1.1 Tree layout (`/mnt/Lucy`, 47 GB used of 250 GB)

| Path | Size | Newest content | Role |
|---|---|---|---|
| `00-CURRENT/` | symlinks | 2026-09-08 | Stable entry points into the numbered dirs |
| `10-releases/` | 6.3 G | 2026-09-13 | Two ISOs (6.2.49, 6.2.50) |
| `20-runtime/` | 94 M | 2026-09-13 | Deployed app + `.env` + config |
| `30-source/` | 19 G | 2026-09-16 | 14 source trees |
| `40-iso-profile/` | 3.8 G | 2026-09-16 | mkarchiso profile + airootfs payload |
| `50-backends/`, `50-boot/` | 11 M / 5.3 M | 2026-09-08 / 09-07 | Workspace service, boot assets |
| `60-boltz-brain/` | 1.1 M | 2026-09-16 | swarm-memory mirror (active) |
| `70-scripts/` | 168 K | 2026-09-16 | 19 scripts |
| `80-vm/`, `90-docs/`, `99-archive/` | 1.3 M / 80 K / 952 K | — | VM harness, 11 docs, archive |
| `swarm_os_build_work/` | **11 G** | 2026-09-14 | mkarchiso work dir (gitignored) |
| `_to_delete/` | **6.4 G** | 2026-09-12 | Quarantine: dup ISOs, git locks, old history w/ exposed key |
| `logs/` | 232 K | 2026-09-16 | boot-gate, swarm-ui, sync logs |

### 1.2 Changed in the last 24 h

10,150 files by mtime, but nearly all of that is one `rsync`/copy of the Flutter asset bundle into `40-iso-profile/.../airootfs/opt/`. The **substantive** changes:

- `70-scripts/auto_sync_github.sh` (09-16 09:27) — memory-mirror block added
- `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` (09-16 09:27)
- `70-scripts/install_companion_apk_v1.0.0_2026-09-16.sh` (09-16 11:25) — new
- `60-boltz-brain/swarm-memory/**` (09-16) — memory sync active and working
- `.gitignore` (09-16 09:28), `CLAUDE.md` (09-16 09:31), `README.md` (09-16 08:36)
- `90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md` — new doc
- `40-iso-profile/.../labwc/autostart`, `usr/local/bin/swarm-snapshot.sh`, `install_swarm_os.sh`

### 1.3 `git log --oneline -20`

All twenty are `auto-sync: <ISO-8601>` commits from 2026-09-16 06:38 → 10:02, roughly every 11 minutes, from `swarm-lucy-sync.timer`. There are no hand-authored commits in the window. Remotes: `origin` (swarm-os-i30ltz), `i30ltz-recovery`, `i30ltz-swarm-companion`. `origin/main` and `HEAD` are level (0 ahead / 0 behind). 1,343 files tracked; **no binaries, build output, or credentials are tracked** — `git ls-files` comes back empty for `*.o *.a *.so *.class *.jar *.apk *.qcow2 *.iso *.dll *.zip` and for `.env`/`secret`/`credential` patterns.

### 1.4 Build scripts

| Script | Size | Modified | Note |
|---|---|---|---|
| `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh` | 29,847 | 2026-09-16 | **The live one.** `00-CURRENT/build-iso.sh` → this. Filename says 6.2.19; it builds 6.2.55 next. |
| `70-scripts/build_swarm_iso_v6.2.19_2026-09-07.sh` | 8,098 | 2026-09-07 | Superseded |
| `Luccile-v+/build_swarm_iso_v6.2.2_2026-09-07.sh` | 13,479 | 2026-09-07 | Orphan; only file in that dir |
| `install_swarm_os.sh` (root) | 23,190 | 2026-09-13 | Reads version from `/etc/swarm-release` — correct |
| `70-scripts/auto_sync_github.sh` | 2,021 | 2026-09-16 | See BLOCKER-1 |
| `70-scripts/sync_lucille_ai.sh` | 6,919 | 2026-09-12 | See BLOCKER-2 |
| `70-scripts/vm_boot_gate.sh` | 9,697 | 2026-09-13 | QEMU boot gate |
| + 12 more (snapshot, seal_secrets, verify_bundle_deps, manifest, companion, syncthing, …) | | | |

### 1.5 Release artifacts & checksums

```
3377790976  2026-09-13 10:30  swarm-os-v6.2.49-cc49de3a-2026.09.13-x86_64.iso
                              sha256 b8c774b720b17aa7781f9f7905baeeacba9185d90e8ff4175cadfb6b1159885f
3377790976  2026-09-13 23:35  swarm-os-v6.2.50-cc49de3a-2026.09.13-x86_64.iso
                              sha256 f6d736121a3e441da48a5d4fd0f445f1a49fff9986b2ddcd3b60aa0cd1119b52
```

Identical byte size, identical embedded commit `cc49de3a`, **different content hashes** — two builds from one commit. **There are no `.sha256`, `.md5`, or manifest files anywhere in `10-releases/`.** The two hashes above were computed during this audit; they are not recorded anywhere on disk.

### 1.6 Version labelling across the stack

| Location | Value | Stamped by build script? |
|---|---|---|
| `VERSION` | 6.2.54 | ✅ auto-increment |
| `30-source/frontend/pubspec.yaml` | `6.2.54+54` | ✅ |
| `30-source/swarm-slint/Cargo.toml` | `6.2.54` | ✅ |
| `40-iso-profile/.../profiledef.sh` | `swarm-os-v6.2.54-cc49de3a` | ✅ |
| `airootfs/etc/swarm-release` | `SWARM_VERSION=6.2.54` | ✅ |
| **`efiboot/loader/entries/01-archiso-linux.conf`** | **`title SWARM OS v6.2.19`** | ❌ **never** |
| **`grub/grub.cfg` + `grub/loopback.cfg`** | `"Swarm OS — Live Kiosk"` | ❌ no version at all |
| **`android_companion/swarm_os-companion/app/build.gradle.kts`** | `versionName "6.2.12"`, `versionCode 72` | ❌ **path wrong** |
| `android_companion(seperate…)/…/build.gradle.kts` | `versionName "6.2.11"` | ❌ orphan |

---

## 2. Evaluation

### BLOCKER-1 — `auto_sync_github.sh` aborts before the companion subtree push · CONFIRMED

`auto_sync_github.sh` runs `set -euo pipefail`, then:

```bash
git subtree --quiet push --prefix=30-source/i30ltz-recovery          i30ltz-recovery main
git subtree --quiet push --prefix=30-source/android_companion/swarm_os-companion i30ltz-swarm-companion main
```

`30-source/i30ltz-recovery` **does not exist** — the directory is `30-source/i30ltz-recovery(seperate-related-project)/` (7 files tracked under that name). `git subtree push` on a missing prefix exits non-zero; `set -e` kills the script on that line; **the companion subtree push on the next line never executes.**

*Failure scenario:* you commit a companion fix, the timer fires, `origin` receives it, and `i30ltz-swarm-companion` receives nothing — silently, forever, because the timer's exit status is not surfaced anywhere you look. Any device or CI pulling the companion repo builds a stale app and you have no signal that it is stale.

*Settle / fix:*
```bash
systemctl status swarm-lucy-sync.service --no-pager -l     # confirm the non-zero exit
```
Then either rename the directory (drop the parentheses — they also break unquoted paths in every other script) or correct the prefix and reorder so the companion push runs first.

### BLOCKER-2 — `sync_lucille_ai.sh` has failed on every run since at least 2026-09-15 · CONFIRMED

`logs/sync_lucille_ai.log`, every entry:

```
rsync: --no-delete: unknown option
rsync error: syntax or usage error (code 1) at main.c(1886) [client=3.5.0-g471e17dc]
[2026-09-16 03:43:31] FAIL  Lucille-AI sdb8 (i30ltz-AI) (exit 1)
[2026-09-16 03:43:31] Sync complete — ok=0 fail=1
```

`--no-delete` is not an rsync option (rsync 3.5.0 on this box rejects it; deletion is opt-in via `--delete`, so the flag was never needed). Every run: `ok=0 fail=1`. The same log also shows the BLOCKER-1 rename biting a second script:

```
SKIP DR. I30LTZ Recovery — binary not built at /mnt/Lucy/30-source/i30ltz-recovery/target/release/i30ltz-recovery
```

*Failure scenario:* the Lucille-AI payload on `i30ltz-AI`/`lucy-master` is whatever it was before this rsync flag was introduced. You believe AI assets are being replicated to the recovery drives; they are not. If `/mnt/Lucy` is lost, the recovery drives restore a stale brain.

*Settle / fix:* delete the `--no-delete` token from `70-scripts/sync_lucille_ai.sh`, then `bash 70-scripts/sync_lucille_ai.sh` and confirm `ok=1 fail=0`.

### BLOCKER-3 — companion version stamping is a no-op; the ISO ships an APK from 2026-09-08 · CONFIRMED

The build script, line 125:

```bash
COMPANION_GRADLE="$LUCY/30-source/android_companion/app/build.gradle.kts"
if [ -f "$COMPANION_GRADLE" ]; then   # ← false, every build
```

The real file is `30-source/android_companion/swarm_os-companion/app/build.gradle.kts` (one level deeper). The `if -f` guard swallows it without a word. Result: `versionName = "6.2.12"` / `versionCode = 72` while everything else in the stack reads 6.2.54.

Compounding it, the APK baked into the ISO is not built from either companion tree:

| File | sha256 (first 16) | Size |
|---|---|---|
| `40-iso-profile/.../assets/companion/SWARM_OS_Companion.apk` | `647b33595f0add7b` | 28,703,773 |
| `swarm_flutter/.../companion/SWARM_OS_Companion.apk` (09-08) | `647b33595f0add7b` | 28,703,773 |
| `android_companion/.../app-debug.apk` (09-16 build) | `b73813a774a7537e` | 36,517,997 |
| `android_companion(seperate…)/SWARM_OS_Companion_v6.2.20.apk` | `fb827efc604093c4` | — |

*Failure scenario:* a user boots 6.2.54, taps "install companion", and gets an app that reports itself as 6.2.12 and is byte-identical to the 2026-09-08 build — eight megabytes and eight days behind the source. Any companion/server protocol change since 09-08 fails at the handshake with no useful error.

*Settle / fix:* point `COMPANION_GRADLE` at the real path, drop the silent `if -f` (make it `|| exit 1`), and have the build copy `app/build/outputs/apk/release/*.apk` into the airootfs rather than reusing a checked-in blob.

### MAJOR-4 — UEFI boot menu has said "v6.2.19" for 35 releases · CONFIRMED

`40-iso-profile/swarm_os_iso_profile/efiboot/loader/entries/01-archiso-linux.conf`, line 1:

```
title    SWARM OS v6.2.19
```

Hardcoded. The build script seds pubspec, Cargo.toml, profiledef and `/etc/swarm-release`, and never touches `efiboot/`. Confirmed visually in your own boot gate — `logs/boot-gate-20260914-190435.log` captured the systemd-boot screen of the v6.2.50 ISO rendering `SWARM OS v6.2.19`.

The GRUB path is inconsistent in the other direction: `grub/grub.cfg` and `grub/loopback.cfg` say `"Swarm OS — Live Kiosk (default)"` with **no version string at all**. So the first screen a user sees either lies about the version or omits it, depending on firmware path.

*Failure scenario:* you keep three ISOs on the Ventoy stick to bisect a regression and cannot tell them apart from the boot menu — all three say v6.2.19 under UEFI, and all three say nothing under GRUB.

*Settle / fix:* add to the Step-1 stamping block —
```bash
sed -i "s|^title.*|title    SWARM OS v${NEW_VER}|" "$PROFILE_DIR/efiboot/loader/entries/01-archiso-linux.conf"
sed -i "s|Swarm OS — Live Kiosk (default)|Swarm OS v${NEW_VER} — Live Kiosk (default)|" "$PROFILE_DIR/grub/grub.cfg" "$PROFILE_DIR/grub/loopback.cfg"
```

### MAJOR-5 — no checksums ship with releases; VERSION no longer means "latest shipped" · CONFIRMED

`10-releases/` holds two ISOs and zero checksum files. Nothing on disk records what a good v6.2.50 hashes to, so a truncated Ventoy copy or a bad USB write is undetectable.

Separately, Step 0 of the build script increments `VERSION` **before** mkarchiso runs, so a failed build burns a number. Git shows `VERSION` going `6.2.44 → 6.2.54` inside a single auto-sync window on 2026-09-15, while the newest ISO on disk is **6.2.50 from 09-13**. At least four version numbers have been consumed with no artifact behind them.

*Failure scenario:* someone asks "are you on 6.2.54?" — the tree says yes, and no such ISO has ever existed. Worse, a partially written ISO on the Ventoy stick boots into a broken squashfs and there is no hash to check it against.

*Settle / fix:* write `sha256sum` beside every ISO at the end of a successful build, and move the `echo "$NEW_VER" > "$VERSION_FILE"` write to *after* mkarchiso exits 0.

### MAJOR-6 — last boot gate did not observe a successful boot · NOT CONFIRMED (metadata + log only)

`logs/boot-gate-20260914-190435.log` ends mid-countdown at the boot menu; the companion `-qemu.log` reads:

```
qemu-system-x86_64: terminating on signal 15 from pid 46960 (bash)
```

That is the gate's own timeout kill, not a shutdown. Every gate log in `logs/` (09-13 ×6, 09-14 ×1) shows the same shape — menu reached, then SIGTERM. Nothing in the logs shows the compositor starting, `swarm-ui.service` coming up, or a login prompt. Whether the ISO actually boots to a desktop is **unverified**; I did not run QEMU.

*Settle:*
```bash
bash /mnt/Lucy/70-scripts/vm_boot_gate.sh /mnt/Lucy/10-releases/swarm-os-v6.2.50-cc49de3a-2026.09.13-x86_64.iso
```
and confirm the new log contains a `swarm-ui` or login line rather than another signal-15.

### MINOR-7 — `*.bak-$(date +%s)` files, three of them, in two places · CONFIRMED (was 2, now 3)

- `/mnt/Lucy/40-iso-profile/swarm_os_iso_profile/profiledef.sh.bak-$(date +%s)` (1,126 B, 2026-09-06)
- Drive mirror root: `install_swarm_os.sh.bak-$(date +%s)` (10,832 B)
- Drive mirror root: `build_swarm_iso.sh.bak-$(date +%s)` (9,556 B)

Single-quoted `cp "$f" "$f.bak-\$(date +%s)"` somewhere. Harmless content, but the literal `$( )` in a filename breaks glob-based cleanup and any script that expands it. Delete or rename with a real timestamp.

### MINOR-8 — stray relative-path artefacts in the project root · CONFIRMED

```
/mnt/Lucy/mnt/lucy                       0 bytes, 2026-09-16
/mnt/Lucy/run/media/i30ltz/lucy-master   0 bytes, 2026-09-16
```

Zero-byte *files* where mount points would be — something ran with a relative path and created placeholders inside the project. Created today. Also: `build_swarm_iso_6.2.19_2026-09-08.sh` line 39 sets `SCRIPT_DIR="/run/media/i30ltz/lucy-master/Luccile-v+"`, which does not exist on this machine; grep confirms the variable is **assigned and never read**, so it is dead weight rather than a failure — but it is the same stale assumption that produced the placeholders. Delete the two paths, delete line 39.

### MINOR-9 — Drive mirror is 10 days stale and still holds VM images · CONFIRMED

Newest `modifiedTime` under root `1T4Oi5abo…`: **2026-09-06T17:01:56Z** (`lucille-core/`). The mirror's `VERSION` was last touched 2026-09-03. It predates the 00-/10-/20- reorganisation entirely — it is a flat `frontend/ LucyServer/ lucille-core/ swarm_os_iso_profile/` layout that no longer matches the tree.

Open item re: compiled artifacts — **still true in the mirror**: `swarm_vm_disk.qcow2` (197 KB), `OVMF_VARS.fd` and `swarm_ovmf_vars.fd` (540 KB each) sit at the mirror root. The mirror carries the **old 515-byte `.gitignore`**, not the current 1,797-byte one that excludes `*.qcow2` and `*.fd`. So the mirror is not violating the current ignore rules; it simply predates them.

*Impact:* the mirror is unusable as a fallback source today — following the prompt's fallback order would have produced an audit of a 10-day-old, differently-shaped tree. Either re-seed it from `/mnt/Lucy` or retire it in favour of the GitHub remotes, which are current.

### MINOR-10 — housekeeping: 17.4 GB of quarantine and scratch

`swarm_os_build_work/` 11 G (mkarchiso scratch, 2026-09-14) + `_to_delete/` 6.4 G. `_to_delete/` contains `duplicate-isos-2026-09-12`, `git-locks-2026-09-12`, and **`git-with-exposed-key-2026-09-12`** — the pre-rotation git history. It is gitignored and the volume is LUKS-encrypted at rest, so there is no live exposure, but that history should not outlive confirmation that the key was rotated. 191 GB free, so this is tidiness, not pressure.

### Clean — verified, no action

- **Git hygiene is genuinely good.** 1,343 tracked files, zero tracked binaries, zero tracked credentials. `.gitignore` (v1.1.0, 2026-09-12, 1,797 B) is thorough and current — it even names the specific `appsettings.Development.json` that carried a live OpenRouter key.
- **Version stamping across Flutter / Slint / profiledef / swarm-release is consistent at 6.2.54.** The known open item "VERSION disagreeing with hardcoded versions in build scripts" is **fixed** for those four. Only the two boot menus and the companion gradle remain, and those are called out above as MAJOR-4 and BLOCKER-3.
- **`CLAUDE.md` is fixed.** The stock AWS boilerplate is gone. It is now 8,379 bytes of real SWARM OS conventions — working directory, the decoy-path warning, the component/language/location table, labwc config paths. Zero hits for `aws|amazon|bedrock|s3|lambda`. **Do not report this again.**
- **Secrets are sealed properly.** Only `swarm_os.env.gpg` + manifest ship; plaintext `/etc/swarm_os.env` is gone; `swarm-secrets.service` unseals to tmpfs at boot.
- **Wi-Fi backend is correct.** `iwd.service` and `NetworkManager.service` are both enabled, which normally means contention — but `airootfs/etc/NetworkManager/conf.d/wifi-backend.conf` sets `wifi.backend=iwd`. Clean.
- **`aspnet-runtime-10.0` in `packages.x86_64` matches `<TargetFramework>net10.0</TargetFramework>`** in both `LucyServer.csproj` and `LucyServer.Tests.csproj`. Consistent.
- **The swarm-memory mirror is working.** `60-boltz-brain/swarm-memory/` updated 2026-09-16, and the `auto_sync_github.sh` mirror block degrades quietly when `/mnt/brains` is unmounted.
- **`origin` is current.** 0 ahead, 0 behind, clean tree.

### Note on the task's stated stack

The brief describes ".NET 8 backend" and "C++ `lucille-core`" with a Flutter shell. The tree has moved: `CLAUDE.md` (2026-09-11) and the source confirm **.NET 10 → Go migration in progress** (`LucyServer-go/`), a **Rust + Slint** companion panel (`swarm-slint/`), and a **Go GamingAgent** on port 8401. Worth updating the scheduled task's context block so future runs start from the real architecture.

---

## 3. Upgrades — ranked by value

### U1. Make the build fail loudly instead of silently (highest value)

Three of this audit's findings are the *same bug class*: a path that stopped existing, guarded by something that swallows the failure — `if [ -f ]`, a bare subtree push under `set -e`, a `SKIP` branch. None of them printed an error you would ever see.

*Why it matters:* you are not losing time to hard problems, you are losing it to silent no-ops. Every one of BLOCKER-1/2/3 would have surfaced on the first run with a preflight.

*First step:* add a `preflight()` at the top of `build_swarm_iso_6.2.19_2026-09-08.sh` that asserts every path variable resolves, and exits 1 naming the first that does not:
```bash
for v in VERSION_FILE PROFILE_DIR AIROOTFS FLUTTER_DIR SLINT_DIR SOURCE_DIR COMPANION_GRADLE; do
  [ -e "${!v}" ] || { echo "PREFLIGHT FAIL: \$$v = ${!v} does not exist"; exit 1; }
done
```
Ten lines. It catches BLOCKER-3 today.

### U2. One version stamper, driven by a manifest

Version truth is currently spread across six `sed` calls in one script, and two files nobody remembered to add. Replace with `70-scripts/stamp_version.sh` reading a `version_targets.tsv` of `path<TAB>sed-expression`, so adding a new versioned surface is one line in a data file rather than a new `sed` in a 700-line script.

*Why it matters:* it structurally prevents MAJOR-4 from recurring, and it is the thing your own rule — *"everything labelled with a date and a version, even on UI"* — actually requires. Right now the OS's most visible label is 35 releases out of date.

*First step:* create the TSV with the six paths that already work plus the two boot menus, and have the build call the stamper instead of inlining seds.

### U3. Release manifests — turn `10-releases/` into a real release directory

Each build should emit, beside the ISO: `<iso>.sha256`, and a `<iso>.manifest.json` carrying version, git commit, build timestamp, mkarchiso version, the `packages.x86_64` hash, and the companion APK's sha256.

*Why it matters:* it fixes MAJOR-5, makes the two same-size-different-hash 6.2.49/6.2.50 ISOs explicable rather than mysterious, and gives the boot gate something to assert against. It is also what makes "which ISO is on the Ventoy stick" answerable without booting it.

*First step:* append to the build's success block:
```bash
( cd "$OUT_DIR" && sha256sum "$ISO_NAME" > "$ISO_NAME.sha256" )
```

### U4. Make the boot gate assert, not just watch

The gate currently boots QEMU and gets SIGTERM'd at the menu. It has never, in any log on disk, confirmed the system reaches a desktop.

*Why it matters:* you are shipping ISOs whose only validation is that they produce a boot menu. `swarm-ui.service` is the single most likely thing to break (PAM session, seatd, DRM, the Flutter GTK embedder — the service file itself carries three separate comments about fallback paths).

*First step:* boot with `-serial file:$LOG`, append `systemd.journald.forward_to_console=1` to the kernel cmdline in a gate-only loader entry, and grep the serial log for `Started SWARM OS Desktop`. Exit 0 on match, 1 on timeout.

### U5. Retire the parenthesised directory names

`i30ltz-recovery(seperate-related-project)` and `android_companion(seperate-related-project)` have now broken three scripts between them, and the word is misspelled. Parentheses are shell metacharacters; every unquoted reference is a latent bug.

*First step:* `git mv` both to `i30ltz-recovery-standalone/` and `android_companion-standalone/`, then `grep -rn 'seperate-related-project' 70-scripts/` and fix the references — which is also how you close BLOCKER-1 and BLOCKER-2 permanently. Decide precedence at the same time: `30-source/android_companion/swarm_os-companion/` is the live tree (it is the subtree source for `i30ltz-swarm-companion` and is at versionName 6.2.12); the `(seperate…)` copy is at 6.2.11 and holds loose release APKs. Mark one `README.md` in each saying which is authoritative.

---

## 4. Tooling — packages worth adding to the OS

Grounded in the actual `packages.x86_64` (205 lines) as it stands today. `pacman.conf` currently enables **only `[core]` and `[extra]`** — no multilib, no AUR — which constrains several of these; noted where it applies.

### 4.1 Coding — the Coder Droid story has a hole in it

| Package | What it enables / replaces | Why now |
|---|---|---|
| **`android-tools`** | `adb`, `fastboot` | **This is the gap.** The OS is built for Android development, ships `SWARM_OS_Companion.apk` inside the ISO, and `install_companion_apk_v1.0.0_2026-09-16.sh` falls back to `ADB=adb` on `PATH` — which does not exist on a booted SWARM OS. Right now you cannot install the companion *from* the OS the companion belongs to. |
| **`scrcpy`** | Mirror/control a connected phone on the desktop | Turns the hex desktop into an actual Android workstation: test the companion on a real device beside the Flutter shell instead of alt-tabbing to a phone. Pairs with `android-tools`. |
| **`neovim`** | Replaces `vim` (already present) | `vim` is in the list; `neovim` costs ~30 MB more and gives you LSP, which is what makes editing Dart/Go/Rust on a live ISO tolerable when the Flutter shell is the only GUI. |
| **`ripgrep` + `fd`** | Replaces `grep -r` / `find` for interactive use | Small (~6 MB together), and they are what Claude Code / the `claude` CLI (already provisioned via `nodejs`/`npm`) reaches for. Without them the CC tile falls back to `grep -r` across a 19 GB tree. |
| **`lazygit`** | Terminal git UI | The whole project is git-driven by a timer. When `auto_sync_github.sh` fails, `lazygit` is how you see *what* is uncommitted without typing eight commands into `alacritty`. |
| **`distrobox`** | Arch-on-Arch and non-Arch toolchains via the `podman` already installed | `podman`, `podman-docker`, `crun`, `fuse-overlayfs` are all present — `distrobox` is the ~1 MB shim that makes them usable for "I need Ubuntu's NDK build" without touching the ISO. |
| **`jq`** | JSON on the command line | `LucyServer` exposes ~100 endpoints and `GamingAgent-go` is a JSON API on 8401. Debugging either on the live system currently means reading raw JSON. |

### 4.2 Gaming — `gaming-agent.service` is enabled and has nothing to drive

`GamingAgent-go` ships `steam_service.go`, `games_service.go` and `handlers/steam.go`, and `gaming-agent.service` is in `multi-user.target.wants`. **Steam is not in `packages.x86_64`.** The service boots and manages a library that cannot exist.

| Package | What it enables / replaces | Note |
|---|---|---|
| **`steam`** | The thing `steam_service.go` talks to | **Requires enabling `[multilib]` in `pacman.conf`** — it is 32-bit. This is a one-block edit, but it is a real decision: it roughly doubles the dependency surface. Without it, close the loop the other way and document GamingAgent as GFN/streaming-only. |
| **`gamemode`** | CPU governor + scheduler tuning per-game | Pairs directly with the Monitor tab in `swarm-slint`. Also needs multilib for the 32-bit `lib32-gamemode` if Steam goes in. |
| **`mangohud`** | On-screen FPS/frametime/temps overlay | Gives the Lucille gaming panel something real to read and display — the data is already exposed via the MangoHud shared-memory/logging interface. |
| **`lutris`** | Non-Steam launcher: GOG, Epic, emulators | The generic answer if you decline multilib for Steam — Lutris itself is 64-bit and can manage Wine/Proton prefixes per game. |
| **`vulkan-nouveau` / `nvidia-utils`** | NVIDIA rendering | `vulkan-radeon`, `vulkan-intel` and `libva-mesa-driver` are present; **there is no NVIDIA path at all**. A live ISO that hits an NVIDIA box today falls back to llvmpipe and the Flutter shell will crawl. `nvidia-utils` + `nvidia-dkms` is the heavy answer; `vulkan-nouveau` is the free-driver stopgap that at least gives hardware acceleration. |
| **`gamescope`** | Micro-compositor: resolution/HDR/FSR isolation per game | Fits the existing labwc setup exactly — run a game in its own scaled, framerate-limited surface instead of fighting the hex desktop for the output. |

### 4.3 Daily life

| Package | What it enables / replaces | Note |
|---|---|---|
| **`snapper` + `snap-pac`** | Automatic pre/post-pacman btrfs snapshots | `btrfs-progs` is already in the list and `swarm-snapshot.service` already exists — `snapper` is the proven implementation that hooks pacman, which is exactly when a rolling Arch system breaks. Replaces hand-rolled snapshot logic in `snapshot_before_update.sh`. |
| **`flatpak`** | Apps that will never be packaged for this profile | Discord, Spotify, Obsidian, Bitwarden. Keeps the ISO's `packages.x86_64` lean — the alternative is growing it toward a general-purpose distro. |
| **`syncthing`** | Device-to-device file sync | `70-scripts/setup_syncthing_v1.0.0_2026-09-07.sh` and three `.stignore` files already exist in the tree, so this is *already the intended design* — the daemon just was never added to the ISO. |
| **`restic`** | Encrypted, deduplicated, incremental backup | BLOCKER-2 is a backup failure that went unnoticed for days. `restic` with a `--json` status line is something `sync_lucille_ai.sh` could actually assert on, instead of hand-rolled rsync flags that vary by rsync version. |
| **`firewalld`** *(evaluate, don't just add)* | Zone-based firewall management | `nftables.conf` is the real firewall (default-drop) and `ufw` is installed-but-deliberately-not-enabled, per the annotated note in `packages.x86_64`. **Do not enable a third firewall front-end** — listed only so the decision is explicit. The existing nftables setup is fine; leave it. |
| **`wl-clipboard`** | `wl-copy` / `wl-paste` under Wayland | Under labwc with no desktop environment, copy/paste between `alacritty`, `chromium` and the Flutter shell has no CLI path at all. ~100 KB. |
| **`brightnessctl`** + **`wlsunset`** | Backlight control and night colour temperature | Basic laptop livability that labwc does not provide on its own. `wlr-randr` is already in the list for output config; these are the two obvious companions. |

---

## 5. Scope ledger

**Source of record:** `/mnt/Lucy` — the LUKS `lucy-master` volume, unlocked and mounted as a connected folder. This is the authoritative tree (option 1 in the task's ordering). The staged copy at `/run/media/i30ltz/LUCILLE/Luccile-v+` was **not** used. The Google Drive mirror was queried for freshness and open-item verification only.

**Read in full:**
`VERSION` · `.gitignore` · `CLAUDE.md` (head, plus full-text grep for AWS boilerplate) · `70-scripts/auto_sync_github.sh` · `40-iso-profile/swarm_os_iso_profile/profiledef.sh` (head) · `40-iso-profile/swarm_os_iso_profile/packages.x86_64` · `airootfs/etc/swarm-release` · `airootfs/etc/NetworkManager/conf.d/wifi-backend.conf` · `airootfs/etc/systemd/system/swarm-ui.service` (head) · `efiboot/loader/entries/01-archiso-linux.conf` · `logs/boot-gate-20260914-190435.log` and its `-qemu.log` · `logs/sync_lucille_ai.log` (tail 20) · targeted line ranges and greps of `70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh`, `install_swarm_os.sh`, `70-scripts/install_companion_apk_v1.0.0_2026-09-16.sh`, both companion `build.gradle.kts`, both `.csproj`, `grub/grub.cfg`, `grub/loopback.cfg`, `pacman.conf`.

**Computed during this audit:** sha256 of both ISOs in `10-releases/` (full 3.4 GB reads), and sha256 of four `SWARM_OS_Companion.apk` / `app-debug.apk` copies. These hashes exist only in this document — nothing was written to `10-releases/`.

**Seen by metadata only (mtime, size, `git ls-files`, directory listing — contents not read):**
the ~10,150 files changed in 24 h, of which the Flutter asset bundle under `40-iso-profile/.../flutter_assets/` is the overwhelming majority · `swarm_os_build_work/` (11 G) · `_to_delete/` (6.4 G, including `git-with-exposed-key-2026-09-12` — **not** opened) · `20-runtime/.env` (**not** opened) · `images/` · `99-archive/` · `30-source/lucille-core/` sources · `30-source/LucyServer/` and `LucyServer-go/` sources beyond the `.csproj` · `30-source/GamingAgent-go/` beyond a filename grep for Steam references · the full contents of both Android companion trees.

**Not reachable / not done:**
- **Nothing was compiled, built, or run.** No `mkarchiso`, no `dotnet build`, no `cargo build`, no `flutter build`, no `gradle`, no QEMU. No ISO was booted or mounted.
- Toolchains (`dotnet`, `go`, `cargo`, `flutter`) are **not present in the device-bridge shell's PATH**. This is a property of the bridge, **not** evidence that they are absent from LUCILLE — build health below the "does the script's logic hold" level is therefore unverified.
- `git ls-remote` to all three GitHub remotes failed with `could not read Username for 'https://github.com'` — no credential helper in the bridge shell. **The claim in BLOCKER-1 that `i30ltz-swarm-companion` is not receiving pushes is therefore reasoned from the script's `set -e` control flow and the confirmed-missing prefix path, not from observing the remote.** Settle it on LUCILLE with `git ls-remote i30ltz-swarm-companion main` and compare against `git subtree split --prefix=30-source/android_companion/swarm_os-companion`.
- `/run/media/i30ltz/lucy-master/Luccile-v+` (the build script's dead `SCRIPT_DIR`) does not exist on this machine — confirmed absent, not merely unmounted, from the bridge's view.
- Google Drive mirror: folder listing and metadata read; **no file contents downloaded.** Freshness (newest `modifiedTime` 2026-09-06T17:01:56Z) and the presence of `*.qcow2` / `*.fd` / two `*.bak-$(date +%s)` files are from listing metadata.

---

*SWARM OS Daily Evaluation Audit · v1.0.0 · 2026-09-16 · generated against `/mnt/Lucy` @ `ab3a0351` · VERSION 6.2.54*
