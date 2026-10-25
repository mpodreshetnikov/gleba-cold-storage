# Review previews for v0.2: encapsulator (press) and cryo vault, with the
# mod's own mist and frost overlays, layered the way the game draws them.
import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cma_render as R
from PIL import Image, ImageDraw, ImageFont, ImageChops
MOD = os.environ.get('GCS_MOD', os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')))
OUT = sys.argv[1]
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
ICE = (153, 217, 255)
R.ROOT_MOD = MOD

def additive(canvas, img, center, shift, alpha=1.0):
    x = int(center[0] + shift[0] * 64 - img.width / 2); y = int(center[1] + shift[1] * 64 - img.height / 2)
    layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0)); layer.alpha_composite(img, (max(0, x), max(0, y)))
    a = layer.split()[3].point(lambda v: int(v * alpha))
    rgb = Image.composite(Image.merge('RGB', layer.split()[:3]), Image.new('RGB', canvas.size), a)
    canvas.paste(Image.merge('RGBA', (*ImageChops.add(Image.merge('RGB', canvas.split()[:3]), rgb).split(), canvas.split()[3])))

def sheet_frame(path, w, h, n, cols, i, scale=0.5):
    im = Image.open(path).convert('RGBA'); i = int(i) % n
    fr = im.crop(((i % cols) * w, (i // cols) * h, (i % cols + 1) * w, (i // cols + 1) * h))
    k = scale / 0.5
    return fr.resize((int(w * k), int(h * k)), Image.LANCZOS) if k != 1 else fr

mist_sheet = Image.open(f'{MOD}/graphics/entity/cold-chamber/cold-mist.png').convert('RGBA')
def mist(i, scale):
    i = int(i) % 60
    fr = mist_sheet.crop(((i % 8) * 256, (i // 8) * 256, (i % 8 + 1) * 256, (i // 8 + 1) * 256))
    k = scale / 0.5
    return fr.resize((int(256 * k), int(256 * k)), Image.LANCZOS)

def press(canvas, c, tick, d='north'):
    m = R.Machine('industrial-press', f'mk2-{d}', tint=ICE, glow=ICE)
    m.draw(canvas, c, int(tick * 0.5))
    M = m.S['main']
    fr = sheet_frame(f'{MOD}/graphics/entity/encapsulator/frost-{d}.png', M['width'], M['height'], 32, 8, tick * 0.5)
    canvas.alpha_composite(fr, (int(c[0] + M['shift'][0] * 64 - fr.width / 2), int(c[1] + M['shift'][1] * 64 - fr.height / 2)))
    tint_shift = m.S['tint']['shift']
    additive(canvas, mist(tick * 0.15, 0.65), c, (0, -10 / 32), 0.6)

def vault(canvas, c, tick, glow=None, cooling=True):
    m = R.Machine('pressure-tank', 'mk3-north', glow=glow)
    m.draw(canvas, c, 0, working=False)
    if cooling:
        S = m.S['emission']
        e = Image.open(f'{R.ROOT}/graphics/entity/pressure-tank/pressure-tank-mk3-north-hr-emission.png').convert('RGBA')
        if glow: e = R.hue_shift(e, glow)
        additive(canvas, e, c, S['shift'])
        additive(canvas, mist(tick * 0.15, 0.65), c, (0, -10 / 32), 0.6)

def gif(path, w, h, frames, draw, title):
    bg = R.ground(w, h)
    out = []
    for f in range(frames):
        im = bg.copy(); draw(im, f * 2)
        ImageDraw.Draw(im).text((10, 8), title, fill=(255, 255, 255), font=F)
        out.append(im.convert('RGB').quantize(colors=255, method=Image.Quantize.FASTOCTREE))
    out[0].save(path, save_all=True, append_images=out[1:], duration=33, loop=0, optimize=True)

def enc(im, t):
    for k, d in enumerate(['north', 'east', 'south', 'west']):
        press(im, (170 + k * 300, 220), t, d)
gif(f'{OUT}/encapsulator-press.gif', 1200, 380, 96, enc, 'Криокапсулятор (пресс): работает, все 4 поворота')

GL = [None, (255, 70, 60), (70, 120, 255), (80, 230, 90)]
def vaults(im, t):
    for k, g in enumerate(GL):
        vault(im, (170 + k * 300, 220), t, g)
gif(f'{OUT}/cryo-vault.gif', 1200, 380, 96, vaults, 'Криохранилище: охлаждает (кольца горят, иней-пар); обычное, поставщик, запросчик, буфер')

im = R.ground(620, 380)
vault(im, (160, 210), 0, None, cooling=True); vault(im, (460, 210), 0, None, cooling=False)
d = ImageDraw.Draw(im); d.text((10, 8), 'Холодит                                Нет ячеек / нет тока: кольца погасли', fill=(255, 255, 255), font=F)
im.convert('RGB').save(f'{OUT}/cryo-vault-on-off.png')
