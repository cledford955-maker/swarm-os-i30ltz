#!/usr/bin/env bash
# install_from_debian.sh — install / reinstall SWARM OS onto the internal NVMe
# from a running Debian, with no boot from USB.
#
# How it works (reconstructed 2026-10-10 from the original, unrecorded install):
#   1. Unpack a SWARM ISO's airootfs.sfs into /mnt/swarmbuild/install-env/root.
#      That is a complete Arch Linux environment carrying pacstrap, arch-chroot,
#      genfstab, grub, btrfs-progs and the installer itself.
#   2. arch-chroot into it and run install_swarm_os.sh in partition mode.
#
# Usage (run as your normal user; sudo is requested where needed):
#   install_from_debian.sh prepare [ISO]   unpack ISO (default: newest on Ventoy) + init pacman keys
#   install_from_debian.sh refresh         copy the repo's CURRENT install_swarm_os.sh and package
#                                          manifests into the environment (an unpacked ISO holds
#                                          the installer it was built with, not today's fixes)
#   install_from_debian.sh install         format the swarm-root partition and install
#   install_from_debian.sh status          show what exists, change nothing
#
# SAFETY: only the btrfs partition labelled swarm-root on nvme0n1 is formatted;
# the EFI partition (FE19-A70F) is kept. Both are resolved at run time (a
# reinstall changes the filesystem UUID, so UUIDs are not hard-coded) and the
# installer additionally refuses its protected-UUID list (Lucy, brains, Slick,
# swap, Ventoy). You must type the root device path to continue.
set -euo pipefail

