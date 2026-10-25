# Tech tree diagram for review.
import os
import sys
from PIL import Image, ImageDraw, ImageFont
G = os.environ.get('GCS_MOD', os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))) + '/graphics'
OUT = sys.argv[1]
B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"; Rg = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
F1, F2, F3 = ImageFont.truetype(B, 20), ImageFont.truetype(Rg, 15), ImageFont.truetype(B, 15)
W, H = 1320, 760
im = Image.new('RGB', (W, H), (36, 35, 33)); d = ImageDraw.Draw(im)
def icon(name, size=40):
    return Image.open(f'{G}/icons/{name}.png').convert('RGBA').resize((size, size), Image.LANCZOS)
def box(x, y, w, h, fill=(58, 56, 52), outline=(110, 104, 92)):
    d.rounded_rectangle((x, y, x + w, y + h), 8, fill=fill, outline=outline, width=2)
def prereq(x, y, text):
    box(x, y, 200, 44, fill=(48, 47, 44)); d.text((x + 10, y + 13), text, fill=(200, 196, 186), font=F2)

NODES = [
    dict(x=30, tech='cold-chamber', name='Холодовая цепь', where='Глеба',
         cost='300 × 5 пакетов (до агро), 30 с',
         unlocks=[('cold-chamber', 'Холодильная камера')],
         note=['×3 медленнее при 0°', 'ток 250 кВт + вода 6/с,', 'выдаёт пар 100°', 'упёрся пар — холод встаёт']),
    dict(x=460, tech='cryo-vault', name='Криохранение', where='после Аквилона',
         cost='1000 × 8 пакетов (до криогенного), 60 с',
         unlocks=[('cryo-vault', 'Криохранилище'), ('cryo-vault-passive-provider', '…пассивный поставщик'),
                  ('cryo-vault-requester', '…запросчик'), ('cryo-vault-buffer', '…буфер'),
                  ('refrigerated-wagon', 'Рефрижераторный вагон'), ('empty-cryo-cell', 'Пустая криоячейка'),
                  ('cryo-cell', 'Криоячейка (только Аквилон)')],
         note=['до ×20 при −35°', 'на Аквилоне холод бесплатный', 'в других местах: ток + ячейки']),
    dict(x=890, tech='encapsulation', name='Криокапсуляция', where='после Аквилона',
         cost='1500 × 8 пакетов, 60 с',
         unlocks=[('encapsulator', 'Криокапсулятор'), ('ice-overlay', 'Лёд из воды'),
                  ('snowflake', '20 рецептов заморозки'), ('thaw', '20 рецептов разморозки')],
         note=['10 продуктов + 1 лёд → блок', 'блок хранится', 'в 10 раз дольше']),
]
d.text((40, 16), 'Дерево технологий Gleba Cold Storage 0.2', fill=(255, 230, 170), font=F1)
prereq(30, 60, 'Агро-научный пакет')
prereq(460, 60, 'Криогенный пакет'); prereq(680, 60, 'Логистич. система')
for n in NODES:
    x = n['x']; y = 130
    box(x, y, 400, 600)
    t = Image.open(f"{G}/technology/{n['tech']}.png").convert('RGBA').resize((128, 128), Image.LANCZOS)
    im.paste(t, (x + 12, y + 12), t)
    d.text((x + 150, y + 18), n['name'], fill=(255, 230, 170), font=F1)
    d.text((x + 150, y + 48), n['where'], fill=(170, 210, 255), font=F2)
    yy = y + 76
    for line in n['note']:
        d.text((x + 150, yy), line, fill=(220, 216, 206), font=F2); yy += 19
    d.text((x + 12, y + 156), 'Цена: ' + n['cost'], fill=(200, 196, 186), font=ImageFont.truetype(Rg, 13))
    d.text((x + 12, y + 184), 'Открывает:', fill=(255, 255, 255), font=F3)
    yy = y + 210
    for ic, label in n['unlocks']:
        i = icon(ic); im.paste(i, (x + 14, yy), i)
        d.text((x + 64, yy + 11), label, fill=(230, 226, 216), font=F2); yy += 48
# arrows
def arrow(x1, y1, x2, y2):
    d.line((x1, y1, x2, y2), fill=(240, 200, 120), width=4)
    d.polygon([(x2, y2), (x2 - 12, y2 - 8), (x2 - 12, y2 + 8)], fill=(240, 200, 120))
arrow(430, 260, 458, 260); arrow(860, 260, 888, 260)
d.line((130, 104, 130, 128), fill=(240, 200, 120), width=3)
d.line((560, 104, 560, 128), fill=(240, 200, 120), width=3); d.line((780, 104, 780, 128), fill=(240, 200, 120), width=3)
im.save(OUT)
