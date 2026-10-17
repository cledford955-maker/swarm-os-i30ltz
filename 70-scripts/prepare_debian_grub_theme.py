#!/usr/bin/env python3
"""Build the Debian-GRUB theme (grub_themes/swarm_dev) from images/grub/developerbackground.jpg.

Renders glossy 3D medallion icons with pycairo + ImageMagick (no network, no image model),
packages background, 9-slice selection frame, fonts and theme.txt.
Run from anywhere:  python3 70-scripts/prepare_debian_grub_theme.py
"""
import math, shutil, subprocess, sys
from pathlib import Path
import cairo

ROOT = Path(__file__).resolve().parents[1]
SRC_BG = ROOT / "images/grub/developerbackground.jpg"
OUT = ROOT / "grub_themes/swarm_dev"
ART = ROOT / "images/grub/icons3d"          # hi-res source art kept for reuse
S = 512                                      # work canvas
ICON = 56                                    # px shown in the menu
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def hexc(h, a=1.0):
    h = h.lstrip("#")
    return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a)


def surface():
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, S, S)
    c = cairo.Context(s)
    c.set_antialias(cairo.ANTIALIAS_BEST)
    return s, c


def lin(x0, y0, x1, y1, stops):
    g = cairo.LinearGradient(x0, y0, x1, y1)
    for off, col in stops:
        g.add_color_stop_rgba(off, *col)
    return g


def rad(cx, cy, r0, r1, stops, fx=None, fy=None):
    g = cairo.RadialGradient(fx if fx is not None else cx, fy if fy is not None else cy, r0, cx, cy, r1)
    for off, col in stops:
        g.add_color_stop_rgba(off, *col)
    return g


def plate(c, glow):
    """Round 3D medallion: bevelled metal rim, dark glass face, coloured inner glow, gloss."""
    cx = cy = S / 2
    c.arc(cx, cy, 246, 0, 2 * math.pi)
    c.set_source(lin(90, 40, 420, 480, [(0, hexc("#c9d3e6")), (.45, hexc("#5d6980")), (1, hexc("#10151f"))]))
    c.fill()
    c.arc(cx, cy, 232, 0, 2 * math.pi)
    c.set_source(lin(420, 480, 90, 40, [(0, hexc("#e4ecfa")), (.5, hexc("#44506a")), (1, hexc("#0b0f17"))]))
    c.fill()
    c.arc(cx, cy, 220, 0, 2 * math.pi)
    c.set_source(rad(cx, cy, 10, 225, [(0, hexc("#2d3b5c")), (.65, hexc("#0e1422")), (1, hexc("#05070c"))], 200, 170))
    c.fill()
    c.arc(cx, cy, 214, 0, 2 * math.pi)
    c.set_source(rad(cx, cy, 120, 218, [(0, hexc(glow, 0)), (.8, hexc(glow, .10)), (1, hexc(glow, .75))]))
    c.fill()
    c.arc(cx, cy, 216, 0, 2 * math.pi)
    c.set_source_rgba(*hexc(glow, .9))
    c.set_line_width(5)
    c.stroke()
    # glass reflection
    c.save()
    c.arc(cx, cy, 214, 0, 2 * math.pi)
    c.clip()
    c.save()
    c.translate(cx, 130)
    c.scale(190, 118)
    c.arc(0, 0, 1, 0, 2 * math.pi)
    c.restore()
    c.set_source(lin(0, 30, 0, 250, [(0, hexc("#ffffff", .34)), (1, hexc("#ffffff", 0))]))
    c.fill()
    c.restore()


def tube(c, path, w, pal, caps=cairo.LINE_CAP_ROUND, join=cairo.LINE_JOIN_ROUND):
    """Stroke `path` as a lit 3D tube: nested strokes shrink toward the light (upper-left)."""
    layers = [(1.00, 0, 0, pal[0]), (.88, -.02, -.03, pal[1]), (.66, -.06, -.09, pal[2]),
              (.38, -.11, -.16, pal[3]), (.13, -.17, -.25, "#ffffff")]
    c.set_line_cap(caps)
    c.set_line_join(join)
    for k, dx, dy, col in layers:
        c.save()
        c.translate(dx * w, dy * w)
        path(c)
        c.set_line_width(w * k)
        c.set_source_rgba(*hexc(col, .92 if col == "#ffffff" else 1))
        c.stroke()
        c.restore()


