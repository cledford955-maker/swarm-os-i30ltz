#!/usr/bin/env python3
"""Print the font name stored in a GRUB .pf2 file: pf2name.py FONT.pf2

theme.txt must reference fonts by exactly this name (e.g. "DejaVu Sans Bold 26"), which
grub-mkfont derives from the TTF's family/style and the size, so build.sh reads it back
instead of guessing.
"""
import struct
import sys


def pf2_name(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:4] != b"FILE" or data[8:12] != b"PFF2":
        raise ValueError(f"{path}: not a PF2 font")
    pos = 12
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4]
        (length,) = struct.unpack(">I", data[pos + 4:pos + 8])
        if tag == b"NAME":
            return data[pos + 8:pos + 8 + length].rstrip(b"\0").decode("utf-8")
        pos += 8 + length
    raise ValueError(f"{path}: no NAME section")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    print(pf2_name(sys.argv[1]))
