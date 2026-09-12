# Review: build_swarm_iso_v6.2.1.sh — 2026-09-07
*swarm-code-review v1.1.0 · review doc r1.0.0 · 1 file, 145 lines read*

## Verdict
Do not ship. The script cannot complete on the drive's current layout — it exits at
step 1 — and the build-identity block it computes (version, date, commit) is discarded
before the ISO is named.

## Findings

### 1. [BLOCKER · CONFIRMED] Every source path points at a tree that is not there
`build_swarm_iso_v6.2.1.sh:35-41`

    SCRIPT_DIR="/run/media/i30ltz/lucy-master/Luccile-v+"

The drive mounts at `/run/media/i30ltz/LUCILLE`, not `lucy-master`, and that drive's
`Luccile-v+/` currently holds only this script and its `.bak`. `frontend/`,
`LucyServer/`, `swarm_os_iso_profile/` and `grub_themes/` are not under it —
`LucyServer/` and `grub_themes/` are siblings at the drive root.

**Fails when:** run at all. Line 52 `cd "$FLUTTER_DIR"` fails, `set -e` exits 1 with a
bare `cd` error, nothing is built and no diagnostic names the real problem.

**Fix:** derive the root from the script's own location, point at the real siblings, and
assert before building:

    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    DRIVE_ROOT="$(dirname "$SCRIPT_DIR")"
    FLUTTER_DIR="${FLUTTER_DIR:-$SCRIPT_DIR/frontend}"
    SERVER_DIR="${SERVER_DIR:-$DRIVE_ROOT/LucyServer}"
    PROFILE_DIR="${PROFILE_DIR:-$SCRIPT_DIR/swarm_os_iso_profile}"
    GRUB_THEME_DIR="${GRUB_THEME_DIR:-$DRIVE_ROOT/grub_themes/swarm_os}"

    for d in "$FLUTTER_DIR" "$SERVER_DIR" "$PROFILE_DIR"; do
      [ -d "$d" ] || { echo "FATAL: missing required directory: $d" >&2; exit 1; }
    done

### 2. [BLOCKER · CONFIRMED] Build identity is computed, printed, then thrown away
`build_swarm_iso_v6.2.1.sh:3-8` vs `:123-128`

`ISO_LABEL` is assembled from version, date and commit at line 7, echoed at line 8, and
never referenced again. The ISO is named by the hardcoded literal `swarm-os-v6.2.1.iso`.
The two source paths in that block (`/mnt/Lucy/Luccile-v+`, `/mnt/Lucy/VERSION`) are a
third root, distinct from `SCRIPT_DIR` and from the real mount.

**Fails when:** always. `/mnt/Lucy/VERSION` is unreadable, so `BUILD_VERSION` is empty and
`COMMIT` falls back to `nogit`, producing the malformed label
`swarm-os--20260907-nogit` — which is then discarded anyway. Every ISO ships with no
build date and no commit, and two builds a month apart are byte-distinct files with
identical names.

**Fix:** source the identity from the real tree, fail if version is empty, name the
artifact from the label, and print the label in the banner so the on-screen UI carries
the same version and date the file does:

    VERSION_FILE="$SCRIPT_DIR/VERSION"
    BUILD_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null || true)"
    [ -n "$BUILD_VERSION" ] || { echo "FATAL: no version in $VERSION_FILE" >&2; exit 1; }
    COMMIT="$(git -C "$SCRIPT_DIR" rev-parse --short=8 HEAD 2>/dev/null || echo nogit)"
    BUILD_DATE="$(date +%Y-%m-%d)"
    ISO_LABEL="swarm-os-v${BUILD_VERSION}-${BUILD_DATE}-${COMMIT}"
    # banner:
    echo -e "${CYAN}${BOLD}  SWARM OS :: LIVE ISO BUILD ENGINE — ${ISO_LABEL}${NC}"
    # output:
    cp -f "$LATEST_ISO" "$OUT_DIR/${ISO_LABEL}.iso"
    ln -sfn "${ISO_LABEL}.iso" "$OUT_DIR/swarm-os-latest.iso"

