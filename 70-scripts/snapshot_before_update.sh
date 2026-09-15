#!/usr/bin/env bash
# snapshot_before_update.sh — take a Btrfs snapshot of the installed SWARM OS root
# before applying any update, so you can boot back if the update breaks something.
#
# Usage:
#   sudo 70-scripts/snapshot_before_update.sh [label]
#
# What it does:
#   1. Mounts nvme0n1p2 at its Btrfs root (no subvol) if not already.
#   2. Snapshots @ → @snapshots/swarm-YYYYMMDD-HHMMSS[-label]
#   3. Writes a GRUB entry for it into @/boot/grub/custom.cfg
#      (GRUB auto-sources this file — no grub-mkconfig needed).
#   4. Keeps the 5 newest snapshots; removes older ones + their GRUB entries.
#   5. Unmounts the scratch mount if this script created it.
#
# Run this BEFORE: deploying a new Flutter bundle, new Go binaries, system
# package upgrades, or any change to the installed system that you want to
# be able to undo at the boot menu.
#
# Rollback: reboot → GRUB menu → "SWARM OS Snapshot — YYYY-MM-DD HH:MM"
#
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run this script with sudo.${NC}"
    exit 1
fi

# ── Config ────────────────────────────────────────────────────────────────────
ROOT_DEV="/dev/nvme0n1p2"
ROOT_UUID="366134c3-3986-4475-b9de-4707d582656e"
BTRFS_MNT="/mnt/swarm_btrfs_top"    # scratch mount — Btrfs root, no subvol
KEEP=5                               # how many snapshots to keep

LABEL="${1:-}"                       # optional human label, e.g. "pre-flutter-update"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAP_NAME="swarm-${TIMESTAMP}${LABEL:+-$LABEL}"

echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}  📸 SWARM OS — Pre-Update Snapshot${NC}"
echo -e "  Snapshot: ${GREEN}${SNAP_NAME}${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ── 1. Mount Btrfs root ───────────────────────────────────────────────────────
MOUNTED_HERE=0
if ! mountpoint -q "$BTRFS_MNT" 2>/dev/null; then
    mkdir -p "$BTRFS_MNT"
    mount "$ROOT_DEV" -o subvol=/ "$BTRFS_MNT"
    MOUNTED_HERE=1
    echo -e "  ${GREEN}✓ mounted${NC} $ROOT_DEV (btrfs root) → $BTRFS_MNT"
else
    echo -e "  ${GREEN}✓ already mounted${NC} $BTRFS_MNT"
fi

SNAP_DIR="$BTRFS_MNT/@snapshots"
GRUB_CUSTOM="$BTRFS_MNT/@/boot/grub/custom.cfg"

# ── 2. Take snapshot ──────────────────────────────────────────────────────────
echo -e "  Taking snapshot @ → @snapshots/${SNAP_NAME} ..."
btrfs subvolume snapshot "$BTRFS_MNT/@" "$SNAP_DIR/$SNAP_NAME"
echo -e "  ${GREEN}✓ snapshot created:${NC} $SNAP_NAME"

# ── 3. Write GRUB entry for this snapshot ─────────────────────────────────────
GRUB_LABEL="${TIMESTAMP:0:4}-${TIMESTAMP:4:2}-${TIMESTAMP:6:2} ${TIMESTAMP:9:2}:${TIMESTAMP:11:2}${LABEL:+  ($LABEL)}"

# Entry block — delimited by marker comments so we can remove stale ones later
ENTRY=$(cat <<GRUBEOF
### SWARM-SNAP-BEGIN: ${SNAP_NAME} ###
menuentry "SWARM OS — Snapshot ${GRUB_LABEL}" --class swarm --class gnu-linux {
    insmod part_gpt
    insmod btrfs
    search --no-floppy --fs-uuid --set=root ${ROOT_UUID}
    linux   /@snapshots/${SNAP_NAME}/boot/vmlinuz-linux root=UUID=${ROOT_UUID} rootflags=subvol=@snapshots/${SNAP_NAME} rw quiet loglevel=3 apparmor=1 security=apparmor
    initrd  /@snapshots/${SNAP_NAME}/boot/intel-ucode.img /@snapshots/${SNAP_NAME}/boot/initramfs-linux.img
}
### SWARM-SNAP-END: ${SNAP_NAME} ###
GRUBEOF
)

# Ensure custom.cfg exists with a header comment
if [ ! -f "$GRUB_CUSTOM" ]; then
    printf '# SWARM OS snapshot boot entries — auto-managed by snapshot_before_update.sh\n# Do not hand-edit; entries are added/removed automatically.\n\n' > "$GRUB_CUSTOM"
fi

printf '\n%s\n' "$ENTRY" >> "$GRUB_CUSTOM"
echo -e "  ${GREEN}✓ GRUB entry written${NC} → /boot/grub/custom.cfg"

# ── 4. Prune: keep only newest $KEEP snapshots ────────────────────────────────
ALL_SNAPS=()
while IFS= read -r -d '' d; do
    ALL_SNAPS+=("$d")
done < <(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'swarm-*' -print0 2>/dev/null | sort -z)
# sort -z gives lexicographic order; because names start YYYYMMDD-HHMMSS this is chronological

if [ "${#ALL_SNAPS[@]}" -gt "$KEEP" ]; then
    TO_DELETE=("${ALL_SNAPS[@]:0:$((${#ALL_SNAPS[@]} - KEEP))}")
    echo -e "  ${YELLOW}Pruning ${#TO_DELETE[@]} old snapshot(s) beyond the newest $KEEP:${NC}"
    for old in "${TO_DELETE[@]}"; do
        OLD_NAME=$(basename "$old")
        echo -e "    ${RED}✗ deleting${NC} $OLD_NAME"
        btrfs subvolume delete "$old"

        # Remove its GRUB entry from custom.cfg
        if [ -f "$GRUB_CUSTOM" ]; then
            sed -i "/^### SWARM-SNAP-BEGIN: ${OLD_NAME} ###\$/,/^### SWARM-SNAP-END: ${OLD_NAME} ###\$/d" "$GRUB_CUSTOM"
        fi
    done
fi

echo -e "  ${GREEN}✓ keeping $(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'swarm-*' 2>/dev/null | wc -l) snapshot(s)${NC}"

# ── 5. Unmount if we mounted it ───────────────────────────────────────────────
if [ "$MOUNTED_HERE" = "1" ]; then
    umount "$BTRFS_MNT"
    echo -e "  ${GREEN}✓ unmounted${NC} $BTRFS_MNT"
fi

echo -e "\n${GREEN}${BOLD}Done.${NC} To roll back: reboot → GRUB → \"SWARM OS — Snapshot ${GRUB_LABEL}\"\n"