def poly(pts, close=False):
    def p(c):
        c.new_path()
        c.move_to(*pts[0])
        for q in pts[1:]:
            c.line_to(*q)
        if close:
            c.close_path()
    return p


def arc_path(cx, cy, r, a0, a1):
    def p(c):
        c.new_path()
        c.arc(cx, cy, r, math.radians(a0), math.radians(a1))
    return p


# ------------------------------------------------------------------ emblems
def emblem_debian(c):
    pts = []
    for i in range(0, 241):
        t = i / 240
        th = math.radians(-70 + 650 * t)
        r = 30 + 128 * t ** .9
        pts.append((256 + r * math.cos(th), 262 + r * math.sin(th)))
    tube(c, poly(pts), 44, ["#4a0010", "#c80a32", "#ff4a68", "#ffa6b4"])


def emblem_swarm(c):
    hx = [(256 + 168 * math.cos(math.radians(60 * i - 90)), 256 + 168 * math.sin(math.radians(60 * i - 90))) for i in range(6)]
    tube(c, poly(hx, True), 30, ["#5a3a00", "#d18a00", "#ffc83a", "#fff0a8"], join=cairo.LINE_JOIN_ROUND)
    # bee: wings, body, stripes, head
    for sx in (-1, 1):
        c.save()
        c.translate(256 + sx * 62, 222)
        c.rotate(sx * math.radians(32))
        c.scale(66, 30)
        c.arc(0, 0, 1, 0, 2 * math.pi)
        c.restore()
        c.set_source(lin(180, 170, 330, 270, [(0, hexc("#ffffff", .85)), (1, hexc("#7cc8ff", .45))]))
        c.fill_preserve()
        c.set_source_rgba(*hexc("#bfe6ff", .9))
        c.set_line_width(4)
        c.stroke()
    c.save()
    c.translate(256, 288)
    c.scale(50, 74)
    c.arc(0, 0, 1, 0, 2 * math.pi)
    c.restore()
    c.set_source(lin(206, 230, 306, 360, [(0, hexc("#fff0a0")), (.5, hexc("#f0a800")), (1, hexc("#7a4a00"))]))
    c.fill_preserve()
    c.save()
    c.clip()
    c.set_source_rgba(*hexc("#140a00", .95))
    for y in (262, 300, 338):
        c.rectangle(190, y, 130, 17)
    c.fill()
    c.restore()
    c.arc(256, 206, 29, 0, 2 * math.pi)
    c.set_source(rad(256, 206, 4, 32, [(0, hexc("#6a5a40")), (1, hexc("#0c0804"))], 246, 196))
    c.fill()
    c.move_to(256, 360); c.line_to(256, 384)
    c.set_source_rgba(*hexc("#140a00"))
    c.set_line_width(9); c.set_line_cap(cairo.LINE_CAP_ROUND); c.stroke()
    for sx in (-1, 1):  # antennae
        c.move_to(256 + sx * 12, 182); c.curve_to(256 + sx * 20, 150, 256 + sx * 38, 142, 256 + sx * 52, 144)
        c.set_line_width(5); c.stroke()


def emblem_recovery(c):
    cx = cy = 256
    ring = arc_path(cx, cy, 138, 0, 360)
    tube(c, ring, 74, ["#6a7488", "#dfe6f2", "#f6f9ff", "#ffffff"])
    for a in (45, 135, 225, 315):
        tube(c, arc_path(cx, cy, 138, a - 22, a + 22), 74, ["#4a0a0a", "#c4161c", "#ff5a4a", "#ffb8a8"], caps=cairo.LINE_CAP_BUTT)
    cross = lambda v: (lambda cc: (cc.new_path(), cc.move_to(256 - 46, 256) if v == 0 else cc.move_to(256, 256 - 46), cc.line_to(256 + 46, 256) if v == 0 else cc.line_to(256, 256 + 46)))
    for v in (0, 1):
        tube(c, cross(v), 30, ["#003d1c", "#00a050", "#3aff8a", "#c8ffe0"], caps=cairo.LINE_CAP_ROUND)


def emblem_cachy(c):
    pts = [(344, 172), (298, 128), (216, 128), (156, 190), (156, 322), (216, 384), (298, 384), (344, 340)]
    tube(c, poly(pts), 62, ["#00384c", "#0a9cc4", "#3ae0ff", "#bcf8ff"])


