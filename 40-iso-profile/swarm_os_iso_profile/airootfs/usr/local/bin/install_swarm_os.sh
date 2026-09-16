#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; CYN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GRN}  ✓ $1${NC}"; }
warn()  { echo -e "${YLW}  ⚠ $1${NC}"; }
banner(){ echo -e "\n${CYN}  === $1 ===${NC}\n"; }

# ── Disk detection ────────────────────────────────────────────────────────────
# Usage: install_swarm_os.sh [--disk /dev/sdX]
# If --disk is not passed, the script auto-detects the largest non-removable disk
# and asks for confirmation before touching anything.
DISK=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --disk) DISK="$2"; shift 2 ;;
    *)      shift ;;
  esac
done

if [ -z "$DISK" ]; then
  # Find non-removable physical disks, excluding any that already contain a
  # LUKS-encrypted partition (an encrypted archive/reference drive — e.g. this
  # project's read-only `lucy-master` mirror — is never the intended
  # wipe-and-reinstall target), then pick the largest of what's left.
  #
  # This matters concretely on this project's hardware: /dev/sda and /dev/sdb
  # swap identities between boots, and whichever one currently holds
  # `lucy-master` is also frequently the largest disk in the machine —
  # "largest disk" alone would target it instead of the real OS disk.
  LUKS_DISKS=$(lsblk -rno PKNAME,FSTYPE | awk '$2=="crypto_LUKS"{print $1}' | sort -u)
  DISK=""
  while read -r _SIZE NAME; do
    BASENAME=$(basename "$NAME")
    if ! grep -qx "$BASENAME" <<<"$LUKS_DISKS"; then
      DISK="$NAME"
      break
    fi
  done < <(lsblk -dpno NAME,TYPE,RM,SIZE --bytes | awk '$2=="disk" && $3=="0" {print $4, $1}' | sort -rn)
  if [ -z "$DISK" ]; then
    echo -e "${RED}ERROR: Could not auto-detect a target disk.${NC}"
    echo "Pass one explicitly:  sudo $0 --disk /dev/nvme0n1"
    exit 1
  fi
  echo -e "\n${CYN}Detected target disk: ${YLW}${DISK}${NC}"
  lsblk "$DISK"
  echo -e "\n${RED}WARNING: ALL DATA ON ${DISK} WILL BE ERASED.${NC}"
  # Require the operator to type the exact disk path, not just "YES" — forces
  # a moment of actually reading which device this is about to erase.
  read -r -p "Type the disk path exactly (${DISK}) to continue: " CONFIRM
  [[ "$CONFIRM" == "$DISK" ]] || { echo "Aborted."; exit 1; }
fi

# Derive EFI and root partitions (handles NVMe p1/p2 vs SATA 1/2)
if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
  TARGET_EFI="${DISK}p1"
  TARGET_ROOT="${DISK}p2"
else
  TARGET_EFI="${DISK}1"
  TARGET_ROOT="${DISK}2"
fi

info "Target disk : $DISK"
info "EFI partition  : $TARGET_EFI"
info "Root partition : $TARGET_ROOT"

