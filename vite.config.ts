import { createHash } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import type { Plugin } from "vite";
import { defineConfig } from "vitest/config";

/**
 * The Fairy-Stockfish engine build (fairy-stockfish-nnue.wasm) uses WebAssembly threads,
 * which need SharedArrayBuffer. Browsers only expose it on "cross-origin isolated" pages,
 * so every server that hosts the app must send these two headers (the service worker adds
 * them where the host cannot, see src/pwa/sw.template.js).
 */
const crossOriginIsolation = {
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Embedder-Policy": "require-corp",
};

/** Files served by the host only, never requested by the app. */
const NOT_CACHED = new Set(["sw.js", "_headers"]);

function listFiles(dir: string, root = dir): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    return entry.isDirectory() ? listFiles(path, root) : [relative(root, path).split("\\").join("/")];
  });
}

/**
 * Writes dist/sw.js from the template after the build: the list of every file to cache for
 * offline play, and a version that changes whenever any of them changes (so players get updates).
 */
function serviceWorker(): Plugin {
  let outDir = "dist";
  return {
    name: "shogi-service-worker",
    apply: "build",
    configResolved(config) {
      outDir = resolve(config.root, config.build.outDir);
    },
    closeBundle() {
      const files = listFiles(outDir).filter((file) => !NOT_CACHED.has(file)).sort();
      const hash = createHash("sha256");
      for (const file of files) hash.update(file).update(readFileSync(join(outDir, file)));
      const template = readFileSync(resolve(import.meta.dirname, "src/pwa/sw.template.js"), "utf8");
      hash.update(template);
      const precache = JSON.stringify(["./", ...files.map((file) => `./${file}`)], null, 2);
      writeFileSync(
        join(outDir, "sw.js"),
        template.replace("__VERSION__", hash.digest("hex").slice(0, 12)).replace("__PRECACHE__", precache),
      );
    },
  };
}

export default defineConfig({
  // Sub-path the site is served from: "/" normally, "/Shogi/" on GitHub Pages (set by the workflow).
  base: process.env.BASE_PATH ?? "/",
  plugins: [serviceWorker()],
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
