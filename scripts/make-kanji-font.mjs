/**
 * Rebuilds src/ui/fonts/koma-kanji.woff2: the Potta One brush font reduced to the Japanese
 * characters the app uses (on the pieces and in the course texts). Run it after adding a new
 * Japanese term: `node scripts/make-kanji-font.mjs`.
 *
 * The Google Fonts API returns a font with only the characters passed in `text=`.
 */
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const JAPANESE = /[\u3040-\u30ff\u3400-\u9fff\u3005]/gu;
/** Characters on the pieces, always included. */
const PIECES = "王玉将飛車角行金銀桂馬香歩兵龍竜全圭杏と成棋";

function sourceFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return sourceFiles(path);
    return /\.(ts|html)$/.test(entry.name) ? [path] : [];
  });
}

const chars = new Set(PIECES);
for (const file of sourceFiles("src")) for (const char of readFileSync(file, "utf8").match(JAPANESE) ?? []) chars.add(char);
const text = [...chars].sort().join("");

// A modern browser user agent makes the API answer with woff2.
const headers = { "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" };
const css = await (await fetch(`https://fonts.googleapis.com/css2?family=Potta+One&text=${encodeURIComponent(text)}`, { headers })).text();
const url = /url\((https:[^)]+)\)\s*format\(['"]woff2['"]\)/.exec(css)?.[1];
if (!url) throw new Error(`No woff2 in the Google Fonts answer:\n${css}`);
const font = Buffer.from(await (await fetch(url, { headers })).arrayBuffer());
writeFileSync("src/ui/fonts/koma-kanji.woff2", font);
console.log(`koma-kanji.woff2: ${chars.size} characters, ${font.length} bytes`);
console.log(text);
