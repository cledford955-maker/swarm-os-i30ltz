#!/usr/bin/env bash
# =============================================================================
# 🚀 swarm-snapshot.sh — SWARM OS Btrfs Root Snapshot & Instant Rollback Utility
# Creates pre/post build snapshots with sub-second rollback capabilities.
# =============================================================================
set -e

SNAPSHOT_DIR="/.snapshots"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

ensure_snapshot_dir() {
    if [ ! -d "$SNAPSHOT_DIR" ]; then
        mkdir -p "$SNAPSHOT_DIR"
    fi
}

is_btrfs() {
    local target="${1:-/}"
    local fstype=$(findmnt -n -o FSTYPE "$target" 2>/dev/null || echo "")
    [ "$fstype" = "btrfs" ]
}

create_snapshot() {
    local prefix="$1"
    local tag="$2"
    ensure_snapshot_dir

    if ! is_btrfs "/"; then
        echo "[swarm-snapshot] Warning: Root '/' is not a Btrfs filesystem. Skipping snapshot creation."
        return 0
    fi

    local name="${prefix}_${tag}_${TIMESTAMP}"
    local dest="${SNAPSHOT_DIR}/${name}"

    echo "[swarm-snapshot] Creating read-only Btrfs snapshot: $name..."
    btrfs subvolume snapshot -r / "$dest"
    echo "[swarm-snapshot] ✓ Snapshot created at: $dest"
}

list_snapshots() {
    ensure_snapshot_dir
    echo "======================================================================"
    echo "                 SWARM OS BTRFS SYSTEM SNAPSHOTS                      "
    echo "======================================================================"
    if is_btrfs "/"; then
        btrfs subvolume list -s / 2>/dev/null || ls -ld "$SNAPSHOT_DIR"/* 2>/dev/null || echo "No snapshots found."
    else
        ls -la "$SNAPSHOT_DIR" 2>/dev/null || echo "No snapshots directory."
    fi
}

rollback_snapshot() {
    local snap_name="$1"
    if [ -z "$snap_name" ]; then
        echo "Error: Must specify snapshot name to rollback."
        exit 1
    fi

    local snap_path="${SNAPSHOT_DIR}/${snap_name}"
    if [ ! -d "$snap_path" ]; then
        echo "Error: Snapshot '$snap_path' does not exist."
        exit 1
    fi

    echo "[swarm-snapshot] Initiating atomic rollback to '$snap_name'..."
    # 1. Create a safety backup of current state
    create_snapshot "backup" "before_rollback"

    # 2. Set default subvolume or replace active root
    local subvol_id=$(btrfs subvolume show "$snap_path" | grep "Subvolume ID:" | awk '{print $3}')
    if [ -n "$subvol_id" ]; then
        btrfs subvolume set-default "$subvol_id" /
        echo "[swarm-snapshot] ✓ Subvolume default ID updated to $subvol_id ($snap_name)."
        echo "[swarm-snapshot] ✓ Reboot required to activate rollback cleanly."
    else
        echo "[swarm-snapshot] Error: Could not determine subvolume ID for $snap_path."
        exit 1
    fi
}

delete_snapshot() {
    local snap_name="$1"
    if [ -z "$snap_name" ]; then
        echo "Error: Must specify snapshot name to delete."
        exit 1
    fi

    local snap_path="${SNAPSHOT_DIR}/${snap_name}"
    if [ -d "$snap_path" ]; then
        echo "[swarm-snapshot] Deleting subvolume snapshot '$snap_name'..."
        btrfs subvolume delete "$snap_path"
        echo "[swarm-snapshot] ✓ Snapshot deleted."
    else
        echo "Error: Snapshot '$snap_path' not found."
    fi
}

case "$1" in
    pre|create-pre)
        create_snapshot "pre" "${2:-build}"
        ;;
    post|create-post)
        create_snapshot "post" "${2:-build}"
        ;;
    list|ls)
        list_snapshots
        ;;
    rollback)
        rollback_snapshot "$2"
        ;;
    delete|rm)
        delete_snapshot "$2"
        ;;
    *)
        echo "Usage: $0 {pre <tag>|post <tag>|list|rollback <snap_name>|delete <snap_name>}"
        exit 1
        ;;
esac