### 3. [MAJOR · CONFIRMED] A v6.2.1 build is written over the v6.2 artifact
`build_swarm_iso_v6.2.1.sh:127-128`

    cp -f "$LATEST_ISO" "$OUT_DIR/swarm-os-v6.2.1.iso"
    cp -f "$LATEST_ISO" "$OUT_DIR/swarm-os-v6.2.iso"

**Fails when:** a real v6.2 release exists on the drive. It is silently replaced by
v6.2.1 bytes under its old name, so the version number on disk no longer describes the
contents and the earlier release is unrecoverable.

**Fix:** delete the second `cp`. Use the `swarm-os-latest.iso` symlink from finding 2 if
a stable name is needed.

### 4. [MAJOR · CONFIRMED] A successful build can be reported as a failure
`build_swarm_iso_v6.2.1.sh:123`

    LATEST_ISO=$(ls -t "$OUT_DIR"/swarm-os-v6.2.1*.iso 2>/dev/null | head -n 1)

The glob is hardcoded to `6.2.1` and must match `iso_name`/`iso_version` in the
`swarm_os_iso_profile`, which this script never reads.

**Fails when:** the profile is bumped to 6.2.2 (or any rename). `mkarchiso` succeeds and
writes the ISO; the glob matches nothing; line 143 prints "Error: ISO file was not
found" and exits 1 after a full multi-minute build.

**Fix:** glob on the profile's own value — read `iso_version` from
`$PROFILE_DIR/profiledef.sh` — or match `"$OUT_DIR"/*.iso` by mtime and verify it is
newer than the start of the run.

### 5. [MINOR · CONFIRMED] `set -e` alone, on a script that reads possibly-absent files
`build_swarm_iso_v6.2.1.sh:18` — no `-u`, no `pipefail`. Unset variables expand to empty
inside `rm -rf` and `cp` targets, and the pipeline at line 123 hides a failing `ls`.
**Fix:** `set -euo pipefail`.

### 6. [MINOR · CONFIRMED] Hardcoded home directory
`build_swarm_iso_v6.2.1.sh:130` — `/home/i30ltz/Desktop`. Fails silently under any other
user; the `|| true` guarantees no one notices. **Fix:** `"${HOME}/Desktop"`, and drop the
error suppression so a real failure is visible.

### 7. [MINOR · CONFIRMED] Parsing `ls` output
`build_swarm_iso_v6.2.1.sh:123` — breaks on any filename containing whitespace or a
newline. **Fix:** a glob into an array, or `find -printf '%T@ %p\n' | sort -nr`.

### 8. [MINOR · CONFIRMED] No toolchain preflight
`flutter` (line 53), `dotnet` (61) and `mkarchiso` (117) are never checked. A missing
`dotnet` is discovered only after the Flutter build has already run.
**Fix:** `for c in flutter dotnet mkarchiso; do command -v "$c" >/dev/null || { echo "FATAL: $c not found" >&2; exit 1; }; done` before step 1.

### 9. [MINOR · CONFIRMED] Three full ISO copies per build
`:127-130` writes ~3x the ISO size (roughly 5.4 GB at the current 1.8 GB) every run, two
of them on the external drive. **Fix:** one real file plus symlinks.

## Nits
- `:6` — `cat FILE | tr` is a useless use of cat; use `tr ... < FILE`.
- `:15-16` — the header comment promises sudo is requested "only when mkarchiso runs",
  but `:113` runs `sudo rm -rf` first.
- version string `6.2.1` is hardcoded in 8 places; after finding 2 it should appear once.

## Scope ledger
- **Reviewed:** `build_swarm_iso_v6.2.1.sh`, all 145 lines.
- **NOT reviewed:** `build_swarm_iso_v6.2.1.sh.bak`; `swarm_os_iso_profile/`,
  `frontend/`, `LucyServer/`, `grub_themes/` — none of these were readable from this
  session, which is itself the evidence for finding 1.
- **NOT executed:** nothing was compiled, run, or built. No ISO was produced, `mkarchiso`
  was never invoked, and no fix in this document has been applied or tested.
- **Directory claims verified** on 2026-09-07 by listing `/run/media/i30ltz/LUCILLE`
  (returned: android-studio, app, bin, grub_themes, lost+found, Luccile-v+, LucyServer)
  and `/run/media/i30ltz/LUCILLE/Luccile-v+` (returned: this script and its .bak only).
