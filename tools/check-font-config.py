#!/usr/bin/env python3
"""Check that the bitmap fonts agree with their configuration, the design and docs/fonts.md (#17).

    python3 tools/check-font-config.py                  (make check-fonts)
    python3 tools/check-font-config.py --write          (make fonts: record the hashes, copy fonts.md's table in)

Adapted from Matrix Time's. The sources of truth are resources/fonts/resolutions.json (the
reference resolution and the targets), resources/fonts/fonts.xml (each font's size at the
reference, in its .fnt filename) and resources/fonts/charsets.json (each font's glyphs).
garmin-font-scaler derives everything else: the resources-<family>/fonts directories and
fonts.md, whose size table docs/fonts.md copies. This script derives what those must be and
checks them, never the reverse. It also repeats the design's sizing of the digits and the
tags (DESIGN.md §4.1, the simulator's groupLayout, Geom), which the face no longer computes at
run time, and checks every generated size against it. It holds the typeface and every bitmap to
the SHA-256 hashes make fonts records in fonts.sha256, and, where the SDK's device definitions
are present, every product in manifest.xml to a family with fonts. Pure Python, no SDK, no font
tools.
"""
import hashlib
import json
import math
import os
import re
import sys
import zlib
import struct

FONT_RE = re.compile(r'<font\s+id="(\w+)"\s+filename="([^"]+)"')
FONT_IDS = {'Time', 'Tag', 'TagLetter'}
# The glyphs each font draws: the time is %02d hours and minutes; the tags are the grade, 4 to 8
# (Climb.mc, Route: grade = 4 + ... % 5), and the proficiency, B, I or E (Draw.tags). Tag sizes the
# boxes (Draw.tagGlyphWidth measures it) and TagLetter, LETTER of its size, draws the letters (#62).
CHARSETS = {'Time': '0123456789', 'Tag': '45678BEI', 'TagLetter': '45678BEI'}
LETTER = 0.8
# Connect IQ's deviceFamily shapes; any other spelling makes a directory the compiler never
# selects, silently (wkusnierczyk/garmin-matrix-time#39).
CIQ_SHAPES = {'round', 'semiround', 'rectangle', 'semioctagon'}

# Roboto Condensed Bold, in font units (resources/fonts/RobotoCondensed-Bold.ttf): the digits'
# common advance, B's (the widest tag glyph), and the line, ascender plus descender, that
# ttf2bmp writes as lineHeight, rounded up (Draw.LINE_EM).
UPM = 2048
DIGIT_ADVANCE = 1035
B_ADVANCE = 1149
LINE = 1900 + 500

# Where the SDK manager keeps the device definitions: macOS, then Linux (CI's container runs as
# root, so ~ is /root). CIQ_DEVICES overrides. As in tools/ci-devices.py.
DEVICE_DIRS = ['~/Library/Application Support/Garmin/ConnectIQ/Devices', '~/.Garmin/ConnectIQ/Devices']
HASHES = 'fonts.sha256'
WRITE = '--write' in sys.argv[1:]

fail = []


def ok(cond, msg):
    print(f"  {'OK  ' if cond else 'FAIL'}  {msg}")
    if not cond:
        fail.append(msg)


