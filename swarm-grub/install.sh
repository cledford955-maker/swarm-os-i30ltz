#!/usr/bin/env bash
# Install the swarm-grub theme into DEBIAN's GRUB.
#   sudo bash swarm-grub/install.sh                  install / update the theme
#   sudo bash swarm-grub/install.sh --with-entries   ...and the SWARM OS / Recovery OS / Ventoy / Power menu entries
#   sudo bash swarm-grub/install.sh --uninstall      remove the theme, the entries and the settings this script added
#        bash swarm-grub/install.sh --dry-run        rehearse in a scratch directory (no root, changes nothing)
#
# It builds the theme, copies it to /boot/grub/themes/swarm-grub, adds one managed block (GRUB_THEME, gfxterm,
# GRUB_GFXMODE, GRUB_BACKGROUND) to /etc/default/grub and regenerates /boot/grub/grub.cfg. With --with-entries it
# also installs /etc/grub.d/20_swarm_entries (from entries/) and turns os-prober off so nothing is listed twice;
# --without-entries removes them again, and with neither flag an already installed entries script is left alone.
# It never runs grub-install or touches the EFI partition or any disk, and it never leaves a half-written
# grub.cfg: the new one is generated aside, checked, then swapped in. Backups of /etc/default/grub, grub.cfg, the
# previous theme and entries script: /var/backups/swarm-grub/<timestamp>/.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
THEME=swarm-grub
BEGIN='# BEGIN SWARM-GRUB THEME (managed by swarm-grub/install.sh - edit outside this block)'
END='# END SWARM-GRUB THEME'
THEME_DIR_CFG=/boot/grub/themes/$THEME             # paths as GRUB's own tools see them
THEME_CFG=$THEME_DIR_CFG/theme.txt

usage() { sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }
say()   { echo "swarm-grub: $*"; }

MODE=install DRY=0 STAGE="" ENTRIES_FLAG=keep WANT_ENTRIES=0
while (($#)); do
  case $1 in
    --uninstall)       MODE=uninstall ;;
    --dry-run)         DRY=1 ;;
    --with-entries)    ENTRIES_FLAG=yes ;;
    --without-entries) ENTRIES_FLAG=no ;;
    --stage)           STAGE=$(realpath -m "${2:?--stage needs a directory}"); shift ;;   # used by the tests
    -h|--help)         usage; exit 0 ;;
    *)                 usage >&2; exit 2 ;;
  esac
  shift
done

CLEAN=() BK="" ARMED=0
cleanup() { local d; for d in "${CLEAN[@]}"; do rm -rf "$d"; done; }
trap cleanup EXIT

if ((DRY)); then STAGE=$(mktemp -d); CLEAN+=("$STAGE"); fi

# ROOT prefixes every system path: empty for the real thing, a scratch directory when rehearsing.
ROOT=$STAGE
BOOT_GRUB=$ROOT/boot/grub
DEFAULT_FILE=$ROOT/etc/default/grub
BACKUPS=$ROOT/var/backups/swarm-grub
DEST=$BOOT_GRUB/themes/$THEME
ENTRIES_SRC=$HERE/entries/20_swarm_entries
ENTRIES_DST=$ROOT/etc/grub.d/20_swarm_entries

# Put /etc/default/grub, the theme directory and the entries script back the way the backup has them.
# grub.cfg is never touched before its replacement has passed every check, so it needs no restoring.
rollback() {
  trap - ERR; ARMED=0
  echo "swarm-grub: failed - restoring the previous GRUB settings from $BK" >&2
  cp -a "$BK/default-grub" "$DEFAULT_FILE"
  if [[ $MODE == install ]]; then
    rm -rf "$DEST"
    [[ ! -d $BK/previous-theme ]] || cp -a "$BK/previous-theme" "$DEST"
  fi
  if [[ -f $BK/previous-entries ]]; then cp -a "$BK/previous-entries" "$ENTRIES_DST"; else rm -f "$ENTRIES_DST"; fi
  rm -f "$BOOT_GRUB/grub.cfg.swarm-new"
  exit 1
}
die() { echo "swarm-grub: $*" >&2; if ((ARMED)); then rollback; fi; exit 1; }
trap 'if ((ARMED)); then rollback; fi' ERR

