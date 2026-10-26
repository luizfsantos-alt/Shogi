import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { FairyBackend } from "../src/core/FairyBackend";
import { setup } from "../src/learn/board";
import { coachTip, pieceValue } from "../src/learn/coachTips";
import { newGame } from "./helpers";

let game: FairyBackend;
beforeAll(async () => {
  game = await newGame();
});
afterAll(() => game.dispose());

const tipFor = (sfen: string, seen: string[] = [], moves: string[] = []) => {
  game.load(sfen, moves);
  return coachTip(game, game.sideToMove(), new Set(seen));
};

describe("coach tips", () => {
  it("suggests a first move, then stays quiet", () => {
    expect(tipFor(game.variant.startSfen)?.id).toBe("opening");
    expect(tipFor(game.variant.startSfen, ["opening"])).toBeNull();
  });

  it("explains a check before anything else", () => {
    expect(tipFor(setup({ "5i": "K", "5c": "r", "5a": "k" }), ["opening"])?.id).toBe("check");
  });

  it("points out a fork", () => {
    const tip = tipFor(setup({ "5a": "k", "7c": "r", "5c": "g", "2h": "K", "3h": "S", "3i": "G", "2g": "P" }, "N"), ["opening"]);
    expect(tip?.id).toBe("fork");
    expect(tip?.squares).toEqual(expect.arrayContaining([{ file: 7, rank: 3 }, { file: 5, rank: 3 }]));
  });

  it("warns about an undefended piece under attack", () => {
    const tip = tipFor(setup({ "5i": "K", "5a": "k", "2e": "B", "2c": "r" }), ["opening"]);
    expect(tip?.id).toBe("hanging");
    expect(tip?.text).toContain("2e");
  });

  it("talks about pieces in hand and promotion", () => {
    expect(tipFor(setup({ "5i": "K", "5a": "k" }, "P"), ["opening"])?.id).toBe("hand");
    expect(tipFor(setup({ "5i": "K", "5a": "k", "1d": "P" }), ["opening"])?.id).toBe("promotion");
  });

  it("does not suggest a promotion into a recapture", () => {
    // After 7g7f 3a4b, Bx3c+ is legal but the silver and the knight take back.
    expect(tipFor(game.variant.startSfen, ["opening"], ["7g7f", "3a4b"])?.id).not.toBe("promotion");
  });

  it("notices a king left in the centre", () => {
    const moves = ["9g9f", "9c9d", "1g1f", "1c1d", "9f9e", "9d9e", "1f1e", "1d1e", "8g8f", "8c8d", "2g2f", "2c2d", "3g3f", "3c3d", "7g7f", "7c7d"];
    expect(tipFor(game.variant.startSfen, ["opening", "hand", "hanging", "fork", "promotion"], moves)?.id).toBe("sitting-king");
  });

  it("uses the beginner piece values", () => {
    expect(pieceValue({ type: "R", promoted: false })).toBe(10);
    expect(pieceValue({ type: "P", promoted: true })).toBe(6);
  });
});
