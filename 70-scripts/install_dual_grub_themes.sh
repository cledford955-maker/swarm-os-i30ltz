#!/usr/bin/env bash
# Theme/menu update only: never installs bootloader EFI files or changes disks.
set -Eeuo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SWARM_ROOT=/mnt/swarm/@
[[ $EUID == 0 ]] || { echo 'Run this script with sudo.' >&2; exit 1; }
[[ $(findmnt -n -o UUID -T /) == ef9acba2-3816-4fd7-bdd7-a9526816d3f0 ]] || { echo 'Run from the CachyOS installation.' >&2; exit 1; }
[[ $(findmnt -n -o UUID -T "$SWARM_ROOT") == 366134c3-3986-4475-b9de-4707d582656e ]] || { echo 'Expected SWARM installation is not mounted.' >&2; exit 1; }
for target in / "$SWARM_ROOT"; do
 [[ -f "$target/etc/default/grub" && -f "$target/boot/grub/grub.cfg" && -f "$target/etc/grub.d/10_linux" ]] || exit 1
done
# arch-chroot requires the actual system root to be a mountpoint, not
# merely a subdirectory of the mounted Btrfs top-level volume.
SWARM_BIND_CREATED=0
cleanup_mount() {
 if (( SWARM_BIND_CREATED )); then
  umount "$SWARM_ROOT"
 fi
}
trap cleanup_mount EXIT
if ! mountpoint -q "$SWARM_ROOT"; then
 mount --bind "$SWARM_ROOT" "$SWARM_ROOT"
 SWARM_BIND_CREATED=1
fi
# Fail before changing either menu if GRUB cannot resolve the installed root.
SWARM_PROBED_UUID=$(arch-chroot "$SWARM_ROOT" grub-probe --target=fs_uuid /)
[[ $SWARM_PROBED_UUID == 366134c3-3986-4475-b9de-4707d582656e ]] || {
 echo 'GRUB could not identify the expected SWARM root filesystem.' >&2
 exit 1
}
BACKUP_DIR="$PROJECT_DIR/grub_themes/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
rollback() {
 trap - ERR
 echo "Theme installation failed; restoring saved menus. Backup: $BACKUP_DIR" >&2
 for theme in cachyos swarm_os; do
  target=/
  [[ $theme != swarm_os ]] || target=$SWARM_ROOT
  saved="$BACKUP_DIR/$theme"
  [[ -f "$saved/default-grub" && -f "$saved/grub.cfg" ]] || continue
  cp -a "$saved/default-grub" "$target/etc/default/grub"
  cp -a "$saved/grub.cfg" "$target/boot/grub/grub.cfg"
  if [[ -f "$saved/grub.d/09_swarm_multiboot" ]]; then
   cp -a "$saved/grub.d/09_swarm_multiboot" "$target/etc/grub.d/09_swarm_multiboot"
  else
   rm -f "$target/etc/grub.d/09_swarm_multiboot"
  fi
  if [[ -d "$saved/previous-theme" ]]; then
   cp -a "$saved/previous-theme/." "$target/boot/grub/themes/$theme/"
  fi
 done
 exit 1
}
trap rollback ERR
for theme in cachyos swarm_os; do
 target=/
 [[ $theme != swarm_os ]] || target=$SWARM_ROOT
 mkdir -p "$BACKUP_DIR/$theme"
 cp -a "$target/etc/default/grub" "$BACKUP_DIR/$theme/default-grub"
 cp -a "$target/etc/grub.d" "$BACKUP_DIR/$theme/grub.d"
 cp -a "$target/boot/grub/grub.cfg" "$BACKUP_DIR/$theme/grub.cfg"
 if [[ -d "$target/boot/grub/themes/$theme" ]]; then
  cp -a "$target/boot/grub/themes/$theme" "$BACKUP_DIR/$theme/previous-theme"
 fi
 mkdir -p "$target/boot/grub/themes/$theme"
 cp -a "$PROJECT_DIR/grub_themes/$theme/." "$target/boot/grub/themes/$theme/"
 install -m 755 "$PROJECT_DIR/grub_themes/09_swarm_multiboot" "$target/etc/grub.d/09_swarm_multiboot"
 # Last assignment wins; remove previous managed block on reruns.
 sed -i '/^# BEGIN SWARM DUAL THEME$/,/^# END SWARM DUAL THEME$/d' "$target/etc/default/grub"
 cat >> "$target/etc/default/grub" <<EOF
# BEGIN SWARM DUAL THEME
GRUB_THEME="/boot/grub/themes/$theme/theme.txt"
GRUB_FONT="/boot/grub/themes/$theme/menu.pf2"
GRUB_GFXMODE="1920x1080,1600x900,1280x720,auto"
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=10
GRUB_DEFAULT="swarm-native>0"
SWARM_MENU_LOCAL=$theme
# END SWARM DUAL THEME
EOF
 if [[ $theme == cachyos ]]; then
  grub-mkconfig -o /boot/grub/grub.cfg.swarm-new
  grub-script-check /boot/grub/grub.cfg.swarm-new
 else
  arch-chroot "$target" grub-mkconfig -o /boot/grub/grub.cfg.swarm-new
  grub-script-check "$target/boot/grub/grub.cfg.swarm-new"
 fi
 # Do not activate a broken or incomplete menu.
 for entry in swarm-native swarm-endeavour swarm-ventoy; do
  grep -q -- "$entry" "$target/boot/grub/grub.cfg.swarm-new"
 done
done
# Activate only after both generated configurations pass validation.
for target in / "$SWARM_ROOT"; do
 mv "$target/boot/grub/grub.cfg.swarm-new" "$target/boot/grub/grub.cfg"
done
trap - ERR
printf 'Both themes installed. Original files backed up in %s\n' "$BACKUP_DIR"
