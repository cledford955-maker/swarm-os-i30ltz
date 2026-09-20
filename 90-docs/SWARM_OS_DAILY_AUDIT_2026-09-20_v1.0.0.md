# SWARM OS — Daily Evaluation Audit

```
Document         : SWARM_OS_DAILY_AUDIT_2026-09-20_v1.0.0.md
Document version : v1.0.0
Audit date       : 2026-09-20
Machine          : LUCILLE (cachyos-i30ltz, x86_64, Linux)
Project          : Luccile-v+  ·  branding "LLcy Core"  ·  persona "Boltz"
Source read      : /mnt/Lucy  (LUKS "lucy-master", UNLOCKED and read directly)
OS VERSION file  : 6.2.69
Git HEAD         : c025660  auto-sync: 2026-09-20T10:10:35-04:00
Prior audit      : SWARM_OS_DAILY_AUDIT_2026-09-18_v1.0.0.md  (no 09-19 audit exists)
Built / compiled : NOTHING. No build, no cargo, no dotnet, no mkarchiso, no VM run.
```

---

## 0. Headline

**The authoritative tree was reachable today.** `/mnt/Lucy` was unlocked and mounted, so
everything below is read from source, not from the Drive mirror.

**SWARM OS has had no working offsite copy for 29 hours, and the cause is new.**
Yesterday's audit found the GitHub sync dead from a stale `.git/index.lock`. That is fixed —
the lock is gone and commits are flowing again, 135 of them. But the *first* commit after the
fix added a **3.78 GB tar file** to the repository, and GitHub refuses any file over 100 MB.
Every `git push` since **2026-09-19 09:21** has failed. The sync has now been broken two days
running for two entirely different reasons, and the second one cannot be fixed by waiting —
the blob is baked into 135 commits and has to be rewritten out.

The Drive mirror is 14 days stale. Between the two, **there is currently no copy of SWARM OS
anywhere except the one encrypted drive in this machine.**

Everything else moved in the right direction. Four of yesterday's findings are genuinely fixed
and are reported as clean below, not rehashed.

---

## 1. Inventory

### 1.1 Where the source was read

| Source | Status | Used |
|---|---|---|
| `/mnt/Lucy` — LUKS "lucy-master" | **Unlocked, mounted, 65 GB used of 250 GB (173 GB free)** | ✅ **Primary — everything below** |
| `/run/media/i30ltz/LUCILLE/Luccile-v+` | Not attached to this session | ❌ not consulted |
| Google Drive mirror `1T4Oi5abo…` | Reachable, **14 days stale** | ⚠️ metadata only, for staleness check |
| `/mnt/ventoy/ISO/SWARM_OS/` | **Outside the connected folder — not visible to this session** | ❌ unreachable, see §4 |

Note the tree no longer matches the old `frontend/ LucyServer/ lucille-core/` layout. It has
been reorganised into numbered stages (`00-CURRENT` … `99-archive`), and `Luccile-v+/` is now
a near-empty leftover holding one superseded build script from 09-07.

### 1.2 Changed in the last 24 h

9,979 files carry an mtime inside 24 h, but 9,9xx of those are Rust incremental-compile
cache under `30-source/swarm-slint/target/` (gitignored, correctly). The meaningful changes:

| File | When | What it means |
|---|---|---|
| `60-boltz-brain/swarm-memory/PROJECT_MEMORY.md` | 09-20 14:00 | Memory mirror still ticking — the sync script's *first* half works |
| `30-source/frontend/lib/models/agent.dart` (34.8 KB) | 09-19 17:48 | Active frontend work |
| `30-source/frontend/lib/skills/nvidia_nim_skill.dart` | 09-19 17:48 | New NVIDIA NIM skill wired in |
| `30-source/frontend/lib/services/skill_router.dart` + `providers/skill_router_providers.dart` | 09-19 17:48 | Skill-router plumbing — this is the "code itself" path |
| `SWARM_AI_FEATURES.md` (200 KB) | 09-19 17:48 | Living feature record, updated per CLAUDE.md policy ✅ |
| `SWARM_OS_IMPLEMENTATION_CHECKLIST.md` | 09-19 17:50 | Grew 6.6 KB → 10.5 KB |
| `70-scripts/vm_boot_gate.sh` | 09-19 17:03 | Boot gate was edited, then run (§2 BLOCKER-2) |
| `80-vm/desktop/booted.ppm`, `started.ppm` | 09-19 17:05 / 17:07 | Boot-gate frame captures — see BLOCKER-2 |

