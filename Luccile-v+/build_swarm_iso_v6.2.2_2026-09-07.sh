#!/usr/bin/env bash
# =============================================================================
#  build_swarm_iso — SWARM OS Live Bootable ISO build engine
#
#  Script version : 6.2.2
#  Script date    : 2026-09-07
#  Supersedes     : build_swarm_iso_v6.2.1.sh
#  Review         : REVIEW_build_swarm_iso_v6.2.1_2026-09-07_r1.0.0.md
#  Changelog      : bottom of this file
#
#  NOTE: 6.2.2 is the version of THIS SCRIPT, not of the OS. The ISO's version
#  is read from the VERSION file (or $SWARM_VERSION) so that the artifact
#  filename, the checksum, the manifest, the build banner and the running
#  system's /etc/swarm-os-release all carry the same version and build date.
#
#  Run WITHOUT sudo:  ./build_swarm_iso_v6.2.2_2026-09-07.sh
#  sudo is requested twice, both inside step 4 (clear work dir, then mkarchiso).
#
#  Environment overrides (all optional):
#    SWARM_VERSION  FLUTTER_DIR  SERVER_DIR  PROFILE_DIR  GRUB_THEME_DIR
#    ANDROID_STUDIO_DIR  VERSION_FILE  WORK_DIR  OUT_DIR  KEEP_WORK=1
# =============================================================================

set -euo pipefail

SCRIPT_VERSION="6.2.2"
SCRIPT_DATE="2026-09-07"

# ── Colors ───────────────────────────────────────────────────────────────────
CYAN=$'\033[0;36m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
RED=$'\033[0;31m';  BOLD=$'\033[1m';     NC=$'\033[0m'

step() { printf '\n%s[%s] %s%s\n' "$CYAN" "$1" "$2" "$NC"; }
ok()   { printf '  %s* %s%s\n' "$GREEN" "$1" "$NC"; }
warn() { printf '  %s! %s%s\n' "$YELLOW" "$1" "$NC"; }
die()  { printf '\n%sFATAL: %s%s\n' "$RED" "$1" "$NC" >&2; exit 1; }

# ── Guard: never run the whole script as root ────────────────────────────────
if [ "${EUID}" -eq 0 ]; then
    die "Do NOT run this script with sudo. Run as your normal user: $0
       sudo is requested only for the two commands in step 4."
fi

# ── Roots: derived from this script's own location, never hardcoded ──────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRIVE_ROOT="$(dirname -- "$SCRIPT_DIR")"

FLUTTER_DIR="${FLUTTER_DIR:-$SCRIPT_DIR/frontend}"
SERVER_DIR="${SERVER_DIR:-$DRIVE_ROOT/LucyServer}"
PROFILE_DIR="${PROFILE_DIR:-$SCRIPT_DIR/swarm_os_iso_profile}"
GRUB_THEME_DIR="${GRUB_THEME_DIR:-$DRIVE_ROOT/grub_themes/swarm_os}"
ANDROID_STUDIO_DIR="${ANDROID_STUDIO_DIR:-$DRIVE_ROOT/android-studio}"
VERSION_FILE="${VERSION_FILE:-$SCRIPT_DIR/VERSION}"
WORK_DIR="${WORK_DIR:-/tmp/swarm_os_build}"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR}"
AIROOTFS="$PROFILE_DIR/airootfs"

# ── safe_rm: refuse to delete anything outside the build tree ────────────────
safe_rm() {
    local target="${1:-}"
    [ -n "$target" ] || die "internal: safe_rm called with an empty path"
    case "$target" in
        "$AIROOTFS"/?*) : ;;
        *) die "internal: refusing to remove a path outside airootfs: $target" ;;
    esac
    rm -rf -- "$target"
}

# =============================================================================
# Step 0: Preflight — fail here, cheaply, instead of ten minutes into a build
# =============================================================================
step "0/5" "Preflight checks..."

for cmd in flutter dotnet mkarchiso git awk find sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || die "required command not found: $cmd"
done
ok "Toolchain present (flutter, dotnet, mkarchiso)."

