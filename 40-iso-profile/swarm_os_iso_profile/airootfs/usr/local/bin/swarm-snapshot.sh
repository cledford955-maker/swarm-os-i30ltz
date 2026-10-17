#!/usr/bin/env bash
# swarm-snapshot.sh — on-boot self-snapshot for the installed SWARM OS.
# Run by swarm-snapshot.service at every clean boot.
#
# Captures "what the system looked like when it last booted successfully."
# If a future update breaks the system, you still have the last-good snapshot
# in the GRUB menu to boot back into.
#
# Can also be called manually:  sudo swarm-snapshot.sh [label]
#
set -euo pipefail

INSTALLED_ROOT_UUID="366134c3-3986-4475-b9de-4707d582656e"
KEEP=5
LABEL="${1:-}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAP_NAME="swarm-${TIMESTAMP}${LABEL:+-$LABEL}"

# Skip gracefully on the live ISO — root UUID will differ.
ACTUAL_UUID=$(findmnt -n -o UUID / 2>/dev/null || true)
if [ "$ACTUAL_UUID" != "$INSTALLED_ROOT_UUID" ]; then
    echo "swarm-snapshot: not on installed root (UUID=$ACTUAL_UUID) — skipping."
    exit 0
fi

BTRFS_MNT=$(mktemp -d /tmp/swarm-snap-XXXXXX)
GRUB_CUSTOM="/boot/grub/custom.cfg"

cleanup() {
    mountpoint -q "$BTRFS_MNT" 2>/dev/null && umount "$BTRFS_MNT" 2>/dev/null || true
    rmdir "$BTRFS_MNT" 2>/dev/null || true
}
trap cleanup EXIT

# Mount the Btrfs root (not @) so we can create subvolumes under @snapshots/
mount -U "$INSTALLED_ROOT_UUID" -o subvol=/ "$BTRFS_MNT"

SNAP_DIR="$BTRFS_MNT/@snapshots"

# ── Snapshot ──────────────────────────────────────────────────────────────────
btrfs subvolume snapshot "$BTRFS_MNT/@" "$SNAP_DIR/$SNAP_NAME"
echo "swarm-snapshot: created $SNAP_NAME"

# ── GRUB entry ────────────────────────────────────────────────────────────────
GRUB_LABEL="${TIMESTAMP:0:4}-${TIMESTAMP:4:2}-${TIMESTAMP:6:2} ${TIMESTAMP:9:2}:${TIMESTAMP:11:2}${LABEL:+  ($LABEL)}"

if [ ! -f "$GRUB_CUSTOM" ]; then
    printf '# SWARM OS snapshot entries — managed by swarm-snapshot.sh\n\n' > "$GRUB_CUSTOM"
fi

cat >> "$GRUB_CUSTOM" <<GRUBEOF

### SWARM-SNAP-BEGIN: ${SNAP_NAME} ###
menuentry "SWARM OS — Snapshot ${GRUB_LABEL}" --class swarm --class gnu-linux {
    insmod part_gpt
    insmod btrfs
    search --no-floppy --fs-uuid --set=root ${INSTALLED_ROOT_UUID}
    linux   /@snapshots/${SNAP_NAME}/boot/vmlinuz-linux root=UUID=${INSTALLED_ROOT_UUID} rootflags=subvol=@snapshots/${SNAP_NAME} rw quiet loglevel=3 apparmor=1 security=apparmor
    initrd  /@snapshots/${SNAP_NAME}/boot/intel-ucode.img /@snapshots/${SNAP_NAME}/boot/initramfs-linux.img
}
### SWARM-SNAP-END: ${SNAP_NAME} ###
GRUBEOF

echo "swarm-snapshot: GRUB entry written → $GRUB_CUSTOM"

# ── Prune: keep newest $KEEP ──────────────────────────────────────────────────
ALL_SNAPS=()
while IFS= read -r -d '' d; do
    ALL_SNAPS+=("$d")
done < <(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'swarm-*' -print0 2>/dev/null | sort -z)

if [ "${#ALL_SNAPS[@]}" -gt "$KEEP" ]; then
    for old in "${ALL_SNAPS[@]:0:$((${#ALL_SNAPS[@]} - KEEP))}"; do
        OLD_NAME=$(basename "$old")
        btrfs subvolume delete "$old"
        sed -i "/^### SWARM-SNAP-BEGIN: ${OLD_NAME} ###\$/,/^### SWARM-SNAP-END: ${OLD_NAME} ###\$/d" "$GRUB_CUSTOM" 2>/dev/null || true
        echo "swarm-snapshot: pruned $OLD_NAME"
    done
fi

echo "swarm-snapshot: done — $(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name 'swarm-*' 2>/dev/null | wc -l) snapshot(s) active"
