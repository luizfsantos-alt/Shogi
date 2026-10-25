import { describe, expect, it } from "vitest";
import { formatWesternMove } from "../src/core/kifu";
import { formatUsiRecord, parseUsiRecord, RecordFormatError } from "../src/core/usiRecord";
import { newGame } from "./helpers";

async function notate(sfen: string | undefined, moves: string[], move: string): Promise<string> {
  const game = await newGame(sfen, moves);
  const text = formatWesternMove(game.position(), game.legalMoves(), move, game.variant.dims);
  game.dispose();
  return text;
}

describe("western move notation", () => {
  it("formats simple moves, captures, promotions and drops", async () => {
    expect(await notate(undefined, [], "7g7f")).toBe("P-7f");
    expect(await notate(undefined, ["7g7f", "3c3d"], "8h2b+")).toBe("Bx2b+");
    expect(await notate(undefined, ["7g7f", "3c3d"], "8h2b")).toBe("Bx2b=");
    expect(await notate("4k4/9/9/9/9/9/9/9/4K4 b P 1", [], "P*5e")).toBe("P*5e");
  });

  it("adds the origin only when two identical pieces can reach the square", async () => {
    expect(await notate(undefined, [], "6i5h")).toBe("G6i-5h");
    expect(await notate(undefined, [], "6i7h")).toBe("G-7h");
  });

  it("marks promoted pieces", async () => {
    expect(await notate("8k/9/9/9/9/9/9/4+R4/K8 b - 1", [], "5h5g")).toBe("+R-5g");
  });
});

describe("USI game records", () => {
  const START = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1";

  it("formats with startpos or sfen", () => {
    expect(formatUsiRecord(START, START, ["7g7f", "3c3d"])).toBe("position startpos moves 7g7f 3c3d");
    expect(formatUsiRecord("4k4/9/9/9/9/9/9/9/4K4 b P 1", START, [])).toBe("position sfen 4k4/9/9/9/9/9/9/9/4K4 b P 1");
  });

  it.each([
    ["position startpos moves 7g7f 3c3d", { sfen: null, moves: ["7g7f", "3c3d"] }],
    ["startpos moves 7g7f", { sfen: null, moves: ["7g7f"] }],
    ["7g7f 3c3d 8h2b+", { sfen: null, moves: ["7g7f", "3c3d", "8h2b+"] }],
    ["position sfen 4k4/9/9/9/9/9/9/9/4K4 b P 1 moves P*5e", { sfen: "4k4/9/9/9/9/9/9/9/4K4 b P 1", moves: ["P*5e"] }],
    ["sfen 4k4/9/9/9/9/9/9/9/4K4 b P 1", { sfen: "4k4/9/9/9/9/9/9/9/4K4 b P 1", moves: [] }],
    ["  4k4/9/9/9/9/9/9/9/4K4 b P 1 ", { sfen: "4k4/9/9/9/9/9/9/9/4K4 b P 1", moves: [] }],
  ])("parses %j", (text, expected) => {
    expect(parseUsiRecord(text)).toEqual(expected);
  });

  it("rejects garbage", () => {
    expect(() => parseUsiRecord("")).toThrow(RecordFormatError);
    expect(() => parseUsiRecord("startpos moves 7g7f banana")).toThrow(RecordFormatError);
  });
});
