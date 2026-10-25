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
  server: { headers: crossOriginIsolation },
  preview: { headers: crossOriginIsolation },
  optimizeDeps: {
    // Emscripten modules locate their .wasm files themselves; pre-bundling breaks that.
    exclude: ["ffish-es6", "fairy-stockfish-nnue.wasm"],
  },
  test: {
    include: ["tests/**/*.test.ts"],
    environment: "node",
    testTimeout: 120_000,
  },
});
