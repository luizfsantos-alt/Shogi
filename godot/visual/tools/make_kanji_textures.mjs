/**
 * Generates the engraving masks for the piece faces: godot/visual/textures/kanji/<name>.png.
 * White = carved deepest, black = untouched surface. The soft edge is the groove wall.
 * Uses Kaisei Tokumin ExtraBold (fonts/, reduced to the piece characters), drawn in Chromium.
 *
 *   node godot/visual/tools/make_kanji_textures.mjs
 */
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

// Playwright comes preinstalled globally (see scripts/make-icons.cjs); require() finds it.
const { chromium } = createRequire(import.meta.url)("playwright");

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, "../textures/kanji");
const font = readFileSync(join(here, "../fonts/kaisei-tokumin-800-koma.woff2")).toString("base64");

// Front (unpromoted) faces read top to bottom; promoted backs use one character.
const FACES = {
  king_sente: "王将", king_gote: "玉将", rook: "飛車", bishop: "角行", gold: "金将",
  silver: "銀将", knight: "桂馬", lance: "香車", pawn: "歩兵",
  rook_p: "龍王", bishop_p: "龍馬", silver_p: "全", knight_p: "圭", lance_p: "杏", pawn_p: "と",
};
const W = 384, H = 448;

const browser = await chromium.launch();
const page = await browser.newPage();
await page.setContent(`<style>@font-face{font-family:K;src:url(data:font/woff2;base64,${font})}</style><canvas></canvas>`);
await page.evaluate(() => document.fonts.load("100px K", "王将"));
for (const [name, text] of Object.entries(FACES)) {
  const png = await page.evaluate(({ text, W, H }) => {
    const c = document.createElement("canvas");
    c.width = W; c.height = H;
    const g = c.getContext("2d");
    g.fillStyle = "#000"; g.fillRect(0, 0, W, H);
    // The letters fill the body of the piece, below the pointed tip.
    const top = H * 0.2, bottom = H * 0.93;
    const draw = (blur) => {
      g.filter = blur ? `blur(${blur}px)` : "none";
      g.fillStyle = "#fff";
      g.textAlign = "center";
      g.textBaseline = "middle";
      if (text.length === 2) {
        const cell = (bottom - top) / 2;
        g.font = `${cell * 0.92}px K`;
        for (let i = 0; i < 2; i++) {
          g.save();
          g.translate(W / 2, top + cell * (i + 0.5));
          g.scale(0.9, 1);
          g.fillText(text[i], 0, 0);
          g.restore();
        }
      } else {
        g.font = `${(bottom - top) * 0.62}px K`;
        g.fillText(text, W / 2, (top + bottom) / 2 + H * 0.02);
      }
    };
    // A soft wide pass for the groove walls under a crisp core: a rounded V-shaped cut.
    g.globalCompositeOperation = "lighter";
    g.globalAlpha = 0.45; draw(3);
    g.globalAlpha = 0.55; draw(1);
    return c.toDataURL("image/png");
  }, { text, W, H });
  writeFileSync(join(out, `${name}.png`), Buffer.from(png.split(",")[1], "base64"));
}
await browser.close();
console.log(`${Object.keys(FACES).length} masks in ${out}`);