# Warn if partitions don't exist yet
if [ ! -b "$TARGET_EFI" ] || [ ! -b "$TARGET_ROOT" ]; then
  echo -e "${YLW}  Partitions not found — you may need to partition $DISK first.${NC}"
  echo -e "  Suggested layout (GPT):"
  echo -e "    ${DISK}p1 (or ${DISK}1) — 512MB  EFI  FAT32"
  echo -e "    ${DISK}p2 (or ${DISK}2) — rest   ROOT btrfs"
  echo -e "  Quick partition command (DESTRUCTIVE):"
  echo -e "    parted -s $DISK mklabel gpt mkpart EFI fat32 1MiB 513MiB mkpart ROOT 513MiB 100% set 1 esp on"
  echo -e "    mkfs.fat -F32 $TARGET_EFI"
  echo ""
  read -r -p "Partitions are in place — continue? [y/N] " YN
  [[ "$YN" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

MOUNT_POINT="/mnt/swarm_os"

# -------------------------------------------------------
banner "SWARM OS INSTALLER — Standard Btrfs Root (Non-LUKS)"
# -------------------------------------------------------

# Ensure mount point is unmounted before formatting
for mount_path in \
  "$MOUNT_POINT/boot/efi" \
  "$MOUNT_POINT/.snapshots" \
  "$MOUNT_POINT/home" \
  "$MOUNT_POINT"; do
  if mountpoint -q "$mount_path"; then
    umount "$mount_path"
  fi
done
if findmnt -rn -S "$TARGET_ROOT" >/dev/null 2>&1; then
  echo -e "${RED}ERROR: $TARGET_ROOT is still mounted.${NC}"
  findmnt -rn -S "$TARGET_ROOT"
  exit 1
fi

banner "Formatting $TARGET_ROOT with btrfs..."
mkfs.btrfs -f -L "swarm-root" "$TARGET_ROOT"
info "btrfs filesystem ready on $TARGET_ROOT"

banner "Creating btrfs subvolumes (@, @home, @snapshots)..."
BTRFS_TMP="/mnt/swarm_btrfs_tmp"
mkdir -p "$BTRFS_TMP"
mount "$TARGET_ROOT" "$BTRFS_TMP"
btrfs subvolume create "$BTRFS_TMP/@"
btrfs subvolume create "$BTRFS_TMP/@home"
btrfs subvolume create "$BTRFS_TMP/@snapshots"
umount "$BTRFS_TMP"
rmdir "$BTRFS_TMP"
info "@, @home, @snapshots subvolumes created"

banner "Mounting filesystems..."
mkdir -p "$MOUNT_POINT"
mount -o subvol=@,noatime,compress=zstd "$TARGET_ROOT" "$MOUNT_POINT"
mkdir -p "$MOUNT_POINT/home"
mount -o subvol=@home,noatime,compress=zstd "$TARGET_ROOT" "$MOUNT_POINT/home"
mkdir -p "$MOUNT_POINT/.snapshots"
mount -o subvol=@snapshots,noatime "$TARGET_ROOT" "$MOUNT_POINT/.snapshots"
mkdir -p "$MOUNT_POINT/boot/efi"
mount "$TARGET_EFI" "$MOUNT_POINT/boot/efi"
info "Mounted $TARGET_ROOT (@ subvol) → $MOUNT_POINT"
info "Mounted $TARGET_ROOT (@home subvol) → $MOUNT_POINT/home"
info "Mounted $TARGET_EFI → $MOUNT_POINT/boot/efi"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_PACKAGES="$SCRIPT_DIR/swarm_os_iso_profile/packages.x86_64"
if [ ! -f "$PROFILE_PACKAGES" ]; then
  PROFILE_PACKAGES="/usr/local/share/swarm-os/packages.x86_64"
fi
if [ ! -f "$PROFILE_PACKAGES" ]; then
  echo -e "${RED}ERROR: Package manifest is missing from the live environment.${NC}"
  echo "Expected: /usr/local/share/swarm-os/packages.x86_64"
  exit 1
fi
PROFILE_ROOT="$SCRIPT_DIR/swarm_os_iso_profile"
if [ ! -d "$PROFILE_ROOT/airootfs" ]; then
  PROFILE_ROOT="/mnt/Lucy/40-iso-profile/swarm_os_iso_profile"
fi
PROFILE_PACMAN_CONF="/usr/local/share/swarm-os/pacman.conf"
if [ ! -f "$PROFILE_PACMAN_CONF" ]; then
  PROFILE_PACMAN_CONF="/mnt/Lucy/40-iso-profile/swarm_os_iso_profile/pacman.conf"
fi
if [ ! -f "$PROFILE_PACMAN_CONF" ]; then
  echo -e "${RED}ERROR: SWARM OS pacman configuration is missing.${NC}"
  exit 1
fi

banner "Running pacstrap..."
PACKAGES=$(grep -v '^#' "$PROFILE_PACKAGES" | grep -v '^$' | tr '\n' ' ')
pacstrap -C "$PROFILE_PACMAN_CONF" -K "$MOUNT_POINT" base linux linux-firmware cryptsetup lvm2 $PACKAGES
info "pacstrap complete"

banner "Generating fstab..."
genfstab -U "$MOUNT_POINT" >> "$MOUNT_POINT/etc/fstab"
mkdir -p "$MOUNT_POINT/mnt/Lucy"
# Add Lucy drive entry only if not already present
LUCY_UUID="62f0e009-43c2-4760-8d6c-d7c445f5f3df"
if ! grep -q "$LUCY_UUID\|/mnt/Lucy" "$MOUNT_POINT/etc/fstab" 2>/dev/null; then
    echo "UUID=${LUCY_UUID}  /mnt/Lucy  ext4  defaults,noatime,nofail,x-systemd.device-timeout=5  0 2" >> "$MOUNT_POINT/etc/fstab"
    info "Lucy drive (LUCILLE) added to fstab → /mnt/Lucy"
else
    info "Lucy drive already in fstab — skipping"
fi

# i30ltz-brains (Lucille memory, nvme0n1p5)
BRAINS_UUID="fba1b27f-407b-4385-9dfa-851833f249db"
mkdir -p "$MOUNT_POINT/mnt/brains"
if ! grep -q "$BRAINS_UUID\|/mnt/brains" "$MOUNT_POINT/etc/fstab" 2>/dev/null; then
    echo "UUID=${BRAINS_UUID}  /mnt/brains  ext4  defaults,noatime,nofail,x-systemd.device-timeout=5  0 2" >> "$MOUNT_POINT/etc/fstab"
    info "brains partition added to fstab → /mnt/brains"
fi

# i30ltz-AI backup drive (sdb8)
AIBACKUP_UUID="689e6547-b439-4e7f-93c9-a6dcfabed46b"
mkdir -p "$MOUNT_POINT/mnt/boltz"
if ! grep -q "$AIBACKUP_UUID\|/mnt/boltz" "$MOUNT_POINT/etc/fstab" 2>/dev/null; then
    echo "UUID=${AIBACKUP_UUID}  /mnt/boltz  ext4  defaults,noatime,noauto,nofail,x-systemd.device-timeout=5  0 2" >> "$MOUNT_POINT/etc/fstab"
    info "Dr. Boltz drive (sdb8 i30ltz-AI) added to fstab → /mnt/boltz"
fi

# Slick — encrypted vault (nvme0n1p6, noauto — unlock_slick.sh required)
SLICK_UUID="019a3cd8-46c5-4a19-a760-8e0c1096b248"
SLICK_MAPPER="luks-${SLICK_UUID}"
mkdir -p "$MOUNT_POINT/mnt/slick"
if ! grep -q "$SLICK_UUID\|/mnt/slick" "$MOUNT_POINT/etc/crypttab" 2>/dev/null; then
    echo "${SLICK_MAPPER}  UUID=${SLICK_UUID}  none  luks,noauto" >> "$MOUNT_POINT/etc/crypttab"
    info "Slick LUKS entry added to crypttab"
fi
if ! grep -q "slick\|$SLICK_MAPPER" "$MOUNT_POINT/etc/fstab" 2>/dev/null; then
    echo "/dev/mapper/${SLICK_MAPPER}  /mnt/slick  ext4  defaults,noauto,nofail,x-systemd.device-timeout=5  0 2" >> "$MOUNT_POINT/etc/fstab"
    info "Slick vault added to fstab → /mnt/slick"
fi

# EndeavourOS recovery parent (sda4, btrfs) — UUID-keyed so sda/sdb swap is safe
ENDEAVOR_UUID="0ac123f1-bbd1-4ea6-8fdd-930bd0d45e18"
mkdir -p "$MOUNT_POINT/mnt/endeavor"
if ! grep -q "$ENDEAVOR_UUID\|/mnt/endeavor" "$MOUNT_POINT/etc/fstab" 2>/dev/null; then
    echo "UUID=${ENDEAVOR_UUID}  /mnt/endeavor  btrfs  defaults,noatime,nofail,x-systemd.device-timeout=5  0 0" >> "$MOUNT_POINT/etc/fstab"
    info "EndeavourOS partition added to fstab → /mnt/endeavor"
fi

# Recovery build workspace (sda7, btrfs)
RECOVERYBUILD_UUID="3f6e3011-94a1-47d5-8192-6d86e9fd26d2"
mkdir -p "$MOUNT_POINT/mnt/recoverybuild"
if ! grep -q "$RECOVERYBUILD_UUID\|/mnt/recoverybuild" "$MOUNT_POINT/etc/fstab" 2>/dev/null; then
    echo "UUID=${RECOVERYBUILD_UUID}  /mnt/recoverybuild  btrfs  defaults,noatime,nofail,x-systemd.device-timeout=5  0 0" >> "$MOUNT_POINT/etc/fstab"
    info "Recovery build workspace added to fstab → /mnt/recoverybuild"
fi

# Recovery OS output (sda6, ext4)
RECOVERYOS_UUID="9a9c857f-f2cb-47cc-ac13-2cf3a3e24bc8"
mkdir -p "$MOUNT_POINT/mnt/recoveryos"
if ! grep -q "$RECOVERYOS_UUID\|/mnt/recoveryos" "$MOUNT_POINT/etc/fstab" 2>/dev/null; then
    echo "UUID=${RECOVERYOS_UUID}  /mnt/recoveryos  ext4  defaults,noatime,nofail,x-systemd.device-timeout=5  0 2" >> "$MOUNT_POINT/etc/fstab"
    info "Recovery OS output added to fstab → /mnt/recoveryos"
fi

info "fstab written"

banner "Copying custom airootfs files..."
if [ -d "$PROFILE_ROOT/airootfs/" ]; then
    # Backup base system auth files before copying airootfs
    cp -a "$MOUNT_POINT/etc/passwd" "$MOUNT_POINT/etc/passwd.sys" 2>/dev/null || true
    cp -a "$MOUNT_POINT/etc/group" "$MOUNT_POINT/etc/group.sys" 2>/dev/null || true
    cp -a "$MOUNT_POINT/etc/shadow" "$MOUNT_POINT/etc/shadow.sys" 2>/dev/null || true
    # The airootfs ships its own static fstab/crypttab for the live boot
    # environment (no root/home subvol entries — those are mounted by the
    # live boot process). Back up the genfstab-generated fstab (with the
    # real @home mount and our custom drive entries) and crypttab (with the
    # Slick LUKS entry) so the airootfs copy below doesn't silently stomp them.
    cp -a "$MOUNT_POINT/etc/fstab" "$MOUNT_POINT/etc/fstab.sys" 2>/dev/null || true
    cp -a "$MOUNT_POINT/etc/crypttab" "$MOUNT_POINT/etc/crypttab.sys" 2>/dev/null || true

    # --no-preserve=ownership: the profile on /mnt/Lucy is owned by the build
    # user (uid 1000). Plain `cp -a` carried that owner onto the target's
    # /etc, /etc/sudoers.d/10-wheel, /etc/systemd/system and root-run scripts
    # in /opt — letting the desktop user edit sudoers and root services, and
    # making sudo reject 10-wheel (found 2026-09-16). Copied files are root-
    # owned now; per-user config (labwc) is chowned to i30ltz further down.
    cp -a --no-preserve=ownership "$PROFILE_ROOT/airootfs/"* "$MOUNT_POINT/"

    # Restore pristine system auth files (so users and render groups exist)
    [ -f "$MOUNT_POINT/etc/passwd.sys" ] && mv "$MOUNT_POINT/etc/passwd.sys" "$MOUNT_POINT/etc/passwd"
    [ -f "$MOUNT_POINT/etc/group.sys" ] && mv "$MOUNT_POINT/etc/group.sys" "$MOUNT_POINT/etc/group"
    [ -f "$MOUNT_POINT/etc/shadow.sys" ] && mv "$MOUNT_POINT/etc/shadow.sys" "$MOUNT_POINT/etc/shadow"
    # Restore the real fstab/crypttab (root/home subvol mounts + custom drives)
    [ -f "$MOUNT_POINT/etc/fstab.sys" ] && mv "$MOUNT_POINT/etc/fstab.sys" "$MOUNT_POINT/etc/fstab"
    [ -f "$MOUNT_POINT/etc/crypttab.sys" ] && mv "$MOUNT_POINT/etc/crypttab.sys" "$MOUNT_POINT/etc/crypttab"
    info "airootfs files copied"
fi

banner "Purging live ISO artifacts & restoring standard initramfs preset..."
# Remove live-ISO-only files copied from airootfs
rm -f "$MOUNT_POINT/etc/mkinitcpio.conf.d/archiso.conf"
rm -f "$MOUNT_POINT/etc/mkinitcpio.conf.d/swarm-encrypt.conf"
rm -f "$MOUNT_POINT/etc/systemd/system/getty@tty1.service.d/autologin.conf"
rm -f "$MOUNT_POINT/etc/systemd/journald.conf.d/volatile-storage.conf"
rm -f "$MOUNT_POINT/etc/systemd/resolved.conf.d/archiso.conf"
rm -f "$MOUNT_POINT/etc/ssh/sshd_config.d/10-archiso.conf"
rm -rf "$MOUNT_POINT/etc/pacman.d/hooks"

# Restore standard Arch Linux mkinitcpio linux.preset
cat > "$MOUNT_POINT/etc/mkinitcpio.d/linux.preset" <<'PRESETEOF'
# mkinitcpio preset file for the 'linux' package

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default' 'fallback')

#default_config="/etc/mkinitcpio.conf"
default_image="/boot/initramfs-linux.img"

#fallback_config="/etc/mkinitcpio.conf"
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
PRESETEOF

# Configure standard mkinitcpio hooks for disk boot
cat > "$MOUNT_POINT/etc/mkinitcpio.conf" <<'MKINEOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
MKINEOF

# Ensure SWARM OS GRUB theme is in place
if [ -d "$SCRIPT_DIR/grub_themes/swarm_os" ]; then
    mkdir -p "$MOUNT_POINT/boot/grub/themes"
    cp -a "$SCRIPT_DIR/grub_themes/swarm_os" "$MOUNT_POINT/boot/grub/themes/"
    info "SWARM OS GRUB theme installed"
fi

# Get UUID of the raw root partition
ROOT_UUID=$(blkid -s UUID -o value "$TARGET_ROOT")
info "Root UUID: $ROOT_UUID"

# Leave a durable, non-secret record on the installed root so recovery tools
# can identify exactly which SWARM OS build was installed on this partition.
BUILD_RELEASE_FILE="$MOUNT_POINT/etc/swarm-release"
BUILD_VERSION=$(sed -n 's/^SWARM_VERSION=//p' "$BUILD_RELEASE_FILE" 2>/dev/null | head -n1 || true)
BUILD_COMMIT=$(sed -n 's/^SWARM_COMMIT=//p' "$BUILD_RELEASE_FILE" 2>/dev/null | head -n1 || true)
BUILD_DATE=$(sed -n 's/^SWARM_DATE=//p' "$BUILD_RELEASE_FILE" 2>/dev/null | head -n1 || true)
BUILD_VERSION=${BUILD_VERSION:-unknown}
BUILD_COMMIT=${BUILD_COMMIT:-unknown}
BUILD_DATE=${BUILD_DATE:-unknown}
cat > "$MOUNT_POINT/etc/swarm-build-info" <<BUILDINFO
# SWARM OS installed-build record. No secrets are stored here.
SWARM_VERSION=$BUILD_VERSION
SWARM_COMMIT=$BUILD_COMMIT
SWARM_BUILD_DATE=$BUILD_DATE
INSTALL_DATE=$(date -Is)
INSTALL_TARGET_DISK=$DISK
INSTALL_TARGET_ROOT=$TARGET_ROOT
INSTALL_ROOT_UUID=$ROOT_UUID
BUILDINFO
chmod 0644 "$MOUNT_POINT/etc/swarm-build-info"
info "Installed build record written to /etc/swarm-build-info"

# Capture existing password hash for i30ltz from host if available
HOST_PW_HASH=$(grep '^i30ltz:' /etc/shadow 2>/dev/null | cut -d: -f2 || true)

banner "Configuring system (chroot)..."
arch-chroot "$MOUNT_POINT" /bin/bash <<EOF
set -e
# Restore standard system user database
pacman -S --noconfirm --overwrite '*' filesystem

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "swarm-os" > /etc/hostname

# Build clean initramfs
mkinitcpio -P

# Setup user i30ltz with video, render, and wheel groups
useradd -m -G wheel,video,render,users -s /bin/bash i30ltz 2>/dev/null || usermod -a -G wheel,video,render,users i30ltz

# Set command execution password (used for sudo and terminal commands, NOT for graphical login).
# Interactive password entry can't happen in here: this whole block is fed to
# arch-chroot's bash over a heredoc, so passwd's prompt would read leftover
# heredoc text instead of the terminal. When no usable host hash exists, we
# leave the account unset here and prompt for a real password after this
# heredoc closes (see below), where stdin is the actual terminal again.
if [ -n "$HOST_PW_HASH" ] && [ "$HOST_PW_HASH" != "!" ] && [ "$HOST_PW_HASH" != "*" ]; then
    usermod -p "$HOST_PW_HASH" i30ltz
    echo "✓ Preserved user password for running commands from host"
fi

# Standard sudo requires password for running commands
sed -i 's/^#\?\s*%wheel ALL=(ALL:ALL)\s*ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
rm -f /etc/sudoers.d/01-wheel-nopasswd

# Configure swarm-ui kiosk to auto-login as user i30ltz
if [ -f /etc/systemd/system/swarm-ui.service ]; then
    sed -i 's/^User=.*/User=i30ltz/' /etc/systemd/system/swarm-ui.service
    sed -i 's/^Group=.*/Group=i30ltz/' /etc/systemd/system/swarm-ui.service
    sed -i 's|^WorkingDirectory=.*|WorkingDirectory=/home/i30ltz|' /etc/systemd/system/swarm-ui.service
    sed -i 's|swarm:swarm|i30ltz:i30ltz|g' /etc/systemd/system/swarm-ui.service
fi

# The other SWARM services (gaming-agent, lucy-server, google-workspace,
# i30ltz-recovery) were also written for the live ISO's 'swarm' user, which
# doesn't exist on an installed system — they failed with 217/USER
# "Unknown user" at every boot (found 2026-09-16).
for unit in /etc/systemd/system/*.service; do
    sed -i -e 's/^User=swarm *\$/User=i30ltz/' \
           -e 's/^Group=swarm *\$/Group=i30ltz/' \
           -e 's|chown swarm:swarm|chown i30ltz:i30ltz|g' "\$unit"
done

# BUG FIX: swarm-ui.service now runs as i30ltz, but labwc's config (the
# autostart script that actually launches the Flutter shell + Lucille panel,
# plus rc.xml's floating-window rules) only exists at /home/swarm/.config/labwc
# — baked there by the airootfs skeleton for the live-ISO "swarm" user. Left
# uncopied, labwc starts (it needs no config to start) but runs its autostart
# script from nowhere, so no client windows ever launch: a black screen with
# just the compositor's cursor, on every installed system. Copy the whole
# labwc config dir into i30ltz's home and fix ownership.
if [ -d /home/swarm/.config/labwc ]; then
    mkdir -p /home/i30ltz/.config
    cp -a /home/swarm/.config/labwc /home/i30ltz/.config/
    chown -R i30ltz:i30ltz /home/i30ltz/.config/labwc
fi

# BUG FIX: gaming-agent.service, lucy-server.service, and google-workspace.
# service are all baked with User=swarm (the live-ISO user), but this
# installer never creates a "swarm" system user — only i30ltz. Left
# unpatched, all three backend daemons fail to start on every installed
# (non-live) system. Same treatment as swarm-ui.service.
# (google-workspace.service was missed in the original fix for this same
# bug on the other two services — found+added 2026-09-13.)
for svc in gaming-agent.service lucy-server.service google-workspace.service; do
    if [ -f "/etc/systemd/system/$svc" ]; then
        sed -i 's/^User=swarm$/User=i30ltz/' "/etc/systemd/system/$svc"
        sed -i 's|swarm:swarm|i30ltz:i30ltz|g' "/etc/systemd/system/$svc"
    fi
done

# Rootless Podman needs a subuid/subgid range for i30ltz. useradd normally
# allocates one automatically from /etc/subuid /etc/subgid (baked into the ISO
# with an entry for "swarm"); double-check i30ltz actually got one and fall
# back to an explicit range if not, so `podman run` as i30ltz doesn't fail
# with "newuidmap: no entry" on first use.
if ! grep -q '^i30ltz:' /etc/subuid 2>/dev/null; then
    usermod --add-subuids 165536-231071 i30ltz 2>/dev/null || echo 'i30ltz:165536:65536' >> /etc/subuid
fi
if ! grep -q '^i30ltz:' /etc/subgid 2>/dev/null; then
    usermod --add-subgids 165536-231071 i30ltz 2>/dev/null || echo 'i30ltz:165536:65536' >> /etc/subgid
fi

# Enable services
systemctl enable NetworkManager || true
systemctl enable bluetooth || true
systemctl enable nftables || true
systemctl enable apparmor || true
systemctl enable swarm-podman-linger.service || true
systemctl enable swarm-ui.service || true
systemctl enable swarm-snapshot.service || true

# Install GRUB as UEFI bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=SWARM_OS --recheck

# Write chainload entries
cat > /etc/grub.d/40_custom <<'CUSTOMEOF'
#!/bin/sh
exec tail -n +3 \$0
menuentry "CachyOS (chainload)" --class cachyos --class gnu-linux --class os {
  search --no-floppy --fs-uuid --set=root A367-87E3
  chainloader /EFI/cachyos/grubx64.efi
}
menuentry "UEFI Firmware Settings" --class firmware {
    fwsetup
}
menuentry "Reboot" --class reboot {
    reboot
}
menuentry "Shutdown" --class shutdown {
    halt
}
CUSTOMEOF
chmod +x /etc/grub.d/40_custom

# Install snap-pac & grub-btrfs for automated rollback snapshots
pacman -S --noconfirm --needed snap-pac grub-btrfs inotify-tools btrfs-progs || true
systemctl enable grub-btrfsd || true

# Patch GRUB default with direct root UUID, theme, and HD resolution
sed -i 's|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="root=UUID='"${ROOT_UUID}"' rootflags=subvol=@ rw quiet loglevel=3 apparmor=1 security=apparmor"|' /etc/default/grub || \
  echo 'GRUB_CMDLINE_LINUX="root=UUID='"${ROOT_UUID}"' rootflags=subvol=@ rw quiet loglevel=3 apparmor=1 security=apparmor"' >> /etc/default/grub

sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/swarm_os/theme.txt"|' /etc/default/grub || \
  echo 'GRUB_THEME="/boot/grub/themes/swarm_os/theme.txt"' >> /etc/default/grub

sed -i 's|^#\?GRUB_GFXMODE=.*|GRUB_GFXMODE="1920x1080,auto"|' /etc/default/grub || \
  echo 'GRUB_GFXMODE="1920x1080,auto"' >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# ── Ollama: install binary ─────────────────────────────────────────────────
echo -e "\n=== Installing Ollama (CPU mode for integrated GPU)... ===\n"
curl -fsSL https://ollama.com/install.sh | OLLAMA_NO_GPU=1 sh || true
systemctl enable ollama || true
echo "Ollama installed and enabled"

# ── Write the first-boot model pull script ────────────────────────────────
mkdir -p /opt/swarm_os
cat > /opt/swarm_os/swarm-ollama-pull.sh <<'PULLEOF'
#!/bin/bash
# Swarm OS — First-boot Ollama model puller
# Runs once after Ollama service is confirmed up.
# Only pulls models ≤7B (safe for integrated graphics / shared RAM).

LOG=/var/log/swarm-ollama-pull.log
STAMP=/var/lib/swarm-ollama-pulled

[ -f "$STAMP" ] && exit 0  # already ran — skip

exec >> "$LOG" 2>&1
echo "[$(date)] Starting Swarm OS Ollama first-boot pull..."

# Wait for Ollama to be ready (max 60s)
for i in $(seq 1 12); do
  curl -sf http://localhost:11434/ > /dev/null && break
  echo "[$(date)] Waiting for Ollama... ($i/12)"
  sleep 5
done

pull() {
  echo "[$(date)] Pulling $1..."
  ollama pull "$1" && echo "[$(date)] ✓ $1 done" || echo "[$(date)] ✗ $1 failed (skip)"
}

# ── Models ≤7B — safe for integrated GPU + shared RAM ──────────────────────
# Tiny models (always pull — <2GB each)
pull llama3.2:1b          # 1.3GB  — fastest edge responder
pull phi3.5-mini          # 2.2GB  — Microsoft Phi, strong reasoning for size

# 3B tier (~2GB)
pull llama3.2:3b          # 2.0GB  — Meta flagship 3B

# 7B tier (~4–5GB each — pull one at a time, needs ~8GB free RAM)
pull qwen2.5:7b           # 4.7GB  — Alibaba generalist
pull qwen2.5-coder:7b     # 4.7GB  — Alibaba code specialist
pull deepseek-r1:7b       # 4.7GB  — DeepSeek reasoning distill

# Mark done so this service never runs again
touch "$STAMP"
echo "[$(date)] Swarm OS Ollama pull complete."
PULLEOF
chmod +x /opt/swarm_os/swarm-ollama-pull.sh

# ── Systemd one-shot service ─────────────────────────────────────────────
cat > /etc/systemd/system/swarm-ollama-pull.service <<'SVCEOF'
[Unit]
Description=Swarm OS — First-boot Ollama model pull
After=network-online.target ollama.service
Wants=network-online.target ollama.service
ConditionPathExists=!/var/lib/swarm-ollama-pulled

[Service]
Type=oneshot
ExecStart=/opt/swarm_os/swarm-ollama-pull.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl enable swarm-ollama-pull.service
echo "First-boot Ollama pull service enabled"

# Generate a unique SWARM_AUTH_TOKEN if the env file doesn't already have one.
# The ISO ships 'swarm-token-2026' as a fallback; installed systems get a real
# 32-byte random token so every SWARM_OS install has its own credential.
if ! grep -q '^SWARM_AUTH_TOKEN=' /etc/swarm_os.env 2>/dev/null; then
    NEW_TOKEN=\$(openssl rand -hex 32)
    echo "SWARM_AUTH_TOKEN=\$NEW_TOKEN" >> /etc/swarm_os.env
    echo "Generated unique SWARM_AUTH_TOKEN for this install"
fi
EOF

# If no usable host password hash was preserved above, set one now. This runs
# as a normal foreground command (not through the heredoc above) so passwd's
# prompts reach the real terminal instead of leftover heredoc input.
if [ -z "$HOST_PW_HASH" ] || [ "$HOST_PW_HASH" = "!" ] || [ "$HOST_PW_HASH" = "*" ]; then
    echo "Please set a password for user 'i30ltz' (used for sudo and terminal commands):"
    if [ -t 0 ]; then
        # Keep asking — a typo'd confirmation used to leave the account with
        # no password at all, so sudo could never be used after first boot.
        until arch-chroot "$MOUNT_POINT" passwd i30ltz; do
            echo "Passwords didn't match or were rejected — try again."
        done
    else
        echo "WARNING: no terminal attached, so the i30ltz password was NOT set."
        echo "After first boot, open foot (Super+Enter) and run: passwd"
    fi
fi

banner "Cleaning up..."
sync
umount -R "$MOUNT_POINT"

echo ""
echo -e "${GRN}============================================================${NC}"
echo -e "${GRN}  SWARM OS INSTALLED SUCCESSFULLY! (Standard Btrfs Root)${NC}"
echo -e "${GRN}============================================================${NC}"
echo ""
echo -e "  Root Device : $TARGET_ROOT (btrfs)"
echo -e "  Root UUID   : ${ROOT_UUID}"
echo -e "  EFI Device  : $TARGET_EFI"
echo ""
echo -e "${YLW}  Installation complete! You can now reboot: sudo reboot${NC}"
