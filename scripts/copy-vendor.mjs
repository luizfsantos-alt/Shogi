// Copies the Fairy-Stockfish engine from node_modules into public/engine/, where the engine
// Web Worker loads it from (the files keep their original names: they reference each other).
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
