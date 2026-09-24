#!/usr/bin/env bash
# diagnose_ventoy_grub.sh — SWARM OS | 2026-09-24 | v1.0.0
# Run from CachyOS or SWARM OS to verify Ventoy EFI partition and GRUB entry.
set -euo pipefail

echo "══════════════════════════════════════════════"
echo "  VENTOY GRUB DIAGNOSTIC — $(date '+%Y-%m-%d %H:%M')"
echo "══════════════════════════════════════════════"
echo ""

echo "── Block devices with labels and UUIDs ──"
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT 2>/dev/null || true
echo ""

echo "── blkid — all partitions ──"
blkid 2>/dev/null | sort || true
echo ""

echo "── Ventoy-related partitions ──"
blkid 2>/dev/null | grep -i "ventoy\|VTOY\|E039" || echo "  (none found matching ventoy/VTOY/E039)"
echo ""

echo "── EFI partition at /dev/disk/by-label/ ──"
ls -la /dev/disk/by-label/ 2>/dev/null | grep -i "VTOY\|EFI\|ventoy" || echo "  (no VTOYEFI/EFI labels found)"
echo ""

# Try to mount Ventoy EFI partition and check files
VTOY_DEV=""
if blkid 2>/dev/null | grep -q "VTOYEFI"; then
  VTOY_DEV=$(blkid 2>/dev/null | grep VTOYEFI | cut -d: -f1 | head -1)
elif blkid 2>/dev/null | grep -qi "E039-AD96"; then
  VTOY_DEV=$(blkid 2>/dev/null | grep -i "E039-AD96" | cut -d: -f1 | head -1)
fi

if [ -n "$VTOY_DEV" ]; then
  echo "── Ventoy EFI device found: $VTOY_DEV ──"
  UUID_FOUND=$(blkid -s UUID -o value "$VTOY_DEV" 2>/dev/null || echo "unknown")
  LABEL_FOUND=$(blkid -s LABEL -o value "$VTOY_DEV" 2>/dev/null || echo "unknown")
  echo "  UUID:  $UUID_FOUND"
  echo "  LABEL: $LABEL_FOUND"
  echo ""
  TMP=$(mktemp -d)
  if mount -o ro "$VTOY_DEV" "$TMP" 2>/dev/null; then
    echo "── EFI files on $VTOY_DEV ──"
    find "$TMP/EFI" -name "*.EFI" -o -name "*.efi" 2>/dev/null | head -20 || echo "  (no EFI files found)"
    umount "$TMP"
  else
    echo "  Could not mount $VTOY_DEV (may need root)"
  fi
  rmdir "$TMP"
else
  echo "── No Ventoy EFI partition detected ──"
  echo "  Is the Ventoy USB plugged in?"
fi

echo ""
echo "── Current GRUB Ventoy entry UUID in 09_swarm_multiboot ──"
grep "E039\|VTOYEFI" /mnt/Lucy/grub_themes/09_swarm_multiboot 2>/dev/null || \
grep "E039\|VTOYEFI" /etc/grub.d/09_swarm_multiboot 2>/dev/null || echo "  (file not found)"

echo ""
echo "── SUMMARY ──"
echo "  If UUID above does NOT match what blkid reports for your Ventoy EFI partition,"
echo "  edit /mnt/Lucy/grub_themes/09_swarm_multiboot and update the UUID on the"
echo "  'search --fs-uuid' line, then run:"
echo "    sudo /mnt/Lucy/70-scripts/install_dual_grub_themes.sh"
echo ""
echo "  If UUID matches but boot still fails, the --force flag fix will resolve it."
echo "  Just run the reinstall above."
echo "══════════════════════════════════════════════"
