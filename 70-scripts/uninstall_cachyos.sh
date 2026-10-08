#!/usr/bin/env bash
# ==============================================================================
# uninstall_cachyos.sh — Safely decommission and reclaim CachyOS on SWARM OS Host
# ==============================================================================
# HARD SAFETY INVARIANTS:
#   1. NEVER touch the lucy-master LUKS partition (GPT PARTUUID 20a96573-0c80-4393-ba95-40a64964b39e).
#   2. NEVER wipe the entire disk.
#   3. ONLY target the former CachyOS root (GPT PARTUUID 993d0098-1b2f-44a2-b51d-11c2bfeddc40).
#   4. Debian root/EFI and every other partition must remain untouched.
#   Partitions are found by PARTUUID, never by /dev/sdX letter: letters swap between boots
#   ("sda3"/"sda4" below are only the names on the 2026-10-07 Debian boot).
#   The former CachyOS root becomes the Recovery OS root, formatted btrfs (user decision 2026-10-07).
# ==============================================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "ERROR: This script must be run with sudo: sudo bash $0" >&2; exit 1; }

echo "=== SWARM OS: CachyOS Decommission & Uninstall Helper ==="
echo

# 1. Verification of current environment
echo "[1/5] Verifying disk topology..."
TARGET_PARTUUID=993d0098-1b2f-44a2-b51d-11c2bfeddc40    # former CachyOS root -> Recovery OS root
PROTECT_PARTUUID=20a96573-0c80-4393-ba95-40a64964b39e   # lucy-master LUKS: never touched
TARGET=$(readlink -f "/dev/disk/by-partuuid/$TARGET_PARTUUID" 2>/dev/null || true)
PROTECT=$(readlink -f "/dev/disk/by-partuuid/$PROTECT_PARTUUID" 2>/dev/null || true)
[[ -b $TARGET && -b $PROTECT ]] || { echo "FATAL: target or lucy-master partition not found by PARTUUID; aborting." >&2; exit 1; }
[[ $TARGET != "$PROTECT" ]] || { echo "FATAL: target and protected partition are the same device." >&2; exit 1; }
[[ $(lsblk -ndo PKNAME "$TARGET") == "$(lsblk -ndo PKNAME "$PROTECT")" ]] || { echo "FATAL: target is not on the same disk as lucy-master; aborting." >&2; exit 1; }
echo "Target:    $TARGET ($(lsblk -ndo SIZE "$TARGET"), PARTUUID $TARGET_PARTUUID)"
echo "Protected: $PROTECT (lucy-master, will NOT be touched)"

ROOT_SRC=$(findmnt -n -o SOURCE /)
ACTIVE_ROOT=$(readlink -f "${ROOT_SRC%%\[*}")
echo "Active Host Root: $ACTIVE_ROOT"
if [[ "$ACTIVE_ROOT" == "$TARGET" ]]; then
  echo "FATAL: You are currently booted into the target partition! Cannot uninstall active OS." >&2
  exit 1
fi

# 2. Unmount /mnt/endeavor
echo
echo "[2/5] Checking /mnt/endeavor mount state..."
if findmnt /mnt/endeavor >/dev/null 2>&1; then
  echo "Unmounting /mnt/endeavor ($TARGET)..."
  if ! umount /mnt/endeavor 2>/dev/null; then
    echo "Standard umount reported busy (open desktop color profiles/Xwayland); performing lazy unmount (umount -l)..."
    umount -l /mnt/endeavor
  fi
  echo "Successfully unmounted /mnt/endeavor."
else
  echo "/mnt/endeavor is already unmounted."
fi

# 3. Clean /etc/fstab
echo
echo "[3/5] Cleaning /etc/fstab..."
if grep -q "ef9acba2-3816-4fd7-bdd7-a9526816d3f0" /etc/fstab || grep -q "/mnt/endeavor" /etc/fstab; then
  FSTAB_BAK="/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
  cp -a /etc/fstab "$FSTAB_BAK"
  echo "Backed up /etc/fstab to $FSTAB_BAK"
  sed -i '/ef9acba2-3816-4fd7-bdd7-a9526816d3f0/d' /etc/fstab
  sed -i '/\/mnt\/endeavor/d' /etc/fstab
  systemctl daemon-reload
  echo "Removed /mnt/endeavor from /etc/fstab."
else
  echo "No /mnt/endeavor entry found in /etc/fstab."
fi

# 4. Clean EFI NVRAM boot entries
echo
echo "[4/5] Cleaning CachyOS boot entries from UEFI NVRAM..."
for bootnum in 0001 0002 000C 000D; do
  if efibootmgr | grep -q "Boot${bootnum}"; then
    echo "Removing UEFI entry Boot${bootnum}..."
    efibootmgr -b "${bootnum}" -B >/dev/null 2>&1 || true
  fi
done

echo "Updating Debian GRUB menu..."
update-grub

# 5. Partition reclamation prompt
echo
echo "[5/5] Partition Reclamation (Wiping CachyOS root partition)"
echo "Target Partition: $TARGET ($(lsblk -ndo SIZE "$TARGET"))"
echo "Backups stored safely at: /mnt/downloads/cachyos-backup/"
echo
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

echo "This partition is the future Recovery OS root and is formatted btrfs (user decision 2026-10-07)."
read -p "To ERASE $TARGET and format it btrfs (label 'Recovery-OS'), type the device path exactly (anything else skips): " -r CONFIRM
if [[ "$CONFIRM" == "$TARGET" ]]; then
  if findmnt -S "$TARGET" >/dev/null 2>&1; then
    echo "FATAL: $TARGET is still mounted; unmount it first." >&2
    exit 1
  fi
  echo "Formatting $TARGET as btrfs..."
  udevadm settle
  wipefs -a "$TARGET" 2>/dev/null || true
  mkfs.btrfs -f -L "Recovery-OS" "$TARGET"
  echo "Formatted $TARGET as btrfs 'Recovery-OS'."
  echo "New filesystem UUID: $(blkid -s UUID -o value "$TARGET") - record it in CLAUDE.md and tell the Recovery AI."
else
  echo "Skipped formatting $TARGET. The Recovery installer will format it when RC-11 runs."
fi

echo
echo "=== CachyOS decommission complete! SWARM OS is running 100% Debian ==="
