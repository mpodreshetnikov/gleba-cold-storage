# Hoarfrost overlay for an animation sheet: pale crystals on the machine's
# edges and lit (upward-facing) surfaces, following every frame.
import sys, random
import numpy as np
from PIL import Image, ImageFilter
src, out = sys.argv[1], sys.argv[2]
strength = float(sys.argv[3]) if len(sys.argv) > 3 else 0.55
im = Image.open(src).convert('RGBA')
a = np.asarray(im).astype(np.float32) / 255
lum = (0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2])
alpha = a[..., 3]
lum_img = Image.fromarray((lum * 255).astype(np.uint8))
edges = np.asarray(lum_img.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
rng = np.random.default_rng(7)
h, w = lum.shape
noise = rng.random((h // 4 + 1, w // 4 + 1)).astype(np.float32)
noise = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)).astype(np.float32) / 255
crystals = np.clip((noise - 0.58) * 3.5, 0, 1)
fine = (rng.random((h, w)) > 0.985).astype(np.float32)
cover = np.clip(0.05 + 1.6 * np.clip(lum - 0.45, 0, 1) + 2.5 * edges, 0, 1)
fa = np.clip((0.8 * crystals + 0.5 * fine) * cover * strength, 0, 1) * (alpha > 0.5)
outa = np.zeros((h, w, 4), np.uint8)
outa[..., 0] = 225; outa[..., 1] = 242; outa[..., 2] = 255
outa[..., 3] = (fa * 255).astype(np.uint8)
Image.fromarray(outa).save(out, optimize=True)