Nothing at all has been edited by hand since 09-19 17:50. The only 09-20 activity is the
memory mirror and the auto-sync commits.

### 1.3 Git state

```
branch        main
HEAD          c025660   auto-sync: 2026-09-20T10:10:35-04:00
vs origin     ahead 135, behind 0
last push     7f81006   2026-09-19 09:21:35 -0400
working tree  clean (0 dirty paths)
.git size     5.7 GB
remotes       origin                 github.com/cledford955-maker/swarm-os-i30ltz
              i30ltz-recovery        github.com/cledford955-maker/i30ltz-recovery
              i30ltz-swarm-companion github.com/cledford955-maker/i30ltz-swarm-companion
```

Commits land every ~11 minutes and the tree is clean, so the commit half of
`auto_sync_github.sh` is healthy. The push half is not. See BLOCKER-1.

### 1.4 Build and operations scripts — `70-scripts/`

The dated-script sprawl from yesterday is **resolved**. `build_swarm_iso_6.2.19_2026-09-08.sh`
and `build_swarm_iso_v6.2.19_2026-09-07.sh` are now **162-byte compatibility forwards**, not
30 KB twins; `00-CURRENT/build-iso.sh` is a 50-byte forward. The single live engine is
`70-scripts/build_swarm_iso.sh` (22,492 b, 09-19), exactly as `CLAUDE.md` states.

It auto-bumps `VERSION` on every build and stamps six surfaces:

| Line | Surface stamped |
|---|---|
| 132 | `frontend/pubspec.yaml` → `version: ${NEW_VER}+${NEW_PATCH}` |
| 133 | `frontend/lib/shell/top_bar.dart` → UI version badge |
| 136 | `swarm-slint/Cargo.toml` → crate version |
| 139–140 | `profiledef.sh` → `iso_name`, `iso_application` |
| 145–146 | companion `build.gradle.kts` → `versionName`, `versionCode` |
| 397 | `airootfs/etc/swarm-release` → `SWARM_VERSION / SWARM_COMMIT / SWARM_DATE` |

### 1.5 Release artifacts and checksums

| Location | Contents |
|---|---|
| `10-releases/` | **Empty** (only a stray `.claude/` dir). Gitignored. |
| `00-CURRENT/releases` | Symlink → `../10-releases`, therefore also empty |
| `/mnt/ventoy/ISO/SWARM_OS/` | **Not reachable from this session** — cannot confirm or deny |
| `_to_delete/duplicate-isos-2026-09-12/` | 2 × 3.38 GB ISOs (`v6.2.44…`, `swarm-os-v6.2.iso`) quarantined |
| checksums / manifests | **None anywhere.** Only `90-docs/MANIFEST_2026-09-07.md`, 13 days old and generated by a script nothing calls. |

`80-vm/desktop/launcher.log` records the VM opening `/mnt/Lucy/10-releases/swarm-os-v6.2.69.iso`
on 09-19 — so a 6.2.69 ISO did exist and has since left that directory, presumably to Ventoy
per policy. Its current whereabouts cannot be verified from here.

### 1.6 Version labelling across the stack

| Surface | Value today | Verdict |
|---|---|---|
| `VERSION` | `6.2.69` | reference |
| `frontend/pubspec.yaml` | `6.2.69+69` | ✅ stamped |
| `frontend/lib/shell/top_bar.dart` | `'v6.2.69'` | ✅ stamped (UI badge correct) |
| `swarm-slint/Cargo.toml` | `6.2.69` | ✅ stamped |
| `swarm-slint/src/main.rs` | `option_env!("SWARM_VERSION")` → build injects it | ✅ correct by design |
| `profiledef.sh` `iso_name` / `iso_application` | stamped at build | ✅ |
| `airootfs/etc/swarm-release` | written at build | ✅ |
| **`efiboot/loader/entries/01-archiso-linux.conf`** | **`title SWARM OS v6.2.19`** | ❌ **50 releases stale — MAJOR-3** |
| **companion `app/build.gradle.kts`** | **`versionName = "6.2.12"`** | ❌ **57 releases stale — MAJOR-4** |
| **`frontend/lib/pages/developer_ecosystem_page.dart`** | **ALPHA `v6.2.20-alpha.3`, BETA `v6.2.19-beta.1`, STABLE `v6.2.18`** | ❌ **user-visible, never stamped — MAJOR-5 (new today)** |

