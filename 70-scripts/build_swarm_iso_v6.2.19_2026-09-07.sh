#!/usr/bin/env bash
# =============================================================================
#  build_swarm_iso  —  SWARM OS live bootable ISO build engine
#  Script version : 2.0.0            Date: 2026-09-07
#  Supersedes     : build_swarm_iso_v6.2.1.sh (2026-08-31)
#
#  Addresses all 9 findings in
#  90-docs/REVIEW_build_swarm_iso_v6.2.1_2026-09-07_r1.0.0.md
#
#  Run WITHOUT sudo.  Sudo is requested at step 4 (mkarchiso) and for the
#  work-directory cleanup that immediately precedes it.
# =============================================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m';  BOLD='\033[1m';   NC='\033[0m'

die() { echo -e "${RED}FATAL: $*${NC}" >&2; exit 1; }

[ "${EUID}" -eq 0 ] && die "do not run this script with sudo; run it as your normal user"

# ── Roots: derived from this script's own location (finding 1) ───────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DRIVE_ROOT="$(dirname "$SCRIPT_DIR")"

FLUTTER_DIR="${FLUTTER_DIR:-$DRIVE_ROOT/30-source/frontend}"
SERVER_DIR="${SERVER_DIR:-$DRIVE_ROOT/30-source/LucyServer}"
PROFILE_DIR="${PROFILE_DIR:-$DRIVE_ROOT/40-iso-profile}"
GRUB_THEME_DIR="${GRUB_THEME_DIR:-$DRIVE_ROOT/50-boot/grub_themes/swarm_os}"
ANDROID_STUDIO_DIR="${ANDROID_STUDIO_DIR:-$DRIVE_ROOT/20-runtime/android-studio}"
VERSION_FILE="${VERSION_FILE:-$DRIVE_ROOT/VERSION}"
AIROOTFS="$PROFILE_DIR/airootfs"

WORK_DIR="${WORK_DIR:-/tmp/swarm_os_build.$$}"
PUBLISH_DIR="$WORK_DIR/lucyserver-publish"   # out-of-tree: no publish/publish/ nesting

# ── Toolchain preflight (finding 8) ─────────────────────────────────────────
for c in flutter dotnet mkarchiso git; do
  command -v "$c" >/dev/null 2>&1 || die "required tool not found on PATH: $c"
done

# ── Required inputs must exist BEFORE anything is built (finding 1) ─────────
for d in "$FLUTTER_DIR" "$SERVER_DIR" "$PROFILE_DIR"; do
  [ -d "$d" ] || die "missing required directory: $d"
done
[ -f "$VERSION_FILE" ] || die "missing version file: $VERSION_FILE"

# ── Build identity: computed once, and actually USED (finding 2) ────────────
BUILD_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
[ -n "$BUILD_VERSION" ] || die "no version string in $VERSION_FILE"
COMMIT="$(git -C "$DRIVE_ROOT" rev-parse --short=8 HEAD 2>/dev/null || echo nogit)"
BUILD_DATE="$(date +%Y-%m-%d)"
ISO_LABEL="swarm-os-v${BUILD_VERSION}_${BUILD_DATE}_${COMMIT}"

OUT_DIR="${OUT_DIR:-$DRIVE_ROOT/10-releases/$ISO_LABEL}"
RELEASES_DIR="$DRIVE_ROOT/10-releases"
CURRENT_DIR="$DRIVE_ROOT/00-CURRENT"

echo -e "\n${CYAN}${BOLD}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  SWARM OS :: LIVE ISO BUILD ENGINE${NC}"
echo -e "${CYAN}${BOLD}  ${ISO_LABEL}${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "  drive root : $DRIVE_ROOT"
echo -e "  profile    : $PROFILE_DIR"
echo -e "  output     : $OUT_DIR\n"

BUILD_START="$(date +%s)"

# ── Step 1: Flutter Linux release bundle ────────────────────────────────────
echo -e "${CYAN}[1/5] Compiling Flutter Linux release shell...${NC}"
( cd "$FLUTTER_DIR" && flutter build linux --release )
FLUTTER_BUNDLE="$FLUTTER_DIR/build/linux/x64/release/bundle"
[ -d "$FLUTTER_BUNDLE" ] || die "flutter bundle not produced at $FLUTTER_BUNDLE"
echo -e "  ${GREEN}OK${NC} Flutter shell compiled."

# ── Step 2: LucyServer (published out-of-tree) ──────────────────────────────
echo -e "\n${CYAN}[2/5] Publishing LucyServer...${NC}"
mkdir -p "$PUBLISH_DIR"
( cd "$SERVER_DIR" && dotnet publish -c Release -o "$PUBLISH_DIR" --self-contained false )
[ -f "$PUBLISH_DIR/LucyServer.dll" ] || die "LucyServer.dll not found in $PUBLISH_DIR"
echo -e "  ${GREEN}OK${NC} LucyServer published to $PUBLISH_DIR"

# ── Step 3: Stage into airootfs ─────────────────────────────────────────────
echo -e "\n${CYAN}[3/5] Staging payload into ISO profile...${NC}"
mkdir -p "$AIROOTFS/opt/swarm_os"
rm -rf "${AIROOTFS:?}/opt/swarm_os/swarm_flutter" \
       "${AIROOTFS:?}/opt/swarm_os/data" \
       "${AIROOTFS:?}/opt/swarm_os/lib" \
       "${AIROOTFS:?}/opt/swarm_os/LucyServer"
