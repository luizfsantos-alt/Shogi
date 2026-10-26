/**
 * Generates the pixel-art engraving masks for the piece faces: godot/visual/textures/kanji_px/<name>.png.
 * One big kanji in DotGothic16 (a 16 px pixel font, OFL) on a 32×36 grid, plus the movement
 * marks around it: a 2×2 dot = one square, two dots in a row = any distance, a small cross = the
 * knight's jump. White = carved, black = untouched. The shader samples it with nearest filtering,
 * so every texel shows as a square on the lacquer.
 *
 * The font is not in the repository (1.9 MB); download DotGothic16-Regular.ttf from Google Fonts:
 *
 *   node godot/visual/tools/make_pixel_kanji.mjs /path/to/DotGothic16-Regular.ttf
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
const W = 32, H = 36;
// Top-left texel of the dot for one square, and of the second dot for "any distance".
const DOTS = {
  N: [[15, 6], [15, 3]], NE: [[21, 9], [23, 7]], NW: [[9, 9], [7, 7]],
  E: [[25, 20], [28, 20]], W: [[5, 20], [2, 20]],
  SE: [[25, 30], [27, 32]], SW: [[5, 30], [3, 32]], S: [[15, 31], [15, 33]],
};

const browser = await chromium.launch();
const page = await browser.newPage();
await page.setContent(`<style>@font-face{font-family:D;src:url(data:font/ttf;base64,${font})}</style>`);
await page.evaluate(() => document.fonts.load("16px D", "王"));
for (const [name, [kanji, moves]] of Object.entries(FACES)) {
  const png = await page.evaluate(({ kanji, moves, W, H, DOTS }) => {
    // The kanji at the font's native size, thresholded: no grey, only whole pixels.
    const k = document.createElement("canvas");
    k.width = 16; k.height = 16;
    const kg = k.getContext("2d");
    kg.fillStyle = "#fff";
    kg.font = "16px D";
    kg.textBaseline = "top";
    kg.textAlign = "center";
    kg.fillText(kanji, 8, 0);
    const glyph = kg.getImageData(0, 0, 16, 16).data;

    const c = document.createElement("canvas");
    c.width = W; c.height = H;
    const g = c.getContext("2d");
    g.fillStyle = "#000"; g.fillRect(0, 0, W, H);
    g.fillStyle = "#fff";
    for (let y = 0; y < 16; y++)
      for (let x = 0; x < 16; x++)
        if (glyph[(y * 16 + x) * 4 + 3] > 110) g.fillRect(8 + x, 13 + y, 1, 1);
    const dot = ([x, y]) => g.fillRect(x, y, 2, 2);
    (moves.step || []).forEach((d) => dot(DOTS[d][0]));
    (moves.slide || []).forEach((d) => { dot(DOTS[d][0]); dot(DOTS[d][1]); });
    if (moves.jump) {
      for (const [x, y] of [[7, 8], [25, 8]]) { g.fillRect(x - 1, y, 3, 1); g.fillRect(x, y - 1, 1, 3); }
    }
    return c.toDataURL("image/png");
  }, { kanji, moves, W, H, DOTS });
  writeFileSync(join(out, `${name}.png`), Buffer.from(png.split(",")[1], "base64"));
}
await browser.close();
console.log(`${Object.keys(FACES).length} masks in ${out}`);
