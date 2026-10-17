#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# SWARM OS · GRUB Theme Builder
# Generates 1920×1080 PNG backgrounds from Python/Cairo rendering scripts.
# Requires: python3, python3-cairo  (pacman -S python-cairo)
# Usage:  ./build_themes.sh [swarm|arch|all]
# ─────────────────────────────────────────────────────────────────────────────
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-all}"

info()  { echo -e "\033[0;36m  ➤  $1\033[0m"; }
ok()    { echo -e "\033[0;32m  ✓  $1\033[0m"; }
warn()  { echo -e "\033[1;33m  ⚠  $1\033[0m"; }

check_deps() {
  if ! python3 -c "import cairo" 2>/dev/null; then
    warn "python-cairo not found. Install with:"
    echo "       sudo pacman -S python-cairo"
    exit 1
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# SWARM OS background — hex-grid on void-black
# ─────────────────────────────────────────────────────────────────────────────
build_swarm() {
  info "Rendering SWARM OS background (1920×1080)..."
  python3 - <<'PYEOF'
import cairo, math, random

W, H = 1920, 1080
surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
ctx  = cairo.Context(surf)

# ── Background ──
ctx.set_source_rgb(0, 0.020, 0.028)
ctx.paint()

# ── Hex grid ──
R  = 44
dw = R * math.sqrt(3)
dh = R * 1.5
rnd = random.Random(0xBEEF)

def hex_path(cx, cy, r):
    for i in range(6):
        a  = math.pi / 3 * i - math.pi / 6
        px = cx + r * math.cos(a)
        py = cy + r * math.sin(a)
        ctx.line_to(px, py) if i else ctx.move_to(px, py)
    ctx.close_path()

cols = int(W / dw) + 3
rows = int(H / dh) + 3
for row in range(-1, rows):
    for col in range(-1, cols):
        x = col * dw + (0 if row % 2 == 0 else dw / 2)
        y = row * dh
        nx = (x - W / 2) / W
        ny = (y - H / 2) / H
        d  = math.sqrt(nx*nx + ny*ny)
        intensity = rnd.random() * max(0, 1 - d * 1.25)

        # Fill
        fa = 0.04 + intensity * 0.22
        ctx.new_path()
        hex_path(x, y, R - 1.5)
        ctx.set_source_rgba(0, 0.30 + intensity*0.35, 0.55 + intensity*0.39, fa)
        ctx.fill()
        # Stroke
        ctx.new_path()
        hex_path(x, y, R - 1.5)
        ctx.set_source_rgba(0, 0.70 + intensity*0.30, 1.0, 0.15 + intensity*0.55)
        ctx.set_line_width(0.7 + intensity)
        ctx.stroke()
        # Bright cell
        if intensity > 0.70:
            ctx.new_path()
            hex_path(x, y, R - 2.5)
            ctx.set_source_rgba(0, 0.86, 1.0, intensity * 0.7)
            ctx.set_line_width(1.8)
            ctx.stroke()

# ── Center vignette ──
pat = cairo.RadialGradient(W/2, H*0.55, 0, W/2, H*0.55, W*0.68)
pat.add_color_stop_rgba(0.0,  0, 0.016, 0.047, 0.72)
pat.add_color_stop_rgba(0.55, 0, 0.016, 0.047, 0.38)
pat.add_color_stop_rgba(1.0,  0, 0,     0,     0.00)
ctx.set_source(pat)
ctx.paint()

# Edge vignette
epat = cairo.RadialGradient(W/2, H/2, W*0.35, W/2, H/2, W*0.76)
epat.add_color_stop_rgba(0.0, 0, 0, 0, 0.00)
epat.add_color_stop_rgba(1.0, 0, 0.008, 0.031, 0.70)
ctx.set_source(epat)
ctx.paint()

surf.write_to_png("swarm_os/background.png")
print("  → swarm_os/background.png")
PYEOF
  ok "swarm_os/background.png written"
}

# ─────────────────────────────────────────────────────────────────────────────
# Arch Trans Am background — 1999 Electric Blue Trans Am WS6, night scene
# ─────────────────────────────────────────────────────────────────────────────
build_arch() {
  info "Rendering Arch Trans Am background (1920×1080)..."
  python3 - <<'PYEOF'
import cairo, math, random

W, H = 1920, 1080
surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
ctx  = cairo.Context(surf)

def rgba(r, g, b, a=1.0):
    ctx.set_source_rgba(r/255, g/255, b/255, a)

def lin_grad(x0, y0, x1, y1, stops):
    p = cairo.LinearGradient(x0, y0, x1, y1)
    for pos, (r, g, b, a) in stops:
        p.add_color_stop_rgba(pos, r/255, g/255, b/255, a)
    return p

def rad_grad(cx, cy, r0, r1, stops):
    p = cairo.RadialGradient(cx, cy, r0, cx, cy, r1)
    for pos, (r, g, b, a) in stops:
        p.add_color_stop_rgba(pos, r/255, g/255, b/255, a)
    return p

def poly(pts):
    ctx.new_path()
    ctx.move_to(*pts[0])
    for p in pts[1:]: ctx.line_to(*p)
    ctx.close_path()

# ── Night sky ──
sky = lin_grad(0, 0, 0, H*0.65, [
    (0.0, ( 2,  4,  8, 1.0)),
    (0.55,( 6, 12, 24, 1.0)),
    (1.0, (13, 20, 40, 1.0)),
])
ctx.set_source(sky)
ctx.paint()

# ── Stars ──
rnd = random.Random(0xC0FF33)
for _ in range(220):
    sx = rnd.random() * W
    sy = rnd.random() * H * 0.52
    sz = rnd.random() * 2.2 + 0.3
    br = rnd.random() * 0.7 + 0.3
    ctx.new_path()
    ctx.arc(sx, sy, sz, 0, math.pi*2)
    ctx.set_source_rgba(0.78, 0.84, 1.0, br)
    ctx.fill()

# ── Horizon glow ──
hg = lin_grad(0, H*0.45, 0, H*0.65, [
    (0.0, ( 0,  0,  0, 0.00)),
    (0.6, (30, 40, 80, 0.35)),
    (1.0, ( 0, 20, 60, 0.55)),
])
ctx.set_source(hg)
ctx.rectangle(0, H*0.45, W, H*0.2)
ctx.fill()

# ── Road ──
road = lin_grad(0, H*0.6, 0, H, [
    (0.0, (10, 12, 16, 1.0)),
    (0.4, (14, 16, 22, 1.0)),
    (1.0, (18, 20, 26, 1.0)),
])
ctx.set_source(road)
ctx.rectangle(0, H*0.62, W, H*0.38)
ctx.fill()

# Road edge
ctx.set_source_rgba(100/255, 110/255, 140/255, 0.25)
ctx.set_line_width(3)
ctx.move_to(0, H*0.62); ctx.line_to(W, H*0.62); ctx.stroke()

# Center dashes
for i in range(14):
    x0 = i / 14 * W
    ctx.set_source_rgba(180/255, 160/255, 80/255, 0.30)
    ctx.set_line_width(4)
    ctx.move_to(x0, H*0.79); ctx.line_to(x0 + W/14*0.45, H*0.79); ctx.stroke()

# ── Headlight beams ──
for spread in [0.7, 0.45]:
    bg = lin_grad(W, H*0.76, W+300, H*0.76, [
        (0.0, (255, 240, 180, 0.22*spread)),
        (0.4, (255, 240, 180, 0.07*spread)),
        (1.0, (255, 240, 180, 0.00)),
    ])
    ctx.set_source(bg)
    ctx.new_path()
    ctx.move_to(W - 10, H*0.76)
    ctx.line_to(W + 300, H*0.76 - H*0.40*spread)
    ctx.line_to(W + 300, H*0.76 + H*0.40*spread)
    ctx.close_path()
    ctx.fill()

# ── Ground shadow under car ──
gs = rad_grad(W*0.66, H*0.89, 0, 680, [
    (0.0, (0, 0, 0, 0.55)),
    (1.0, (0, 0, 0, 0.00)),
])
ctx.set_source(gs)
ctx.rectangle(0, H*0.88, W, H*0.12)
ctx.fill()

# ── Trans Am body ──
G = 960  # ground y
ROOF = 472

body_pts = [
    (1865, G), (1865, 835), (1853, 808), (1843, 790), (1828, 774),
    (1810, 762), (1720, 750), (1620, 742), (1540, 738), (1480, 734),
    (1440, 728), (1400, 733), (1360, 732), (1320, 737), (1280, 740),
    (1200, 745), (1150, 750), (1100, 756),
    (960, ROOF+5), (840, ROOF), (760, ROOF+4),
    (710, ROOF+30), (678, 560), (658, 680), (646, 800),
    (648, 868), (655, 920), (660, G),
]

poly(body_pts)
body_g = lin_grad(660, ROOF, 1865, G+50, [
    (0.0,  (12,  34, 120, 1.0)),
    (0.30, (24,  71, 200, 1.0)),
    (0.65, (19,  64, 168, 1.0)),
    (1.0,  (11,  30,  96, 1.0)),
])
ctx.set_source(body_g)
ctx.fill()

# Body edge highlight
poly(body_pts)
ctx.set_source_rgba(60/255, 130/255, 255/255, 0.65)
ctx.set_line_width(2)
ctx.stroke()

# Hood top highlight
ctx.new_path()
ctx.move_to(1828, 774)
ctx.curve_to(1700, 748, 1400, 730, 1150, 750)
ctx.line_to(1100, 756)
ctx.line_to(960, ROOF+5)
ctx.line_to(1000, 500)
ctx.curve_to(1100, 720, 1350, 710, 1500, 720)
ctx.curve_to(1600, 725, 1700, 730, 1828, 760)
ctx.close_path()
hg2 = lin_grad(W*0.7, 700, W*0.92, 760, [
    (0.0, (60, 120, 240, 0.62)),
    (1.0, (20,  60, 180, 0.00)),
])
ctx.set_source(hg2)
ctx.fill()

# Hood specular line
spec = lin_grad(1000, 0, 1600, 0, [
    (0.0, (150, 200, 255, 0.00)),
    (0.3, (180, 220, 255, 0.68)),
    (0.6, (200, 230, 255, 0.50)),
    (1.0, (150, 200, 255, 0.00)),
])
ctx.set_source(spec)
ctx.set_line_width(2.5)
ctx.new_path()
ctx.move_to(1828, 756)
ctx.curve_to(1700, 740, 1400, 724, 1100, 742)
ctx.stroke()

# WS6 scoops
for sx, sy in [(1440, 732), (1360, 731)]:
    ctx.new_path()
    ctx.set_line_width(1.5)
    ctx.set_source_rgba(6/255, 12/255, 40/255, 1.0)
    ctx.arc(sx, sy + 9, 34, 0, math.pi*2); ctx.fill()
    ctx.arc(sx, sy + 9, 34, 0, math.pi*2)
    ctx.set_source_rgba(50/255, 100/255, 200/255, 0.6); ctx.stroke()

# Windshield
poly([(1100,756),(960,ROOF+5),(840,ROOF),(870,ROOF+12),(1000,758)])
wg = lin_grad(960, ROOF, 1050, 760, [
    (0.0, (10,18,50, 0.92)),
    (0.4, (15,30,80, 0.85)),
    (1.0, (20,40,100,0.60)),
])
ctx.set_source(wg); ctx.fill()

# Windshield reflection
ctx.set_source_rgba(150/255, 200/255, 255/255, 0.30)
ctx.set_line_width(1.5)
ctx.new_path()
ctx.move_to(980, 760); ctx.curve_to(970, 680, 940, 600, 920, ROOF+20); ctx.stroke()

# Side window
poly([(840,ROOF),(760,ROOF+4),(740,ROOF+80),(860,ROOF+18)])
ctx.set_source_rgba(8/255, 16/255, 50/255, 0.88); ctx.fill()
ctx.set_source_rgba(60/255, 100/255, 220/255, 0.5)
ctx.set_line_width(1); ctx.stroke()

# Wheels
def draw_wheel(wx, wy, wr):
    ctx.new_path(); ctx.arc(wx, wy, wr, 0, math.pi*2)
    ctx.set_source_rgb(0.067, 0.071, 0.082); ctx.fill()
    ctx.new_path(); ctx.arc(wx, wy, wr-12, 0, math.pi*2)
    ctx.set_source_rgba(160/255, 180/255, 220/255, 0.70)
    ctx.set_line_width(6); ctx.stroke()
    ctx.new_path(); ctx.arc(wx, wy, wr-28, 0, math.pi*2)
    ctx.set_source_rgba(100/255, 120/255, 180/255, 0.50)
    ctx.set_line_width(3); ctx.stroke()
    for i in range(5):
        a = math.pi * 2 / 5 * i
        ctx.move_to(wx + math.cos(a)*(wr-28), wy + math.sin(a)*(wr-28))
        ctx.line_to(wx + math.cos(a)*16,      wy + math.sin(a)*16)
        ctx.set_source_rgba(140/255, 165/255, 210/255, 0.65)
        ctx.set_line_width(4); ctx.stroke()
    ctx.new_path(); ctx.arc(wx, wy, 18, 0, math.pi*2)
    ctx.set_source_rgba(120/255, 140/255, 190/255, 0.80); ctx.fill()

draw_wheel(1640, G, 108)
draw_wheel(820,  G, 108)

# Pop-up headlights
HL_X, HL_Y, HL_W, HL_H = 1865-10, 808, 82, 58
ctx.set_source_rgba(10/255, 13/255, 24/255, 1.0)
ctx.rectangle(HL_X-HL_W, HL_Y-HL_H*0.9, HL_W, HL_H); ctx.fill()
for lx in [HL_X-HL_W+18, HL_X-22]:
    ly = HL_Y - HL_H*0.48
    lg = rad_grad(lx, ly, 0, 18, [
        (0.0, (255, 255, 255, 1.0)),
        (0.35,(255, 232, 176, 1.0)),
        (1.0, (255, 220, 100, 0.0)),
    ])
    ctx.set_source(lg); ctx.new_path(); ctx.arc(lx, ly, 18, 0, math.pi*2); ctx.fill()

# Tail lights
ctx.set_source_rgba(1.0, 0.133, 0.0, 0.90)
ctx.rectangle(668, 855, 24, 50); ctx.fill()
ctx.set_source_rgba(1.0, 0.39, 0.0, 0.90)
ctx.rectangle(672, 863, 8, 14); ctx.fill()

# Firebird decal
FB_CX, FB_CY, FB_W, FB_H = 1260, 735, 220, 90

ctx.save()
ctx.translate(FB_CX, FB_CY)

def fb_wing(flip):
    ctx.new_path()
    s = -1 if flip else 1
    ctx.move_to(0, 0)
    ctx.curve_to(s*FB_W*0.18, -FB_H*0.20, s*FB_W*0.45, -FB_H*0.12, s*FB_W*0.50, FB_H*0.15)
    ctx.curve_to(s*FB_W*0.38,  FB_H*0.08, s*FB_W*0.22, -FB_H*0.05, 0, FB_H*0.18)
    ctx.close_path()

wg_f = cairo.LinearGradient(-FB_W/2, 0, FB_W/2, 0)
wg_f.add_color_stop_rgba(0.0,  210/255, 140/255, 0/255, 0.0)
wg_f.add_color_stop_rgba(0.25, 230/255, 160/255, 0/255, 0.85)
wg_f.add_color_stop_rgba(0.5,  255/255, 190/255, 30/255, 0.95)
wg_f.add_color_stop_rgba(0.75, 230/255, 160/255, 0/255, 0.85)
wg_f.add_color_stop_rgba(1.0,  210/255, 140/255, 0/255, 0.0)
for flip in (False, True):
    fb_wing(flip); ctx.set_source(wg_f); ctx.fill()

# Body
ctx.new_path()
BW, BH = FB_W*0.5, FB_H*0.7
ctx.move_to(0, -FB_H*0.5)
ctx.curve_to( BW*0.3, -BH*0.35,  BW*0.18,  0,  BW*0.12, BH*0.2)
ctx.curve_to( BW*0.05, BH*0.42,  0, FB_H*0.5,  0, FB_H*0.5)
ctx.curve_to(-BW*0.05, BH*0.42, -BW*0.12, BH*0.2, -BW*0.18, 0)
ctx.curve_to(-BW*0.3, -BH*0.35,  0, -FB_H*0.5,  0, -FB_H*0.5)
ctx.close_path()
bodyf = cairo.LinearGradient(0, -FB_H*0.5, 0, FB_H*0.5)
bodyf.add_color_stop_rgb(0.0, 1.0, 0.816, 0.376)
bodyf.add_color_stop_rgb(0.4, 0.910, 0.502, 0.0)
bodyf.add_color_stop_rgb(1.0, 0.722, 0.314, 0.0)
ctx.set_source(bodyf); ctx.fill()

# Head
ctx.new_path()
ctx.move_to(0, -FB_H*0.5)
ctx.curve_to(-FB_W*0.08, -FB_H*0.72, -FB_W*0.06, -FB_H*0.88, 0, -FB_H*0.92)
ctx.curve_to( FB_W*0.06, -FB_H*0.88,  FB_W*0.08, -FB_H*0.72, 0, -FB_H*0.5)
ctx.close_path()
ctx.set_source_rgb(1.0, 0.816, 0.376); ctx.fill()
ctx.restore()

# Character line
cl = lin_grad(660, 0, 1865, 0, [
    (0.0, (80,140,255,0.00)),
    (0.2, (100,160,255,0.55)),
    (0.8, (80,150,255,0.60)),
    (1.0, (80,140,255,0.00)),
])
ctx.set_source(cl); ctx.set_line_width(1.8)
ctx.new_path()
ctx.move_to(1828, 790); ctx.curve_to(1600, 775, 1200, 800, 900, 820)
ctx.curve_to(820, 824, 760, 830, 700, 855); ctx.stroke()

# ── ARCH LINUX TEXT (baked into the background) ──

# Arch triangle logo
LOG_CX, LOG_CY, LOG_R = 200, 60, 52
ctx.new_path()
ctx.move_to(LOG_CX, LOG_CY - LOG_R)
ctx.line_to(LOG_CX + LOG_R*0.88, LOG_CY + LOG_R*0.5)
ctx.line_to(LOG_CX - LOG_R*0.88, LOG_CY + LOG_R*0.5)
ctx.close_path()
tri_g = lin_grad(LOG_CX, LOG_CY-LOG_R, LOG_CX, LOG_CY+LOG_R, [
    (0.0, (255, 128,  64, 1.0)),
    (1.0, (192,  64,   0, 1.0)),
])
ctx.set_source(tri_g); ctx.fill()
ctx.new_path()
ctx.move_to(LOG_CX, LOG_CY - LOG_R*0.28)
ctx.line_to(LOG_CX + LOG_R*0.42, LOG_CY + LOG_R*0.48)
ctx.line_to(LOG_CX - LOG_R*0.42, LOG_CY + LOG_R*0.48)
ctx.close_path()
ctx.set_source_rgb(6/255, 9/255, 26/255); ctx.fill()

# "ARCH" — painted large using rectangles to approximate the letters
# (cairo won't have Bebas Neue; we simulate with big block letterforms)
def block_letter_ARCH(ox, oy, lw, lh, gap=18):
    """Very rough block-letter approach for ARCH"""
    pass  # Actual font rendering below via toy_font_face

ctx.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
ctx.set_font_size(H * 0.235)
ctx.set_source_rgba(1.0, 1.0, 1.0, 0.95)
ctx.move_to(88, H * 0.322)
ctx.show_text("ARCH")

ctx.set_source_rgba(232/255, 92/255, 10/255, 0.95)
ctx.move_to(88, H * 0.576)
ctx.show_text("LINUX")

# Divider
div_g = lin_grad(88, 0, 600, 0, [
    (0.0, (232, 92, 10, 0.60)),
    (1.0, (232, 92, 10, 0.00)),
])
ctx.set_source(div_g); ctx.set_line_width(1)
ctx.move_to(88, H*0.595); ctx.line_to(600, H*0.595); ctx.stroke()

# Scanlines
ctx.set_source_rgba(0, 0, 0, 0.022)
for y in range(0, H, 2):
    ctx.rectangle(0, y, W, 1); ctx.fill()

surf.write_to_png("arch_transam/background.png")
print("  → arch_transam/background.png")
PYEOF
  ok "arch_transam/background.png written"
}

# ─────────────────────────────────────────────────────────────────────────────
check_deps
cd "$DIR"

case "$TARGET" in
  swarm) build_swarm ;;
  arch)  build_arch  ;;
  all)   build_swarm; build_arch ;;
  *)     echo "Usage: $0 [swarm|arch|all]"; exit 1 ;;
esac

echo ""
ok "Done. Copy theme dirs to /boot/grub/themes/ and set"
echo "   GRUB_THEME=/boot/grub/themes/<name>/theme.txt"
echo "   in /etc/default/grub, then run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