if [[ -n $STAGE ]]; then
  mkdir -p "$BOOT_GRUB/themes" "$(dirname "$DEFAULT_FILE")" "$ROOT/etc/grub.d"
  [[ -f $DEFAULT_FILE ]] || cp /etc/default/grub "$DEFAULT_FILE"
else
  [[ $EUID == 0 ]] || die "run with sudo:  sudo bash $0 ${*:-}"
  . /etc/os-release
  [[ ${ID:-} == debian ]] || die "this is ${PRETTY_NAME:-not Debian}, not Debian - refusing (the SWARM OS and Recovery OS GRUBs have their own themes)"
  [[ -d /boot/grub && -f /etc/default/grub ]] || die "/boot/grub or /etc/default/grub not found - is GRUB installed here?"
  command -v grub-mkconfig >/dev/null && command -v grub-script-check >/dev/null || die "grub-mkconfig / grub-script-check not found"
fi

strip_block() { sed -i '/^# BEGIN SWARM-GRUB THEME/,/^# END SWARM-GRUB THEME$/d' "$1"; }
ours() { [[ -f $ENTRIES_DST ]] && grep -q '^# swarm-grub boot entries' "$ENTRIES_DST"; }   # is the installed entries script ours?

new_backup() {  # new_backup SUFFIX
  BK=$BACKUPS/$(date +%Y%m%d-%H%M%S)$1
  mkdir -p "$BK"
  cp -a "$DEFAULT_FILE" "$BK/default-grub"
  [[ ! -f $BOOT_GRUB/grub.cfg ]] || cp -a "$BOOT_GRUB/grub.cfg" "$BK/grub.cfg"
  [[ ! -d $DEST ]] || cp -a "$DEST" "$BK/previous-theme"
  [[ ! -f $ENTRIES_DST ]] || cp -a "$ENTRIES_DST" "$BK/previous-entries"
  ARMED=1
}