cp -a "$FLUTTER_BUNDLE/." "$AIROOTFS/opt/swarm_os/"
echo -e "  ${GREEN}OK${NC} Flutter app -> /opt/swarm_os/"
cp -a "$PUBLISH_DIR" "$AIROOTFS/opt/swarm_os/LucyServer"
echo -e "  ${GREEN}OK${NC} LucyServer -> /opt/swarm_os/LucyServer/"

if [ -d "$ANDROID_STUDIO_DIR" ] && [ -n "$(ls -A "$ANDROID_STUDIO_DIR" 2>/dev/null)" ]; then
  rm -rf "${AIROOTFS:?}/opt/android-studio"
  cp -a "$ANDROID_STUDIO_DIR" "$AIROOTFS/opt/android-studio"
  echo -e "  ${GREEN}OK${NC} Android Studio -> /opt/android-studio/"
else
  echo -e "  ${YELLOW}SKIP${NC} Android Studio not staged (dir absent or empty: $ANDROID_STUDIO_DIR)"
fi

if [ -d "$GRUB_THEME_DIR" ]; then
  mkdir -p "$AIROOTFS/boot/grub/themes/swarm_os"
  cp -r "$GRUB_THEME_DIR/." "$AIROOTFS/boot/grub/themes/swarm_os/"
  echo -e "  ${GREEN}OK${NC} GRUB theme -> /boot/grub/themes/swarm_os/"
else
  echo -e "  ${YELLOW}SKIP${NC} GRUB theme not found at $GRUB_THEME_DIR"
fi

# ── Step 4: mkarchiso ───────────────────────────────────────────────────────
echo -e "\n${CYAN}[4/5] Building bootable ISO with mkarchiso (sudo required)...${NC}"
mkdir -p "$OUT_DIR"
sudo rm -rf "${WORK_DIR:?}/archiso"
mkdir -p "$WORK_DIR/archiso"
sudo SYSTEMD_LOG_LEVEL=err mkarchiso -v -w "$WORK_DIR/archiso" -o "$OUT_DIR" "$PROFILE_DIR"

# ── Step 5: Name, checksum, and publish the artifact ────────────────────────
echo -e "\n${CYAN}[5/5] Finalizing release...${NC}"

# Newest .iso in OUT_DIR, produced by THIS run (findings 4 + 7: no ls parsing,
# no hardcoded version glob, must be newer than the start of the build)
BUILT_ISO="$(find "$OUT_DIR" -maxdepth 1 -type f -name '*.iso' -newermt "@$BUILD_START" \
             -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)"
[ -n "$BUILT_ISO" ] || die "mkarchiso reported success but no new .iso appeared in $OUT_DIR"

FINAL_ISO="$OUT_DIR/${ISO_LABEL}.iso"
[ "$BUILT_ISO" = "$FINAL_ISO" ] || mv -f "$BUILT_ISO" "$FINAL_ISO"

echo -e "  computing sha256..."
( cd "$OUT_DIR" && sha256sum "${ISO_LABEL}.iso" > "${ISO_LABEL}.iso.sha256" )

# Stable pointers -- symlinks, never extra copies (findings 3 + 9)
ln -sfn "$ISO_LABEL/${ISO_LABEL}.iso" "$RELEASES_DIR/swarm-os-latest.iso"
mkdir -p "$CURRENT_DIR"
ln -sfn "../10-releases/$ISO_LABEL/${ISO_LABEL}.iso" "$CURRENT_DIR/swarm-os-CURRENT.iso"

# Build record
cat > "$OUT_DIR/BUILD-INFO.txt" <<INFO
label      : $ISO_LABEL
version    : $BUILD_VERSION
date       : $BUILD_DATE
commit     : $COMMIT
built_by   : ${USER:-unknown}@$(hostname)
built_at   : $(date -Iseconds)
profile    : $PROFILE_DIR
duration_s : $(( $(date +%s) - BUILD_START ))
INFO

ISO_SIZE="$(du -h "$FINAL_ISO" | cut -f1)"
echo -e "\n${CYAN}${BOLD}======================================================================${NC}"
echo -e "${GREEN}${BOLD}  BUILD SUCCESSFUL — ${ISO_LABEL}${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"
echo -e "  ISO      : ${BOLD}$FINAL_ISO${NC} ($ISO_SIZE)"
echo -e "  sha256   : ${BOLD}$FINAL_ISO.sha256${NC}"
echo -e "  latest   : ${BOLD}$RELEASES_DIR/swarm-os-latest.iso${NC} -> $ISO_LABEL"
echo -e "  current  : ${BOLD}$CURRENT_DIR/swarm-os-CURRENT.iso${NC}"
echo -e "\n${YELLOW}${BOLD}Flash to USB:${NC}"
echo -e "  ${BOLD}sudo dd bs=4M if=$FINAL_ISO of=/dev/sdX status=progress oflag=sync${NC}\n"

rm -rf "${WORK_DIR:?}"
