/**
 * Generates the pixel-art engraving masks for the piece faces: godot/visual/textures/kanji_px/<name>.png.
 * One big kanji in Noto Sans JP Black (OFL), rasterized on a 48×54 grid and thresholded, so its
 * strokes are 2 to 4 whole texels wide, and the movement marks around it ("moldura-bússola"). The
 * outline of the piece is the compass: the tip is forward, the shoulders the forward diagonals,
 * the middle of each side the sideways step, the base corners the backward diagonals and the
 * middle of the base backward. A filled circle there, painted where it falls on the piece = one
 * square; a chevron pointing out of the piece there =
 * any distance; two little horns under the tip = the knight's jump. The marks are pixel sprites
 * (true pixel circles, lines at 0, 45 or 90 degrees), pushed in from the edge until all of each is
 * on the piece. They reach over the rounded edge (koma_pixel.gdshader carves the mask on the top
 * of the bevel too) and keep one texel of bare lacquer around the kanji: a mark that would touch
 * it stops the script.
 * Red = the kanji, green = the marks (both carved the same way; two channels so the marks can be
 * drawn again without the font), black = untouched. The shader samples it with nearest filtering,
 * so every texel shows as a square on the lacquer.
 *
 * The font is not in the repository (5.7 MB); download the Black (900) NotoSansJP .ttf from
 * Google Fonts:
 *
 *   node godot/visual/tools/make_pixel_kanji.mjs /path/to/NotoSansJP-Black.ttf
 *
 * Without a font, the kanji already in the masks are kept and only the marks are drawn again:
 *
 *   node godot/visual/tools/make_pixel_kanji.mjs --keep-kanji
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const { chromium } = createRequire(import.meta.url)("playwright");

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "../textures/kanji_px");
mkdirSync(out, { recursive: true });
const keepKanji = process.argv[2] === "--keep-kanji";
const font = keepKanji ? null : readFileSync(process.argv[2]).toString("base64");

const ALL = ["N", "NE", "NW", "E", "W", "SE", "SW", "S"];
const GOLD = ["N", "NE", "NW", "E", "W", "S"];
const ORTHO = ["N", "S", "E", "W"];
const DIAG = ["NE", "NW", "SE", "SW"];
// Kanji, kind (for the outline) and movement of each face (Sente's view: N is toward the tip).
const FACES = {
  king_sente: ["王", "K", { step: ALL }], king_gote: ["玉", "K", { step: ALL }],
  rook: ["飛", "R", { slide: ORTHO }], bishop: ["角", "B", { slide: DIAG }],
  gold: ["金", "G", { step: GOLD }], silver: ["銀", "S", { step: ["N", "NE", "NW", "SE", "SW"] }],
  knight: ["桂", "N", { jump: true }], lance: ["香", "L", { slide: ["N"] }], pawn: ["歩", "P", { step: ["N"] }],
  rook_p: ["龍", "R", { slide: ORTHO, step: DIAG }], bishop_p: ["馬", "B", { slide: DIAG, step: ORTHO }],
  silver_p: ["全", "S", { step: GOLD }], knight_p: ["圭", "N", { step: GOLD }],
  lance_p: ["杏", "L", { step: GOLD }], pawn_p: ["と", "P", { step: GOLD }],
};
const W = 48, H = 54;
// The kanji is centred in this square box, its size in px of the font, and kept where the
// antialiased glyph is more than this opaque (0-255).
const BOX = { x: 9, y: 15, size: 30 }, PX = 31, THRESHOLD = 120;

// --- The outline of each piece, as koma_mesh.gd builds it (cm, x across, y toward the tip). ---
// The outline is checked texel by texel against the rounded pentagon, so marks never fall off it.
const SIZES = { K: [2.85, 3.2], R: [2.75, 3.1], B: [2.75, 3.1], G: [2.65, 3.0], S: [2.65, 3.0], N: [2.55, 2.95], L: [2.35, 2.9], P: [2.25, 2.8] };
const SCALE = 1.1, SHOULDER = 0.7, SHOULDER_W = 0.92;
const RADII = [0.16, 0.16, 0.22, 0.14, 0.22]; // base left, base right, right shoulder, tip, left shoulder

const sub = (a, b) => [a[0] - b[0], a[1] - b[1]];
const add = (a, b) => [a[0] + b[0], a[1] + b[1]];
const mul = (a, k) => [a[0] * k, a[1] * k];
const len = (a) => Math.hypot(a[0], a[1]);
const norm = (a) => mul(a, 1 / len(a));

function outline(kind) {
  const [w, h] = SIZES[kind].map((v) => v * SCALE);
  const corners = [[-w / 2, -h / 2], [w / 2, -h / 2], [(w / 2) * SHOULDER_W, -h / 2 + h * SHOULDER], [0, h / 2], [(-w / 2) * SHOULDER_W, -h / 2 + h * SHOULDER]];
  // Each rounded corner: the centre of its arc and where the arc meets the two edges.
  const round = corners.map((p, i) => {
    const prev = norm(sub(corners[(i + 4) % 5], p)), next = norm(sub(corners[(i + 1) % 5], p));
    const half = Math.acos(prev[0] * next[0] + prev[1] * next[1]) / 2;
    const centre = add(p, mul(norm(add(prev, next)), RADII[i] / Math.sin(half)));
    const dist = RADII[i] / Math.tan(half);
    return { p, centre, t1: add(p, mul(prev, dist)), t2: add(p, mul(next, dist)) };
  });
  return { w, h, corners, round };
}

function inside(poly, q) {
  let s = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [x1, y1] = poly[i], [x2, y2] = poly[j];
    if ((y1 > q[1]) !== (y2 > q[1]) && q[0] < ((x2 - x1) * (q[1] - y1)) / (y2 - y1) + x1) s = !s;
  }
  return s;
}

// Inside the rounded outline: inside the polygon, and not in the sliver a rounded corner cuts off
// (between the corner and its arc).
function onPiece(o, q) {
  if (!inside(o.corners, q)) return false;
  return o.round.every(({ p, centre, t1, t2 }, i) => !(inside([p, t1, t2], q) && len(sub(q, centre)) > RADII[i]));
}

// --- The marks: pixel sprites, drawn once in a "pointing up" (or "up and right") pose and turned
// for each direction, so every circle is a true pixel circle and every line runs at 0, 45 or 90
// degrees, in even steps. Texel offsets [x, y], y down; "out" is the way out of the piece.

// One square: a pixel circle, 8 texels across on the tip, the sides and the base (centred on a
// texel corner), 7 across on the corners (centred on a texel). Its inner half (the half disc,
// straight side toward the edge) is what is fitted on the piece; the whole circle is then painted
// wherever it falls on the piece, so the outer half fills the space up to the edge.
const DISC = [], DISC_HALF = [];
for (let y = -4; y < 4; y++)
  for (let x = -4; x < 4; x++)
    if ((x + 0.5) ** 2 + (y + 0.5) ** 2 <= 16) {
      DISC.push([x, y]);
      if (y >= 0) DISC_HALF.push([x, y]);
    }
const DISC_CORNER = [], DISC_CORNER_HALF = [];
for (let y = -3; y <= 3; y++)
  for (let x = -3; x <= 3; x++)
    if (x * x + y * y <= 12.25) {
      DISC_CORNER.push([x, y]);
      if (x <= y) DISC_CORNER_HALF.push([x, y]);
    }
// Any distance: a chevron pointing out. Straight ones have two arms at 45 degrees, two texels
// thick, five rows long; corner ones are a square bracket, two texels thick, six long each way.
const CHEVRON = [];
for (let y = 0; y < 5; y++) CHEVRON.push([-y - 1, y], [-y, y], [y - 1, y], [y, y]);
const CHEVRON_CORNER = [];
for (let i = 0; i < 6; i++) CHEVRON_CORNER.push([-i, 0], [-i, 1], [0, i], [-1, i]);
// The knight: two horns under the tip, a straight stem whose top bends out at 45 degrees (two
// squares forward, one aside). The left one; the right is its mirror image.
const HORN = [[-2, 0], [-1, 0], [-1, 1], [0, 1], [0, 2], [1, 2], [0, 3], [1, 3], [0, 4], [1, 4], [0, 5], [1, 5]];

const unique = (texels) => [...new Map(texels.map((t) => [t.join(), t])).values()];
// Turns a sprite from its pose to a direction. Straight sprites are centred on a texel boundary
// across their axis (x = 0 is the texel right of the axis), corner sprites on a texel.
const turn = {
  N: ([x, y]) => [x, y], S: ([x, y]) => [x, -y], E: ([x, y]) => [-y, x], W: ([x, y]) => [y, x],
  NE: ([x, y]) => [x, y], SE: ([x, y]) => [x, -y], NW: ([x, y]) => [-x, y], SW: ([x, y]) => [-x, -y],
};

// Where a sprite goes: its origin on the edge, and the step that pushes it into the piece. It is
// pushed in a texel at a time until all of `sprite` is on the piece, never cut by the outline;
// then `paint` (the sprite itself, or the whole circle around a half disc) is drawn there, where
// it falls on the piece. The left directions are the mirror images of the right ones, so the two
// sides always match.
function placeSprite(o, sprite, dir, paint = sprite) {
  const onTexel = ([x, y]) => x >= 0 && y >= 0 && x < W && y < H && onPiece(o, [((x + 0.5) / W - 0.5) * o.w, (0.5 - (y + 0.5) / H) * o.h]);
  const mirror = { W: "E", NW: "NE", SW: "SE" }[dir];
  const d = mirror || dir;
  const sy = Math.round((1 - SHOULDER) * H) - 1; // the shoulder's row
  const yMid = BOX.y + BOX.size / 2;
  const [origin, step] = {
    N: [[W / 2, 0], [0, 1]], S: [[W / 2, H - 1], [0, -1]], E: [[W - 1, yMid], [-1, 0]],
    NE: [[W - 1, sy], [-1, 0]], SE: [[W - 1, H - 1], [-1, -1]],
  }[d];
  const at = (k, s) => s.map(turn[d]).map(([x, y]) => [origin[0] + step[0] * k + x, origin[1] + step[1] * k + y]);
  for (let k = 0; k < 24; k++) {
    if (!at(k, sprite).every(onTexel)) continue;
    const texels = at(k, paint).filter(onTexel);
    return mirror ? texels.map(([x, y]) => [W - 1 - x, y]) : texels;
  }
  throw new Error(`no room for a mark at ${dir}`);
}

// The marks of one face, as mask texels.
function marksOf(kind, moves) {
  const o = outline(kind);
  const corner = (dir) => dir.length === 2;
  const texels = [];
  for (const dir of moves.step || [])
    texels.push(...(corner(dir) ? placeSprite(o, DISC_CORNER_HALF, dir, DISC_CORNER) : placeSprite(o, DISC_HALF, dir, DISC)));
  for (const dir of moves.slide || []) texels.push(...placeSprite(o, corner(dir) ? CHEVRON_CORNER : CHEVRON, dir));
  if (moves.jump) {
    // Under the tip, just below where a forward half disc would end, four texels apart.
    const tipRow = placeSprite(o, DISC_HALF, "N")[0][1];
    const horns = HORN.flatMap(([x, y]) => [[W / 2 - 4 + x, tipRow + 4 + y], [W / 2 + 3 - x, tipRow + 4 + y]]);
    if (!horns.every(([x, y]) => onPiece(o, [((x + 0.5) / W - 0.5) * o.w, (0.5 - (y + 0.5) / H) * o.h])))
      throw new Error("no room for the knight's horns");
    texels.push(...horns);
  }
  return unique(texels);
}

const browser = await chromium.launch();
const page = await browser.newPage();
if (font) {
  await page.setContent(`<style>@font-face{font-family:D;src:url(data:font/ttf;base64,${font})}</style>`);
  await page.evaluate(() => document.fonts.load("31px D", "王"));
}
for (const [name, [kanji, kind, moves]] of Object.entries(FACES)) {
  const marks = marksOf(kind, moves);
  const old = keepKanji ? "data:image/png;base64," + readFileSync(join(out, `${name}.png`)).toString("base64") : null;
  const png = await page.evaluate(async ({ kanji, old, marks, W, H, BOX, PX, THRESHOLD }) => {
    const c = document.createElement("canvas");
    c.width = W; c.height = H;
    const g = c.getContext("2d");
    const ink = new Uint8Array(W * H);
    if (old) {
      // The kanji of the existing mask: the red texels inside the kanji's box.
      const img = new Image();
      img.src = old;
      await img.decode();
      g.drawImage(img, 0, 0);
      const d = g.getImageData(0, 0, W, H).data;
      for (let y = BOX.y; y < BOX.y + BOX.size; y++)
        for (let x = BOX.x; x < BOX.x + BOX.size; x++) ink[y * W + x] = d[(y * W + x) * 4] > 127 ? 1 : 0;
    } else {
      // The kanji in a canvas twice its size, thresholded: no grey, only whole texels.
      const size = PX * 2;
      const k = document.createElement("canvas");
      k.width = size; k.height = size;
      const kg = k.getContext("2d");
      kg.fillStyle = "#fff";
      kg.font = `${PX}px D`;
      kg.textBaseline = "middle";
      kg.textAlign = "center";
      kg.fillText(kanji, PX, PX);
      const glyph = kg.getImageData(0, 0, size, size).data;
      const on = (x, y) => glyph[(y * size + x) * 4 + 3] > THRESHOLD;
      // Its bounding box, to centre it in the box whatever the font's side bearings.
      let x0 = size, y0 = size, x1 = -1, y1 = -1;
      for (let y = 0; y < size; y++)
        for (let x = 0; x < size; x++)
          if (on(x, y)) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
      const ox = Math.round(BOX.x + (BOX.size - (x1 - x0 + 1)) / 2);
      const oy = Math.round(BOX.y + (BOX.size - (y1 - y0 + 1)) / 2);
      for (let y = y0; y <= y1; y++)
        for (let x = x0; x <= x1; x++)
          if (on(x, y)) ink[(oy + y - y0) * W + ox + x - x0] = 1;
    }
    // The marks keep one texel of bare lacquer around the kanji, so the two never merge.
    const mark = new Uint8Array(W * H);
    const nearKanji = (x, y) => {
      for (let dy = -1; dy <= 1; dy++)
        for (let dx = -1; dx <= 1; dx++) {
          const xx = x + dx, yy = y + dy;
          if (xx >= 0 && yy >= 0 && xx < W && yy < H && ink[yy * W + xx] === 1) return true;
        }
      return false;
    };
    // A mark that would touch the kanji is a layout error, not something to trim quietly.
    const touching = marks.filter(([x, y]) => nearKanji(x, y));
    if (touching.length) return { error: `marks touch the kanji at ${JSON.stringify(touching)}` };
    for (const [x, y] of marks) mark[y * W + x] = 1;
    g.fillStyle = "#000"; g.fillRect(0, 0, W, H);
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++)
        if (ink[y * W + x] || mark[y * W + x]) {
          g.fillStyle = ink[y * W + x] ? "#f00" : "#0f0";
          g.fillRect(x, y, 1, 1);
        }
    return { png: c.toDataURL("image/png") };
  }, { kanji, old, marks, W, H, BOX, PX, THRESHOLD });
  if (png.error) throw new Error(`${name}: ${png.error}`);
  writeFileSync(join(out, `${name}.png`), Buffer.from(png.png.split(",")[1], "base64"));
}
await browser.close();
console.log(`${Object.keys(FACES).length} masks in ${out}`);
