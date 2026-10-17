#!/usr/bin/env bash
# tidy_swarm_grub_menu.sh — clean up the installed SWARM OS GRUB menu
# (nvme0n1p2, label swarm-root) from another OS:
#   * the main entry says "SWARM OS" (not "Arch Linux"), with the SWARM icon class
#   * dead entries are removed: CachyOS (decommissioned), EndeavourOS (its
#     partition no longer exists), Ventoy (it pointed at a stick UUID that no
#     longer exists), and the duplicate "UEFI Firmware Settings" the custom
#     block added next to the stock one
#   * kept: SWARM OS, Advanced options (fallback initramfs), UEFI Firmware
#     Settings, Debian GNU/Linux, Reboot, Shutdown, the snapshot entry, memtest
#
#   sudo tidy_swarm_grub_menu.sh [--dry-run]
#   tidy_swarm_grub_menu.sh --root-dir DIR [--dry-run]   # operate on a COPY of the
#                                                        # files (etc/default/grub,
#                                                        # etc/default/grub-btrfs/config,
#                                                        # etc/grub.d/{10_linux,40_custom},
#                                                        # boot/grub/grub.cfg); no root
#
# Durable, not cosmetic: the SOURCES grub-mkconfig reads are edited as well as the
# generated grub.cfg, so a later regeneration gives the same menu:
#   etc/default/grub                 GRUB_DISTRIBUTOR="SWARM OS"
#   etc/grub.d/10_linux              OS="${GRUB_DISTRIBUTOR}"   (was "... Linux")
#   etc/grub.d/40_custom             dead entries removed
#   etc/default/grub-btrfs/config    GRUB_BTRFS_SUBMENUNAME="SWARM OS snapshots"
# The live grub.cfg is patched surgically so every boot-critical line (linux,
# initrd, search, root=) stays byte-identical; that is asserted, not assumed.
# 10_linux belongs to the grub package, so a grub package upgrade can restore the
# "... Linux" suffix (the menu then reads "SWARM OS Linux"); re-run this script.
#
# Safety: every change is built on temp copies and checked first; originals are
# saved under boot/grub/backups/tidy-menu-<stamp>/ (non-executable, outside
# grub.d); the written files are re-checked and put back if anything is off.
set -euo pipefail

DRY=0; ROOT_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY=1 ;;
    --root-dir) ROOT_DIR=${2:?--root-dir needs a directory}; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "REFUSED: $*" >&2; exit 1; }
say() { echo "  $*"; }
STAMP=$(date +%Y%m%d-%H%M%S)

if [ -n "$ROOT_DIR" ]; then
  R=$ROOT_DIR; [ -d "$R" ] || die "$R is not a directory"
  say "TEST MODE on a copy: $R"
else
  [ "$EUID" -eq 0 ] || die "run with sudo (grub.cfg is root-only)"
  ROOT_DEV=/dev/nvme0n1p2
  [ -b "$ROOT_DEV" ] || die "$ROOT_DEV does not exist"
  [ "$(lsblk -no LABEL "$ROOT_DEV" | head -n1)" = swarm-root ] || die "$ROOT_DEV is not labelled swarm-root"
  TOP=$(findmnt -rn -S "$ROOT_DEV" -o TARGET | head -n1 || true)
  [ -n "$TOP" ] || die "$ROOT_DEV is not mounted (mount its top level, e.g. /mnt/swarm)"
  R=$TOP/@
  say "target: $R"
fi

DEF=$R/etc/default/grub
BTR=$R/etc/default/grub-btrfs/config
LIN=$R/etc/grub.d/10_linux
CUS=$R/etc/grub.d/40_custom
CFG=$R/boot/grub/grub.cfg
for f in "$DEF" "$LIN" "$CUS" "$CFG"; do [ -f "$f" ] || die "missing $f"; done
grep -q 'SWARM-DEBIAN-CHAINLOAD-BEGIN' "$CFG" || die "the Debian entry is not in grub.cfg; run add_debian_chainload_to_swarm_grub.sh first"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
N_DEF=$TMP/default-grub; N_BTR=$TMP/grub-btrfs-config; N_LIN=$TMP/10_linux; N_CUS=$TMP/40_custom; N_CFG=$TMP/grub.cfg

# ── remove whole menuentry blocks by title (brace-depth aware) ──────────────
# region=1: act on the whole file (40_custom). region=0: only between the
# BEGIN/END 40_custom markers of the generated grub.cfg.
strip_dead() {   # <in> <out> <region 0|1>
  awk -v region="$3" '
    function opens(s,  t){ t=s; return gsub(/[{]/,"",t) }
    function closes(s, t){ t=s; return gsub(/[}]/,"",t) }
    /^### BEGIN \/etc\/grub.d\/40_custom ###$/ { inreg=1 }
    /^### END \/etc\/grub.d\/40_custom ###$/   { inreg=0 }
    skip { depth += opens($0) - closes($0); if (depth <= 0) skip=0; next }
    (region || inreg) && /^[ \t]*menuentry "(CachyOS \(chainload\)|EndeavourOS|Ventoy|UEFI Firmware Settings)"/ {
      skip=1; depth = opens($0) - closes($0); if (depth <= 0) skip=0; next }
    { print }
  ' "$1" > "$2"
}

