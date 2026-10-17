#!/usr/bin/env python3
"""Minimal rsvg-convert stand-in: svg2png.py IN.svg OUT.png WIDTH HEIGHT

build.sh prefers the real `rsvg-convert` (apt: librsvg2-bin). This helper is the fallback
when only the librsvg *library* is installed (it usually is on a desktop Debian), through
PyGObject + pycairo. Output is a plain 8-bit RGBA, non-interlaced PNG, which GRUB can read.
"""
import sys

import cairo
import gi

gi.require_version("Rsvg", "2.0")
from gi.repository import Rsvg  # noqa: E402


def main(argv):
    if len(argv) != 5:
        print(__doc__, file=sys.stderr)
        return 2
    src, dst, w, h = argv[1], argv[2], int(argv[3]), int(argv[4])
    handle = Rsvg.Handle.new_from_file(src)
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h)
    ctx = cairo.Context(surface)
    viewport = Rsvg.Rectangle()
    viewport.x, viewport.y, viewport.width, viewport.height = 0, 0, w, h
    handle.render_document(ctx, viewport)
    surface.write_to_png(dst)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
