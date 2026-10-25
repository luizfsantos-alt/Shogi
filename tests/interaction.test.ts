import { describe, expect, it } from "vitest";
import { chooseMove, targetsFor } from "../src/ui/interaction";
import { newGame } from "./helpers";

describe("board interaction", () => {
  it("lists target squares of a selected piece and of a hand piece", async () => {
    const game = await newGame("4k4/9/9/9/9/9/9/9/4K4 b G 1");
    expect(targetsFor({ kind: "board", square: { file: 5, rank: 9 } }, game.legalMoves())).toHaveLength(5);
    expect(targetsFor({ kind: "hand", type: "G" }, game.legalMoves())).toHaveLength(79);
    game.dispose();
  });

  it("asks about optional promotion, decides mandatory promotion alone", async () => {
    const game = await newGame("k8/4P4/9/4S4/9/9/9/9/4K4 b - 1");
    const legal = game.legalMoves();
    expect(chooseMove({ kind: "board", square: { file: 5, rank: 4 } }, { file: 5, rank: 3 }, legal)).toEqual({
      kind: "promotion",
      promote: "5d5c+",
      stay: "5d5c",
    });
    expect(chooseMove({ kind: "board", square: { file: 5, rank: 2 } }, { file: 5, rank: 1 }, legal)).toEqual({
      kind: "move",
      move: "5b5a+",
    });
    expect(chooseMove({ kind: "board", square: { file: 5, rank: 4 } }, { file: 5, rank: 6 }, legal)).toEqual({ kind: "none" });
    game.dispose();
  });
});
