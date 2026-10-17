#!/usr/bin/env bash
# Build the swarm-grub theme into OUTDIR. No root needed; nothing outside OUTDIR is touched.
#   swarm-grub/build.sh OUTDIR
#
# Needs: grub-mkfont (grub-common), python3, and an SVG renderer: `rsvg-convert` (apt install
# librsvg2-bin) or, failing that, the librsvg library through PyGObject (tools/svg2png.py).
# Font: put Orbitron-Bold.ttf in swarm-grub/fonts/ for the intended look; without it the theme
# falls back to DejaVu Sans Bold and says so.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT=${1:-}
[[ -n $OUT ]] || { echo "usage: $0 OUTDIR" >&2; exit 2; }

ICON_PX=64                       # keep in step with icon_width/icon_height in theme.txt.in
BG_W=1920 BG_H=1080
RANGE=0x20-0x7e,0xa0-0xff,0x2190-0x2193,0x25b8-0x25b8   # Latin-1 + the arrows the hint line uses (ranges must not overlap: GRUB rejects the font)
REQUIRED_ICONS=(debian swarm_os recovery_os ventoy tools restart shutdown efi linux arch unknown)

die()  { echo "build.sh: $*" >&2; exit 1; }
note() { echo "build.sh: $*" >&2; }

# --- SVG renderer: render IN.svg OUT.png WIDTH HEIGHT ----------------------------------------------
if command -v rsvg-convert >/dev/null 2>&1; then
  render() { rsvg-convert -w "$3" -h "$4" -o "$2" "$1"; }
elif python3 -c 'import gi, cairo; gi.require_version("Rsvg", "2.0"); from gi.repository import Rsvg' 2>/dev/null; then
  render() { python3 "$HERE/tools/svg2png.py" "$1" "$2" "$3" "$4"; }
else
  die "no SVG renderer found. Install one:  sudo apt install librsvg2-bin"
fi
command -v grub-mkfont >/dev/null 2>&1 || die "grub-mkfont not found (package grub-common)"

# --- fonts -----------------------------------------------------------------------------------------
dejavu() {
  local d
  for d in /usr/share/fonts/truetype/dejavu /usr/share/fonts/dejavu /usr/share/fonts/TTF; do
    [[ -f $d/$1 ]] && { echo "$d/$1"; return 0; }
  done
  return 1
}
if [[ -f $HERE/fonts/Orbitron-Bold.ttf ]]; then
  DISPLAY_TTF=$HERE/fonts/Orbitron-Bold.ttf
else
  DISPLAY_TTF=$(dejavu DejaVuSans-Bold.ttf) || die "neither fonts/Orbitron-Bold.ttf nor DejaVu Sans Bold found"
  note "fonts/Orbitron-Bold.ttf not found - using DejaVu Sans Bold. Add the font and rebuild for the Orbitron look."
fi
HINT_TTF=$(dejavu DejaVuSans-Bold.ttf) || HINT_TTF=$DISPLAY_TTF     # needs the arrows Orbitron lacks
MONO_TTF=$(dejavu DejaVuSansMono-Bold.ttf) || MONO_TTF=$HINT_TTF    # console wants a fixed-width face

mkdir -p "$OUT/icons"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkfont() { grub-mkfont -s "$2" -r "$RANGE" -o "$OUT/$3" "$1" >/dev/null; }
mkfont "$DISPLAY_TTF" 56 title.pf2
mkfont "$DISPLAY_TTF" 26 menu.pf2
mkfont "$DISPLAY_TTF" 18 small.pf2
mkfont "$HINT_TTF"    16 hint.pf2
mkfont "$MONO_TTF"    16 mono.pf2
fname() { python3 "$HERE/tools/pf2name.py" "$OUT/$1"; }

# --- icons: one SVG per menu class, plus the alias names GRUB tries -------------------------------------
declare -A ALIASES=(
  [linux]="gnu-linux gnu"
  [arch]="archlinux"
  [swarm_os]="swarm-os swarm swarmos"
  [recovery_os]="recovery-os recovery"
  [restart]="reboot"
  [shutdown]="poweroff halt"
)
for name in "${REQUIRED_ICONS[@]}"; do
  [[ -f $HERE/icons/$name.svg ]] || die "missing icons/$name.svg"
done
for svg in "$HERE"/icons/*.svg; do
  name=$(basename "$svg" .svg)
  render "$svg" "$OUT/icons/$name.png" "$ICON_PX" "$ICON_PX"
  for alias in ${ALIASES[$name]:-}; do cp "$OUT/icons/$name.png" "$OUT/icons/$alias.png"; done
done

# --- background ------------------------------------------------------------------------------------
render "$HERE/background.svg" "$OUT/background.png" "$BG_W" "$BG_H"
render "$HERE/terminal_bg.svg" "$OUT/terminal_bg.png" 480 270   # backdrop for the c / e console, see terminal_bg.svg

# --- 9-slice pixmaps: cut a (2R+1)-px master into nw n ne w c e sw s se by viewBox -----------------------
slice() {  # slice MASTER.svg PREFIX R
  local master=$1 prefix=$2 r=$3 s=$((2 * $3 + 1)) spec name x y w h
  for spec in "nw 0 0 $r $r" "n $r 0 1 $r" "ne $((r + 1)) 0 $r $r" \
              "w 0 $r $r 1" "c $r $r 1 1" "e $((r + 1)) $r $r 1" \
              "sw 0 $((r + 1)) $r $r" "s $r $((r + 1)) 1 $r" "se $((r + 1)) $((r + 1)) $r $r"; do
    read -r name x y w h <<<"$spec"
    sed -E "s|viewBox=\"0 0 $s $s\" width=\"$s\" height=\"$s\"|viewBox=\"$x $y $w $h\" width=\"$w\" height=\"$h\"|" \
      "$master" >"$TMP/slice.svg"
    grep -q "viewBox=\"$x $y $w $h\"" "$TMP/slice.svg" || die "$master: expected a ${s}x${s} px master (corner radius $r)"
    render "$TMP/slice.svg" "$OUT/${prefix}_${name}.png" "$w" "$h"
  done
}
slice "$HERE/selection.svg"    select       8
slice "$HERE/item.svg"         item         8   # transparent, same padding as select_*: keeps rows from shifting
slice "$HERE/terminal_box.svg" terminal_box 6

# --- theme.txt: fill in the real font names read back from the .pf2 files ------------------------------
sed -e "s|@FONT_TITLE@|$(fname title.pf2)|g" \
    -e "s|@FONT_MENU@|$(fname menu.pf2)|g" \
    -e "s|@FONT_SMALL@|$(fname small.pf2)|g" \
    -e "s|@FONT_HINT@|$(fname hint.pf2)|g" \
    -e "s|@FONT_MONO@|$(fname mono.pf2)|g" \
    "$HERE/theme.txt.in" >"$OUT/theme.txt"
if grep -q '@FONT_' "$OUT/theme.txt"; then die "unfilled font placeholder in theme.txt"; fi

note "built $(find "$OUT" -type f | wc -l) files in $OUT (display font: $(fname menu.pf2))"
