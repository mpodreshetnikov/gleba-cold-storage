# Mod portal thumbnail options (144x144 shipped, 512 for the portal gallery).
import os
import sys
from PIL import Image, ImageDraw, ImageFilter
CMA = os.environ.get('CMA_ROOT', 'cma-graphics') + '/graphics/icons'
MOD = os.environ.get('GCS_MOD', os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))) + '/graphics'
OUT = sys.argv[1]
S = 512

def background(top, bottom):
    bg = Image.new('RGBA', (S, S))
    d = ImageDraw.Draw(bg)
    for y in range(S):
        t = y / S
        d.line((0, y, S, y), fill=tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,))
    # frosty vignette
    v = Image.new('L', (S, S), 0); ImageDraw.Draw(v).ellipse((-80, -80, S + 80, S + 80), fill=255)
    v = v.filter(ImageFilter.GaussianBlur(60))
    dark = Image.new('RGBA', (S, S), (8, 14, 24, 255))
    return Image.composite(bg, dark, v)

def frost_corners(img):
    import random
    random.seed(4)
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    for _ in range(900):
        corner = random.choice([(0, 0), (S, 0), (0, S), (S, S)])
        r = random.random() ** 2.2 * 170
        import math
        a = random.uniform(0, 2 * math.pi)
        x = corner[0] + (abs(math.cos(a)) * r) * (1 if corner[0] == 0 else -1)
        y = corner[1] + (abs(math.sin(a)) * r) * (1 if corner[1] == 0 else -1)
        s = random.uniform(1, 3.5)
        d.ellipse((x - s, y - s, x + s, y + s), fill=(220, 240, 255, random.randint(60, 200)))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.8)))

def place(img, src, size, pos):
    im = Image.open(src).convert('RGBA').resize((size, size), Image.LANCZOS)
    sh = Image.new('RGBA', im.size, (0, 0, 0, 0)); sh.putalpha(im.split()[3].point(lambda v: int(v * 0.55)))
    sh = sh.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(sh, (pos[0] + 14, pos[1] + 18)); img.alpha_composite(im, pos)

def snowflake(img, size, pos):
    s = Image.open(f'{MOD}/icons/snowflake.png').convert('RGBA').resize((size, size), Image.LANCZOS)
    glow = s.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(glow, pos); img.alpha_composite(s, pos)

# A: the cryo vault alone, big snowflake.
a = background((40, 78, 110), (14, 30, 48)); frost_corners(a)
place(a, f'{CMA}/pressure-tank-mk3-big.png', 430, (40, 50)); snowflake(a, 130, (372, 14))
# B: chamber + vault pair.
b = background((40, 78, 110), (14, 30, 48)); frost_corners(b)
place(b, f'{MOD}/technology/cold-chamber.png', 250, (20, 210))
place(b, f'{CMA}/pressure-tank-mk3-big.png', 330, (170, 40)); snowflake(b, 120, (370, 370))
# C: green Gleba-to-ice: warm green top fading to ice blue.
c = background((58, 92, 52), (20, 52, 78)); frost_corners(c)
place(c, f'{CMA}/pressure-tank-mk3-big.png', 430, (40, 50)); snowflake(c, 130, (372, 14))
row = Image.new('RGBA', (3 * 300 + 40, 360), (30, 30, 30, 255))
for i, (n, im) in enumerate([('A', a), ('B', b), ('C', c)]):
    im.save(f'{OUT}/thumb-{n}-512.png'); im.resize((144, 144), Image.LANCZOS).save(f'{OUT}/thumb-{n}-144.png')
    row.alpha_composite(im.resize((280, 280), Image.LANCZOS), (10 + i * 310, 10))
    row.alpha_composite(im.resize((64, 64), Image.LANCZOS), (10 + i * 310, 292))
    ImageDraw.Draw(row).text((90 + i * 310, 315), n, fill=(255, 255, 255))
row.save(f'{OUT}/thumb-options.png')
