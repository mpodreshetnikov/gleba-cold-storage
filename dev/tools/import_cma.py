# Copy the CMA Graphics sprites the mod uses into graphics/entity/cma and
# build the recoloured vault glows and the icons.
import sys, os, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cma_render as R
from PIL import Image

MOD = os.environ.get('GCS_MOD', os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')))
SRC = R.ROOT
OUT = f'{MOD}/graphics/entity/cma'
os.makedirs(OUT, exist_ok=True)
os.makedirs(f'{MOD}/prototypes/cma', exist_ok=True)

for d in ['north', 'east', 'south', 'west']:
    for layer in ['animation', 'emission', 'shadow', 'tint', 'frozen']:
        f = f'industrial-press-mk2-{d}-hr-{layer}.png'
        shutil.copy(f'{SRC}/graphics/entity/industrial-press/{f}', OUT)
for layer in ['idle', 'shadow', 'emission']:
    f = f'pressure-tank-mk3-north-hr-{layer}.png'
    shutil.copy(f'{SRC}/graphics/entity/pressure-tank/{f}', OUT)
for m in ['industrial-press', 'pressure-tank']:
    shutil.copy(f'{SRC}/lib/sprites/{m}.lua', f'{MOD}/prototypes/cma/{m}.lua')

GLOWS = {'-passive-provider': (255, 70, 60), '-requester': (70, 120, 255), '-buffer': (80, 230, 90)}
em = Image.open(f'{OUT}/pressure-tank-mk3-north-hr-emission.png').convert('RGBA')
for suffix, rgb in GLOWS.items():
    R.hue_shift(em, rgb).save(f'{OUT}/pressure-tank-mk3-north-hr-emission{suffix}.png', optimize=True)

def icon(machine, key, path, glow=None, tint=None):
    m = R.Machine(machine, key, glow=glow, tint=tint)
    canvas = Image.new('RGBA', (400, 400), (0, 0, 0, 0))
    m.draw(canvas, (200, 200), 0, working=True, shadow=False)
    canvas = canvas.crop(canvas.getbbox())
    side = max(canvas.size)
    sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    sq.alpha_composite(canvas, ((side - canvas.width) // 2, (side - canvas.height) // 2))
    sq.resize((64, 64), Image.LANCZOS).save(path, optimize=True)

I = f'{MOD}/graphics/icons'
icon('pressure-tank', 'mk3-north', f'{I}/cryo-vault.png')
for suffix, rgb in GLOWS.items():
    icon('pressure-tank', 'mk3-north', f'{I}/cryo-vault{suffix}.png', glow=rgb)
icon('industrial-press', 'mk2-north', f'{I}/encapsulator.png', tint=(150, 215, 255))
print('ok')