# Generate a fresh grub.cfg aside, check it, and only then swap it in.
regenerate() {  # regenerate theme|no-theme
  local new=$BOOT_GRUB/grub.cfg.swarm-new f id
  if [[ -n $STAGE ]]; then say "(rehearsal) would now run: grub-mkconfig -o /boot/grub/grub.cfg"; return 0; fi
  rm -f "$new"
  grub-mkconfig -o "$new"
  grub-script-check "$new" || die "the generated grub.cfg failed grub-script-check; the current one is untouched"
  grep -q '^[[:space:]]*menuentry ' "$new" || die "the generated grub.cfg has no menu entries; the current one is untouched"
  if [[ $1 == theme ]]; then
    grep -q "set theme=.*themes/$THEME/theme.txt" "$new" || die "the generated grub.cfg does not use the theme (is GRUB_TERMINAL=console set elsewhere?)"
    grep -q 'terminal_output gfxterm' "$new" || die "the generated grub.cfg does not switch to gfxterm"
    for f in "$DEST"/*.pf2; do
      grep -q "loadfont .*themes/$THEME/$(basename "$f")" "$new" || die "the generated grub.cfg does not load font $(basename "$f")"
    done
    grep -q "background_image .*themes/$THEME/terminal_bg.png" "$new" \
      || say "NOTE: Debian's own wallpaper may show behind the 'c' console (the console backdrop was not picked up)"
    if ((WANT_ENTRIES)); then
      for id in swarm-swarmos swarm-recovery swarm-ventoy swarm-power; do
        grep -q -- "--id $id" "$new" || die "the generated grub.cfg lacks the $id entry"
      done
    fi
  else
    ! grep -q "themes/$THEME" "$new" || die "the generated grub.cfg still mentions the theme; the current one is untouched"
  fi
  chmod --reference="$BOOT_GRUB/grub.cfg" "$new"
  mv -f "$new" "$BOOT_GRUB/grub.cfg"
}

# ----------------------------------------------------------------------------------------------------
if [[ $MODE == uninstall ]]; then
  new_backup -uninstall
  if grep -q '^# BEGIN SWARM-GRUB THEME' "$DEFAULT_FILE"; then
    strip_block "$DEFAULT_FILE"
    say "removed the managed block from /etc/default/grub (backup: $BK)"
  else
    say "no swarm-grub block in /etc/default/grub - nothing to remove there"
  fi
  if ours; then rm -f "$ENTRIES_DST"; say "removed the entries script $ENTRIES_DST"; fi
  regenerate no-theme
  ARMED=0
  rm -rf "$DEST"
  say "uninstalled; GRUB is back to its stock look. Reinstall any time with: sudo bash $0"
  exit 0
fi

# ----------------------------------------------------------------------------------------------------
if grep -q '^# BEGIN SWARM DEBIAN THEME' "$DEFAULT_FILE"; then
  say "NOTE: the older swarm_dev block is still in /etc/default/grub. Its other settings (such as GRUB_DEFAULT)"
  say "      stay in force. Remove it with: sudo 70-scripts/install_debian_grub_theme.sh --uninstall"
fi

case $ENTRIES_FLAG in
  yes) WANT_ENTRIES=1 ;;
  no)  WANT_ENTRIES=0 ;;
  *)   if ours; then WANT_ENTRIES=1; fi ;;
esac
if ((WANT_ENTRIES)); then
  [[ -f $ENTRIES_SRC ]] || die "entries/20_swarm_entries is missing"
  if [[ -f $ENTRIES_DST ]] && ! ours; then die "$ENTRIES_DST exists and is not ours; not overwriting it"; fi
fi

BUILD=$(mktemp -d); CLEAN+=("$BUILD")
say "building the theme..."
bash "$HERE/build.sh" "$BUILD/$THEME"

new_backup ""
rm -rf "$DEST"; mkdir -p "$BOOT_GRUB/themes"
cp -a "$BUILD/$THEME" "$DEST"
chmod -R u=rwX,go=rX "$DEST"

if ((WANT_ENTRIES)); then
  install -m 755 "$ENTRIES_SRC" "$ENTRIES_DST"
elif [[ $ENTRIES_FLAG == no ]] && ours; then
  rm -f "$ENTRIES_DST"
  say "removed the entries script $ENTRIES_DST"
fi

strip_block "$DEFAULT_FILE"
if [[ -s $DEFAULT_FILE && -n $(tail -c1 "$DEFAULT_FILE") ]]; then echo >>"$DEFAULT_FILE"; fi
{
  echo "$BEGIN"
  echo "GRUB_THEME=\"$THEME_CFG\""
  echo 'GRUB_TERMINAL_OUTPUT="gfxterm"'
  echo 'GRUB_GFXMODE="1920x1080,1600x900,1280x720,auto"'
  echo "GRUB_BACKGROUND=\"$THEME_DIR_CFG/terminal_bg.png\""
  # The entries script lists SWARM OS / Recovery OS itself; os-prober would add a second, different row for each.
  if ((WANT_ENTRIES)); then echo 'GRUB_DISABLE_OS_PROBER=true'; fi
  echo "$END"
} >>"$DEFAULT_FILE"

regenerate theme
ARMED=0

if ((DRY)); then
  echo; say "rehearsal only - nothing on this system was changed. What would change in /etc/default/grub:"
  diff -u /etc/default/grub "$DEFAULT_FILE" || true
  echo; say "theme files that would go to /boot/grub/themes/$THEME: $(find "$DEST" -type f | wc -l)"
  if ((WANT_ENTRIES)); then say "and this entries script would be installed as /etc/grub.d/20_swarm_entries"; fi
else
  say "installed: $DEST"
  if ((WANT_ENTRIES)); then say "entries:   $ENTRIES_DST (SWARM OS, Recovery OS, Ventoy, Power options)"; fi
  say "backup:    $BK"
  say "revert:    sudo bash $0 --uninstall"
  say "reboot to see it, or just use the GRUB menu on the next start."
fi