def sha(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def fnt(path):
    """lineHeight, and {char: xadvance}, from an AngelCode .fnt."""
    text = read(path)
    line = int(re.search(r'lineHeight=(\d+)', text).group(1))
    adv = {chr(int(i)): int(a) for i, a in re.findall(r'^char id=(\d+)\s.*?xadvance=(-?\d+)', text, re.M)}
    return line, adv


# ---------------------------------------------------------------- sources of truth
res = json.loads(read('resources/fonts/resolutions.json'))
ref = res['reference']
rw, rh = ref['resolution']
targets = [(t['resolution'][0], t['resolution'][1], t['shape']) for t in res['targets']]
print("\nSOURCE OF TRUTH")
print(f"  resolutions.json  reference = {rw}x{rh} {ref['shape']}, {len(targets)} targets")

refsize = {}
for fid, fn in FONT_RE.findall(read('resources/fonts/fonts.xml')):
    m = re.match(r'(.+)-(\d+)\.fnt$', fn)
    if not m:
        ok(False, f"fonts.xml {fid}: filename {fn!r} is not <name>-<size>.fnt")
        continue
    refsize[fid] = (m.group(1), int(m.group(2)))
    print(f"  fonts.xml         {fid:5} -> {fn}  (reference size {m.group(2)})")


# Regular expressions, not xml.etree: Homebrew's Python on the owner's Mac has no working
# pyexpat (2026-11-16), and these files are the scaler's, in one known shape.
ATTR_RE = re.compile(r'(\w+)="([^"]*)"')
ELEM_RE = re.compile(r'<font\s([^>]*?)/>')


def font_elements(text):
    return [dict(ATTR_RE.findall(e)) for e in ELEM_RE.findall(text)]


def scaler_shape(text):
    """The scaler's output: a declaration, <resources><fonts>, <font/> elements, nothing else."""
    body = re.sub(r'\s+', '', ELEM_RE.sub('', text))
    return re.sub(r'^<\?xml[^>]*\?>', '', body) == '<resources><fonts></fonts></resources>'


base_fonts = font_elements(read('resources/fonts/fonts.xml'))


def k(w, h):
    return min(w / rw, h / rh)


def size_at(fid, w, h):
    """The scaler's rule: round(reference size x k), k the constraining dimension's ratio."""
    return round(refsize[fid][1] * k(w, h))


print("\nCHAIN")
ok(set(refsize) == FONT_IDS, f"fonts.xml declares exactly {sorted(FONT_IDS)} (found {sorted(refsize)})")
ok(len({stem for stem, _ in refsize.values()}) == 1 and
   len({size for _, size in refsize.values()}) == len(refsize),
   "every font is one typeface at a size of its own: the scaler names a bitmap by face and size, "
   "so two fonts at one size overwrite each other")
ok((rw, rh, ref['shape']) in targets, f"reference {rw}x{rh} {ref['shape']} is one of the targets")
for shape in sorted({ref['shape']} | {s for _, _, s in targets}):
    ok(shape in CIQ_SHAPES, f"shape {shape!r} is a Connect IQ deviceFamily shape")
for stem in sorted({stem for stem, _ in refsize.values()}):
    ok(os.path.exists(f'resources/fonts/{stem}.ttf'), f"resources/fonts/{stem}.ttf is there")
ok(os.path.exists('resources/fonts/OFL-RobotoCondensed.txt'), "the typeface's licence is beside it")

dirs = sorted(d for d in os.listdir('.') if re.match(r'resources-(round|semiround|rectangle|semioctagon)-\d+x\d+$', d))
want_dirs = sorted(f"resources-{s}-{w}x{h}" for w, h, s in targets)
ok(dirs == want_dirs, f"the resources-<family> directories are exactly the targets ({len(want_dirs)})"
   + ("" if dirs == want_dirs else f": found {dirs}"))

bad = 0
for w, h, shape in targets:
    d = f"resources-{shape}-{w}x{h}/fonts"
    if not os.path.exists(f'{d}/fonts.xml'):
        ok(False, f"{d}/fonts.xml is missing"); bad += 1
        continue
    got = dict(FONT_RE.findall(read(f'{d}/fonts.xml')))
    # The whole file, as the scaler writes it: <resources><fonts> and the base's <font>
    # elements, every attribute as the base has it but the filename, and nothing else.
    text = read(f'{d}/fonts.xml')
    want_attrs = [dict(e, filename=f"{refsize[e['id']][0]}-{size_at(e['id'], w, h)}.fnt")
                  for e in base_fonts if e.get('id') in refsize]
    if not scaler_shape(text) or font_elements(text) != want_attrs:
        ok(False, f"{d}/fonts.xml is not the scaler's: {font_elements(text)}"); bad += 1
    if set(got) != set(refsize):
        ok(False, f"{d}: declares {sorted(got)}, resources/fonts declares {sorted(refsize)}"); bad += 1
    for fid in sorted(set(got) & set(refsize)):
        want = f"{refsize[fid][0]}-{size_at(fid, w, h)}.fnt"
        if got[fid] != want:
            ok(False, f"{d} {fid}: {got[fid]}, expected {want}"); bad += 1
        elif not all(os.path.exists(f"{d}/{want[:-4]}.{e}") for e in ('fnt', 'png')):
            ok(False, f"{d} {fid}: {want} or its .png is missing"); bad += 1
if not bad:
    ok(True, "every target's fonts.xml is the scaler's, each font at round(reference x k), and its files are there")

orphans = []
for d in ['resources/fonts'] + [f"{x}/fonts" for x in dirs]:
    if not os.path.exists(f'{d}/fonts.xml'):
        continue
    keep = set(dict(FONT_RE.findall(read(f'{d}/fonts.xml'))).values())
    keep |= {f[:-4] + '.png' for f in keep}
    orphans += [f"{d}/{f}" for f in os.listdir(d) if f.endswith(('.fnt', '.png')) and f not in keep]
ok(not orphans, "no bitmap that no fonts.xml declares" + (f" (found {orphans[:3]})" if orphans else ""))

# The scaler does not refresh resources/fonts/, which the compiler reads for any product without
# a directory of its own: those copies must be the reference resolution's, byte for byte.
refdir = f"resources-{ref['shape']}-{rw}x{rh}/fonts"
for fid, (stem, size) in sorted(refsize.items()):
    for ext in ('fnt', 'png'):
        b, r = f'resources/fonts/{stem}-{size}.{ext}', f'{refdir}/{stem}-{size}.{ext}'
        ok(os.path.exists(b) and os.path.exists(r) and sha(b) == sha(r),
           f"resources/fonts/{stem}-{size}.{ext} is {refdir}'s, byte for byte")

# A product whose family has no fonts directory compiles with resources/fonts/'s copies, the
# reference's 95 and 56, too large for any smaller screen, and nothing else would say so.
dev_dir = os.environ.get('CIQ_DEVICES') or next(
    (p for p in map(os.path.expanduser, DEVICE_DIRS) if os.path.isdir(p)), None)
products = re.findall(r'<iq:product id="([^"]+)"', read('manifest.xml'))
if dev_dir is None:
    print(f"  SKIP  every product has a font family: no device definitions (looked in "
          f"{', '.join(DEVICE_DIRS)}; set CIQ_DEVICES)")
else:
    families, missing = {}, []
    for p in products:
        f = os.path.join(dev_dir, p, 'compiler.json')
        if os.path.exists(f):
            families.setdefault(json.loads(read(f))['deviceFamily'], []).append(p)
        else:
            missing.append(p)
    ok(not missing, f"every product in manifest.xml has a device definition in {dev_dir}"
       + (f" (missing {missing})" if missing else ""))
    want_fam = {f"{s}-{w}x{h}" for w, h, s in targets}
    ok(set(families) == want_fam,
       f"the {len(products)} products' families are exactly resolutions.json's targets"
       + ("" if set(families) == want_fam else
          f" (without fonts: {sorted(set(families) - want_fam)}, no product: {sorted(want_fam - set(families))})"))

# The typeface and every bitmap, by the hashes make fonts records: a changed TTF, or a bitmap
# copied over another of the same name, passes every other check.
hashed = sorted([f'resources/fonts/{stem}.ttf' for stem in {s for s, _ in refsize.values()}] +
                [f'{d}/{f}' for d in ['resources/fonts'] + [f"{x}/fonts" for x in dirs]
                 if os.path.isdir(d) for f in os.listdir(d) if f.endswith(('.fnt', '.png'))])
now = {p: sha(p) for p in hashed}
if WRITE:
    with open(HASHES, 'w', encoding='utf-8') as f:
        f.writelines(f"{h}  {p}\n" for p, h in sorted(now.items()))
    print(f"  wrote {HASHES}")
recorded = {}
if os.path.exists(HASHES):
    for line in read(HASHES).splitlines():
        h, p = line.split(None, 1)
        recorded[p] = h
changed = sorted(p for p in set(now) | set(recorded) if now.get(p) != recorded.get(p))
ok(not changed, f"the typeface and the {len(hashed) - 1} bitmaps match {HASHES} (SHA-256)"
   + (f" (differ: {changed[:4]}; make fonts records them)" if changed else ""))

# ---------------------------------------------------------------------- glyphs
print("\nGLYPHS")
charsets = {c['fontId']: c['fontCharset'] for c in json.loads(read('resources/fonts/charsets.json'))}
for fid, chars in sorted(CHARSETS.items()):
    ok(sorted(charsets.get(fid, '')) == sorted(chars),
       f"charsets.json {fid} holds exactly {chars!r} (found {charsets.get(fid)!r})")

# Every character the code measures must be in the font it measures: a missing glyph is
# measured at a fallback width without a word (playbook, fonts.md).
draw = read('source/Draw.mc')
m = re.search(r'function tagGlyphWidth.*?var chars = \[([^\]]*)\]', draw, re.S)
measured = re.findall(r'"(.)"', m.group(1)) if m else []
ok(bool(measured) and all(c in CHARSETS['Tag'] for c in measured),
   f"Draw.tagGlyphWidth measures only Tag glyphs ({''.join(measured) or 'none found'})")
ok(re.findall(r'getTextWidthInPixels\("(.)"', draw) and
   all(c in CHARSETS['Time'] for c in re.findall(r'getTextWidthInPixels\("(.)"', draw)),
   "every literal Draw measures with getTextWidthInPixels is a Time glyph")

bad = 0
for w, h, shape in targets:
    d = f"resources-{shape}-{w}x{h}/fonts"
    for fid, (stem, _) in sorted(refsize.items()):
        size = size_at(fid, w, h)
        path = f"{d}/{stem}-{size}.fnt"
        if not os.path.exists(path):
            continue
        line, adv = fnt(path)
        if sorted(adv) != sorted(CHARSETS[fid]):
            ok(False, f"{path}: holds {''.join(sorted(adv))!r}, not {CHARSETS[fid]!r}"); bad += 1
        if fid == 'Time' and len({adv.get(c) for c in '0123456789'}) != 1:
            ok(False, f"{path}: the digits' advances differ ({sorted(set(adv.values()))}): cells need one"); bad += 1
        if math.floor(line * UPM / LINE) != size:
            ok(False, f"{path}: lineHeight {line} does not give back size {size} (Draw.em)"); bad += 1
        # ttf2bmp rounds an advance up, so a whole pixel either way is the font's own.
        units = {'8': DIGIT_ADVANCE, '0': DIGIT_ADVANCE, 'B': B_ADVANCE}
        if any(abs(adv[c] - u / UPM * size) > 1 for c, u in units.items() if c in adv):
            ok(False, f"{path}: the advances are not the units above at size {size}"); bad += 1
if not bad:
    ok(True, "every bitmap holds its charset, the digits one advance, and its size in its line height")

# ---------------------------------------------------------------------- design
# The design's sizes (DESIGN.md §4.1; the simulator's groupLayout; Geom.fitGroup), for the time
# group beside the right-half wall: the digits 0.19 H, shrunk so four cells of 1.04 x width("0")
# fit between the bezel and the group's right edge, then x 1.1 x TIME_SIZE and truncated, as the
# vector-font face did; the tags so that two boxes hugging B (padded 0.12 of their size each
# side) and their gap of 0.18 span the minutes' two cells, rounded.
print("\nDESIGN")
climb = read('source/utils/Climb.mc')
time_size = float(re.search(r'const TIME_SIZE = ([\d.]+);', climb).group(1))
layout = re.search(r'const LAYOUT = (Climb\.\w+);', draw).group(1)
linear = re.search(r'const TIME_LINEAR = (\w+);', draw).group(1)
ok(layout == 'Climb.LAYOUT_HALF' and linear == 'true',
   f"the face draws the layout this sizing is for, the right half and HHMM in one line ({layout}, {linear})")


def design(w, h, shape):
    W, H = float(w), float(h)
    right = 0.5 * W - 0.03 * W
    lb = 0.03 * W
    if shape == 'round':
        dy = 0.10 * H
        lb = W / 2 - math.sqrt(W * W / 4 - dy * dy) + 0.03 * W
    fs = 0.19 * H
    tot = 4 * 1.04 * DIGIT_ADVANCE / UPM * fs
    if tot > right - lb:
        fs *= (right - lb) / tot
    digits = math.floor(fs * 1.1 * time_size)
    tag = 2 * 1.04 * DIGIT_ADVANCE / UPM * digits / (2 * (B_ADVANCE / UPM + 0.24) + 0.18)
    return digits, tag


# The scaler makes one size per screen, the reference's times the tighter of the two ratios; the
# design's digits are a share of the height. Where the height binds in the scaler too (every round
# screen, the reference) the two agree, and the size must be the design's. Where the width binds
# (320x360, #56) the two can round 1 px apart, so there the digits are within 1, and the report names
# the screen. The tags are within 1 everywhere.
rows = []
bad = 0
for w, h, shape in targets:
    digits, tag = design(w, h, shape)
    got_t, got_g, got_l = size_at('Time', w, h), size_at('Tag', w, h), size_at('TagLetter', w, h)
    width_binds = w / rw < h / rh
    off = f", {got_t - digits:+d} px, the width binds" if got_t != digits else ""
    rows.append(f"{w}x{h} Time {got_t} (design {digits}{off}), Tag {got_g} (design {tag:.2f}), "
                f"TagLetter {got_l} (design {LETTER * tag:.2f})")
    if abs(got_t - digits) > (1 if width_binds else 0) or abs(got_g - tag) > 1 or abs(got_l - LETTER * tag) > 1:
        bad += 1
for r in rows:
    print(f"        {r}")
ok(not bad, "every target's Time is the design's size, within 1 where the width binds, and its Tag and "
   f"TagLetter ({LETTER} of the Tag) within 1")

# ------------------------------------------------------------------- the tag boxes
# Each tag letter inside its box with space on every side (#62), as Draw.tags and
# Draw.inkCentred place them: the box on whole pixels from the Tag font (groupRows' row, hugging
# B, padded 0.12 of the tag size, a ring of max(2, 0.05 size) on the box's edge, its larger half
# inside), the TagLetter letter top-aligned so that its ink centre, the baseline less half the
# cap height, lands on the box's centre, a pixel up against the renderer's (TEXT_DY). The ink is
# read from each bitmap, not assumed. Both directions are relative to the box's whole-pixel edge;
# across, INK_X stands in for the bitmap's own centre, so the check asks a pixel more there, 3 px.
# The constants and code lines this model restates are asserted from Draw.mc and View.mc below,
# so that a change there fails here until the model follows.
CAP_EM = 1456 / 2048   # OS/2 sCapHeight (Draw.CAP_EM)
LINE_EM = 2400 / 2048  # Draw.LINE_EM


def png_alpha(path):
    """Rows of alpha values from an 8-bit RGBA PNG, the format ttf2bmp writes."""
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f"{path}: not a PNG (a Git LFS pointer not checked out?)")
    pos, idat, width = 8, b'', 0
    while pos < len(data):
        n, kind = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b'IHDR':
            width, _, depth, colour = struct.unpack('>IIBB', body[:10])
            if (depth, colour) != (8, 6):
                raise ValueError(f"{path}: not 8-bit RGBA")
        elif kind == b'IDAT':
            idat += body
        pos += 12 + n
    raw, stride, rows, prev, at = zlib.decompress(idat), width * 4, [], bytearray(width * 4), 0
    while at < len(raw):
        kind, line = raw[at], bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for x in range(stride):
            a = line[x - 4] if x >= 4 else 0
            b, c = prev[x], (prev[x - 4] if x >= 4 else 0)
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([line[x] for x in range(3, stride, 4)])
        prev = line
    return rows


