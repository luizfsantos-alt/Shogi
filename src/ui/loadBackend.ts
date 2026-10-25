import wasmUrl from "ffish-es6/ffish.wasm?url";
import { FairyBackend } from "../core/FairyBackend";
import { loadFfish } from "../core/ffishLoader";

/** Browser-side wiring: loads ffish.wasm from the URL Vite emits and creates a backend. */
export async function loadBackend(variant?: string): Promise<FairyBackend> {
  const ffish = await loadFfish({ locateFile: () => wasmUrl });
  return FairyBackend.create(ffish, variant);
}
