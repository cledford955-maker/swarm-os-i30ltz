#!/usr/bin/env bash
# See the theme in a real GRUB (UEFI, under QEMU) without touching this machine's boot setup.
#   swarm-grub/preview.sh [-o shot.png] [-d N] [-t BUILT_THEME_DIR] [-e N]
#     -o  screenshot to write            (default: ./swarm-grub-preview.png)
#     -d  press Down N times first       (default 1: highlights the second entry)
#     -t  use an already built theme     (default: build one in a scratch dir)
#     -e  number of menu entries         (default 7; 9 shows how a long menu scrolls)
#     -k  extra QEMU key names to press after the Downs, e.g. -k c for the command line (default: none)
#     -x  debug: print GRUB's loaded font list (and any loadfont errors) instead of showing the menu
# The Debian rows are harmless stand-ins; SWARM OS / Recovery OS / Ventoy / Power are the real entries/20_swarm_entries
# (do not press Enter on them: they would try to chainload, which only the QEMU stand-in disk can answer). It mimics what Debian's grub-mkconfig generates for a
# theme: 00_header's font/gfxterm/theme lines, then 05_debian_theme's background_image for GRUB_BACKGROUND.
# Needs: qemu-system-x86_64, OVMF, grub-mkstandalone with the x86_64-efi modules, socat, ImageMagick.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPNG=$PWD/swarm-grub-preview.png DOWN=1 THEME_DIR="" ENTRIES=7 DEBUG=0 KEYS=""
while getopts 'o:d:t:e:k:xh' o; do
  case $o in
    o) OUTPNG=$(realpath -m "$OPTARG") ;; d) DOWN=$OPTARG ;; t) THEME_DIR=$(realpath "$OPTARG") ;;
    e) ENTRIES=$OPTARG ;; x) DEBUG=1 ;; k) KEYS=$OPTARG ;; *) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 2 ;;
  esac
done
die() { echo "preview.sh: $*" >&2; exit 1; }
for t in qemu-system-x86_64 grub-mkstandalone socat convert; do command -v "$t" >/dev/null || die "$t not found"; done
CODE=/usr/share/OVMF/OVMF_CODE_4M.fd VARS=/usr/share/OVMF/OVMF_VARS_4M.fd
[[ -f $CODE && -f $VARS ]] || die "OVMF firmware not found (package ovmf)"

TMP=$(mktemp -d)
QPID=""
cleanup() { [[ -n $QPID ]] && kill "$QPID" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

if [[ -z $THEME_DIR ]]; then THEME_DIR=$TMP/theme; bash "$HERE/build.sh" "$THEME_DIR" 2>&1 | sed 's/^/  /'; fi
[[ -f $THEME_DIR/theme.txt ]] || die "$THEME_DIR/theme.txt missing"

# Everything GRUB needs is embedded in the EFI binary (memdisk), so the ESP only holds that one file.
mkdir -p "$TMP/img/boot/grub/fonts" "$TMP/esp/EFI/BOOT"
cp -a "$THEME_DIR" "$TMP/img/boot/grub/themes-src"; mkdir -p "$TMP/img/boot/grub/themes"
mv "$TMP/img/boot/grub/themes-src" "$TMP/img/boot/grub/themes/swarm-grub"
cp /usr/share/grub/unicode.pf2 "$TMP/img/boot/grub/fonts/unicode.pf2"

{
  cat <<'CFG'
set timeout=60
set timeout_style=menu
insmod all_video
insmod gfxterm
insmod gfxmenu
insmod png
insmod part_gpt
loadfont unicode
set gfxmode=1920x1080,1280x720,auto
terminal_output gfxterm
CFG
  for f in "$THEME_DIR"/*.pf2; do echo "loadfont (memdisk)/boot/grub/themes/swarm-grub/$(basename "$f")"; done
  if ((DEBUG)); then echo 'lsfonts'; echo 'ls (memdisk)/boot/grub/themes/swarm-grub/'; echo 'sleep 300'; fi
  cat <<'CFG'
# what 05_debian_theme emits for GRUB_BACKGROUND (the console backdrop install.sh sets)
insmod png
if background_image (memdisk)/boot/grub/themes/swarm-grub/terminal_bg.png; then
  true
fi
set theme=(memdisk)/boot/grub/themes/swarm-grub/theme.txt
export theme
CFG
  echo "menuentry 'Debian GNU/Linux' --class debian --class gnu-linux --class gnu --class os { true }"
  echo "submenu 'Advanced options for Debian GNU/Linux' --class debian --class gnu-linux --class gnu --class os { menuentry 'x' { true } }"
  sh "$HERE/entries/20_swarm_entries"     # the real SWARM OS / Recovery OS / Ventoy / Power options entries
  echo "menuentry 'UEFI Firmware Settings' --class efi { true }"
  for ((i = 8; i <= ENTRIES; i++)); do echo "menuentry 'Arch Linux (on /dev/nvme0n1p$i)' --class arch --class gnu-linux { true }"; done
} >"$TMP/grub.cfg"

grub-mkstandalone -O x86_64-efi -o "$TMP/esp/EFI/BOOT/BOOTX64.EFI" \
  --modules='part_gpt part_msdos fat all_video gfxterm gfxmenu png font normal configfile echo test memdisk tar' \
  "boot/grub/grub.cfg=$TMP/grub.cfg" "boot/grub/=$TMP/img/boot/grub/" >/dev/null 2>"$TMP/mkstandalone.log" \
  || { cat "$TMP/mkstandalone.log" >&2; die "grub-mkstandalone failed"; }

cp "$VARS" "$TMP/vars.fd"
ACCEL=tcg; [[ -r /dev/kvm ]] && ACCEL=kvm
qemu-system-x86_64 -machine q35,accel=$ACCEL -m 1024 -display none -vga std -no-reboot \
  -drive if=pflash,format=raw,readonly=on,file="$CODE" -drive if=pflash,format=raw,file="$TMP/vars.fd" \
  -drive file=fat:rw:"$TMP/esp",format=raw,if=ide \
  -monitor unix:"$TMP/mon",server,nowait &
QPID=$!
for _ in $(seq 50); do [[ -S $TMP/mon ]] && break; sleep 0.2; done
mon() { printf '%s\n' "$1" | socat - UNIX-CONNECT:"$TMP/mon" >/dev/null; }

# OVMF + GRUB need a while under TCG; poll until the screen shows something other than black/firmware.
WAIT=18; [[ $ACCEL == tcg ]] && WAIT=60
sleep "$WAIT"
shot() {  # shot FILE.png - screendump through the QEMU monitor
  rm -f "$TMP/shot.ppm"; mon "screendump $TMP/shot.ppm"
  for _ in $(seq 20); do [[ -s $TMP/shot.ppm ]] && sleep 0.5 && break; sleep 0.5; done
  [[ -s $TMP/shot.ppm ]] || die "no screenshot produced"
  convert "$TMP/shot.ppm" "$1"
  echo "preview.sh: wrote $1 ($(identify -format '%wx%h' "$1"))"
}
if ((DOWN > 0 && !DEBUG)); then   # the countdown only shows until the first key press
  shot "${OUTPNG%.png}-countdown.png"
fi
for ((i = 0; i < DOWN; i++)); do mon "sendkey down"; sleep 0.6; done
for k in $KEYS; do mon "sendkey $k"; sleep 1; done
sleep 2
shot "$OUTPNG"
