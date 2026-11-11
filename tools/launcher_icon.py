"""Prototype launcher icon: a climber on a hold, drawn at 4x and downsampled.

python3 tools/launcher_icon.py <size> <out.png>
"""
import sys
from PIL import Image, ImageDraw

size, out = int(sys.argv[1]), sys.argv[2]
S = size * 4
im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([0, 0, S - 1, S - 1], fill=(36, 41, 45, 255))
u = S / 60
y = (247, 201, 72, 255)
for x0, y0 in [(22, 12), (36, 18), (18, 40), (40, 44)]:
    d.ellipse([x0 * u, y0 * u, (x0 + 6) * u, (y0 + 4) * u], fill=y)
w = (245, 245, 245, 255)
L = lambda a, b, t: d.line([a[0] * u, a[1] * u, b[0] * u, b[1] * u], fill=w, width=int(t * u))
L((30, 22), (30, 34), 4)              # torso
L((28, 22), (25, 14), 2); L((32, 22), (38, 20), 2)   # arms
L((29, 34), (21, 41), 2.4); L((31, 34), (41, 45), 2.4)  # legs
d.ellipse([27 * u, 15 * u, 33 * u, 21 * u], fill=w)  # head
im.resize((size, size), Image.LANCZOS).save(out)
