/**
 * Rebuilds src/ui/fonts/koma-kanji.woff2: the Potta One brush font reduced to the Japanese
 * characters the app uses (on the pieces and in the course texts). Run it after adding a new
 * Japanese term: `node scripts/make-kanji-font.mjs`.
 *
 * `node scripts/make-kanji-font.mjs --godot` makes the Godot app's font instead: the pixel kanji
 * of its interface (godot/app/ui/fonts/dot-kanji.ttf), DotGothic16 with the characters of the
 * scripts and the exported course in godot/, plus the symbols the pixel Latin fonts (Pixelify
 * Sans, Jersey 10) lack.
 *
 * The Google Fonts API returns a font with only the characters passed in `text=`.
 */
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const JAPANESE = /[\u3040-\u30ff\u3400-\u9fff\u3005]/gu;
/** Characters on the pieces, always included. */
const PIECES = "王玉将飛車角行金銀桂馬香歩兵龍竜全圭杏と成棋";
/** Symbols of the Godot interface missing from its Latin fonts, drawn by DotGothic16. */
const SYMBOLS = "★☆←→↑↓▲▼△▽▷◁■□◆≡、";

function sourceFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return sourceFiles(path);
    return /\.(ts|html|gd|json)$/.test(entry.name) ? [path] : [];
  });
}

const godot = process.argv.includes("--godot");
const output = godot ? "godot/app/ui/fonts/dot-kanji.ttf" : "src/ui/fonts/koma-kanji.woff2";
const chars = new Set(godot ? PIECES + SYMBOLS : PIECES);
for (const file of godot ? [...sourceFiles("godot/app"), ...sourceFiles("godot/learn"), ...sourceFiles("godot/game")] : sourceFiles("src")) for (const char of readFileSync(file, "utf8").match(JAPANESE) ?? []) chars.add(char);
const text = [...chars].sort().join("");

// A modern browser user agent makes the API answer with woff2; without one it answers with
// TrueType (the Godot font: Godot imports both).
const headers = godot ? {} : { "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" };
const family = godot ? "DotGothic16" : "Potta+One";
const css = await (await fetch(`https://fonts.googleapis.com/css2?family=${family}&text=${encodeURIComponent(text)}`, { headers })).text();
const format = godot ? "truetype" : "woff2";
const url = new RegExp(`url\\((https:[^)]+)\\)\\s*format\\(['"]${format}['"]\\)`).exec(css)?.[1];
if (!url) throw new Error(`No ${format} in the Google Fonts answer:\n${css}`);
const font = Buffer.from(await (await fetch(url, { headers })).arrayBuffer());
if (godot) fitLineHeight(font);
writeFileSync(output, font);
console.log(`${output}: ${chars.size} characters, ${font.length} bytes`);
console.log(text);

/**
 * DotGothic16's line (hhea and Windows metrics: 1.448 em) is much taller than its glyphs and than
 * the Latin fonts it backs up, and Godot makes every line as tall as the tallest font in the
 * fallback chain: Latin text would get a third more height than it needs and spill out of its
 * boxes. The line becomes the font's own typographic one (its glyphs' bounds, 1 em).
 */
function fitLineHeight(font) {
  const tables = {};
  for (let i = 0; i < font.readUInt16BE(4); i++) {
    const at = 12 + 16 * i;
    tables[font.toString("latin1", at, at + 4)] = font.readUInt32BE(at + 8);
  }
  const os2 = tables["OS/2"];
  const hhea = tables.hhea;
  const ascent = font.readInt16BE(os2 + 68);
  const descent = font.readInt16BE(os2 + 70);
  font.writeInt16BE(ascent, hhea + 4);
  font.writeInt16BE(descent, hhea + 6);
  font.writeInt16BE(0, hhea + 8);
  font.writeUInt16BE(ascent, os2 + 74);
  font.writeUInt16BE(-descent, os2 + 76);
}
