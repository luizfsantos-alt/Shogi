import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { FairyEngine } from "../src/ai/FairyEngine";
import { getLevel, LEVELS, type LevelConfig } from "../src/ai/levels";
import { goCommand, positionCommand } from "../src/ai/uci";
import { getVariant } from "../src/core/variants";
import { newGame, nodeEngineTransport } from "./helpers";

const shogi = getVariant("shogi");
const START = shogi.startSfen;
const quick: LevelConfig = { id: 0, name: "test", description: "", skill: 20, depth: 4 };

describe("UCI helpers", () => {
  it("builds position and go commands in Fairy-Stockfish notation", () => {
    expect(positionCommand({ initialSfen: START, moves: ["7g7f", "3c3d"] }, shogi)).toBe(
      "position fen lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL[] w - - 0 1 moves c3c4 g7g6",
    );
    expect(goCommand({ ...quick, movetimeMs: 500 })).toBe("go depth 4 movetime 500");
  });

  it("defines 5 levels from Iniciante to Mestre", () => {
    expect(LEVELS.map((l) => l.name)).toEqual(["Iniciante", "Fácil", "Médio", "Difícil", "Mestre"]);
  });
});

describe("FairyEngine", () => {
  let engine: FairyEngine;
  beforeAll(async () => {
    engine = new FairyEngine(await nodeEngineTransport(), shogi, { threads: 1 });
    await engine.init();
  });
  afterAll(() => engine.dispose());

  it("returns a legal USI move for the start and for a position with moves", async () => {
    const game = await newGame();
    expect(game.isLegal((await engine.bestMove({ initialSfen: START, moves: [] }, quick))!)).toBe(true);
    game.load(START, ["7g7f", "3c3d", "8h2b+"]);
    expect(game.isLegal((await engine.bestMove({ initialSfen: START, moves: game.history() }, quick))!)).toBe(true);
    game.dispose();
  });

  it("finds a mate in one with a drop", async () => {
    // "Head gold": G*5b, protected by the pawn on 5c, mates the king on 5a.
    const sfen = "4k4/9/4P4/9/9/9/9/9/4K4 b G 1";
    const move = await engine.bestMove({ initialSfen: sfen, moves: [] }, quick);
    const game = await newGame(sfen, [move!]);
    expect(game.result()).toEqual({ over: true, winner: "black", reason: "checkmate" });
    game.dispose();
  });

  it("never plays uchifuzume, even when it looks like mate", async () => {
    const sfen = "7lk/9/7G1/9/9/9/9/9/4K4 b P 1";
    expect(await engine.bestMove({ initialSfen: sfen, moves: [] }, quick)).not.toBe("P*1b");
  });

  it("can be cancelled and keeps working afterwards", async () => {
    const long = engine.bestMove({ initialSfen: START, moves: [] }, { ...quick, depth: undefined, movetimeMs: 20_000 });
    setTimeout(() => engine.stop(), 200);
    const started = Date.now();
    expect(await long).toBeNull();
    expect(Date.now() - started).toBeLessThan(5_000);
    expect(await engine.bestMove({ initialSfen: START, moves: [] }, quick)).not.toBeNull();
  });

  it("plays at every level", async () => {
    for (const level of LEVELS) {
      const move = await engine.bestMove({ initialSfen: START, moves: ["7g7f"] }, { ...getLevel(level.id), movetimeMs: 200 });
      expect(move).toMatch(/^\d[a-i]\d[a-i]\+?$/);
    }
  });
});
