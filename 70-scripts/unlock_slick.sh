#!/usr/bin/env bash
set -euo pipefail

# unlock_slick.sh — unlock and mount the Slick encrypted vault (nvme0n1p6)
#
# Slick holds uncensored memory accessible only through /lucy/unfiltered.
# Run this as root (or via sudo) when you want to activate uncensored mode.
# After mounting, LucyServer's /lucy/unfiltered endpoint becomes available.

LUKS_UUID="019a3cd8-46c5-4a19-a760-8e0c1096b248"
MAPPER_NAME="luks-${LUKS_UUID}"
MOUNT_POINT="/mnt/slick"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo $0"
    exit 1
fi

mkdir -p "$MOUNT_POINT"

if mountpoint -q "$MOUNT_POINT"; then
    echo "Slick already mounted at $MOUNT_POINT"
    exit 0
fi

if [ ! -b "/dev/mapper/$MAPPER_NAME" ]; then
    echo "Unlocking /dev/nvme0n1p6 (enter passphrase)..."
    cryptsetup open UUID="$LUKS_UUID" "$MAPPER_NAME"
fi

mount "/dev/mapper/$MAPPER_NAME" "$MOUNT_POINT"
# Only swarm user can read the vault contents
chown swarm:swarm "$MOUNT_POINT" 2>/dev/null || true
chmod 700 "$MOUNT_POINT" 2>/dev/null || true

echo "Slick mounted at $MOUNT_POINT — /lucy/unfiltered is now active"
