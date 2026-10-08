#!/usr/bin/env bash
# Install the swarm_dev theme + SWARM/Recovery/Cachy/Ventoy menu into DEBIAN's GRUB.
#   sudo 70-scripts/install_debian_grub_theme.sh              install / update
#   sudo 70-scripts/install_debian_grub_theme.sh --uninstall  restore the newest backup
# Theme/menu only: no grub-install, no EFI binaries, no partition changes.
# Build the assets first (done already): python3 70-scripts/prepare_debian_grub_theme.py
set -Eeuo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
THEME=swarm_dev
SRC="$PROJECT_DIR/grub_themes"
DEST=/boot/grub/themes/$THEME
# Distro scripts that would add duplicate entries or override our theme; we only drop their +x bit.
DISABLE=(05_debian_theme 10_linux 30_uefi-firmware 35_fwupd)
BACKUPS="$SRC/backups"

[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
. /etc/os-release
[[ $ID == debian ]] || { echo "This is $PRETTY_NAME, not Debian; refusing." >&2; exit 1; }

if [[ ${1:-} == --uninstall ]]; then
  last=$(ls -1d "$BACKUPS"/debian-* 2>/dev/null | tail -1) || true
  [[ -n $last && -d $last ]] || { echo 'No debian-* backup found.' >&2; exit 1; }
  cp -a "$last/default-grub" /etc/default/grub
  rm -f /etc/grub.d/09_swarm_debian
  for s in "${DISABLE[@]}"; do [[ -f /etc/grub.d/$s ]] && chmod 755 /etc/grub.d/$s; done
  update-grub
  echo "Restored from $last (theme files left in $DEST)."
  exit 0
fi

for f in theme.txt background.png menu26.pf2 menu16.pf2 icons/debian.png icons/swarm_os.png icons/recovery_os.png \
         icons/cachyos.png icons/ventoy.png 09_swarm_debian; do
  [[ -e $SRC/$THEME/$f || -e $SRC/$f ]] || { echo "Missing $f - run prepare_debian_grub_theme.py" >&2; exit 1; }
done
[[ -d /boot/grub ]] || { echo '/boot/grub not found.' >&2; exit 1; }

BK="$BACKUPS/debian-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp -a /etc/default/grub "$BK/default-grub"
cp -a /etc/grub.d "$BK/grub.d"
cp -a /boot/grub/grub.cfg "$BK/grub.cfg"
[[ -d $DEST ]] && cp -a "$DEST" "$BK/previous-theme"

rollback() {
  trap - ERR
  echo "Install failed; restoring previous GRUB settings from $BK" >&2
  cp -a "$BK/default-grub" /etc/default/grub
  cp -a "$BK/grub.cfg" /boot/grub/grub.cfg
  rm -f /etc/grub.d/09_swarm_debian /boot/grub/grub.cfg.swarm-new
  for s in "${DISABLE[@]}"; do [[ -f /etc/grub.d/$s ]] && chmod 755 /etc/grub.d/$s; done
  exit 1
}
trap rollback ERR

rm -rf "$DEST"; mkdir -p "$DEST"
cp -a "$SRC/$THEME/." "$DEST/"
install -m 755 "$SRC/09_swarm_debian" /etc/grub.d/09_swarm_debian
for s in "${DISABLE[@]}"; do [[ -f /etc/grub.d/$s ]] && chmod 644 /etc/grub.d/$s; done

# Managed block: last assignment wins, so earlier values in the file are overridden.
sed -i '/^# BEGIN SWARM DEBIAN THEME$/,/^# END SWARM DEBIAN THEME$/d' /etc/default/grub
cat >> /etc/default/grub <<EOF
# BEGIN SWARM DEBIAN THEME
GRUB_THEME="$DEST/theme.txt"
GRUB_TERMINAL_OUTPUT=gfxterm
GRUB_GFXMODE="1920x1080,1600x900,1280x720,auto"
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=10
GRUB_DEFAULT="swarm-native>0"
GRUB_DISABLE_OS_PROBER=true
# END SWARM DEBIAN THEME
EOF

grub-mkconfig -o /boot/grub/grub.cfg.swarm-new
grub-script-check /boot/grub/grub.cfg.swarm-new
for id in swarm-native swarm-swarmos swarm-recovery swarm-cachyos swarm-ventoy swarm-tools; do
  grep -q -- "$id" /boot/grub/grub.cfg.swarm-new || { echo "generated config lacks $id" >&2; false; }
done
grep -q "set theme=.*$THEME/theme.txt" /boot/grub/grub.cfg.swarm-new || { echo 'theme line missing' >&2; false; }
grep -q 'menuentry .Debian GNU/Linux' /boot/grub/grub.cfg.swarm-new || { echo 'no Debian kernel entry generated' >&2; false; }

mv /boot/grub/grub.cfg.swarm-new /boot/grub/grub.cfg
trap - ERR
echo "Done. Backup: $BK"
echo "Revert any time: sudo $0 --uninstall"
