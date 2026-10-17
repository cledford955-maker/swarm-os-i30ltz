#!/usr/bin/env bash
# fix_installed_swarm_services.sh — Patch systemd services on installed SWARM root
# (/mnt/swarm/@/etc/systemd/system/) so that all daemons run under the real user
# 'i30ltz' instead of the non-existent 'swarm' user.
#
# Fixes: SW-20, SW-29 (lucille-core.service User=swarm failure)
set -euo pipefail

TARGET_DIR="/mnt/swarm/@/etc/systemd/system"

if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: $TARGET_DIR does not exist. Ensure /dev/nvme0n1p2 is mounted at /mnt/swarm." >&2
    exit 1
fi

echo "Patching systemd services in $TARGET_DIR from User=swarm -> User=i30ltz..."

PATCHED=0
for svc in "$TARGET_DIR"/*.service; do
    if [ -f "$svc" ] && grep -q 'User=swarm' "$svc"; then
        sed -i 's/^User=swarm$/User=i30ltz/' "$svc"
        sed -i 's/^Group=swarm$/Group=i30ltz/' "$svc"
        sed -i 's|swarm:swarm|i30ltz:i30ltz|g' "$svc"
        echo "  ✓ Patched $(basename "$svc")"
        PATCHED=$((PATCHED + 1))
    fi
done

echo "Done. $PATCHED service(s) patched to User=i30ltz."
