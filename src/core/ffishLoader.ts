import createFfish from "ffish-es6";
import type { FairyStockfish } from "ffish-es6";

export type { FairyStockfish };

export interface FfishLoadOptions {
  /** The ffish.wasm bytes (used in Node / tests). */
  wasmBinary?: ArrayBuffer | Uint8Array;
  /** Returns the URL of ffish.wasm (used in the browser). */
  locateFile?: (file: string, prefix: string) => string;
}

/** Loads the ffish.js WebAssembly module (the Fairy-Stockfish rules library). */
export function loadFfish(options: FfishLoadOptions = {}): Promise<FairyStockfish> {
  // `wasmBinary` is a standard Emscripten option missing from ffish's type definitions.
  return createFfish(options as Parameters<typeof createFfish>[0]);
}
