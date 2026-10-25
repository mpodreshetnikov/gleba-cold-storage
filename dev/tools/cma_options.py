import os, sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cma_render as R
from PIL import Image, ImageDraw, ImageFont
OUT = sys.argv[1]
try:
    F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 16)
except Exception:
    F = ImageFont.load_default()
CW, CH = 330, 330
ICE = (150, 215, 255)

def sheet(cells, cols, path, frames=1, working=True, title=None):
    rows = (len(cells) + cols - 1) // cols
    top = 36 if title else 0
    imgs = []
    bg = R.ground(CW * cols, CH * rows + top)
    for i in range(frames):
        im = bg.copy()
        d = ImageDraw.Draw(im)
        if title: d.text((10, 8), title, fill=(255, 255, 255), font=F)
        for n, (label, m) in enumerate(cells):
            x, y = (n % cols) * CW, (n // cols) * CH + top
            m.draw(im, (x + CW // 2 - 10, y + CH // 2 + 10), i, working=working)
            d.text((x + 10, y + 6), label, fill=(255, 255, 255), font=F)
        imgs.append(im.convert("RGB"))
    if frames == 1:
        imgs[0].save(path)
    else:
        imgs[0].save(path, save_all=True, append_images=imgs[1:], duration=50, loop=0, optimize=True)

M = R.Machine
# Cryo vault: main pick and logistic variants (logistic chest colours on the glow rings).
sheet([
    ("A. Криохранилище", M("pressure-tank", "mk3-north")),
    ("A. пассивный поставщик", M("pressure-tank", "mk3-north", glow=(255, 70, 60))),
    ("A. запросчик", M("pressure-tank", "mk3-north", glow=(70, 120, 255))),
    ("A. буфер", M("pressure-tank", "mk3-north", glow=(80, 230, 90))),
], 4, f"{OUT}/vault-option-a.png", title="Вариант A: криобак (pressure tank Mk3), цвет колец = тип логистики")
sheet([
    ("B. купол (research array Mk2)", M("research-array", "mk2")),
    ("C. сосуд (neural vat Mk2)", M("neural-vat", "mk2", tint=ICE)),
    ("D. бак Mk2 (pressure tank)", M("pressure-tank", "mk2-north")),
], 3, f"{OUT}/vault-options-bcd.png", working=False, title="Другие варианты криохранилища")
sheet([
    ("1. реактор (process reactor Mk2)", M("process-reactor", "mk2-north", tint=ICE)),
    ("2. колба (neural vat Mk3)", M("neural-vat", "mk3", tint=ICE)),
    ("3. пресс (industrial press Mk2)", M("industrial-press", "mk2-north", tint=ICE)),
], 3, f"{OUT}/encapsulator-options.gif", frames=32, title="Капсулятор: варианты (в работе, лёд в окнах)")
