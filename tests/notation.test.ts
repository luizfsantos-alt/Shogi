import { describe, expect, it } from "vitest";
import { fairyToUsi, parseUsiMove, usiToFairy } from "../src/core/notation";
import { formatSfen, parseSfen, SfenError, toFairyFen } from "../src/core/position";
import { getVariant } from "../src/core/variants";

const shogi = getVariant("shogi");
const dims = shogi.dims;

describe("USI <-> Fairy-Stockfish move notation", () => {
  const pairs: [string, string][] = [
    ["7g7f", "c3c4"],
    ["P*5e", "P@e5"],
    ["8h2b+", "b2h8+"],
    ["1a1b", "i9i8"],
    ["9i9h", "a1a2"],
    ["N*1c", "N@i7"],
  ];
  it.each(pairs)("%s <-> %s", (usi, fairy) => {
    expect(usiToFairy(usi, dims)).toBe(fairy);
    expect(fairyToUsi(fairy, dims)).toBe(usi);
  });

  it("parses moves", () => {
    expect(parseUsiMove("8h2b+")).toEqual({ from: { file: 8, rank: 8 }, to: { file: 2, rank: 2 }, drop: null, promote: true });
    expect(parseUsiMove("P*5e")).toEqual({ from: null, to: { file: 5, rank: 5 }, drop: "P", promote: false });
    expect(parseUsiMove("x7g")).toBeNull();
  });
});

describe("SFEN parsing and formatting", () => {
  it("round-trips the start position and converts it to Fairy FEN", () => {
    const position = parseSfen(shogi.startSfen, shogi);
    expect(formatSfen(position, shogi)).toBe(shogi.startSfen);
    expect(toFairyFen(position, shogi)).toBe("lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL[] w - - 0 1");
  });

  it("round-trips hands, promoted pieces and move numbers", () => {
    const sfen = "8l/1l+R2P3/p2pBG1pp/kps1p4/Nn1P2G2/P1P1P2PP/1PS6/1KSG3+r1/LN2+p3L w Sbgn3p 124";
    expect(formatSfen(parseSfen(sfen, shogi), shogi)).toBe(sfen);
  });

  it("normalises hand order", () => {
    const position = parseSfen("4k4/9/9/9/9/9/9/9/4K4 b PPpRG 1", shogi);
    expect(formatSfen(position, shogi)).toBe("4k4/9/9/9/9/9/9/9/4K4 b RG2Pp 1");
  });

  it.each([
    ["bad rank count", "4k4/9/9/9/9/9/9/4K4 b - 1"],
    ["bad row width", "4k5/9/9/9/9/9/9/9/4K4 b - 1"],
    ["unknown piece", "4k4/9/9/9/9/9/9/9/4K3Q b - 1"],
    ["missing king", "9/9/9/9/9/9/9/9/4K4 b - 1"],
    ["two black kings", "4k4/9/9/9/9/9/9/9/3KK4 b - 1"],
    ["pawn on last rank", "P3k4/9/9/9/9/9/9/9/4K4 b - 1"],
    ["knight on second-to-last rank", "4k4/N8/9/9/9/9/9/9/4K4 b - 1"],
    ["white lance on its last rank", "4k4/9/9/9/9/9/9/9/l3K4 b - 1"],
    ["nifu", "4k4/9/9/4P4/9/4P4/9/9/4K4 b - 1"],
    ["too many rooks", "4k4/9/9/9/9/9/9/9/4K4 b 3R 1"],
    ["promoted gold", "4k4/9/9/9/9/9/9/9/+G3K4 b - 1"],
    ["bad side", "4k4/9/9/9/9/9/9/9/4K4 x - 1"],
  ])("rejects %s", (_, sfen) => {
    expect(() => parseSfen(sfen, shogi)).toThrow(SfenError);
  });
});