def ink(path, chars):
    """{char: (left, right, top, bottom)} of each glyph's visible ink in its cell, and the base."""
    text = read(path)
    base = int(re.search(r'\bbase=(\d+)', text).group(1))
    alpha = png_alpha(os.path.join(os.path.dirname(path), re.search(r'file="([^"]+)"', text).group(1)))
    out = {}
    for c in chars:
        m = re.search(rf'^char id={ord(c)}\s+x=(\d+)\s+y=(\d+)\s+width=(\d+)\s+height=(\d+)'
                      rf'\s+xoffset=(-?\d+)\s+yoffset=(-?\d+)', text, re.M)
        x0, y0, cw, ch, xo, yo = map(int, m.groups())
        if (xo, yo) != (0, 0):
            raise ValueError(f"{path}: {c} has offset {xo},{yo}; the ink model assumes cells at the origin")
        pts = [(x, y) for y in range(ch) for x in range(cw) if alpha[y0 + y][x0 + x] > 64]
        # The visible centre across: the outer columns count by their strongest pixel, so a half-lit
        # edge column is half a pixel and a faint one next to nothing.
        cols = [max(alpha[y0 + y][x0 + x] for y in range(ch)) / 255 for x in range(cw)]
        lit = [x for x in range(cw) if cols[x] > 0]
        mid = ((lit[0] + 1 - cols[lit[0]]) + (lit[-1] + cols[lit[-1]])) / 2
        out[c] = (min(p[0] for p in pts), max(p[0] for p in pts), min(p[1] for p in pts), max(p[1] for p in pts), mid)
    return out, base