for d in "$FLUTTER_DIR" "$SERVER_DIR" "$PROFILE_DIR"; do
    [ -d "$d" ] || die "required directory missing: $d
       Override with FLUTTER_DIR= / SERVER_DIR= / PROFILE_DIR= if the tree moved."
done
[ -d "$AIROOTFS" ] || die "ISO profile has no airootfs: $AIROOTFS"
ok "Source tree resolved under $DRIVE_ROOT"

[ -d "$GRUB_THEME_DIR" ]     || warn "GRUB theme not found, skipping: $GRUB_THEME_DIR"
[ -d "$ANDROID_STUDIO_DIR" ] || warn "Android Studio not found, skipping: $ANDROID_STUDIO_DIR"

# ── Build identity: one source of truth, and it must not be empty ────────────
BUILD_VERSION="${SWARM_VERSION:-}"
if [ -z "$BUILD_VERSION" ] && [ -r "$VERSION_FILE" ]; then
    BUILD_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
fi
[ -n "$BUILD_VERSION" ] || die "no OS version found.
       Create it once:   echo 6.2.2 > \"$VERSION_FILE\"
       Or pass it:       SWARM_VERSION=6.2.2 $0"

COMMIT="$(git -C "$SCRIPT_DIR" rev-parse --short=8 HEAD 2>/dev/null || echo nogit)"
BUILD_DATE="$(date +%Y-%m-%d)"
ISO_LABEL="swarm-os-v${BUILD_VERSION}-${BUILD_DATE}-${COMMIT}"
[ "$COMMIT" = "nogit" ] && warn "not a git checkout - commit recorded as 'nogit'"
ok "Build identity: $ISO_LABEL"

# ── Disk space: mkarchiso work dirs are large; /tmp is often a small tmpfs ───
mkdir -p -- "$(dirname -- "$WORK_DIR")"
AVAIL_GB="$(df -BG --output=avail "$(dirname -- "$WORK_DIR")" | tail -n1 | tr -dc '0-9')"
if [ -n "$AVAIL_GB" ] && [ "$AVAIL_GB" -lt 20 ]; then
    warn "only ${AVAIL_GB}G free at $(dirname -- "$WORK_DIR") - mkarchiso may fail."
    warn "Re-run with WORK_DIR=/path/on/a/bigger/disk if the build runs out of space."
fi

printf '\n%s%s======================================================================%s\n' "$CYAN" "$BOLD" "$NC"
printf '%s%s  SWARM OS :: LIVE ISO BUILD ENGINE%s\n' "$CYAN" "$BOLD" "$NC"
printf '%s%s  Building : %s%s\n' "$CYAN" "$BOLD" "$ISO_LABEL" "$NC"
printf '%s%s  Builder  : build_swarm_iso v%s (%s)%s\n' "$CYAN" "$BOLD" "$SCRIPT_VERSION" "$SCRIPT_DATE" "$NC"
printf '%s%s======================================================================%s\n' "$CYAN" "$BOLD" "$NC"

# =============================================================================
# Step 1: Flutter Linux release bundle
# =============================================================================
step "1/5" "Compiling Flutter Linux release shell..."
( cd "$FLUTTER_DIR" && flutter build linux --release )
FLUTTER_BUNDLE="$FLUTTER_DIR/build/linux/x64/release/bundle"
[ -d "$FLUTTER_BUNDLE" ] || die "Flutter bundle not produced at $FLUTTER_BUNDLE"
ok "Flutter desktop shell compiled."

# =============================================================================
# Step 2: LucyServer backend (.NET 8)
# =============================================================================
step "2/5" "Compiling LucyServer subsystem (.NET 8)..."
SERVER_PUBLISH="$SERVER_DIR/publish"
( cd "$SERVER_DIR" && dotnet publish -c Release -o "$SERVER_PUBLISH" --self-contained false )
[ -d "$SERVER_PUBLISH" ] || die "LucyServer publish output not produced at $SERVER_PUBLISH"
ok "LucyServer published."

# =============================================================================
# Step 3: Stage bundles, assets, and the build identity into airootfs
# =============================================================================
step "3/5" "Staging app bundles, assets and release identity into ISO profile..."

