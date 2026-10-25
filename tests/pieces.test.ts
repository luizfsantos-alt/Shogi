import { describe, expect, it } from "vitest";
import { pieceInfo } from "../src/core/pieces";
import { formatSquare } from "../src/core/notation";
import { newGame } from "./helpers";

/** Destinations predicted by the movement diagram for a Sente piece on 5e of an empty board. */
function predicted(type: string, promoted: boolean): string[] {
  const { steps, slides, jumps } = pieceInfo({ type, promoted }).movement;
  // Sente faces rank "a"; its right-hand side is file 1.
  const square = (dx: number, dy: number) => ({ file: 5 - dx, rank: 5 - dy });
  const inside = (s: { file: number; rank: number }) => s.file >= 1 && s.file <= 9 && s.rank >= 1 && s.rank <= 9;
  const result = new Set<string>();
  for (const [dx, dy] of [...steps, ...jumps]) if (inside(square(dx, dy))) result.add(formatSquare(square(dx, dy)));
  for (const [dx, dy] of slides) {
    for (let n = 1; inside(square(dx * n, dy * n)); n++) result.add(formatSquare(square(dx * n, dy * n)));
  }
  return [...result].sort();
}

describe("movement diagrams match the rules engine", () => {
  const cases: [string, boolean][] = [
    ["K", false], ["R", false], ["B", false], ["G", false], ["S", false], ["N", false], ["L", false], ["P", false],
    ["R", true], ["B", true], ["S", true], ["N", true], ["L", true], ["P", true],
  ];
  it.each(cases)("%s (promoted: %s)", async (type, promoted) => {
    // Kings on 9h and 1b stay out of every line through 5e.
    const kings = type === "K" ? "9/8k/9/9/4K4/9/9/9/9" : "9/8k/9/9/4X4/9/9/K8/9";
    const board = kings.replace("X", (promoted ? "+" : "") + type);
    const game = await newGame(`${board} b - 1`);
    const actual = [...new Set(game.legalMoves().filter((m) => m.startsWith("5e")).map((m) => m.slice(2, 4)))].sort();
    expect(actual).toEqual(predicted(type, promoted));
    game.dispose();
  });
});