def emblem_ventoy(c):
    tube(c, poly([(132, 150), (256, 372), (380, 150)]), 66, ["#06214f", "#1a64d8", "#4fa2ff", "#c4e2ff"])
    tube(c, poly([(176, 392), (336, 392)]), 22, ["#06214f", "#1a64d8", "#4fa2ff", "#c4e2ff"])


def emblem_power(c):
    tube(c, arc_path(256, 276, 112, -60, 240), 44, ["#3a0a4a", "#a43ae0", "#d98aff", "#f4dcff"])
    tube(c, poly([(256, 120), (256, 250)]), 44, ["#3a0a4a", "#a43ae0", "#d98aff", "#f4dcff"])


def emblem_reboot(c):
    pal = ["#4a2600", "#e07a00", "#ffb23a", "#ffe2a8"]
    tube(c, arc_path(256, 256, 118, -40, 250), 44, pal)
    a = math.radians(250)  # arrow head at the arc's end
    ex, ey = 256 + 118 * math.cos(a), 256 + 118 * math.sin(a)
    c.new_path(); c.move_to(ex - 52, ey + 8); c.line_to(ex + 46, ey + 14); c.line_to(ex - 10, ey - 70); c.close_path()
    c.set_source(lin(ex - 50, ey - 60, ex + 40, ey + 20, [(0, hexc("#ffe2a8")), (.5, hexc("#ffb23a")), (1, hexc("#b45a00"))])); c.fill()


def emblem_gear(c):
    pal = ["#2a3340", "#8a98ad", "#cdd8ea", "#ffffff"]
    for i in range(8):
        a = math.radians(45 * i)
        tube(c, poly([(256 + 112 * math.cos(a), 256 + 112 * math.sin(a)), (256 + 168 * math.cos(a), 256 + 168 * math.sin(a))]),
             58, pal, caps=cairo.LINE_CAP_BUTT)
    tube(c, arc_path(256, 256, 104, 0, 360), 62, pal)


ICONS = {  # name: (glow colour, emblem)
    "debian": ("#ff2a55", emblem_debian),
    "swarm_os": ("#ffb818", emblem_swarm),
    "recovery_os": ("#2aff8a", emblem_recovery),
    "cachyos": ("#2adcff", emblem_cachy),
    "ventoy": ("#3a8cff", emblem_ventoy),
    "tools": ("#9aa8c0", emblem_gear),
    "shutdown": ("#b04aff", emblem_power),
    "restart": ("#ff9a1a", emblem_reboot),
}
ALIASES = {"debian": ["gnu-linux", "linux", "debian-gnu-linux"], "swarm_os": ["swarm", "swarm-os"],
           "recovery_os": ["recovery", "recovery-os"], "cachyos": ["cachy", "arch", "archlinux"],
           "tools": ["efi"], "shutdown": ["halt", "poweroff"], "restart": ["reboot"]}


def sh(*a):
    subprocess.run([str(x) for x in a], check=True)


def render_icons(tmp):
    ART.mkdir(parents=True, exist_ok=True)
    (OUT / "icons").mkdir(parents=True, exist_ok=True)
    for name, (glow, fn) in ICONS.items():
        ps, pc = surface(); plate(pc, glow); ps.write_to_png(str(tmp / f"{name}_plate.png"))
        es, ec = surface(); fn(ec); es.write_to_png(str(tmp / f"{name}_em.png"))
        big = ART / f"{name}.png"
        # emblem gets a soft drop shadow + coloured halo, then lands on the medallion
        sh("magick", tmp / f"{name}_plate.png",
           "(", tmp / f"{name}_em.png", "(", "+clone", "-background", "black", "-shadow", "75x10+9+16", ")", "+swap",
           "-background", "none", "-layers", "merge", "+repage", ")",
           "-gravity", "center", "-compose", "over", "-composite",
           "(", "+clone", "-background", glow, "-shadow", "55x26+0+0", ")", "+swap",
           "-background", "none", "-layers", "merge", "+repage", "-gravity", "center", "-extent", f"{S}x{S}",
           f"PNG32:{big}")
        small = OUT / "icons" / f"{name}.png"
        sh("magick", big, "-filter", "Lanczos", "-resize", f"{ICON}x{ICON}", "-unsharp", "0x0.6", f"PNG32:{small}")
        for al in ALIASES.get(name, []):
            shutil.copy2(small, OUT / "icons" / f"{al}.png")