# 3a. Flutter app -> /opt/swarm_os/
mkdir -p -- "$AIROOTFS/opt/swarm_os"
safe_rm "$AIROOTFS/opt/swarm_os/swarm_flutter"
safe_rm "$AIROOTFS/opt/swarm_os/data"
safe_rm "$AIROOTFS/opt/swarm_os/lib"
cp -a -- "$FLUTTER_BUNDLE"/. "$AIROOTFS/opt/swarm_os/"
ok "Flutter app staged to /opt/swarm_os/"

# 3b. LucyServer -> /opt/swarm_os/LucyServer/
safe_rm "$AIROOTFS/opt/swarm_os/LucyServer"
cp -a -- "$SERVER_PUBLISH" "$AIROOTFS/opt/swarm_os/LucyServer"
ok "LucyServer staged to /opt/swarm_os/LucyServer/"

# 3c. Android Studio (optional) -> /opt/android-studio/
if [ -d "$ANDROID_STUDIO_DIR" ]; then
    safe_rm "$AIROOTFS/opt/android-studio"
    cp -a -- "$ANDROID_STUDIO_DIR" "$AIROOTFS/opt/android-studio"
    ok "Android Studio staged to /opt/android-studio/"
fi

# 3d. GRUB theme (optional) -> /boot/grub/themes/swarm_os/
if [ -d "$GRUB_THEME_DIR" ]; then
    mkdir -p -- "$AIROOTFS/boot/grub/themes/swarm_os"
    cp -a -- "$GRUB_THEME_DIR"/. "$AIROOTFS/boot/grub/themes/swarm_os/"
    ok "GRUB theme staged to /boot/grub/themes/swarm_os/"
fi

# 3e. Release identity INTO the image, so every UI surface can show the version.
#     Read this from the greeter, the About box and the Flutter shell instead of
#     hardcoding a version string anywhere in the UI.
mkdir -p -- "$AIROOTFS/etc"
cat > "$AIROOTFS/etc/swarm-os-release" <<EOF
NAME="SWARM OS"
PRETTY_NAME="SWARM OS v${BUILD_VERSION}"
VERSION="${BUILD_VERSION}"
VERSION_ID="${BUILD_VERSION}"
BUILD_ID="${BUILD_DATE}-${COMMIT}"
SWARM_ISO_LABEL="${ISO_LABEL}"
SWARM_BUILD_DATE="${BUILD_DATE}"
SWARM_COMMIT="${COMMIT}"
SWARM_BUILDER_VERSION="${SCRIPT_VERSION}"
EOF
ok "Release identity written to /etc/swarm-os-release"

# =============================================================================
# Step 4: Build the ISO with mkarchiso (sudo required for these two commands)
# =============================================================================
step "4/5" "Building bootable ISO with mkarchiso (sudo required)..."
echo "  Work directory:   $WORK_DIR"
echo "  Output directory: $OUT_DIR"

case "$WORK_DIR" in
    /|/root|/home|"$HOME") die "refusing to clear an unsafe work directory: $WORK_DIR" ;;
esac
sudo rm -rf -- "$WORK_DIR"
mkdir -p -- "$WORK_DIR" "$OUT_DIR"

# Marker: anything newer than this is output from THIS run. No name guessing.
MARKER="$(mktemp)"
trap 'rm -f -- "$MARKER"' EXIT

sudo SYSTEMD_LOG_LEVEL=err mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

# =============================================================================
# Step 5: Name, checksum and record the artifact
# =============================================================================
step "5/5" "Finalizing release artifacts..."

mapfile -t NEW_ISOS < <(
    find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -newer "$MARKER" \
        -printf '%T@\t%p\n' | sort -rn | cut -f2-
)
[ "${#NEW_ISOS[@]}" -gt 0 ] || die "mkarchiso reported success but produced no .iso in $OUT_DIR"
[ "${#NEW_ISOS[@]}" -eq 1 ] || warn "${#NEW_ISOS[@]} new ISOs found; taking the newest."

BUILT_ISO="${NEW_ISOS[0]}"
FINAL_ISO="$OUT_DIR/${ISO_LABEL}.iso"