def whole(v):
    return math.floor(v + 0.5)


print("\nTAG BOXES")
tight, off = [], []
inks = re.search(r'const INK_CHARS = "([^"]*)";\s*const INK_X = \[([^\]]*)\]', draw)
ink_x = dict(zip(inks.group(1), (float(v) for v in inks.group(2).split(',')))) if inks else {}
ok(sorted(ink_x) == sorted(CHARSETS['TagLetter']), f"Draw.INK_X has a centre for every tag glyph ({''.join(sorted(ink_x))})")
view = read('source/View.mc')
model = {
    "Draw.CAP_EM is the cap height modelled here": re.search(r'const CAP_EM = 1456\.0 / 2048\.0;', draw),
    "Draw.TEXT_DY is the 1 px modelled here": re.search(r'const TEXT_DY = 1;', draw),
    "Draw.inkCentred draws left- and top-aligned at the modelled x and y": re.search(
        r'drawText\(Math\.round\(cx - dx\), Math\.round\(cy - mid\) - TEXT_DY, f, s, Graphics\.TEXT_JUSTIFY_LEFT\)', draw),
    "Draw.tags splits the ring, the smaller half outside": re.search(r'var out = ring / 2;\s*var inn = ring - out;', draw),
    "Draw.tags pads the hugging box 0.12 of the tag size": re.search(r'var pad = fs \* 0\.12;', draw),
    "View.onLayout sizes the boxes from the Tag font and draws the letters in TagLetter": (
        re.search(r'var tf = WatchUi\.loadResource\(Rez\.Fonts\.Tag\)', view)
        and re.search(r'g\.tagGlyphW = Draw\.tagGlyphWidth\(dc, tf\);', view)
        and re.search(r'g\.tagSize = Draw\.em\(dc, tf\);', view)
        and re.search(r'_tagFont = WatchUi\.loadResource\(Rez\.Fonts\.TagLetter\)', view)),
}
for what, found in model.items():
    ok(bool(found), what)