---

## 2. Evaluation

### BLOCKER-1 — a 3.78 GB tarball has jammed every GitHub push for 29 hours · **CONFIRMED**

**Evidence, all from git itself:**

```
last push to origin/main   7f81006   2026-09-19 09:21:35 -0400
next commit                c256282   2026-09-19 09:34:15 -0400   ← added the blob
blob                       40-iso-profile/swarm_os_iso_profile/airootfs/
                             usr/local/share/swarm-os/airootfs.tar
size                       4,057,999,360 bytes  (3.78 GB)
in unpushed range          yes (git log origin/main..HEAD confirms)
ahead/behind               135 / 0
```

**Failure scenario, concrete:** GitHub rejects any single file over 100 MB outright, and caps a
push at 2 GB. Commit `c256282` is unpushable, and because git pushes commits in order, *every*
commit after it is unpushable too. `auto_sync_github.sh` runs on a timer, finds dirty state,
commits, and calls `git push origin main`, which exits non-zero. With `set -euo pipefail` the
script dies there. This has repeated roughly 135 times. Eleven minutes later it happens again.
Nothing surfaces the failure, so from the outside the sync looks alive — commits *are* being
created, the timer *is* firing, `PROJECT_MEMORY.md` *is* updating.

**Why it happened:** `.gitignore` excludes `40-iso-profile/*/airootfs/opt/`,
`…/airootfs/usr/lib/` and `…/airootfs/var/cache/` — but **not** `…/airootfs/usr/local/share/`.
A build staged the rootfs tarball there and `git add -A` swallowed it.

**Blast radius:** if the lucy-master drive fails, is lost, or the LUKS header is damaged,
everything since 09-19 09:21 is gone — including the whole skill-router and NVIDIA-NIM work
from 09-19 17:48. The Drive mirror is 14 days behind (MINOR-9) and does not cover it.

**Also aborted by the same failure:** the two `git subtree push` calls at the end of the script
never run, so `i30ltz-recovery` and `i30ltz-swarm-companion` are stale too. The script's own
comment block already documents a second, independent bug here — the recovery subtree's
`--prefix` still omits the `(seperate-related-project)` suffix added on 09-18 — so even once
the push is unjammed, that subtree will fail and abort the companion push behind it.

**Fix, in order:**
```bash
cd /mnt/Lucy
printf '40-iso-profile/*/airootfs/usr/local/share/\n' >> .gitignore
git rm --cached '40-iso-profile/swarm_os_iso_profile/airootfs/usr/local/share/swarm-os/airootfs.tar'
git commit -m 'Untrack 3.78 GB airootfs.tar; ignore airootfs usr/local/share'
# the blob is still in 135 commits of history — it must be rewritten out:
pacman -S --needed git-filter-repo
git filter-repo --force --invert-paths \
  --path '40-iso-profile/swarm_os_iso_profile/airootfs/usr/local/share/swarm-os/airootfs.tar'
git remote add origin https://github.com/cledford955-maker/swarm-os-i30ltz.git
git push --force-with-lease origin main
```
`git filter-repo` drops the remotes, hence the re-add. Take a snapshot of `/mnt/Lucy` first —
this rewrites 135 commits.

---

### BLOCKER-2 — the boot gate produced two identical frames; it still proves nothing · **CONFIRMED, and now confirmed by pixels rather than metadata**

`vm_boot_gate.sh` was edited 09-19 17:03 and a VM run followed at 17:01–17:13, writing
`started.ppm` (17:07:48) and `booted.ppm` (17:05:35). Yesterday's audit could only say the
gate was uninformative. Today it can be shown:

```
md5  d799be93f81edb44a3f7479d66564202   started.ppm
md5  d799be93f81edb44a3f7479d66564202   booted.ppm     ← byte-identical
geometry  640 × 480
distinct colours  2   →  (0,0,0) × 276,606  and  (170,170,170) × 30,594
```

**Failure scenario:** the two captures are 2 min 13 s apart and the framebuffer did not change
by a single byte. 640×480 with exactly two colours, one of them `#AAAAAA`, is a firmware or
GRUB text console — not labwc, not the Flutter shell, not the Slint panel. So the run either
never left the boot menu or the capture is reading a stale framebuffer. Either way, a gate that
writes a file named `booted.ppm` containing a text-mode screen will report success for an ISO
that never boots to a desktop. Every gate verdict to date is therefore uninformative, and
6.2.69 has no verified boot.

