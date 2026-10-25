// Copies third-party browser files from node_modules into public/, where they are served as-is:
// - the Fairy-Stockfish engine into public/engine/ (the engine Web Worker loads it from there;
//   the files keep their original names because they reference each other);
// - coi-serviceworker.js, which adds the COOP/COEP headers on hosts that cannot (GitHub Pages).
import { copyFileSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);
const publicDir = join(dirname(new URL(import.meta.url).pathname), "..", "public");

const engineSource = dirname(require.resolve("fairy-stockfish-nnue.wasm/stockfish.js"));
const engineTarget = join(publicDir, "engine");
mkdirSync(engineTarget, { recursive: true });
for (const file of ["stockfish.js", "stockfish.worker.js", "stockfish.wasm"]) {
  copyFileSync(join(engineSource, file), join(engineTarget, file));
}

copyFileSync(require.resolve("coi-serviceworker/coi-serviceworker.js"), join(publicDir, "coi-serviceworker.js"));