# Move, never copy: one artifact per build, no silent overwrite of another version.
[ "$BUILT_ISO" = "$FINAL_ISO" ] || mv -f -- "$BUILT_ISO" "$FINAL_ISO"

( cd "$OUT_DIR" && sha256sum "${ISO_LABEL}.iso" > "${ISO_LABEL}.iso.sha256" )
ln -sfn -- "${ISO_LABEL}.iso" "$OUT_DIR/swarm-os-latest.iso"

ISO_SIZE="$(du -h -- "$FINAL_ISO" | cut -f1)"
cat > "$OUT_DIR/${ISO_LABEL}.manifest.txt" <<EOF
SWARM OS build manifest
iso            : ${ISO_LABEL}.iso
version        : ${BUILD_VERSION}
build_date     : ${BUILD_DATE}
commit         : ${COMMIT}
size           : ${ISO_SIZE}
sha256_file    : ${ISO_LABEL}.iso.sha256
built_by       : build_swarm_iso v${SCRIPT_VERSION} (${SCRIPT_DATE})
profile        : ${PROFILE_DIR}
host           : $(uname -srm)
EOF

if [ -d "$HOME/Desktop" ]; then
    ln -sfn -- "$FINAL_ISO" "$HOME/Desktop/swarm-os-latest.iso"
    ok "Desktop link: $HOME/Desktop/swarm-os-latest.iso"
else
    warn "no $HOME/Desktop - skipped desktop link."
fi

if [ "${KEEP_WORK:-0}" != "1" ]; then
    sudo rm -rf -- "$WORK_DIR"
    ok "Work directory cleared (KEEP_WORK=1 to retain it)."
fi

printf '\n%s%s======================================================================%s\n' "$CYAN" "$BOLD" "$NC"
printf '%s%s  BUILD COMPLETE: %s%s\n' "$GREEN" "$BOLD" "$ISO_LABEL" "$NC"
printf '%s%s======================================================================%s\n' "$CYAN" "$BOLD" "$NC"
printf '  ISO       : %s%s%s (%s)\n' "$BOLD" "$FINAL_ISO" "$NC" "$ISO_SIZE"
printf '  Checksum  : %s%s.iso.sha256%s\n' "$BOLD" "$ISO_LABEL" "$NC"
printf '  Manifest  : %s%s.manifest.txt%s\n' "$BOLD" "$ISO_LABEL" "$NC"
printf '  Stable    : %s%s/swarm-os-latest.iso%s -> this build\n' "$BOLD" "$OUT_DIR" "$NC"
printf '\n%s%sTo flash to USB - CONFIRM THE TARGET DEVICE FIRST:%s\n' "$YELLOW" "$BOLD" "$NC"
printf '  lsblk -o NAME,SIZE,MODEL,TRAN     # find the USB, NOT your system disk\n'
printf '  sudo dd bs=4M if=%s of=/dev/sdX status=progress oflag=sync\n\n' "$FINAL_ISO"

# =============================================================================
# CHANGELOG
# -----------------------------------------------------------------------------
# 6.2.2  2026-09-07
#   - Roots derived from ${BASH_SOURCE[0]}; every path env-overridable.
#     (was: three conflicting hardcoded roots, none of which resolved)
#   - Step 0 preflight: required commands, required directories, work-dir space.
#   - OS version read from VERSION/$SWARM_VERSION and required to be non-empty.
#   - ISO_LABEL is now actually used: names the artifact, the checksum, the
#     manifest, the build banner and /etc/swarm-os-release.
#   - /etc/swarm-os-release staged into the image so UI surfaces read the
#     version instead of hardcoding it.
#   - Output located by mtime marker, not by a hardcoded version glob.
#   - One artifact per build (mv, not cp). No more overwriting swarm-os-v6.2.iso
#     with v6.2.1 content; no more three full-size copies per run.
#   - sha256 + manifest emitted alongside the ISO.
#   - set -euo pipefail; safe_rm guards; $HOME instead of /home/i30ltz.
#   - Desktop entry is a symlink, and its failure is reported, not swallowed.
#   - dd instructions now tell you to identify the device first.
# 6.2.1  (previous) see build_swarm_iso_v6.2.1.sh
# =============================================================================
