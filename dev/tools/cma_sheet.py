# Contact sheet of CMA Graphics idle frames on a Nauvis-ish ground tile.
import sys, os, glob, re
from PIL import Image, ImageDraw, ImageFont
root = sys.argv[1]; out = sys.argv[2]; names = sys.argv[3].split(',')
suffix = sys.argv[4] if len(sys.argv) > 4 else 'north'
CELL = 230
rows = []
for n in names:
    row = []
    for v in ['mk1', 'mk2', 'mk3']:
        cands = [f"{root}/graphics/entity/{n}/{n}-{v}-{suffix}-hr-idle.png", f"{root}/graphics/entity/{n}/{n}-{v}-hr-idle.png"]
        f = next((c for c in cands if os.path.exists(c)), None)
        if not f: continue
        sh = f.replace('-idle', '-shadow')
        fr = f.replace('-idle', '-frozen')
        row.append((n + ' ' + v, f, sh if os.path.exists(sh) else None, fr if os.path.exists(fr) else None))
    rows.append(row)
cols = 6
W = CELL * cols; H = CELL * len(rows)
img = Image.new('RGBA', (W, H), (74, 66, 52, 255))
d = ImageDraw.Draw(img)
for r, row in enumerate(rows):
    c = 0
    for label, f, sh, fr in row:
        for frozen in (False, True):
            if frozen and not fr: c += 1; continue
            x0, y0 = c * CELL, r * CELL
            base = Image.open(f).convert('RGBA')
            if sh:
                s = Image.open(sh).convert('RGBA')
                img.alpha_composite(s, (x0 + (CELL - s.width) // 2 + 30, y0 + (CELL - s.height) // 2 + 20))
            img.alpha_composite(base, (x0 + (CELL - base.width) // 2, y0 + (CELL - base.height) // 2))
            if frozen:
                z = Image.open(fr).convert('RGBA')
                img.alpha_composite(z, (x0 + (CELL - z.width) // 2, y0 + (CELL - z.height) // 2))
            d.text((x0 + 4, y0 + 4), label + (' frozen' if frozen else ''), fill=(255, 255, 255, 255))
            c += 1
img.save(out)