ENV_DIR=/mnt/swarmbuild/install-env
ROOT="$ENV_DIR/root"
ISO_MNT="$ENV_DIR/iso"
VENTOY_DIR=/mnt/ventoy/ISO/SWARM_OS
LUCY=/mnt/Lucy
ROOT_LABEL=swarm-root
ROOT_DISK=nvme0n1
ESP_UUID=FE19-A70F

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'; NC=$'\033[0m'
die()  { echo "${RED}ERROR: $*${NC}" >&2; exit 1; }
info() { echo "${GRN}  ✓ $*${NC}"; }
warn() { echo "${YLW}  ⚠ $*${NC}"; }

[ "$EUID" -ne 0 ] || die "run as your normal user, not with sudo (it calls sudo itself)."
mountpoint -q /mnt/swarmbuild || die "/mnt/swarmbuild is not mounted (run 70-scripts/check_mounts.sh)."

need_tools() {
    local t miss=()
    for t in arch-chroot unsquashfs; do command -v "$t" >/dev/null || miss+=("$t"); done
    [ ${#miss[@]} -eq 0 ] || die "missing ${miss[*]}: sudo apt install arch-install-scripts squashfs-tools"
}

in_env() { sudo arch-chroot "$ROOT" "$@"; }

# arch-chroot needs the chroot to be a mount point.
bind_root() { mountpoint -q "$ROOT" || sudo mount --bind "$ROOT" "$ROOT"; }

cmd_status() {
    echo "Environment : $ROOT"
    if [ -x "$ROOT/usr/local/bin/install_swarm_os.sh" ]; then
        info "unpacked; installer present ($(stat -c %y "$ROOT/usr/local/bin/install_swarm_os.sh" | cut -d. -f1))"
        diff -q "$LUCY/install_swarm_os.sh" "$ROOT/usr/local/bin/install_swarm_os.sh" >/dev/null \
            && info "installer matches the repo copy" || warn "installer differs from the repo copy — run: refresh"
    else
        warn "not prepared — run: prepare"
    fi
    echo; lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS "/dev/$ROOT_DISK"
}

cmd_prepare() {
    need_tools
    local iso="${1:-}"
    if [ -z "$iso" ]; then
        iso=$(ls -t "$VENTOY_DIR"/swarm-os-*.iso 2>/dev/null | head -n1 || true)
    fi
    [ -f "$iso" ] || die "no ISO found (pass a path, or mount Ventoy at /mnt/ventoy)."
    echo "ISO: $iso"
    if [ -d "$ROOT" ] && [ -n "$(ls -A "$ROOT" 2>/dev/null)" ]; then
        read -r -p "$ROOT already exists. Replace it with this ISO's rootfs? [y/N] " a
        [ "$a" = y ] || [ "$a" = Y ] || die "cancelled."
        mountpoint -q "$ROOT" && sudo umount "$ROOT"
        sudo rm -rf --one-file-system "$ROOT"
    fi
    sudo mkdir -p "$ISO_MNT" "$ENV_DIR"
    mountpoint -q "$ISO_MNT" && sudo umount "$ISO_MNT"
    sudo mount -o loop,ro "$iso" "$ISO_MNT"
    local sfs
    sfs=$(ls "$ISO_MNT"/swarm/x86_64/airootfs.sfs "$ISO_MNT"/arch/x86_64/airootfs.sfs 2>/dev/null | head -n1 || true)
    [ -n "$sfs" ] || { sudo umount "$ISO_MNT"; die "airootfs.sfs not found in the ISO."; }
    echo "Unpacking $sfs (several minutes)..."
    sudo unsquashfs -f -d "$ROOT" "$sfs" >/dev/null
    sudo umount "$ISO_MNT"
    bind_root
    in_env bash -c "pacman-key --init && pacman-key --populate archlinux"
    info "environment ready at $ROOT"
    cmd_refresh
}

cmd_refresh() {
    [ -d "$ROOT/usr/local/bin" ] || die "not prepared — run: prepare"
    sudo install -m 0755 "$LUCY/install_swarm_os.sh" "$ROOT/usr/local/bin/install_swarm_os.sh"
    local prof="$LUCY/40-iso-profile/swarm_os_iso_profile" share="$ROOT/usr/local/share/swarm-os"
    sudo mkdir -p "$share"
    for f in packages.x86_64 pacman.conf; do
        [ -f "$prof/$f" ] && sudo install -m 0644 "$prof/$f" "$share/$f"
    done
    info "installer and package manifests refreshed from $LUCY"
}

cmd_install() {
    need_tools
    [ -x "$ROOT/usr/local/bin/install_swarm_os.sh" ] || die "not prepared — run: prepare"
    diff -q "$LUCY/install_swarm_os.sh" "$ROOT/usr/local/bin/install_swarm_os.sh" >/dev/null \
        || die "environment installer is out of date — run: refresh"

    # The mounted copy of the target (automount at /mnt/swarm) must be released.
    sudo systemctl stop mnt-swarm.automount mnt-swarm.mount 2>/dev/null || true
    sudo umount -R /mnt/swarm 2>/dev/null || true

    local root_dev esp_dev root_uuid esp_uuid
    root_dev=$(blkid -L "$ROOT_LABEL" 2>/dev/null || true)
    [ -n "$root_dev" ] || die "no partition labelled $ROOT_LABEL."
    root_dev=$(readlink -f "$root_dev")
    case "$root_dev" in /dev/${ROOT_DISK}p*) ;; *) die "$root_dev is not on $ROOT_DISK; refusing." ;; esac
    [ "$(lsblk -no FSTYPE "$root_dev")" = btrfs ] || die "$root_dev is not btrfs; refusing."
    esp_dev=$(readlink -f "/dev/disk/by-uuid/$ESP_UUID" 2>/dev/null || true)
    [ -b "$esp_dev" ] || die "EFI partition $ESP_UUID not found."
    [ "$(lsblk -no FSTYPE "$esp_dev")" = vfat ] || die "$esp_dev is not FAT; refusing."
    root_uuid=$(blkid -s UUID -o value "$root_dev")
    esp_uuid=$ESP_UUID
    findmnt -rn -S "$root_dev" >/dev/null && die "$root_dev is still mounted; unmount it first."

    echo
    echo "${RED}WILL FORMAT (all data on it is erased):${NC} $root_dev  (label $ROOT_LABEL, UUID $root_uuid)"
    echo "${GRN}KEPT, not formatted (EFI):${NC}            $esp_dev  (UUID $esp_uuid)"
    echo "Debian's ESP and every other partition stay untouched."
    echo
    read -r -p "Type the device path to confirm ($root_dev): " typed
    [ "$typed" = "$root_dev" ] || die "did not match — nothing changed."

    bind_root
    # Let the chroot see the repo (profile fallback) read-only, and the host device nodes.
    sudo mkdir -p "$ROOT$LUCY"
    mountpoint -q "$ROOT$LUCY" || sudo mount --bind -o ro "$LUCY" "$ROOT$LUCY"
    trap 'sudo umount "$ROOT'"$LUCY"'" 2>/dev/null || true' EXIT

    sudo arch-chroot "$ROOT" install_swarm_os.sh --root-uuid "$root_uuid" --esp-uuid "$esp_uuid"
    info "installer finished. Re-run 70-scripts/check_swarm_standalone.sh and boot-test."
}

case "${1:-}" in
    prepare) shift; cmd_prepare "$@" ;;
    refresh) cmd_refresh ;;
    install) cmd_install ;;
    status)  cmd_status ;;
    *) sed -n '2,27p' "$0"; exit 2 ;;
esac
