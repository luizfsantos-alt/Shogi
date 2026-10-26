"""Cuts the black background out of the mentor's art (source/tengu.jpg -> art/tengu.png).

The generated image comes as a JPEG on black. Every near-black pixel connected to the border
becomes transparent (a flood fill, so the black outlines inside the drawing stay), the edge gets
a one-pixel feather and the picture is cropped to the drawing.

    python3 -I godot/app/mentor/tools/cut_background.py
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

HERE = Path(__file__).resolve().parent.parent
SOURCE = HERE / "source" / "tengu.jpg"
OUT = HERE / "art" / "tengu.png"
THRESHOLD = 34  # max channel value counted as background (JPEG noise on the black)
PAD = 6

rgb = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.int16)
h, w, _ = rgb.shape
dark = rgb.max(axis=2) <= THRESHOLD
background = np.zeros((h, w), bool)
queue = deque()
for x in range(w):
    queue.extend([(0, x), (h - 1, x)])
for y in range(h):
    queue.extend([(y, 0), (y, w - 1)])
while queue:
    y, x = queue.popleft()
    if y < 0 or y >= h or x < 0 or x >= w or background[y, x] or not dark[y, x]:
        continue
    background[y, x] = True
    queue.extend([(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)])

alpha = Image.fromarray(np.where(background, 0, 255).astype(np.uint8))
alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
image = Image.fromarray(rgb.astype(np.uint8)).convert("RGBA")
image.putalpha(alpha)
ys, xs = np.nonzero(np.asarray(alpha) > 8)
box = (max(0, xs.min() - PAD), max(0, ys.min() - PAD), min(w, xs.max() + PAD + 1), min(h, ys.max() + PAD + 1))
image = image.crop(box)
OUT.parent.mkdir(parents=True, exist_ok=True)
image.save(OUT, optimize=True)
print(f"{OUT}: {image.size[0]}x{image.size[1]} (crop {box})")
