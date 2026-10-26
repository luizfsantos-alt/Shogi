import wasmUrl from "ffish-es6/ffish.wasm?url";
import { FairyBackend } from "../core/FairyBackend";
import { loadFfish, type FairyStockfish } from "../core/ffishLoader";

let ffish: Promise<FairyStockfish> | null = null;

/**
 * Browser-side wiring: loads ffish.wasm from the URL Vite emits (once) and creates a backend.
 * Each call gives an independent board, e.g. one for the game and one for the lessons.
 */
export async function loadBackend(variant?: string): Promise<FairyBackend> {
  ffish ??= loadFfish({ locateFile: () => wasmUrl });
  return FairyBackend.create(await ffish, variant);
}