def render_select(tmp):
    """Rounded blue-glow frame cut into the nine slices GRUB's selected_item_pixmap_style wants."""
    W = 24; r = 5; m = 0
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, W); c = cairo.Context(s)
    def rr(x0, y0, x1, y1, rad_):
        c.new_path()
        c.arc(x1 - rad_, y0 + rad_, rad_, -math.pi / 2, 0); c.arc(x1 - rad_, y1 - rad_, rad_, 0, math.pi / 2)
        c.arc(x0 + rad_, y1 - rad_, rad_, math.pi / 2, math.pi); c.arc(x0 + rad_, y0 + rad_, rad_, math.pi, 1.5 * math.pi)
        c.close_path()
    rr(m, m, W - m, W - m, r)
    c.set_source(lin(0, 0, 0, W, [(0, hexc("#2a6cff", .55)), (1, hexc("#0a1f5a", .55))])); c.fill_preserve()
    c.set_source_rgba(*hexc("#7cc4ff", .95)); c.set_line_width(2); c.stroke()
    rr(m + 2.5, m + 2.5, W - m - 2.5, W - m - 2.5, r - 2)
    c.set_source_rgba(*hexc("#ffffff", .22)); c.set_line_width(1); c.stroke()
    src = tmp / "select.png"; s.write_to_png(str(src))
    e = 5  # corner slice size; edges are 1px strips from the middle
    cuts = {"nw": (e, e, 0, 0), "ne": (e, e, W - e, 0), "sw": (e, e, 0, W - e), "se": (e, e, W - e, W - e),
            "n": (1, e, W // 2, 0), "s": (1, e, W // 2, W - e), "w": (e, 1, 0, W // 2), "e": (e, 1, W - e, W // 2),
            "c": (1, 1, W // 2, W // 2)}
    for k, (w, h, x, y) in cuts.items():
        sh("magick", src, "-crop", f"{w}x{h}+{x}+{y}", "+repage", f"PNG32:{OUT / f'select_{k}.png'}")


THEME = '''# swarm_dev — Debian GRUB. Background is 1920x1080; the menu sits in the glowing frame of the artwork.
desktop-image: "background.png"
desktop-color: "#05090d"
title-text: ""
terminal-font: "DejaVu Sans Bold 16"

+ boot_menu {
 left = 29%
 top = 34%
 width = 42%
 height = 39%
 item_font = "DejaVu Sans Bold 26"
 selected_item_font = "DejaVu Sans Bold 26"
 item_color = "#a9c8ff"
 selected_item_color = "#ffffff"
 icon_width = 56
 icon_height = 56
 item_height = 58
 item_padding = 2
 item_spacing = 6
 item_icon_space = 22
 selected_item_pixmap_style = "select_*.png"
 scrollbar = false
}
+ progress_bar {
 id = "__timeout__"
 left = 35%
 top = 75%
 width = 30%
 height = 8
 show_text = false
 fg_color = "#4fa2ff"
 bg_color = "#0a1220"
 border_color = "#2a5ca8"
}
+ label {
 left = 15%
 top = 91%
 width = 70%
 align = "center"
 text = "↑ ↓ choose    Enter boot    e edit    c console    ·    Power & firmware ▸ reboot · power off · UEFI setup"
 color = "#7fa8e0"
 font = "DejaVu Sans Bold 16"
}
'''


def main():
    if not SRC_BG.is_file():
        sys.exit(f"missing {SRC_BG}")
    import tempfile
    OUT.mkdir(parents=True, exist_ok=True)
    sh("magick", SRC_BG, "-filter", "Lanczos", "-resize", "1920x1080!", f"PNG24:{OUT / 'background.png'}")
    with tempfile.TemporaryDirectory() as t:
        t = Path(t)
        render_icons(t)
        render_select(t)
    sh("grub-mkfont", "-s", "26", "-o", OUT / "menu26.pf2", BOLD)
    sh("grub-mkfont", "-s", "16", "-o", OUT / "menu16.pf2", BOLD)
    (OUT / "theme.txt").write_text(THEME, encoding="utf-8")
    # contact sheet for eyeballing
    sh("magick", "montage", *[ART / f"{n}.png" for n in ICONS], "-tile", "8x1", "-geometry", "200x200+6+6",
       "-background", "#05090d", ART / "_contact_sheet.png")
    print("theme written to", OUT)


if __name__ == "__main__":
    main()
