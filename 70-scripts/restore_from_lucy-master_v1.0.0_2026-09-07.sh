#!/usr/bin/env bash
# =============================================================================
#  restore_from_lucy-master  —  repopulate LUCILLE from the encrypted master
#  Script version : 1.0.0            Date: 2026-09-07
#
#  LUCILLE currently holds the RUNTIME payload only. Source, the archiso
#  profile and the built ISOs live on the LUKS drive "lucy-master" (and are
#  mirrored in Google Drive). This script copies them into the new layout.
#
#  Run as your normal user. Sudo is needed only to unlock/mount.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEST="$(dirname "$SCRIPT_DIR")"

LUKS_UUID="a24202ce-4d76-4eb7-8923-8e8ddbacdaa7"
MAPPER="luks-${LUKS_UUID}"
SRC_MOUNT="/mnt/lucy"
SRC="$SRC_MOUNT/Luccile-v+"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
die() { echo -e "${RED}FATAL: $*${NC}" >&2; exit 1; }

echo -e "${CYAN}${BOLD}=== Restore LUCILLE from lucy-master ===${NC}"
echo -e "  source : $SRC"
echo -e "  dest   : $DEST\n"

# ── 1. Unlock ───────────────────────────────────────────────────────────────
if [ ! -e "/dev/mapper/$MAPPER" ]; then
  echo -e "${YELLOW}==> LUKS volume is locked. Unlocking (passphrase required)...${NC}"
  sudo cryptsetup open "/dev/disk/by-uuid/$LUKS_UUID" "$MAPPER" \
    || die "could not unlock. Is the drive attached? Check: lsblk -f | grep -i crypt"
else
  echo -e "${GREEN}==> LUKS mapper already open.${NC}"
fi

# ── 2. Mount ────────────────────────────────────────────────────────────────
if ! mountpoint -q "$SRC_MOUNT"; then
  echo -e "${CYAN}==> Mounting $SRC_MOUNT ...${NC}"
  sudo mkdir -p "$SRC_MOUNT"
  sudo mount "/dev/mapper/$MAPPER" "$SRC_MOUNT" || die "mount failed"
else
  echo -e "${GREEN}==> $SRC_MOUNT already mounted.${NC}"
fi
[ -d "$SRC" ] || die "expected project at $SRC — got: $(ls "$SRC_MOUNT" 2>/dev/null | tr '\n' ' ')"

# ── 3. Copy into the layout ─────────────────────────────────────────────────
copy() {  # copy <relative-src> <abs-dest> <description>
  local s="$SRC/$1" d="$2"
  if [ -e "$s" ]; then
    mkdir -p "$(dirname "$d")"
    echo -e "${CYAN}  copying${NC} $1 -> ${d#$DEST/}"
    rsync -a --info=progress2 --human-readable "$s/" "$d/" 2>/dev/null \
      || cp -a "$s" "$d"
  else
    echo -e "${YELLOW}  skip${NC}    $1 (not present on master)"
  fi
}

echo -e "\n${CYAN}==> Source trees${NC}"
copy frontend          "$DEST/30-source/frontend"
copy lucille-core      "$DEST/30-source/lucille-core"
copy LucyServer        "$DEST/30-source/LucyServer"
copy LucyServer.Tests  "$DEST/30-source/LucyServer.Tests"
copy android_companion "$DEST/30-source/android_companion"
copy coder_marketplace "$DEST/30-source/coder_marketplace"

echo -e "\n${CYAN}==> ISO profile${NC}"
copy swarm_os_iso_profile "$DEST/40-iso-profile"

echo -e "\n${CYAN}==> VM tooling${NC}"
for f in OVMF_VARS.fd swarm_ovmf_vars.fd swarm_vm_disk.qcow2; do
  [ -f "$SRC/$f" ] && { mkdir -p "$DEST/80-vm"; cp -a "$SRC/$f" "$DEST/80-vm/"; echo "  copied $f"; }
done

echo -e "\n${CYAN}==> Docs${NC}"
for f in llcy_memory.md ZERO_MOCK_TESTING_GUIDE.md remaining_port_tasks.md SYNC-OPTIONS.md; do
  [ -f "$SRC/$f" ] && { cp -a "$SRC/$f" "$DEST/90-docs/"; echo "  copied $f"; }
done

# Historical ISOs stay on the read-only reference drive. This restore script
# never imports releases. Only Ventoy may hold active SWARM ISO artifacts.
echo 'ISO restore skipped: use /mnt/ventoy/ISO/SWARM_OS for active releases.'

echo -e "\n${GREEN}${BOLD}=== Restore complete ===${NC}"
du -sh "$DEST"/[0-9]* 2>/dev/null
