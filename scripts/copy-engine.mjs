// Copies the Fairy-Stockfish engine files into public/engine/, where the engine Web Worker
// loads them from (they must keep their original names: they reference each other).
import { copyFileSync, mkdirSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);
const source = dirname(require.resolve("fairy-stockfish-nnue.wasm/stockfish.js"));
const target = join(dirname(new URL(import.meta.url).pathname), "..", "public", "engine");

mkdirSync(target, { recursive: true });
for (const file of ["stockfish.js", "stockfish.worker.js", "stockfish.wasm"]) {
  copyFileSync(join(source, file), join(target, file));
}
