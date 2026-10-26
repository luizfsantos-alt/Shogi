"""Turns the generated pictures in art_source/ into the app's pixel art.

The generator draws pixel art but delivers it as a big JPEG on black: every art pixel is a
block of screen pixels (3×3 for the portraits), blurred by the compression, with thousands of
colours. For each picture this script

1. finds where the blocks start (the columns and rows where the colour jumps), for the block size
   given below (measured once per kind of picture: the generator keeps it within a set);
2. cuts the black background: near-black blocks connected to the border become transparent
   (a flood fill, so the dark outlines inside the drawing stay);
3. shrinks the picture to one pixel per block (the median of the block: sharp, no JPEG haze);
4. closes the palette (median cut, no dithering) and crops to the drawing.

Pictures of one group (the tengu's poses, a rival and its defeated face) share one crop box, so
they can replace each other in place. The app draws them with nearest filtering.

    python3 -I godot/art_source/prepare_art.py
"""
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
APP = HERE.parent / "app"
THRESHOLD = 34   # max channel value counted as background (JPEG noise on the black)
PAD = 2          # art pixels of margin around the crop

# name -> (output, block size, colours, group). A group shares its crop box.
JOBS = {
    "tengu_neutral": ("mentor/art/tengu_neutral.png", 3, 48, "tengu"),
    "tengu_explain": ("mentor/art/tengu_explain.png", 3, 48, "tengu"),
    "tengu_point": ("mentor/art/tengu_point.png", 3, 48, "tengu"),
    "tengu_startled": ("mentor/art/tengu_startled.png", 3, 48, "tengu"),
    "tengu_laugh": ("mentor/art/tengu_laugh.png", 3, 48, "tengu"),
    "tengu_stern": ("mentor/art/tengu_stern.png", 3, 48, "tengu"),
    "rival_kappa": ("rivals/art/kappa.png", 3, 40, "kappa"),
    "rival_kappa_defeated": ("rivals/art/kappa_defeated.png", 3, 40, "kappa"),
    "rival_ashigaru": ("rivals/art/ashigaru.png", 3, 40, "ashigaru"),
    "rival_ashigaru_defeated": ("rivals/art/ashigaru_defeated.png", 3, 40, "ashigaru"),
    "rival_benkei": ("rivals/art/benkei.png", 3, 40, "benkei"),
    "rival_benkei_defeated": ("rivals/art/benkei_defeated.png", 3, 40, "benkei"),
    "rival_kiyomori": ("rivals/art/kiyomori.png", 3, 40, "kiyomori"),
    "rival_kiyomori_defeated": ("rivals/art/kiyomori_defeated.png", 3, 40, "kiyomori"),
    "rival_kitsune": ("rivals/art/kitsune.png", 3, 40, "kitsune"),
    "rival_kitsune_defeated": ("rivals/art/kitsune_defeated.png", 3, 40, "kitsune"),
    "emblem_basics": ("course_art/basics.png", 16, 24, None),
    "emblem_tactics": ("course_art/tactics.png", 16, 24, None),
    "emblem_strategy": ("course_art/strategy.png", 16, 24, None),
    "icon_tengu": ("icon/tengu.png", 16, 32, None),  # then the launcher sizes: see icons()
}


def offset(gray: np.ndarray, axis: int, size: int) -> int:
    """Where the blocks start along one axis: the colour jumps most at one phase of `size`."""
    g = np.abs(np.diff(gray, axis=axis)).sum(axis=1 - axis)
    phases = [g[i::size].mean() for i in range(size)]
    return (int(np.argmax(phases)) + 1) % size


def shrink(path: Path, s: int) -> tuple[np.ndarray, np.ndarray]:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.int16)
    gray = rgb.mean(axis=2)
    ox = offset(gray, 1, s)
    oy = offset(gray, 0, s)
    h, w, _ = rgb.shape
    ny, nx = (h - oy) // s, (w - ox) // s
    cells = rgb[oy:oy + ny * s, ox:ox + nx * s].reshape(ny, s, nx, s, 3).transpose(0, 2, 1, 3, 4).reshape(ny, nx, s * s, 3)
    small = np.median(cells, axis=2).astype(np.int16)
    # Background: dark blocks reachable from the border.
    dark = small.max(axis=2) <= THRESHOLD
    bg = np.zeros((ny, nx), bool)
    queue = deque([(y, x) for x in range(nx) for y in (0, ny - 1)] + [(y, x) for y in range(ny) for x in (0, nx - 1)])
    while queue:
        y, x = queue.popleft()
        if 0 <= y < ny and 0 <= x < nx and not bg[y, x] and dark[y, x]:
            bg[y, x] = True
            queue.extend([(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)])
    print(f"  {path.name}: blocks of {s} px from ({ox}, {oy}) -> {nx}x{ny}")
    return small.astype(np.uint8), ~bg


def quantize(rgb: np.ndarray, opaque: np.ndarray, colours: int) -> np.ndarray:
    pixels = rgb[opaque].reshape(-1, 1, 3)
    pal = Image.fromarray(pixels).quantize(colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    full = Image.fromarray(rgb).quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    return np.asarray(full)


def main() -> None:
    results = {}
    for name, (out, size, colours, group) in JOBS.items():
        rgb, opaque = shrink(HERE / f"{name}.jpg", size)
        results[name] = (quantize(rgb, opaque, colours), opaque, out, group)
    # Crop boxes: per group, the union of the drawings (same size pictures only).
    boxes = {}
    for name, (_, opaque, _, group) in results.items():
        ys, xs = np.nonzero(opaque)
        box = [xs.min(), ys.min(), xs.max() + 1, ys.max() + 1]
        key = group or name
        if key in boxes:
            b = boxes[key]
            box = [min(b[0], box[0]), min(b[1], box[1]), max(b[2], box[2]), max(b[3], box[3])]
        boxes[key] = box
    for name, (rgb, opaque, out, group) in results.items():
        x0, y0, x1, y1 = boxes[group or name]
        h, w = opaque.shape
        x0, y0, x1, y1 = max(0, x0 - PAD), max(0, y0 - PAD), min(w, x1 + PAD), min(h, y1 + PAD)
        rgba = np.dstack([rgb, np.where(opaque, 255, 0).astype(np.uint8)])[y0:y1, x0:x1]
        target = APP / out
        target.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(rgba, "RGBA").save(target, optimize=True)
        print(f"{target.relative_to(APP.parent)}: {x1 - x0}x{y1 - y0}")



def icons() -> None:
    """Launcher icons from the tengu's face: square, whole multiples of the art pixels."""
    face = Image.open(APP / "icon/tengu.png").convert("RGBA")
    corner = face.getpixel((1, 1))
    side = max(face.size)
    square = Image.new("RGBA", (side, side), corner)
    square.alpha_composite(face, ((side - face.width) // 2, side - face.height))
    square.save(APP / "icon/icon.png")
    square.resize((side * 3, side * 3), Image.NEAREST).save(APP / "icon/icon_192.png")
    # Adaptive icon: the face on the same colour, the background plain; the launcher masks the
    # outer third, so the face fills the middle 384 of 432 pixels.
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    fg.alpha_composite(square.resize((side * 6, side * 6), Image.NEAREST), ((432 - side * 6) // 2,) * 2)
    fg.save(APP / "icon/icon_foreground_432.png")
    Image.new("RGBA", (432, 432), corner).save(APP / "icon/icon_background_432.png")
    print("app/icon: icon.png, icon_192.png, icon_foreground_432.png, icon_background_432.png")


main()
icons()
