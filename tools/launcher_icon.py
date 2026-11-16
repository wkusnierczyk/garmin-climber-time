#!/usr/bin/env python3
"""Climber Time's launcher icons and store cover: a white climber in a high step, on black.

As a module, this is the renderer garmin-graphics-generator draws the icons with. `make
icons` runs the shared icons command with it (#19), and with ICONS_README from the
Makefile, which names the page, docs/graphics.md, and the sentence there that the size
table follows. The command writes
resources-icon-<size>/, the fallback in resources/drawables/, the mapping block in
monkey.jungle and that table. The launcher icon size is a per-device property, not a
per-family one, which is why the mapping is per product.

As a script, it does what that command does not -- the store cover, and its checks:

  tools/launcher_icon.py cover
  tools/launcher_icon.py check

The artwork is the owner's pick on #19, pose C, "high step" (2026-11-16): a stick
climber with a round head, one foot rocked up beside the hip, one hand low and one reaching
up. It is
drawn in a 100 x 100 box, the box scaled to 0.9 about its corner and moved by (5, 5), so
it sits centred with a margin; strokes are round-capped and round-joined. These are the
mock-up's numbers exactly, so the icon is what the owner approved.

Every icon is drawn at its own size, supersampled and averaged down, rather than scaled
from one master: the strokes are a few pixels wide at 38 x 38, where resampling a large
master blurs them unevenly. The cover is the same drawing at the store's 500 x 500.

Rendering needs Pillow; `check` needs nothing but Python.
"""
import math
import os
import sys

BACKGROUND = (0x00, 0x00, 0x00)
CLIMBER = (0xFF, 0xFF, 0xFF)

# The 100 x 100 box, and where it lands in the icon: scaled to SCALE, moved by OFFSET.
BOX = 100
SCALE = 0.9
OFFSET = 5
# Stroke width and head radius, in box units (before SCALE).
STROKE = 8.5
HEAD_RADIUS = 8.5
HEAD = (44, 22)
# Round-capped, round-joined polylines, in box units.
LIMBS = (
    ((46, 32), (52, 56)),               # torso
    ((46, 34), (32, 44), (22, 38)),     # arm, low and out to the left
    ((46, 34), (62, 30), (76, 22)),     # arm, up to the right
    ((52, 56), (70, 50), (66, 66)),     # the high step: knee up beside the hip
    ((52, 56), (46, 74), (50, 90)),     # the standing leg
)

# Each icon is drawn at SUPERSAMPLE times its size and averaged down by whole blocks
# (Image.reduce), which is the exact coverage of each pixel, without the ringing a
# Lanczos filter adds around white on black. Fixed, so regenerating is byte-identical.
SUPERSAMPLE = 8

# 500 x 500 is the size the store's dashboard asks for, and the store allows 300 KB.
# Paths from the repository root, so the script works from any directory.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COVER = os.path.join(ROOT, 'store/lite/graphics/ClimberTimeCover.png')
FALLBACK = os.path.join(ROOT, 'resources/drawables/launcher_icon.png')
COVER_SIZE = 500
COVER_LIMIT = 300 * 1000


# ------------------------------------------------------------------------ rendering

def render(size):
    """The climber, `size` pixels square."""
    from PIL import Image, ImageDraw

    big = size * SUPERSAMPLE
    unit = big / BOX                    # pixels of the supersampled image per box unit

    def point(p):
        return ((OFFSET + SCALE * p[0]) * unit, (OFFSET + SCALE * p[1]) * unit)

    def disc(c, r):
        draw.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=CLIMBER)

    image = Image.new('RGB', (big, big), BACKGROUND)
    draw = ImageDraw.Draw(image)
    half = STROKE * SCALE * unit / 2

    # A round-capped, round-joined polyline is the union of a disc at every vertex and
    # a rectangle along every segment, each as wide as the stroke.
    for limb in LIMBS:
        points = [point(p) for p in limb]
        for a, b in zip(points, points[1:]):
            dx, dy = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dx, dy)
            nx, ny = -dy / length * half, dx / length * half
            draw.polygon([(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny),
                          (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)], fill=CLIMBER)
        for p in points:
            disc(p, half)
    disc(point(HEAD), HEAD_RADIUS * SCALE * unit)

    return image.reduce(SUPERSAMPLE)


def png_size(path):
    """(width, height) out of the PNG header, so `check` needs no image library."""
    with open(path, 'rb') as f:
        head = f.read(24)
    if head[:8] != b'\x89PNG\r\n\x1a\n' or head[12:16] != b'IHDR':
        return None
    return int.from_bytes(head[16:20], 'big'), int.from_bytes(head[20:24], 'big')


def write_cover(path=COVER):
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    render(COVER_SIZE).save(path, optimize=True)
    print(f"  {COVER_SIZE}x{COVER_SIZE}  {path}  ({os.path.getsize(path)} bytes, store cover)")


# --------------------------------------------------------------------------- actions

def same_pixels(path, size):
    """Whether the PNG at `path` holds exactly what render(size) draws: decoded pixels,
    not file bytes, so zlib's output on another platform does not matter."""
    from PIL import Image
    with Image.open(path) as image:
        return image.convert('RGB').tobytes() == render(size).tobytes()


def check(path=COVER):
    """The checks garmin-graphics-generator icons --check does not make: every icon, the
    fallback and the store cover hold what the renderer draws now (the tool checks sizes
    and the mapping only), and the cover's size and weight. Needs Pillow, the one the
    icons were made with (11.3.0): another may antialias differently."""
    import glob
    fail = []

    def ok(cond, msg):
        print(f"  {'OK  ' if cond else 'FAIL'}  {msg}")
        if not cond:
            fail.append(msg)

    got = png_size(path) if os.path.exists(path) else None
    absent = " (missing)" if not os.path.exists(path) else " (not a PNG)"
    ok(got == (COVER_SIZE, COVER_SIZE),
       f"{path} is {COVER_SIZE}x{COVER_SIZE}"
       + (f" (it is {got[0]}x{got[1]})" if got and got != (COVER_SIZE, COVER_SIZE) else
          "" if got else absent))
    weight = os.path.getsize(path) if got else None
    ok(weight is not None and weight < COVER_LIMIT,
       f"{path} is under {COVER_LIMIT // 1000} KB"
       + (f" ({weight} bytes)" if weight is not None else ""))

    icons = sorted(glob.glob(os.path.join(ROOT, 'resources-icon-*', 'drawables', 'launcher_icon.png')))
    ok(icons, "resources-icon-*/ holds icons")
    for icon in icons + [FALLBACK, path]:
        got = png_size(icon) if os.path.exists(icon) else None
        ok(got is not None and got[0] == got[1] and same_pixels(icon, got[0]),
           f"{os.path.relpath(icon, ROOT)} is what the renderer draws; else run make icons")

    print(f"\n{'ALL CONSISTENT' if not fail else f'{len(fail)} PROBLEM(S)'}\n")
    return 1 if fail else 0


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['cover']:
        write_cover()
    elif args == ['check']:
        sys.exit(check())
    else:
        sys.exit(__doc__)