for d in dirs:
    w_, h_ = map(int, d.rsplit('-', 1)[1].split('x'))
    files = {e['id']: e['filename'] for e in font_elements(read(f'{d}/fonts/fonts.xml'))}
    line_t, _ = fnt(f"{d}/fonts/{files['Time']}")
    line_g, adv = fnt(f"{d}/fonts/{files['Tag']}")
    ds, fs = math.floor(line_t / LINE_EM), math.floor(line_g / LINE_EM)
    line_l, _ = fnt(f"{d}/fonts/{files['TagLetter']}")
    ls = math.floor(line_l / LINE_EM)
    glyphs, base = ink(f"{d}/fonts/{files['TagLetter']}", CHARSETS['TagLetter'])
    dh = 0.72 * ds
    cy = h_ / 2 - dh / 2 + dh + 0.18 * ds + 0.96 * fs / 2        # Draw.groupRows, TIME_CENTRED
    pad = fs * 0.12
    bw = max(adv[c] for c in '8BIE') + 2 * pad                   # Draw.tagGlyphWidth
    th = 0.72 * fs + 2 * pad
    bw_i, th_i, ring_all = whole(bw), whole(th), whole(max(2.0, fs * 0.05))
    ring = ring_all - ring_all // 2                               # the ring's inner part
    y = whole(cy - th / 2)
    top = whole(y + th_i / 2 - (base - CAP_EM * ls / 2))                # Draw.inkCentred (TEXT_DY undoes the renderer's pixel)
    worst = min(min(top + t - (y + ring), (y + th_i - ring - 1) - (top + b)) for _, _, t, b, _ in glyphs.values())
    # Across, relative to the box's left edge (a whole pixel, so it drops out): the glyph's origin
    # at the box's centre less its outline centre, and the space either side of the lit columns.
    side = 99
    for c, (l, r, _, _, mid) in glyphs.items():
        left = whole(bw_i / 2 - ink_x[c] / UPM * ls)
        side = min(side, left + l - ring, (bw_i - ring - 1) - (left + r))
        if abs(ink_x[c] / UPM * ls - mid) > 0.5:
            off.append(f"{d[10:]} {c}: Draw.INK_X puts its centre {ink_x[c] / UPM * ls:.2f} px in, the bitmap {mid:.2f}")
    print(f"        {d[10:]:16} Tag {fs}, TagLetter {ls}: at least {worst} px above and below, {side} px a side")
    if worst < 2 or side < 3:
        tight.append(d)