**Settles it:** add `console=ttyS0,115200` to the ISO cmdline and capture the serial log
instead of the framebuffer — and, cheaply, make the gate fail when
`md5sum started.ppm == md5sum booted.ppm`.

---

### BLOCKER-3 — companion version stamping still points one directory too shallow · **CONFIRMED (third day)**

```
build_swarm_iso.sh:143  COMPANION_GRADLE="$LUCY/30-source/android_companion/app/build.gradle.kts"
actual path             30-source/android_companion/swarm_os-companion/app/build.gradle.kts
                                                    ^^^^^^^^^^^^^^^^^^^ missing segment
```
Line 144 guards with `if [ -f "$COMPANION_GRADLE" ]`, so the stamp is skipped in silence on
every build. `versionName` is stuck at **6.2.12** against a `VERSION` of 6.2.69.

**Failure scenario:** a companion APK installed on a phone reports 6.2.12 in Android's app
settings while the desktop it pairs with reports 6.2.69. Any pairing handshake or update check
that compares the two sees a 57-release gap and will either refuse or loop. `versionCode` is
likewise frozen, so Android will treat a newer build as not-an-upgrade and refuse to install
over it without an uninstall.

**Fix:** insert `swarm_os-companion/` into the path on line 143, and drop the `-f` guard for a
hard failure so the next broken path is loud.

---

### MAJOR-3 — the UEFI boot menu has said "SWARM OS v6.2.19" for 50 releases · **CONFIRMED**

`40-iso-profile/swarm_os_iso_profile/efiboot/loader/entries/01-archiso-linux.conf:1` reads
`title    SWARM OS v6.2.19`. It is not in the stamper's list of six surfaces.

**Failure scenario:** this is the very first thing anyone sees when booting a SWARM USB. With
ten rolling builds kept on Ventoy per the release policy, every one of them presents the same
title, so there is no way to tell from the boot menu which build you are about to run. Picking
the wrong one during a bisect costs a full boot cycle each time.

**Fix:** one more `sed -i` beside lines 139–140, or better, U3 below.

---

### MAJOR-4 — companion `versionName` frozen at 6.2.12 · **CONFIRMED** — this is the visible symptom of BLOCKER-3; fixing the path fixes both.

---

### MAJOR-5 — the Developer Ecosystem page shows three hardcoded, wrong version numbers to the user · **CONFIRMED (new today)**

`30-source/frontend/lib/pages/developer_ecosystem_page.dart` lines 196–200 render three release
channel cards:

| Channel | Displayed | Reality |
|---|---|---|
| ALPHA | `v6.2.20-alpha.3` | 49 behind |
| BETA | `v6.2.19-beta.1` | 50 behind |
| STABLE | `v6.2.18` | 51 behind |

The stamper's line 133 `sed` targets `top_bar.dart` only, so these were never in scope. The
STABLE card also claims *"Production release certified with full SHA-256 integrity"* while no
checksum exists anywhere in the project (MAJOR-6).

**Failure scenario:** this is a UI surface promising a certified, hash-verified 6.2.18 stable
build. Nothing on disk backs that claim, and the numbers will drift further with every build.
Per the project's own rule that UI-facing things carry a visible version label, this page is
currently mislabelling three of them.

**Fix:** these are channel pointers, not build numbers — they belong in a release manifest the
page reads at runtime, not in Dart source. See U3.

---

### MAJOR-6 — no checksums, no manifests, and `10-releases/` is empty · **CONFIRMED**

`10-releases/` holds nothing but a stray `.claude/` directory; `00-CURRENT/releases` symlinks
to it. There is no `.sha256` anywhere in the tree. `generate_manifest_v1.0.0_2026-09-07.sh`
still exists and is still invoked by nothing; the only manifest is 13 days old.

**Failure scenario:** a SWARM ISO on Ventoy cannot be verified — not against corruption, not
against a partial write, and not against "which commit built this." If a build boots badly there
is no way to tell whether the ISO is wrong or the media is. **Not confirmed:** I could not see
`/mnt/ventoy/ISO/SWARM_OS/` from this session, so I cannot say what is actually staged there.
**Settles it:** `ls -la --time-style=long-iso /mnt/ventoy/ISO/SWARM_OS/ && sha256sum /mnt/ventoy/ISO/SWARM_OS/*.iso`

---

