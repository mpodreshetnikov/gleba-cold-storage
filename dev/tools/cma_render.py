# Render CMA Graphics machines the way the game layers them: shadow, base,
# recipe-tint layer (greyscale x colour), additive emission. hr scale: 64 px/tile.
import json, re, os, colorsys
from PIL import Image, ImageChops

ROOT = os.environ.get("CMA_ROOT", "cma-graphics")  # unpacked cma-graphics mod

def sprites(machine):
    s = open(f"{ROOT}/lib/sprites/{machine}.lua").read()
    s = s[s.index("return") + 6:]
    s = re.sub(r'\["([^"]+)"\]\s*=', r'"\1":', s)
    s = re.sub(r'(\w+)\s*=', r'"\1":', s)
    s = re.sub(r'\{(-?[\d.]+),\s*(-?[\d.]+)\}', r'[\1, \2]', s)
    return json.loads(s)

def frame(path, spec, i):
    im = Image.open(path).convert("RGBA")
    w, h = spec["width"], spec["height"]
    n = spec.get("line_length", 1) or 1
    i = i % spec.get("frame_count", 1)
    x, y = (i % n) * w, (i // n) * h
    return im.crop((x, y, x + w, y + h))

def hue_shift(im, target_rgb):
    """Recolour a glow layer to target_rgb, keeping its brightness."""
    r, g, b, a = im.split()
    lum = Image.merge("RGB", (r, g, b)).convert("L")
    out = Image.new("RGB", im.size, target_rgb)
    out = ImageChops.multiply(out, Image.merge("RGB", (lum, lum, lum)))
    out = Image.eval(out, lambda v: min(255, int(v * 1.6)))
    return Image.merge("RGBA", (*out.split(), a))

class Machine:
    def __init__(self, machine, key, tint=None, glow=None, glow_gain=1.0):
        self.machine, self.key = machine, key
        S = sprites(machine)
        self.S = S[key] if key in S else S
        self.prefix = f"{ROOT}/graphics/entity/{machine}/{machine}-{key}-hr"
        self.tint, self.glow, self.glow_gain = tint, glow, glow_gain
        self.frames = self.S["main"].get("frame_count", 1)

    def draw(self, canvas, center, i, working=True, shadow=True):
        cx, cy = center
        def place(img, spec, mode="normal"):
            sx, sy = spec["shift"]
            x = int(cx + sx * 64 - img.width / 2); y = int(cy + sy * 64 - img.height / 2)
            if mode == "additive":
                layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0)); layer.paste(img, (x, y))
                a = layer.split()[3]
                rgb = Image.composite(Image.merge("RGB", layer.split()[:3]), Image.new("RGB", canvas.size), a)
                if self.glow_gain != 1.0: rgb = Image.eval(rgb, lambda v: min(255, int(v * self.glow_gain)))
                base = Image.merge("RGB", canvas.split()[:3])
                canvas.paste(Image.merge("RGBA", (*ImageChops.add(base, rgb).split(), canvas.split()[3])))
            else:
                canvas.alpha_composite(img, (max(0, x), max(0, y)))
        if shadow and os.path.exists(self.prefix + "-shadow.png"):
            place(Image.open(self.prefix + "-shadow.png").convert("RGBA"), self.S["shadow"])
        if working:
            place(frame(self.prefix + "-animation.png", self.S["main"], i), self.S["main"])
        else:
            place(Image.open(self.prefix + "-idle.png").convert("RGBA"), self.S["idle"])
        if self.tint and "tint" in self.S and os.path.exists(self.prefix + "-tint.png"):
            t = frame(self.prefix + "-tint.png", self.S["tint"], i)
            col = Image.new("RGBA", t.size, self.tint + (255,))
            r, g, b, a = ImageChops.multiply(t.convert("RGBA"), col).split()
            place(Image.merge("RGBA", (r, g, b, t.split()[3])), self.S["tint"])
        if working and os.path.exists(self.prefix + "-emission.png"):
            e = frame(self.prefix + "-emission.png", self.S["emission"], i)
            if self.glow: e = hue_shift(e, self.glow)
            place(e, self.S["emission"], "additive")

def ground(w, h, seed=3):
    import random
    random.seed(seed)
    img = Image.new("RGBA", (w, h), (78, 70, 56, 255))
    px = img.load()
    for _ in range(w * h // 9):
        x, y = random.randrange(w), random.randrange(h)
        d = random.randint(-10, 8)
        r, g, b, a = px[x, y]
        px[x, y] = (max(0, r + d), max(0, g + d), max(0, b + d), 255)
    return img
