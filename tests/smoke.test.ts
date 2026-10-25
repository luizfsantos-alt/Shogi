import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { describe, expect, it } from "vitest";
import { testFfish } from "./helpers";

const require = createRequire(import.meta.url);

describe("ffish.js smoke test", () => {
  it("loads and knows the shogi variant", async () => {
    const ffish = await testFfish();
    // Note: in ffish-es6 0.7.10 the module-level string functions (variants(), startingFen())
    // return "" and validateFen() ignores the variant; Board works fine, so we rely on it.
    const board = new ffish.Board("shogi");
    expect(board.fen()).toBe("lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL[] w - - 0 1");
    expect(board.numberLegalMoves()).toBe(30);
    expect(board.legalMoves().split(" ")).toContain("c3c4"); // 7g7f in USI
    expect(board.push("c3c4")).toBe(true);
    expect(board.turn()).toBe(false);
    board.delete();
  });
});

interface StockfishModule {
  postMessage(command: string): void;
  addMessageListener(listener: (line: string) => void): void;
  terminate?(): void;
}

describe("fairy-stockfish-nnue.wasm smoke test", () => {
  it("answers UCI and finds a move in shogi", async () => {
    const dir = require.resolve("fairy-stockfish-nnue.wasm/stockfish.js").replace(/stockfish\.js$/, "");
    const Stockfish = require(`${dir}stockfish.js`) as (opts: object) => Promise<StockfishModule>;
    const engine = await Stockfish({ wasmBinary: readFileSync(`${dir}stockfish.wasm`) });

    const lines: string[] = [];
    const bestMove = new Promise<string>((resolve) => {
      engine.addMessageListener((line) => {
        lines.push(line);
        if (line.startsWith("bestmove")) resolve(line.split(" ")[1]);
      });
    });
    for (const command of ["uci", "setoption name UCI_Variant value shogi", "position startpos", "go depth 6"]) {
      engine.postMessage(command);
    }
    const move = await bestMove;
    engine.terminate?.();

    expect(lines).toContain("uciok");
    expect(lines.some((l) => l.startsWith("option name Skill Level"))).toBe(true);
    expect(lines.some((l) => l.startsWith("option name UCI_Elo"))).toBe(true);
    const ffish = await testFfish();
    const board = new ffish.Board("shogi");
    expect(board.legalMoves().split(" ")).toContain(move);
    board.delete();
  });
});
