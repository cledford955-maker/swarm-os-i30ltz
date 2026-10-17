#!/usr/bin/env bash
# add_debian_chainload_to_swarm_grub.sh — make the installed SWARM OS GRUB
# (nvme0n1p2, label swarm-root) offer "Debian GNU/Linux", which chainloads
# Debian's own bootloader from Debian's EFI partition.
#
#   sudo add_debian_chainload_to_swarm_grub.sh [--dry-run]
#
# Boot picture: firmware -> SWARM GRUB (NVMe ESP, \EFI\SWARM_OS) -> menu entry
# -> \EFI\debian\shimx64.efi on Debian's ESP (sdb1) -> Debian's GRUB.
# It does not change the firmware boot order; that is a separate, deliberate step.
#
# What it edits on the installed root (both, so the change is live now AND
# survives the next grub-mkconfig):
#   etc/grub.d/40_custom    the source the installer wrote
#   boot/grub/grub.cfg      the generated menu GRUB reads at boot
# plus one theme icon (boot/grub/themes/swarm_os/icons/debian.png).
# The entry is a marker-delimited block (### SWARM-DEBIAN-CHAINLOAD-BEGIN/END ###),
# placed just before the CachyOS chainload entry, so re-running replaces it
# instead of duplicating it. Secure Boot must be off (it is: an unsigned GRUB
# cannot chainload shim under Secure Boot).
#
# Safety: nothing is written until every check passes; originals are copied to
# boot/grub/backups/debian-chainload-<stamp>/ first (outside grub.d, so the
# backup is never executed as a grub.d script); the patched files are checked
# with grub-script-check and the originals are put back if that fails.
# Undo: copy the two backed-up files back, or delete the marked block.
set -euo pipefail

DRY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done
[ "$EUID" -eq 0 ] || { echo "REFUSED: run with sudo (grub.cfg is root-only)" >&2; exit 1; }

ROOT_DEV=/dev/nvme0n1p2
DEBIAN_ESP_UUID=${DEBIAN_ESP_UUID:-362A-E48F}
DEBIAN_LOADER=/EFI/debian/shimx64.efi
ICON_SRC=${ICON_SRC:-/mnt/Lucy/grub_themes/swarm_os/icons/debian.png}
STAMP=$(date +%Y%m%d-%H%M%S)

die() { echo "REFUSED: $*" >&2; exit 1; }
say() { echo "  $*"; }

# ── target root ──────────────────────────────────────────────────────────────
[ -b "$ROOT_DEV" ] || die "$ROOT_DEV does not exist"
[ "$(lsblk -no LABEL "$ROOT_DEV" | head -n1)" = swarm-root ] || die "$ROOT_DEV is not labelled swarm-root"
TOP=$(findmnt -rn -S "$ROOT_DEV" -o TARGET | head -n1 || true)
[ -n "$TOP" ] || die "$ROOT_DEV is not mounted (mount its top level, e.g. /mnt/swarm)"
R=$TOP/@
CUSTOM=$R/etc/grub.d/40_custom
CFG=$R/boot/grub/grub.cfg
THEME_ICONS=$R/boot/grub/themes/swarm_os/icons
for f in "$CUSTOM" "$CFG"; do [ -f "$f" ] || die "missing $f"; done
for f in "$CUSTOM" "$CFG"; do
  grep -q '^menuentry "CachyOS (chainload)"' "$f" || die "$f has no CachyOS anchor line to insert before"
done
say "target: $R"

# ── Debian's ESP must exist and really contain the loader ────────────────────
[ -e "/dev/disk/by-uuid/$DEBIAN_ESP_UUID" ] || die "no partition with UUID $DEBIAN_ESP_UUID (Debian's EFI partition)"
ESP_DEV=$(readlink -f "/dev/disk/by-uuid/$DEBIAN_ESP_UUID")
ESP_MNT=$(findmnt -rn -S "$ESP_DEV" -o TARGET | head -n1 || true)
TMP_MNT=""
if [ -z "$ESP_MNT" ]; then
  TMP_MNT=$(mktemp -d); mount -o ro "$ESP_DEV" "$TMP_MNT"; ESP_MNT=$TMP_MNT
fi
found=0; [ -f "$ESP_MNT$DEBIAN_LOADER" ] && found=1
[ -z "$TMP_MNT" ] || { umount "$TMP_MNT"; rmdir "$TMP_MNT"; }
[ "$found" = 1 ] || die "$DEBIAN_LOADER not found on $ESP_DEV"
say "Debian ESP: $ESP_DEV ($DEBIAN_ESP_UUID) has $DEBIAN_LOADER"

# ── Secure Boot must be off, or the chainload would be refused at boot ───────
sb=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -n1 || true)
if [ -n "$sb" ] && [ "$(od -An -t u1 -j4 -N1 "$sb" | tr -d ' ')" = 1 ]; then
  die "Secure Boot is ON; an unsigned GRUB cannot chainload Debian's shim"
