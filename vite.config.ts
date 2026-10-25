import { defineConfig } from "vitest/config";

/**
 * The Fairy-Stockfish engine build (fairy-stockfish-nnue.wasm) uses WebAssembly threads,
 * which need SharedArrayBuffer. Browsers only expose it on "cross-origin isolated" pages,
 * so every server that hosts the app must send these two headers.
 */
const crossOriginIsolation = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
};

export default defineConfig({
  // Sub-path the site is served from: "/" normally, "/Shogi/" on GitHub Pages (set by the workflow).
  base: process.env.BASE_PATH ?? "/",
  server: { headers: crossOriginIsolation },
  preview: { headers: crossOriginIsolation },
  worker: { format: "es" },
  optimizeDeps: {
    // Emscripten modules locate their .wasm files themselves; pre-bundling breaks that.
    exclude: ["ffish-es6", "fairy-stockfish-nnue.wasm"],
  },
  test: {
    // `npm run calibrate` runs the (slow) AI calibration in scripts/calibration instead of the tests.
    include: process.env.CALIBRATE ? ["scripts/calibration/**/*.calib.ts"] : ["tests/**/*.test.ts"],
    environment: "node",
    testTimeout: 120_000,
  },
});