ok(not off, "Draw.INK_X centres each tag glyph within half a pixel of its bitmap's visible centre"
   + (f" (not {off[:3]})" if off else ""))
ok(not tight, "every tag letter has at least 2 px of space above and below inside its ring, and 3 px a side"
   + (f" (not in {', '.join(tight)})" if tight else ""))

# ------------------------------------------------------------------- the tables
print("\nTABLES")
# The element is the font id in words, as the scaler writes it: TagLetter is "Tag letter".
ROW_RE = re.compile(r'^\|\s*(\d+)\s*x\s*(\d+)\s*\|\s*(\w+)\s*\|\s*(\w+(?: \w+)*?)\s*\|\s*([\w ]+?)\s*\|\s*(\d+)\s*\|$')
HEAD = '# Font sizes by resolution'


def resolution_table(text):
    """The lines of the first table after HEAD, or of the table holding a 'Resolution' header."""
    lines = text.split(HEAD, 1)[1].splitlines() if HEAD in text else text.splitlines()
    out = []
    for line in lines:
        if line.startswith('| Resolution |') or (out and line.startswith('|')):
            out.append(line)
        elif out:
            break
    return out


def check_rows(lines, label):
    got = {}
    for line in lines:
        m = ROW_RE.match(line.strip())
        if m:
            fid = ''.join(word.capitalize() for word in m.group(4).split())
            got[(int(m.group(1)), int(m.group(2)), m.group(3), fid)] = int(m.group(6))
    want = {(w, h, s, fid): size_at(fid, w, h) for w, h, s in targets for fid in refsize}
    ok(got == want, f"{label}: one row per target and font, at round(reference x k)"
       + ("" if got == want else f" (differs at {sorted(set(got.items()) ^ set(want.items()))[:3]})"))