fi

# ── the block ────────────────────────────────────────────────────────────────
BLOCK=$(mktemp)
cat > "$BLOCK" <<EOF
### SWARM-DEBIAN-CHAINLOAD-BEGIN ###
menuentry "Debian GNU/Linux" --class debian --class gnu-linux --class os {
  insmod part_gpt
  insmod fat
  insmod chain
  search --no-floppy --fs-uuid --set=root $DEBIAN_ESP_UUID
  chainloader $DEBIAN_LOADER
}
### SWARM-DEBIAN-CHAINLOAD-END ###
EOF

# Replace any earlier copy of the block, then insert before the CachyOS entry.
patch_to() {   # <in> <out>
  awk -v blockfile="$BLOCK" '
    BEGIN { while ((getline line < blockfile) > 0) block = block line "\n" }
    /^### SWARM-DEBIAN-CHAINLOAD-BEGIN ###$/ { skip = 1 }
    skip { if ($0 ~ /^### SWARM-DEBIAN-CHAINLOAD-END ###$/) skip = 0; next }
    /^menuentry "CachyOS \(chainload\)"/ && !done { printf "%s", block; done = 1 }
    { print }
    END { if (!done) exit 3 }
  ' "$1" > "$2"
}

NEW_CUSTOM=$(mktemp); NEW_CFG=$(mktemp)
patch_to "$CUSTOM" "$NEW_CUSTOM" || die "could not place the block in 40_custom"
patch_to "$CFG"    "$NEW_CFG"    || die "could not place the block in grub.cfg"

# ── validate the patched result BEFORE writing anything ─────────────────────
check() {      # <file> <label>
  if command -v grub-script-check >/dev/null 2>&1; then
    grub-script-check "$1" || die "grub-script-check rejected the patched $2"
  else
    say "grub-script-check not installed; skipping syntax check of $2"
  fi
}
check "$NEW_CFG" grub.cfg
OUT=$(mktemp); sh "$NEW_CUSTOM" > "$OUT"; check "$OUT" "40_custom output"
grep -q '^### SWARM-DEBIAN-CHAINLOAD-BEGIN ###$' "$OUT" || die "40_custom would not emit the Debian entry"
say "patched files pass the GRUB syntax check"

echo "---- change to grub.cfg ----"
diff -u "$CFG" "$NEW_CFG" | sed -n '1,40p' || true
echo "-----------------------------"

if [ "$DRY" = 1 ]; then
  echo "dry-run: nothing written."
  rm -f "$BLOCK" "$NEW_CUSTOM" "$NEW_CFG" "$OUT"
  exit 0
fi

# ── back up, then write in place (keeps owner and mode) ─────────────────────
BK=$R/boot/grub/backups/debian-chainload-$STAMP
mkdir -p "$BK"
cp -p "$CUSTOM" "$BK/40_custom.orig"; cp -p "$CFG" "$BK/grub.cfg.orig"
chmod 644 "$BK/40_custom.orig"        # a backup must never be executable
cat "$NEW_CUSTOM" > "$CUSTOM"
cat "$NEW_CFG"    > "$CFG"

# ── read back what is now on disk and re-check it ────────────────────────────
if ! { grub-script-check "$CFG" 2>/dev/null || ! command -v grub-script-check >/dev/null; }; then
  cat "$BK/40_custom.orig" > "$CUSTOM"; cat "$BK/grub.cfg.orig" > "$CFG"
  die "post-write check failed; originals restored from $BK"
fi
[ "$(grep -c '^### SWARM-DEBIAN-CHAINLOAD-BEGIN ###$' "$CFG")" = 1 ] || { cat "$BK/grub.cfg.orig" > "$CFG"; cat "$BK/40_custom.orig" > "$CUSTOM"; die "expected exactly one Debian block in grub.cfg; originals restored"; }

# ── theme icon ───────────────────────────────────────────────────────────────
if [ -f "$ICON_SRC" ] && [ -d "$THEME_ICONS" ]; then
  cp -f "$ICON_SRC" "$THEME_ICONS/debian.png"
  chown --reference="$THEME_ICONS/cachyos.png" "$THEME_ICONS/debian.png" 2>/dev/null || true
  chmod 644 "$THEME_ICONS/debian.png"
  say "icon installed: $THEME_ICONS/debian.png"
else
  say "no icon installed (missing $ICON_SRC or theme icons dir) — the entry just shows without one"
fi

rm -f "$BLOCK" "$NEW_CUSTOM" "$NEW_CFG" "$OUT"
echo "done. SWARM menu entries now:"
grep -n -E '^\s*menuentry|^### SWARM-DEBIAN' "$CFG" | grep -v menuentry_id | cut -c1-90 | sed -n '1,14p'
echo "backups: $BK   (restore: cp -p 40_custom.orig -> etc/grub.d/40_custom, grub.cfg.orig -> boot/grub/grub.cfg)"
