#!/usr/bin/env bash
# =============================================================================
# 🚀 deploy_swarm_os_foundation.sh
# Deploys SWARM OS system configuration layers to the target system.
# =============================================================================
set -e

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; CYN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GRN}  ✓ $1${NC}"; }
warn()  { echo -e "${YLW}  ⚠ $1${NC}"; }
banner(){ echo -e "\n${CYN}=== $1 ===${NC}\n"; }

TARGET_ROOT="${1:-/}"

banner "Deploying SWARM OS Foundation to target: $TARGET_ROOT"

if [ "$EUID" -ne 0 ] && [ "$TARGET_ROOT" = "/" ]; then
    warn "Root privileges are recommended to apply system configuration to '/'."
    echo "Running in local staging mode / user space verification."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Profile may be in 40-iso-profile (the canonical location) or alongside this script
if [ -d "$SCRIPT_DIR/../40-iso-profile/swarm_os_iso_profile/airootfs" ]; then
    AIROOTFS="$(realpath "$SCRIPT_DIR/../40-iso-profile/swarm_os_iso_profile/airootfs")"
else
    AIROOTFS="$SCRIPT_DIR/swarm_os_iso_profile/airootfs"
fi

TARGET_REAL="$(realpath -m "$TARGET_ROOT")"
AIROOTFS_REAL="$(realpath -m "$AIROOTFS")"

if [ "$TARGET_REAL" = "$AIROOTFS_REAL" ]; then
    info "Target is already airootfs profile; verifying file permissions..."
    chmod +x "$AIROOTFS/usr/bin/swarm-session" 2>/dev/null || true
    chmod +x "$AIROOTFS/usr/lib/swarm/detect-vram.sh" "$AIROOTFS/usr/lib/swarm/swarm-snapshot.sh" 2>/dev/null || true
    banner "SWARM OS Foundation verified in airootfs profile!"
    exit 0
fi

# 1. Render & Seat Management
banner "1. Deploying Render & Seat Management"
mkdir -p "$TARGET_ROOT/etc/udev/rules.d"
cp -v "$AIROOTFS/etc/udev/rules.d/99-swarm-render.rules" "$TARGET_ROOT/etc/udev/rules.d/"
mkdir -p "$TARGET_ROOT/etc/systemd/logind.conf.d"
cp -v "$AIROOTFS/etc/systemd/logind.conf.d/99-swarm-seat.conf" "$TARGET_ROOT/etc/systemd/logind.conf.d/"
mkdir -p "$TARGET_ROOT/etc/systemd/system/getty@tty1.service.d"
cp -v "$AIROOTFS/etc/systemd/system/getty@tty1.service.d/autologin.conf" "$TARGET_ROOT/etc/systemd/system/getty@tty1.service.d/"
info "Render and seat management configs staged."

# 2. Embedded Gamescope Session
banner "2. Deploying Embedded Gamescope Session"
mkdir -p "$TARGET_ROOT/usr/bin"
cp -v "$AIROOTFS/usr/bin/swarm-session" "$TARGET_ROOT/usr/bin/"
chmod +x "$TARGET_ROOT/usr/bin/swarm-session"
info "swarm-session executable deployed."

# 3. Kernel Sysctl & Storage I/O
banner "3. Deploying Kernel Sysctl & Storage I/O"
mkdir -p "$TARGET_ROOT/etc/sysctl.d"
cp -v "$AIROOTFS/etc/sysctl.d/99-swarm-performance.conf" "$TARGET_ROOT/etc/sysctl.d/"
cp -v "$AIROOTFS/etc/udev/rules.d/60-ioschedulers.rules" "$TARGET_ROOT/etc/udev/rules.d/"
mkdir -p "$TARGET_ROOT/etc/systemd"
cp -v "$AIROOTFS/etc/systemd/zram-generator.conf" "$TARGET_ROOT/etc/systemd/"
info "Performance sysctl, I/O schedulers, and zram-generator deployed."

# 4. Hardware & Recovery Scripts
banner "4. Deploying Hardware, Audio & Recovery Scripts"
mkdir -p "$TARGET_ROOT/usr/lib/swarm"
cp -v "$AIROOTFS/usr/lib/swarm/detect-vram.sh" "$TARGET_ROOT/usr/lib/swarm/"
cp -v "$AIROOTFS/usr/lib/swarm/swarm-snapshot.sh" "$TARGET_ROOT/usr/lib/swarm/"
chmod +x "$TARGET_ROOT/usr/lib/swarm/detect-vram.sh" "$TARGET_ROOT/usr/lib/swarm/swarm-snapshot.sh"

mkdir -p "$TARGET_ROOT/etc/pipewire/pipewire.conf.d"
cp -v "$AIROOTFS/etc/pipewire/pipewire.conf.d/99-swarm-lowlatency.conf" "$TARGET_ROOT/etc/pipewire/pipewire.conf.d/"

cp -v "$AIROOTFS/etc/nftables.conf" "$TARGET_ROOT/etc/"
info "VRAM detector, snapshot utility, PipeWire low-latency, and nftables firewall deployed."

banner "SWARM OS Foundation Deployment Complete!"
