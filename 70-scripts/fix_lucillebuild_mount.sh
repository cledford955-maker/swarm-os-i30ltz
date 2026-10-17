#!/usr/bin/env bash

# fix_lucillebuild_mount.sh
# Ensure /mnt/lucillebuild is mounted and /mnt/lucilleassistant is a bind mount to it.
# This script is safe to run repeatedly; it only performs actions when needed.

set -euo pipefail

MOUNT_POINT_BUILD="/mnt/lucillebuild"
MOUNT_POINT_ASSISTANT="/mnt/lucilleassistant"
LABEL_BUILD="lucillebuild"
LOG_FILE="/tmp/fix_lucillebuild_mount.log"

log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

# Helper: check if a mount point is already mounted
is_mounted() {
  mountpoint -q "$1"
}

# 1. Mount the lucillebuild partition if not already mounted
if ! is_mounted "$MOUNT_POINT_BUILD"; then
  log "Mount point $MOUNT_POINT_BUILD is not mounted. Attempting to mount by label $LABEL_BUILD."
  # Try to mount by label; fallback to UUID detection via blkid
  if ! mount -L "$LABEL_BUILD" "$MOUNT_POINT_BUILD" 2>/dev/null; then
    log "Label $LABEL_BUILD not found. Trying UUID detection."
    UUID=$(blkid -L "$LABEL_BUILD" || true)
    if [ -z "$UUID" ]; then
      log "ERROR: Could not find partition with label $LABEL_BUILD. Exiting."
      exit 1
    fi
    mount "UUID=$UUID" "$MOUNT_POINT_BUILD"
    log "Mounted partition $UUID on $MOUNT_POINT_BUILD."
  else
    log "Mounted $LABEL_BUILD on $MOUNT_POINT_BUILD via label."
  fi
else
  log "Mount point $MOUNT_POINT_BUILD already mounted."
fi

# 2. Ensure the assistant mount is a bind to the build mount
if is_mounted "$MOUNT_POINT_ASSISTANT"; then
  # Verify it points to the same source
  src=$(findmnt -n -o SOURCE "$MOUNT_POINT_ASSISTANT")
  if [ "$src" != "$MOUNT_POINT_BUILD" ]; then
    log "$MOUNT_POINT_ASSISTANT is mounted to $src, expected bind to $MOUNT_POINT_BUILD. Rebinding."
    umount "$MOUNT_POINT_ASSISTANT"
    mount --bind "$MOUNT_POINT_BUILD" "$MOUNT_POINT_ASSISTANT"
    log "Rebound $MOUNT_POINT_ASSISTANT to $MOUNT_POINT_BUILD."
  else
    log "Bind mount $MOUNT_POINT_ASSISTANT already points to $MOUNT_POINT_BUILD."
  fi
else
  log "$MOUNT_POINT_ASSISTANT not mounted. Creating bind mount."
  mount --bind "$MOUNT_POINT_BUILD" "$MOUNT_POINT_ASSISTANT"
  log "Bind mounted $MOUNT_POINT_ASSISTANT to $MOUNT_POINT_BUILD."
fi

# 3. Optional: sync git repo from lucillebuild back to swarm build if needed
#    This respects user warning: do NOT overwrite without explicit consent.
#    The script only echoes a reminder.
log "Mount configuration completed. If you need to sync the swarm repo from lucillebuild, run 'auto_sync_github.sh' manually."

exit 0
