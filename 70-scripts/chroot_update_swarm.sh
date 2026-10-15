#!/usr/bin/env bash
# chroot_update_swarm.sh — chroot into the installed SWARM OS and run a full
# system update (pacman -Syu), install the USB master key CLI, fix ownership,
# and verify services.
#
# Usage:  sudo ./70-scripts/chroot_update_swarm.sh
#
# Requires: arch-install-scripts (provides arch-chroot), sudo/root.
# The target is /dev/nvme0n1p2 (label swarm-root), mounted at /mnt/swarm.
# Root subvolume: /mnt/swarm/@
set -euo pipefail

die()  { echo "REFUSED: $*" >&2; exit 1; }
say()  { echo "  $*"; }
warn() { echo "  [WARN] $*" >&2; }

# ── must be root ─────────────────────────────────────────────────────────────
[ "$(id -u)" = 0 ] || die "must be run as root (sudo $0)"

# ── verify target ────────────────────────────────────────────────────────────
ROOT_DEV=/dev/nvme0n1p2
[ -b "$ROOT_DEV" ] || die "$ROOT_DEV does not exist"
LABEL=$(lsblk -no LABEL "$ROOT_DEV" | head -n1)
[ "$LABEL" = "swarm-root" ] || die "$ROOT_DEV label is '$LABEL', expected 'swarm-root'"

# find mount point
TOP=$(findmnt -rn -S "$ROOT_DEV" -o TARGET | head -n1 || true)
[ -n "$TOP" ] || die "$ROOT_DEV is not mounted"

R="$TOP/@"
[ -d "$R/opt/swarm_os" ] || die "$R does not look like a SWARM OS root"

# must NOT be the running root
RUNNING_ROOT=$(findmnt -no SOURCE / | sed 's/\[.*//')
[ "$RUNNING_ROOT" != "$ROOT_DEV" ] || die "$ROOT_DEV is the running root; run from another OS"

say "target root: $R"
say "version: $(cat "$R/etc/swarm-release" 2>/dev/null || echo 'unknown')"
echo ""

# ── DNS for pacman inside chroot ─────────────────────────────────────────────
# arch-chroot binds /etc/resolv.conf, but SWARM's is a dangling symlink to
# systemd-resolved (not running outside the chroot). Write a temporary one.
RESOLV_BAK=""
if [ -L "$R/etc/resolv.conf" ] || [ ! -s "$R/etc/resolv.conf" ]; then
    say "setting up DNS for chroot..."
    if [ -L "$R/etc/resolv.conf" ]; then
        RESOLV_BAK=$(readlink "$R/etc/resolv.conf")
        rm -f "$R/etc/resolv.conf"
    fi
    # use the host's nameservers, or fall back to well-known public DNS
    if [ -f /etc/resolv.conf ] && grep -q '^nameserver' /etc/resolv.conf; then
        grep '^nameserver' /etc/resolv.conf > "$R/etc/resolv.conf"
    else
        printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$R/etc/resolv.conf"
    fi
fi

# ── make the chroot root a real mountpoint ───────────────────────────────────
# pacman resolves the filesystem of its cache dir via mountinfo; if $R is just a
# directory it fails with "could not determine cachedir mount point" and then
# "not enough free disk space". Bind-mounting $R onto itself fixes that.
SELF_BOUND=0
if ! mountpoint -q "$R"; then
    say "bind-mounting $R onto itself (pacman needs a mountpoint)..."
    mount --bind "$R" "$R"
    SELF_BOUND=1
fi

# ── bind @home into the chroot ───────────────────────────────────────────────
HOME_SUB="$TOP/@home"
if [ -d "$HOME_SUB" ] && [ -d "$R/home" ]; then
    if ! findmnt -rn "$R/home" >/dev/null 2>&1; then
        say "binding @home → $R/home"
        mount --bind "$HOME_SUB" "$R/home"
    fi
fi