### MAJOR-7 — `AGENTS.md` is a blind find-and-replace of `CLAUDE.md` and contains a broken URL · **CONFIRMED (new today)**

`AGENTS.md` (9,147 b) and `CLAUDE.md` (9,150 b) differ in exactly four lines — every one of
them a `Claude` → `Codex` substitution applied without reading the result:

| `CLAUDE.md` | `AGENTS.md` |
|---|---|
| `…Claude share one append-only memory log…` | `…Codex share one…` (legitimate) |
| `ANTHROPIC_API_KEY, CLAUDE_API_KEY — Anthropic Claude` | **`— Anthropic Codex`** |
| `https://claude.ai/code/artifact/5c970c82-…` | **`https://Codex.ai/code/artifact/5c970c82-…`** |

**Failure scenario:** `AGENTS.md` is the onboarding file a non-Claude coding agent reads first.
It tells that agent that `ANTHROPIC_API_KEY` belongs to a product called "Anthropic Codex" and
points it at `https://Codex.ai/…`, which does not resolve. An agent following the document to
fetch that artifact gets a DNS failure and no explanation.

**Fix:** generate `AGENTS.md` from `CLAUDE.md` with a substitution list that excludes URLs and
vendor names, or keep one file and symlink the other.

---

### MINOR-8 — one `*.bak-$(date +%s)` file locally, two more in the Drive mirror · **CONFIRMED (steady at 1 local)**

```
/mnt/Lucy/40-iso-profile/swarm_os_iso_profile/profiledef.sh.bak-$(date +%s)   1,126 b  09-06
Drive:  install_swarm_os.sh.bak-$(date +%s)    10,832 b
Drive:  build_swarm_iso.sh.bak-$(date +%s)      9,556 b
```
A single-quoted `cp "$f" "$f.bak-$(date +%s)"` that never expanded. The name contains `$`, `(`
and `)`; any unquoted expansion touching it is a shell syntax error. Genuinely minor — one
stale file next to a profile that is rewritten every build. Other backups now use the correct
dated form (`SWARM_AI_FEATURES.md.bak-2026-09-19`), so the generating bug is fixed; this is
residue.

### MINOR-9 — the Google Drive mirror is 14 days stale and still holds VM images · **CONFIRMED**

Newest `modifiedTime` in the mirror root is **2026-09-06T17:01:56Z**. It still advertises the
pre-reorganisation layout (`frontend/`, `LucyServer/`, `lucille-core/`, `coder_marketplace/`),
a `VERSION` file last touched 09-03, and both `swarm_vm_disk.qcow2` and two `OVMF_VARS.fd`
images that `.gitignore` excludes locally. Ordinarily cosmetic — but with BLOCKER-1 active,
this stale mirror is the *only* other copy of the project in existence, and it predates the
entire numbered-stage reorganisation.

### MINOR-10 — 12 `.pdb` debug-symbol files tracked in git · **CONFIRMED**

`git ls-files | grep -c '\.pdb$'` → `12`. Rebuildable .NET debug symbols, not covered by
`.gitignore`. Harmless next to a 3.78 GB tarball, but it is the same class of mistake.

### MINOR-11 — a 417 MB `.deb` is parked in the project root · **CONFIRMED (new today)**

`/mnt/Lucy/chatgpt_amd64.deb`, 417,340,066 b, 09-19 10:31. Correctly untracked (`.deb` is
ignored), so it is not a git problem — it is 417 MB of unrelated vendor installer sitting at
the top of an encrypted project drive, where it will be swept into any `rsync`, `restic` or
`tar` of the tree.

### MINOR-12 — the parenthesised companion directory name is still shell-hostile · **CONFIRMED**

```
30-source/android_companion/                            versionName 6.2.12   ← live (subtree-pushed)
30-source/android_companion(seperate-related-project)/  versionName 6.2.11   ← sibling
```
Down from three trees yesterday to two. Precedence is now de-facto settled — `auto_sync_github.sh`
subtree-pushes `30-source/android_companion/swarm_os-companion` — but still written down
nowhere. The `(` and `)` remain shell metacharacters, the misspelling "seperate" still defeats
grep, and the same directory name already broke the recovery subtree's `--prefix` (BLOCKER-1).

---

### Clean — verified today, no action needed

- **`CLAUDE.md` AWS boilerplate — FIXED.** Zero matches for `aws|bedrock|s3|lambda`. The file
  now opens with the real ISO release policy, the `/mnt/Lucy` working-directory rule, the
  two-Wayland-client architecture and the component table. This is a good onboarding document.
