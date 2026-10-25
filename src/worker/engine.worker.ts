/// <reference lib="webworker" />
/**
 * Web Worker hosting Fairy-Stockfish (fairy-stockfish-nnue.wasm). It only relays UCI text:
 * commands in, engine output lines out. The engine files are served from public/engine/
 * (copied there by scripts/copy-engine.mjs).
 */
import type { WorkerRequest, WorkerResponse } from "./protocol";

interface StockfishModule {
  postMessage(command: string): void;
  addMessageListener(listener: (line: string) => void): void;
}

interface StockfishOptions {
  locateFile: (file: string) => string;
  mainScriptUrlOrBlob: string;
}

type StockfishFactory = (options: StockfishOptions) => Promise<StockfishModule>;

const scope = self as unknown as DedicatedWorkerGlobalScope;
let engine: StockfishModule | null = null;
const pending: string[] = [];

async function start(baseUrl: string): Promise<void> {
  const scriptUrl = `${baseUrl}stockfish.js`;
  // This is a module worker (importScripts is unavailable), so the classic Emscripten script
  // is evaluated in global scope, where it defines the global `Stockfish` factory.
  const source = await (await fetch(scriptUrl)).text();
  (0, eval)(source);
  const Stockfish = (globalThis as unknown as { Stockfish: StockfishFactory }).Stockfish;
  engine = await Stockfish({ locateFile: (file) => `${baseUrl}${file}`, mainScriptUrlOrBlob: scriptUrl });
  engine.addMessageListener((line) => scope.postMessage({ type: "line", line } satisfies WorkerResponse));
  for (const command of pending.splice(0)) engine.postMessage(command);
}

scope.onmessage = (event: MessageEvent<WorkerRequest>) => {
  const message = event.data;
  if (message.type === "init") {
    start(message.engineBaseUrl).catch((error: unknown) =>
      scope.postMessage({ type: "error", message: String(error) } satisfies WorkerResponse),
    );
  } else if (engine) {
    engine.postMessage(message.command);
  } else {
    pending.push(message.command);
  }
};
