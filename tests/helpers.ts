import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { FairyBackend } from "../src/core/FairyBackend";
import { loadFfish, type FairyStockfish } from "../src/core/ffishLoader";
import type { UsiMove } from "../src/core/types";
import type { EngineTransport } from "../src/ai/Engine";

const require = createRequire(import.meta.url);

let ffishPromise: Promise<FairyStockfish> | null = null;

export function testFfish(): Promise<FairyStockfish> {
  ffishPromise ??= loadFfish({ wasmBinary: readFileSync(require.resolve("ffish-es6/ffish.wasm")) });
  return ffishPromise;
}

export async function newGame(sfen?: string, moves?: UsiMove[]): Promise<FairyBackend> {
  return FairyBackend.create(await testFfish(), "shogi", sfen, moves);
}

/** Plays a cycle of moves `times` times. */
export function playCycle(game: FairyBackend, cycle: UsiMove[], times: number): void {
  for (let i = 0; i < times; i++) for (const move of cycle) game.push(move);
}

interface StockfishModule {
  postMessage(command: string): void;
  addMessageListener(listener: (line: string) => void): void;
  terminate?(): void;
}

/** EngineTransport running the real engine module inside the test process. */
export async function nodeEngineTransport(): Promise<EngineTransport> {
  const dir = require.resolve("fairy-stockfish-nnue.wasm/stockfish.js").replace(/stockfish\.js$/, "");
  const Stockfish = require(`${dir}stockfish.js`) as (opts: object) => Promise<StockfishModule>;
  const engine = await Stockfish({ wasmBinary: readFileSync(`${dir}stockfish.wasm`) });
  return {
    send: (command) => engine.postMessage(command),
    onLine: (listener) => engine.addMessageListener(listener),
    terminate: () => engine.terminate?.(),
  };
}