# ── build the new versions ───────────────────────────────────────────────────
# default/grub
if grep -q '^GRUB_DISTRIBUTOR=' "$DEF"; then
  sed 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="SWARM OS"/' "$DEF" > "$N_DEF"
else
  { cat "$DEF"; echo 'GRUB_DISTRIBUTOR="SWARM OS"'; } > "$N_DEF"
fi
# 10_linux: stop appending " Linux" to the distributor name
if grep -q 'OS="${GRUB_DISTRIBUTOR} Linux"' "$LIN"; then
  sed 's/OS="${GRUB_DISTRIBUTOR} Linux"/OS="${GRUB_DISTRIBUTOR}"/' "$LIN" > "$N_LIN"
elif grep -q 'OS="${GRUB_DISTRIBUTOR}"' "$LIN"; then
  cp "$LIN" "$N_LIN"                          # already patched
else
  die "10_linux has neither the stock nor the patched OS= line; refusing to guess"
fi
# grub-btrfs submenu name (only if the package's config exists)
HAVE_BTR=0
if [ -f "$BTR" ]; then
  HAVE_BTR=1
  if grep -q -E '^#?GRUB_BTRFS_SUBMENUNAME=' "$BTR"; then
    sed -E 's/^#?GRUB_BTRFS_SUBMENUNAME=.*/GRUB_BTRFS_SUBMENUNAME="SWARM OS snapshots"/' "$BTR" > "$N_BTR"
  else
    { cat "$BTR"; echo 'GRUB_BTRFS_SUBMENUNAME="SWARM OS snapshots"'; } > "$N_BTR"
  fi
fi
# 40_custom (source) and grub.cfg (generated)
strip_dead "$CUS" "$N_CUS" 1
strip_dead "$CFG" "$TMP/cfg.stripped" 0
sed -E \
  -e "s/^menuentry 'Arch Linux' /menuentry 'SWARM OS' /" \
  -e "s/'Advanced options for Arch Linux'/'Advanced options for SWARM OS'/" \
  -e "s/'Arch Linux, with Linux/'SWARM OS, with Linux/" \
  -e "s/submenu 'Arch Linux snapshots'/submenu 'SWARM OS snapshots'/" \
  -e "s/--class arch --class gnu-linux/--class swarm --class gnu-linux/" \
  "$TMP/cfg.stripped" > "$N_CFG"

# ── checks on the NEW files (nothing written yet) ────────────────────────────
check_cfg() {   # <grub.cfg> <label>
  local f=$1 l=$2 n
  grep -q "^menuentry 'SWARM OS' --class swarm " "$f"        || die "$l: main entry not renamed"
  grep -q "'Advanced options for SWARM OS'" "$f"             || die "$l: advanced submenu not renamed"
  grep -q "'SWARM OS, with Linux linux (fallback initramfs)'" "$f" || die "$l: fallback entry not renamed"
  ! grep -q "Arch Linux" "$f"                                || die "$l: 'Arch Linux' still present"
  n=$(grep -c 'SWARM-DEBIAN-CHAINLOAD-BEGIN' "$f");      [ "$n" = 1 ] || die "$l: expected 1 Debian block, found $n"
  ! grep -q -E 'CachyOS \(chainload\)|menuentry "EndeavourOS"|menuentry "Ventoy"' "$f" || die "$l: dead entry still present"
  n=$(grep -c "UEFI Firmware Settings" "$f");            [ "$n" = 1 ] || die "$l: expected 1 firmware entry, found $n"
  grep -q 'menuentry "Reboot"' "$f" && grep -q 'menuentry "Shutdown"' "$f" || die "$l: Reboot/Shutdown missing"
}
check_cfg "$N_CFG" "new grub.cfg"
# boot-critical lines must be untouched: same linux / initrd / search / root= lines
# (the removed entries carry their own search/insmod lines for other disks, so those
# are not compared; every line about THIS root, and every linux/initrd line, is)
ROOTUUID=$(sed -n 's/.*root=UUID=\([0-9a-fA-F-]*\).*/\1/p' "$DEF" | head -n1)
[ -n "$ROOTUUID" ] || die "could not read the root UUID from $DEF"
crit() { grep -v -E '^\s*(menuentry|submenu)[ ]' "$1" | grep -E "^\s*(linux|initrd)[ \t]|$ROOTUUID" | sed 's/^\s*//' | sort; }
diff <(crit "$CFG") <(crit "$N_CFG") >/dev/null || die "boot-critical lines would change (linux/initrd/anything naming the root $ROOTUUID) — refusing"
say "boot-critical lines (every linux/initrd line and every line naming the root filesystem) identical before/after"

