/**
 * Generates the pixel-art engraving masks for the piece faces: godot/visual/textures/kanji_px/<name>.png.
 * One big kanji in Noto Sans JP Black (OFL), rasterized on a 48×54 grid and thresholded, so its
 * strokes are 2 to 4 whole texels wide; the movement marks sit on the ring around it, near the
 * edge of the face: a 3×3 dot = one square, two dots in a row = any distance, a small cross =
 * the knight's jump. White = carved, black = untouched. The shader samples it with nearest
 * filtering, so every texel shows as a square on the lacquer.
 *
 * The font is not in the repository (5.7 MB); download the Black (900) NotoSansJP .ttf from
 * Google Fonts:
 *
 *   node godot/visual/tools/make_pixel_kanji.mjs /path/to/NotoSansJP-Black.ttf
 */
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const { chromium } = createRequire(import.meta.url)("playwright");

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "../textures/kanji_px");
mkdirSync(out, { recursive: true });
const font = readFileSync(process.argv[2]).toString("base64");

const ALL = ["N", "NE", "NW", "E", "W", "SE", "SW", "S"];
const GOLD = ["N", "NE", "NW", "E", "W", "S"];
const ORTHO = ["N", "S", "E", "W"];
const DIAG = ["NE", "NW", "SE", "SW"];
// Kanji and movement of each face (Sente's view: N is toward the tip).
const FACES = {
  king_sente: ["王", { step: ALL }], king_gote: ["玉", { step: ALL }],
  rook: ["飛", { slide: ORTHO }], bishop: ["角", { slide: DIAG }],
  gold: ["金", { step: GOLD }], silver: ["銀", { step: ["N", "NE", "NW", "SE", "SW"] }],
  knight: ["桂", { jump: true }], lance: ["香", { slide: ["N"] }], pawn: ["歩", { step: ["N"] }],
  rook_p: ["龍", { slide: ORTHO, step: DIAG }], bishop_p: ["馬", { slide: DIAG, step: ORTHO }],
  silver_p: ["全", { step: GOLD }], knight_p: ["圭", { step: GOLD }],
  lance_p: ["杏", { step: GOLD }], pawn_p: ["と", { step: GOLD }],
};
const W = 48, H = 54;
// The kanji is centred in this square box, its size in px of the font, and kept where the
// antialiased glyph is more than this opaque (0-255).
const BOX = { x: 9, y: 15, size: 30 }, PX = 31, THRESHOLD = 120;
const DOT = 3;
// Top-left texel of the dot for one square, and of the second dot for "any distance". The face is
// visible from x 1 to 46, y 53 and below the slanted top. The kanji sits low, in the body of the
// piece as on real koma; E and W sit on the edge, clear of wide kanji.
const DOTS = {
  N: [[22, 8], [22, 4]], NE: [[36, 9], [39, 6]], NW: [[9, 9], [6, 6]],
  E: [[42, 29], [45, 29]], W: [[3, 29], [0, 29]],
  SE: [[41, 47], [44, 50]], SW: [[4, 47], [1, 50]], S: [[22, 47], [22, 51]],
};
// Centres of the knight's two crosses, at the top corners.
const JUMP = [[10, 7], [37, 7]];

const browser = await chromium.launch();
const page = await browser.newPage();
await page.setContent(`<style>@font-face{font-family:D;src:url(data:font/ttf;base64,${font})}</style>`);
await page.evaluate(() => document.fonts.load("31px D", "王"));
for (const [name, [kanji, moves]] of Object.entries(FACES)) {
  const png = await page.evaluate(({ kanji, moves, W, H, BOX, PX, THRESHOLD, DOT, DOTS, JUMP }) => {
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

    const c = document.createElement("canvas");
    c.width = W; c.height = H;
    const g = c.getContext("2d");
    g.fillStyle = "#000"; g.fillRect(0, 0, W, H);
    g.fillStyle = "#fff";
    for (let y = y0; y <= y1; y++)
      for (let x = x0; x <= x1; x++)
        if (on(x, y)) g.fillRect(ox + x - x0, oy + y - y0, 1, 1);
    const dot = ([x, y]) => g.fillRect(x, y, DOT, DOT);
    (moves.step || []).forEach((d) => dot(DOTS[d][0]));
    (moves.slide || []).forEach((d) => { dot(DOTS[d][0]); dot(DOTS[d][1]); });
    if (moves.jump) {
      for (const [x, y] of JUMP) { g.fillRect(x - 2, y, 6, 2); g.fillRect(x, y - 2, 2, 6); }
    }
    return c.toDataURL("image/png");
  }, { kanji, moves, W, H, BOX, PX, THRESHOLD, DOT, DOTS, JUMP });
  writeFileSync(join(out, `${name}.png`), Buffer.from(png.split(",")[1], "base64"));
}
await browser.close();
console.log(`${Object.keys(FACES).length} masks in ${out}`);