# ── cleanup function ─────────────────────────────────────────────────────────
cleanup() {
    say "cleaning up..."
    # restore resolv.conf symlink
    if [ -n "$RESOLV_BAK" ]; then
        rm -f "$R/etc/resolv.conf"
        ln -sf "$RESOLV_BAK" "$R/etc/resolv.conf"
        say "restored resolv.conf → $RESOLV_BAK"
    fi
    # unmount @home bind if we mounted it
    if findmnt -rn "$R/home" >/dev/null 2>&1; then
        umount "$R/home" 2>/dev/null || true
    fi
    # drop the self-bind last (after anything mounted beneath it)
    if [ "$SELF_BOUND" = 1 ] && mountpoint -q "$R"; then
        umount "$R" 2>/dev/null || warn "could not unmount $R (still busy?)"
    fi
}
trap cleanup EXIT

# ── chroot: system update ────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Chrooting into SWARM OS — running pacman -Syu"
echo "═══════════════════════════════════════════════════════════"
echo ""

arch-chroot "$R" /bin/bash -c '
    set -euo pipefail

    echo "  [chroot] initialising pacman keyring..."
    pacman-key --init 2>/dev/null || true
    pacman-key --populate archlinux 2>/dev/null || true

    echo ""
    echo "  [chroot] running pacman -Syu..."
    pacman -Syu --noconfirm

    echo ""
    echo "  [chroot] pacman -Syu complete."
'

# ── install swarm-usb-key to /usr/local/bin ──────────────────────────────────
USB_KEY_SRC="$R/opt/swarm_os/bin/swarm-usb-key"
USB_KEY_DST="$R/usr/local/bin/swarm-usb-key"
if [ -f "$USB_KEY_SRC" ]; then
    say "installing swarm-usb-key → /usr/local/bin/"
    cp -pf "$USB_KEY_SRC" "$USB_KEY_DST"
    chmod 755 "$USB_KEY_DST"
    chown root:root "$USB_KEY_DST"
    say "swarm-usb-key installed"
fi

# ── fix ownership on system dirs ─────────────────────────────────────────────
say "fixing ownership on /opt/swarm_os..."
# The flutter bundle, go binaries etc. should be root:root on the installed system
chown -R root:root "$R/opt/swarm_os" 2>/dev/null || warn "could not chown /opt/swarm_os"
# Ensure executables are marked
chmod +x "$R/opt/swarm_os/swarm_flutter/swarm_flutter" 2>/dev/null || true
for bin in "$R/opt/swarm_os/GamingAgent/gaming-agent" \
           "$R/opt/swarm_os/LucyServer/lucy-server" \
           "$R/opt/swarm_os/bin/swarm-usb-key"; do
    [ -f "$bin" ] && chmod 755 "$bin"
done

# ── verify and patch services ───────────────────────────────────────────────────
echo ""
say "verifying and patching systemd services in installed root..."
for svc in "$R/etc/systemd/system/"*.service; do
    if [ -f "$svc" ] && grep -q 'User=swarm' "$svc"; then
        sed -i 's/^User=swarm$/User=i30ltz/' "$svc"
        sed -i 's/^Group=swarm$/Group=i30ltz/' "$svc"
        sed -i 's|swarm:swarm|i30ltz:i30ltz|g' "$svc"
        say "  ✓ patched $(basename "$svc") to User=i30ltz"
    fi
done
for unit in swarm-ui.service gaming-agent.service lucille-core.service; do
    if [ -f "$R/etc/systemd/system/$unit" ]; then
        say "  ✓ $unit present"
    else
        warn "  ✗ $unit NOT FOUND in /etc/systemd/system/"
    fi
done

# ── update swarm-release ─────────────────────────────────────────────────────
STAMP=$(date +%Y%m%d)
VER_FILE="/mnt/swarmbuild/VERSION"
if [ -f "$VER_FILE" ]; then
    VER=$(cat "$VER_FILE")
    say "updating swarm-release to $VER"
    cat > "$R/etc/swarm-release" <<EOF
SWARM_VERSION=$VER
SWARM_COMMIT=$(git -C /mnt/swarmbuild rev-parse --short HEAD 2>/dev/null || echo 'unknown')
SWARM_DATE=$STAMP
EOF
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  SWARM OS chroot update complete"
echo "═══════════════════════════════════════════════════════════"
echo ""
say "Updated: $(cat "$R/etc/swarm-release" 2>/dev/null)"
echo ""