if command -v grub-script-check >/dev/null 2>&1; then
  grub-script-check "$N_CFG" || die "grub-script-check rejected the new grub.cfg"
  sh "$N_CUS" > "$TMP/40_custom.out"; grub-script-check "$TMP/40_custom.out" || die "grub-script-check rejected the new 40_custom output"
  say "new grub.cfg and 40_custom pass the GRUB syntax check"
else
  say "grub-script-check not installed; syntax check skipped"
fi

# What would a regeneration produce? Run the template's own logic in isolation.
dist=$(sed -n 's/^GRUB_DISTRIBUTOR="\(.*\)"$/\1/p' "$N_DEF")
sim=$( GRUB_DISTRIBUTOR="$dist"; CLASS_BLOCK=$(awk '/^CLASS=/{f=1} f{print} f&&/^fi$/{exit}' "$N_LIN"); eval "$CLASS_BLOCK"; printf '%s|%s' "$OS" "$CLASS" )
[ "$sim" = "SWARM OS|--class swarm --class gnu-linux --class gnu --class os" ] || die "10_linux would generate '$sim', not the expected title/class"
say "regeneration check: 10_linux + GRUB_DISTRIBUTOR=\"$dist\" give title 'SWARM OS' and class 'swarm' (same as the patched grub.cfg)"
grep -q 'SWARM-DEBIAN-CHAINLOAD-BEGIN' "$N_CUS" || die "40_custom lost the Debian block"

# ── show what changes ────────────────────────────────────────────────────────
echo "---- grub.cfg changes ----"; diff -u "$CFG" "$N_CFG" | sed -n '1,90p' || true
echo "---- other files ----"
diff -u "$DEF" "$N_DEF" | grep -E '^[+-][^+-]' || true
diff -u "$LIN" "$N_LIN" | grep -E '^[+-][^+-]' || true
if [ "$HAVE_BTR" = 1 ]; then diff -u "$BTR" "$N_BTR" | grep -E '^[+-][^+-]' || true; fi
echo "---- resulting menu ----"
grep -n -E "^\s*(menuentry|submenu) " "$N_CFG" | sed 's/ \$menuentry_id_option.*{/ {/; s/ --class [^{]*{/ {/' | cut -c1-90

if [ "$DRY" = 1 ]; then echo "dry-run: nothing written."; exit 0; fi

# ── back up, write in place (keeps owner/mode), re-check, roll back on failure
BK=$R/boot/grub/backups/tidy-menu-$STAMP
mkdir -p "$BK"
cp -p "$DEF" "$BK/default-grub"; cp -p "$LIN" "$BK/10_linux.orig"; cp -p "$CUS" "$BK/40_custom.orig"; cp -p "$CFG" "$BK/grub.cfg.orig"
if [ "$HAVE_BTR" = 1 ]; then cp -p "$BTR" "$BK/grub-btrfs-config"; fi
chmod 644 "$BK/10_linux.orig" "$BK/40_custom.orig"   # a backup must never be executable
restore() {
  cat "$BK/default-grub" > "$DEF"; cat "$BK/10_linux.orig" > "$LIN"; cat "$BK/40_custom.orig" > "$CUS"; cat "$BK/grub.cfg.orig" > "$CFG"
  if [ "$HAVE_BTR" = 1 ]; then cat "$BK/grub-btrfs-config" > "$BTR"; fi
}
cat "$N_DEF" > "$DEF"; cat "$N_LIN" > "$LIN"; cat "$N_CUS" > "$CUS"; cat "$N_CFG" > "$CFG"
if [ "$HAVE_BTR" = 1 ]; then cat "$N_BTR" > "$BTR"; fi

ok=1
cmp -s "$N_CFG" "$CFG" || ok=0
cmp -s "$N_CUS" "$CUS" || ok=0
( check_cfg "$CFG" "written grub.cfg" ) >/dev/null 2>&1 || ok=0
if command -v grub-script-check >/dev/null 2>&1; then grub-script-check "$CFG" >/dev/null 2>&1 || ok=0; fi
if [ "$ok" != 1 ]; then restore; die "post-write check failed; originals restored from $BK"; fi
say "written and re-checked."
echo "done. backups: $BK"
echo "restore: copy default-grub -> etc/default/grub, 10_linux.orig -> etc/grub.d/10_linux (keep it executable), 40_custom.orig -> etc/grub.d/40_custom (keep it executable), grub.cfg.orig -> boot/grub/grub.cfg"
