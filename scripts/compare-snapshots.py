#!/usr/bin/env python3
"""Compares a baseline snapshot folder with a new one.

Cards (SVG) must be byte-identical. Screens (PNG) are compared pixel by pixel after `sips` unpacks them to BMP.
Three kinds of drift are tolerated and reported, never counted as failures:
  - a card whose only difference is the "$X last 7 days" cost, which comes from the agents' live logs;
  - the header band of an open-notch screen (top HEADER_PX rows at 2x) holds the churu balance, which moves as
    the agents' logs grow;
  - VOLATILE screens (home-ledger) show live limits and a reset countdown; a task that touches Home checks them
    by eye.
Usage: scripts/compare-snapshots.py <base-dir> <new-dir>   (exit 1 on any real difference)
"""
import glob
import re
import os
import struct
import subprocess
import sys
import tempfile

HEADER_PX = 80
VOLATILE = {"home-ledger.png"}
COST = re.compile(r"\$[0-9][0-9,]*(\.[0-9]+)? last 7 days")

base, new = sys.argv[1], sys.argv[2]
fail = False


def rows_that_differ(png_a, png_b):
    """Row indexes (from the top) whose pixels differ, or None when the sizes differ."""
    with tempfile.TemporaryDirectory() as tmp:
        bmps = []
        for src, name in ((png_a, "a"), (png_b, "b")):
            out = os.path.join(tmp, name + ".bmp")
            subprocess.run(["sips", "-s", "format", "bmp", src, "--out", out], capture_output=True, check=True)
            bmps.append(open(out, "rb").read())
    a, b = bmps
    width, height = struct.unpack_from("<ii", a, 18)
    if (width, height) != struct.unpack_from("<ii", b, 18):
        return None
    offset = struct.unpack_from("<I", a, 10)[0]
    bytes_per_pixel = struct.unpack_from("<H", a, 28)[0] // 8
    stride = (width * bytes_per_pixel + 3) // 4 * 4
    top_down = height < 0
    height = abs(height)
    differing = []
    for y in range(height):
        start = offset + y * stride
        if a[start:start + stride] != b[start:start + stride]:
            differing.append(y if top_down else height - 1 - y)
    return differing


for path in sorted(glob.glob(os.path.join(base, "cards", "*.svg"))):
    name = os.path.basename(path)
    other = os.path.join(new, "cards", name)
    if not os.path.exists(other):
        print(f"MISSING {name}"); fail = True
    elif open(path, "rb").read() == open(other, "rb").read():
        print(f"same  {name}")
    elif COST.sub("$", open(path).read()) == COST.sub("$", open(other).read()):
        print(f"DRIFT {name} (only the live 7-day cost differs)")
    else:
        print(f"DIFF  {name}"); fail = True

for path in sorted(glob.glob(os.path.join(base, "screens", "*.png"))):
    name = os.path.basename(path)
    other = os.path.join(new, "screens", name)
    if not os.path.exists(other):
        print(f"MISSING {name}"); fail = True
        continue
    rows = rows_that_differ(path, other)
    if rows is None:
        print(f"SIZE  {name}"); fail = True
    elif not rows:
        print(f"same  {name}")
    elif max(rows) < HEADER_PX:
        print(f"same  {name} (header band differs: churu balance, rows {min(rows)}-{max(rows)})")
    elif name in VOLATILE:
        print(f"DRIFT {name} (volatile; rows {min(rows)}-{max(rows)} — check by eye if Home changed)")
    else:
        print(f"DIFF  {name} (rows {min(rows)}-{max(rows)})"); fail = True

sys.exit(1 if fail else 0)