fonts_md = read('fonts.md')
table = resolution_table(fonts_md)
check_rows(table, 'fonts.md')

PAGE = 'docs/fonts.md'   # the fonts page, which copies fonts.md's size table (#10)
page = read(PAGE)
START, END = '<!-- fonts.md: start -->', '<!-- fonts.md: end -->'
if WRITE:
    if START in page and END in page:
        head, rest = page.split(START, 1)
        page = head + START + '\n' + '\n'.join(table) + '\n' + END + rest.split(END, 1)[1]
        with open(PAGE, 'w', encoding='utf-8') as f:
            f.write(page)
        print(f"  wrote fonts.md's table into {PAGE}")
    else:
        ok(False, f"{PAGE} has no {START} ... {END} block to write the table into")
block = page.split(START, 1)[1].split(END, 1)[0].strip().splitlines() if START in page and END in page else []
ok(block == table, f"{PAGE}'s size table is fonts.md's, line for line (make fonts copies it)")
paragraphs = [' '.join(b.split()) for b in re.split(r'\n\s*\n', page)]
prose = [b for b in paragraphs if 'reference resolution' in b.lower()]
ok(any(re.search(rf'\b{rw}\s*[x×]\s*{rh}\b', b) and 'resolutions.json' in b for b in prose),
   f"{PAGE} names the reference resolution, {rw}x{rh}, and resolutions.json, in one paragraph")

print()
if fail:
    print(f"{len(fail)} check(s) failed.")
    sys.exit(1)
print("Font configuration is consistent.")