- **Compiled artifacts in git — CLEAN.** `git ls-files` matching `.o .class .qcow2 .so .a .jar .apk .deb .dll .zip` → **0**. (`.pdb` remains, MINOR-10.) The `.qcow2` and `.fd` blobs exist only in the stale Drive mirror.
- **`VERSION` vs hardcoded versions in build scripts — FIXED.** No build script hardcodes an OS
  version any more. `build_swarm_iso.sh` reads `VERSION`, bumps it, and stamps six surfaces.
  Three surfaces outside its list are still stale (MAJOR-3/4/5), but the *scripts* are clean.
- **Duplicate one-character-apart build scripts — FIXED.** Both dated variants are now 162-byte
  compatibility forwards, exactly as `ISO_RELEASE_POLICY.md` requires.
- **Stale `.git/index.lock` (yesterday's BLOCKER-1) — FIXED.** No lock file; 135 commits created
  since; working tree clean.
- **Rust/Slint build — no errors.** `target/flycheck0/stderr` ends
  `Checking swarm-slint v6.2.69 … Finished dev profile in 8.24s`. The backtrace above it is from
  an earlier run. **Not confirmed** — read from a stale cached log, nothing was compiled today.
  **Settles it:** `cd /mnt/Lucy/30-source/swarm-slint && cargo check 2>&1 | tail -20`

---

## 3. Upgrades — ranked by value

### U1. Purge the tarball, then make it structurally impossible to repeat
**Why it matters:** BLOCKER-1 has cost 29 hours of offsite durability and is still running. But
the purge alone only fixes today — `git add -A` on a timer against a tree that also builds ISOs
into itself will do this again the moment another build writes somewhere `.gitignore` does not
cover. The fix is a size guard, not a bigger ignore list.
**First step:** run the BLOCKER-1 fix block above, then add a pre-commit hook that rejects any
staged file over 50 MB:
```bash
git diff --cached --name-only -z | xargs -0 -r -I{} \
  sh -c 'test $(stat -c%s "{}") -lt 52428800 || { echo "BLOCKED: {} >50MB"; exit 1; }'
```

### U2. Make the sync fail loudly, and fix the subtree prefix behind it
**Why it matters:** the sync has now failed twice in two days from two unrelated causes, and
both times it was an audit — not the system — that noticed. A timer that dies quietly is worse
than no timer, because everyone believes it is working. This converts an invisible failure into
a visible one, and it is the change that would have caught BLOCKER-1 at 09:35 instead of +29 h.
**First step:** in `auto_sync_github.sh`, wrap the push, write `ok`/`FAILED <reason> <timestamp>`
to `20-runtime/sync-health`, fire `notify-send` on failure, surface that file in the Flutter top
bar beside the version badge — and correct the `--prefix` on the `i30ltz-recovery` subtree push
to include the `(seperate-related-project)` suffix (the script's own comment already diagnoses
this; it just was not applied).

### U3. One manifest-driven stamper — with the boot entry, the companion and the channel cards in it
**Why it matters:** MAJOR-3, MAJOR-4 and MAJOR-5 are the same bug three times. Version stamping
is a hand-maintained list of `sed` lines where a missing or misspelled path fails silently
(`if [ -f ]`), and every new surface has to be remembered. Three are wrong today; the next one
added will be too.
**First step:** have the build write `10-releases/<version>/manifest.json`
(`version, commit, date, sha256, channel`), then replace the `sed` block with a loop over a
declared surface list that **hard-fails on a missing target** — and make
`developer_ecosystem_page.dart` read its three channel cards from that manifest instead of
hardcoding them.

### U4. Give the boot gate a serial console and a frame-delta check
**Why it matters:** BLOCKER-2 means the project's one automated quality gate has produced no
information since it was written, and today proved it is capturing a two-colour text screen and
calling it `booted`. Until this is fixed, "6.2.69 boots" is an assumption. Fixing it is what
makes every other blocker debuggable, because a serial log says *where* boot stopped.
**First step:** add `console=ttyS0,115200` to the ISO cmdline in `profiledef.sh`/the boot
entries, point QEMU at `-serial file:…`, and gate on the serial text. As a five-minute stopgap,
fail the gate when `started.ppm` and `booted.ppm` hash the same.

### U5. Turn `10-releases/` into a real release directory
**Why it matters:** MAJOR-6 means there is no answer on disk to "what is this ISO, what commit
built it, and did it pass." The directory exists, the symlink points at it, a generator script
was written for it 13 days ago — and it is empty. The STABLE card in the UI is currently
promising SHA-256 integrity that does not exist.
**First step:** have `build_swarm_iso.sh` write `10-releases/<version>/` containing the ISO,
`SHA256SUMS`, `manifest.json` and the boot-gate log *before* copying to Ventoy, and wire
`generate_manifest_v1.0.0_2026-09-07.sh` into the build instead of leaving it orphaned.

---

## 4. Tooling worth adding to SWARM OS

Chosen against what is actually in this tree — labwc/Wayland, Steam, `GamingAgent-go` on
port 8401, Rust+Slint, Go ×2, Flutter/Dart, .NET 10, two Android companion trees.

### Gaming

| Package | What it enables or replaces |
|---|---|
| `gamescope` | A nested micro-compositor for games. SWARM runs labwc; without gamescope a Steam title gets whatever the desktop compositor gives it. Adds per-game resolution, FSR upscaling, frame limiting and HDR passthrough **without** touching labwc's config — which matters because the Flutter shell owns that compositor. |
| `mangohud` + `goverlay` | On-screen FPS, frametime, CPU/GPU temp and power. The Slint panel already has a "monitor" tab with no in-game data source; MangoHud writes a CSV log that `GamingAgent-go` can tail and publish on 8401 — turning that tab from a placeholder into real telemetry. |
| `lutris` + `umu-launcher` | Non-Steam titles and GOG/Epic under one launcher with per-game Proton prefixes. `umu` gives Lutris the same runtime Steam uses, so a GFN-fallback local install behaves identically to the Steam path `GamingAgent` already targets. |
| `vkbasalt` | Vulkan post-processing (CAS sharpening, FXAA) via a config file. Pairs with gamescope's upscaling — you upscale, then sharpen — and costs nothing when unused. |
| *(pin, don't add)* `proton-cachyos` | CachyOS already ships this; pin the version in the ISO profile so a host `pacman -Syu` cannot change game behaviour between two builds that are otherwise identical. |

### Coding

| Package | What it enables or replaces |
|---|---|
| `git-filter-repo` | Required *today* to execute the BLOCKER-1 fix. `git filter-branch` is deprecated and would take hours on a 5.7 GB repo. |
| `pre-commit` | Hosts the >50 MB guard from U1, plus a hook that rejects `*.bak-$(date` filenames (MINOR-8) and `.pdb` (MINOR-10). Replaces three manual audit findings with one config file. |
| `rust-analyzer`, `gopls`, `csharp-ls`, `taplo-cli` | The actual substance behind "VS Code-class." One LSP per language already in the tree: Slint panel (Rust), `LucyServer-go` + `GamingAgent-go` (Go), `LucyServer` net10.0 (C#), `Cargo.toml`/manifests (TOML). Dart/Flutter ships its own. |
| `just` | Replaces the dated-shell-script pile in `70-scripts/` with one discoverable `justfile` — `just build`, `just gate`, `just sync`, `just audit`. The 162-byte compatibility forwards exist precisely because there is no task runner; this is what they are standing in for. |
| `difftastic` | Syntax-aware diffs. Every build rewrites six files by `sed`; `difft` shows *"version string changed"* instead of a line-noise diff, which makes the stamper's output reviewable. |
| `android-tools` + `scrcpy` | `adb install` for the companion APK and screen mirroring of the phone onto the desktop. `install_companion_apk_v1.0.0_2026-09-16.sh` already assumes `adb`; `scrcpy` lets the companion be tested beside the shell it pairs with instead of on a phone in your hand. |
| `distrobox` | Builds the .NET 10 and Flutter toolchains inside a container so the ISO profile does not have to carry them, and so a host toolchain upgrade cannot silently change a build. Directly shrinks the `airootfs` that caused BLOCKER-1. |

### Daily life

| Package | What it enables or replaces |
|---|---|
| `restic` + `rclone` | **The actual fix for the class of problem in BLOCKER-1.** Git is not a backup — it chokes on multi-GB blobs, which is exactly how the push died. `restic` does deduplicated, encrypted, incremental snapshots and `rclone` ships them to the same Google Drive that currently holds a 14-day-old copy. One `restic backup /mnt/Lucy` on a timer would have made today's 29-hour gap a non-event. |
| `syncthing` | `setup_syncthing.sh` already exists in the Drive mirror and was never wired up. Continuous peer-to-peer sync of `/mnt/Lucy` to a second machine — no cloud, no size limit, no 100 MB ceiling. This is the answer to MINOR-9. |
| `snapper` + `btrfs-assistant` | CachyOS defaults to btrfs. A pre-build snapshot makes `git filter-repo` (U1) and every future `sed`-stamping build reversible in seconds instead of "restore from the mirror that is two weeks old." |
| `zellij` | Persistent terminal sessions. A full `mkarchiso` build plus boot gate runs long; zellij survives a disconnect and keeps the scrollback, so a build that fails at minute 40 still has its log. |
| `ripgrep` + `fd` | Concretely justified: a plain `du -sh */` across this tree **timed out at 120 s** during this audit, and `find` needed explicit prunes to finish. Boltz shelling out to `find`/`grep` over a 65 GB tree will hit the same wall; `rg`/`fd` respect `.gitignore` by default and skip `target/`, `.dart_tool/` and `flutter-sdk/` for free. |

---

## 5. Scope ledger

**Read in full (content, on LUCILLE at `/mnt/Lucy`):**
`VERSION` · `.gitignore` · `CLAUDE.md` (head + full grep) · `AGENTS.md` (full diff vs CLAUDE.md) ·
`70-scripts/auto_sync_github.sh` (tail) · `70-scripts/build_swarm_iso.sh` (version/stamp/sed
lines) · `Luccile-v+/build_swarm_iso_v6.2.2_2026-09-07.sh` (header) · `install_swarm_os.sh`
(version lines) · `40-iso-profile/swarm_os_iso_profile/profiledef.sh` (version lines) ·
`efiboot/loader/entries/01-archiso-linux.conf` · both companion `build.gradle.kts` ·
`frontend/pubspec.yaml` · `frontend/lib/shell/top_bar.dart:84` ·
`frontend/lib/pages/developer_ecosystem_page.dart:196–200` · `swarm-slint/Cargo.toml` ·
`swarm-slint/src/main.rs:24–25` · `swarm-slint/target/flycheck0/stderr` (tail) ·
`LucyServer/LucyServer.csproj` · `80-vm/desktop/launcher.log` ·
`90-docs/SWARM_OS_DAILY_AUDIT_2026-09-18_v1.0.0.md` (headings).

**Inspected as data, not just metadata:** `80-vm/desktop/started.ppm`, `booted.ppm`,
`booted.png` — decoded with PIL for geometry and colour histogram, and md5-compared.

**Seen by metadata only:** the ~9,979 files with 24 h mtimes (listed by `find -printf`, not
opened) · the Rust `target/` cache · `chatgpt_amd64.deb` (size/mtime only) ·
`_to_delete/duplicate-isos-2026-09-12/*.iso` (size/mtime only) · `git ls-files` size ranking ·
the Google Drive mirror (root listing metadata only — **no Drive file contents were downloaded**).

**Not reachable, and why:**
- `/mnt/ventoy/ISO/SWARM_OS/` — outside the folder connected to this session; the sandbox can
  only see `/mnt/Lucy`. The ISO inventory, retention count and checksums in MAJOR-6 are
  therefore **unverified**.
- `/run/media/i30ltz/LUCILLE/Luccile-v+` — the staged copy was not attached to this run. Not
  needed; the authoritative tree was live.
- `/mnt/brains/swarm-memory/` — outside the connected folder. Only its git mirror at
  `60-boltz-brain/swarm-memory/` was visible.
- GitHub — no network call was made to any remote. The push-failure conclusion is inferred from
  local git state (`ahead 135`, `origin/main` dated 09-19 09:21, a 3.78 GB blob inside the
  unpushed range) plus GitHub's documented 100 MB file limit. **Not directly observed:** the
  push error text itself. **Settles it:** `cd /mnt/Lucy && git push origin main 2>&1 | tail -20`

**Stated plainly:** nothing was compiled, built, or run during this audit. No `cargo`, no
`dotnet`, no `flutter`, no `mkarchiso`, no `qemu`, no `git push`, no `git` write of any kind,
and no file on LUCILLE was modified except this report being written into `90-docs/`. Every
finding above is from reading files, reading git metadata, and decoding three image files.

---

*SWARM_OS_DAILY_AUDIT_2026-09-20_v1.0.0.md · generated 2026-09-20 · LUCILLE · SWARM OS 6.2.69*
