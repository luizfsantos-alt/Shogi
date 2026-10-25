import { afterEach, describe, expect, it } from "vitest";
import { IllegalMoveError } from "../src/core/GameBackend";
import type { FairyBackend } from "../src/core/FairyBackend";
import { SfenError } from "../src/core/position";
import { newGame, playCycle, testFfish } from "./helpers";

const START = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1";

let game: FairyBackend;
afterEach(() => game?.dispose());

/** Perft through the public backend API (USI moves, push/undo). */
function perft(backend: FairyBackend, depth: number): number {
  if (depth === 0) return 1;
  let nodes = 0;
  for (const move of backend.legalMoves()) {
    backend.push(move);
    nodes += perft(backend, depth - 1);
    backend.undo();
  }
  return nodes;
}

describe("start position and perft", () => {
  it("starts from the official position with Sente to move", async () => {
    game = await newGame();
    expect(game.toSfen()).toBe(START);
    expect(game.sideToMove()).toBe("black");
    expect(game.legalMoves()).toHaveLength(30);
  });

  it("perft 1-3 through the backend: 30, 900, 25 470", async () => {
    game = await newGame();
    expect(perft(game, 1)).toBe(30);
    expect(perft(game, 2)).toBe(900);
    expect(perft(game, 3)).toBe(25_470);
  });

  it("perft 4 with ffish directly: 719 731", async () => {
    const ffish = await testFfish();
    const board = new ffish.Board("shogi");
    const count = (depth: number): number => {
      if (depth === 1) return board.numberLegalMoves();
      let nodes = 0;
      for (const move of board.legalMoves().split(" ")) {
        board.push(move);
        nodes += count(depth - 1);
        board.pop();
      }
      return nodes;
    };
    expect(count(4)).toBe(719_731);
    board.delete();
  });
});

describe("SFEN and USI round trips", () => {
  it("reaches the expected SFEN after 7g7f 3c3d 8h2b+", async () => {
    game = await newGame(START, ["7g7f", "3c3d", "8h2b+"]);
    expect(game.toSfen()).toBe("lnsgkgsnl/1r5+B1/pppppp1pp/6p2/9/2P6/PP1PPPPPP/7R1/LNSGKGSNL w B 4");
    expect(game.hand("black")).toEqual({ B: 1 });
    expect(game.pieceAt({ file: 2, rank: 2 })).toEqual({ color: "black", type: "B", promoted: true });
    expect(game.history()).toEqual(["7g7f", "3c3d", "8h2b+"]);
  });

  it("drops a piece from the hand (P*5e)", async () => {
    game = await newGame("4k4/9/9/9/9/9/9/9/4K4 b P 1");
    expect(game.isLegal("P*5e")).toBe(true);
    game.push("P*5e");
    expect(game.toSfen()).toBe("4k4/9/9/9/4P4/9/9/9/4K4 w - 2");
  });

  it("reloads its own SFEN and history identically", async () => {
    game = await newGame(START, ["7g7f", "3c3d", "8h2b+", "3a2b", "B*4e"]);
    const sfen = game.toSfen();
    const copy = await newGame(game.initialSfen(), game.history());
    expect(copy.toSfen()).toBe(sfen);
    const fromSfen = await newGame(sfen);
    expect(fromSfen.toSfen()).toBe(sfen);
    expect(fromSfen.legalMoves().sort()).toEqual(copy.legalMoves().sort());
    copy.dispose();
    fromSfen.dispose();
  });

  it("undoes moves", async () => {
    game = await newGame(START, ["7g7f", "3c3d"]);
    expect(game.undo()).toBe("3c3d");
    expect(game.undo()).toBe("7g7f");
    expect(game.undo()).toBeNull();
    expect(game.toSfen()).toBe(START);
  });

  it("rejects illegal moves and keeps the state when an imported line is illegal", async () => {
    game = await newGame(START, ["7g7f"]);
    expect(() => game.push("7f7e")).toThrow(IllegalMoveError); // not Sente's turn
    expect(() => game.load(START, ["7g7f", "7f7e"])).toThrow(IllegalMoveError);
    expect(game.history()).toEqual(["7g7f"]);
  });

  it("rejects a position where the side that just moved is in check", async () => {
    game = await newGame();
    // Gote to move, but Sente's king on 5i is attacked by the gote rook on 5a.
    expect(() => game.load("4r4/9/9/9/9/9/9/9/k3K4 w - 1")).toThrow(SfenError);
  });
});

describe("promotion", () => {
  it("is mandatory for a pawn reaching the last rank", async () => {
    game = await newGame("k8/4P4/9/9/9/9/9/9/4K4 b - 1");
    expect(game.isLegal("5b5a+")).toBe(true);
    expect(game.isLegal("5b5a")).toBe(false);
  });

  it("is mandatory for a lance reaching the last rank but optional before", async () => {
    game = await newGame("k8/9/9/4L4/9/9/9/9/4K4 b - 1");
    expect(game.isLegal("5d5a+")).toBe(true);
    expect(game.isLegal("5d5a")).toBe(false);
    expect(game.isLegal("5d5b")).toBe(true);
    expect(game.isLegal("5d5b+")).toBe(true);
  });

  it("is mandatory for a knight on the last two ranks, optional on the third", async () => {
    game = await newGame("k8/9/9/9/4N4/9/9/9/4K4 b - 1");
    expect(game.legalMoves().filter((m) => m.startsWith("5e")).sort()).toEqual(["5e4c", "5e4c+", "5e6c", "5e6c+"]);
    game.load("k8/9/9/4N4/9/9/9/9/4K4 b - 1");
    expect(game.legalMoves().filter((m) => m.startsWith("5d")).sort()).toEqual(["5d4b+", "5d6b+"]);
  });

  it("is optional when moving out of the zone, and impossible for gold and king", async () => {
    game = await newGame("k8/4S4/4G4/9/9/9/9/9/4K4 b - 1");
    expect(game.isLegal("5b4c")).toBe(true);
    expect(game.isLegal("5b4c+")).toBe(true);
    expect(game.legalMoves().some((m) => m.startsWith("5c") && m.endsWith("+"))).toBe(false);
  });

  it("works for Gote too (zone is ranks g-i)", async () => {
    game = await newGame("4k4/9/9/9/9/9/9/4p4/K8 w - 1");
    expect(game.isLegal("5h5i+")).toBe(true);
    expect(game.isLegal("5h5i")).toBe(false);
  });
});

describe("drops", () => {
  it("forbids nifu (second unpromoted pawn on a file)", async () => {
    game = await newGame("4k4/9/9/9/9/9/4P4/9/4K4 b P 1");
    const pawnDrops = game.legalMoves().filter((m) => m.startsWith("P*"));
    expect(pawnDrops.some((m) => m.startsWith("P*5"))).toBe(false);
    expect(pawnDrops).toContain("P*4e");
  });

  it("allows a pawn drop on a file with only a promoted pawn", async () => {
    game = await newGame("4k4/9/9/9/9/9/4+P4/9/4K4 b P 1");
    expect(game.isLegal("P*5e")).toBe(true);
  });

  it("forbids drops of pieces that would have no moves", async () => {
    game = await newGame("4k4/9/9/9/9/9/9/9/4K4 b PLN 1");
    expect(game.isLegal("P*1a")).toBe(false);
    expect(game.isLegal("L*1a")).toBe(false);
    expect(game.isLegal("N*1a")).toBe(false);
    expect(game.isLegal("N*1b")).toBe(false);
    expect(game.isLegal("P*1b")).toBe(true);
    expect(game.isLegal("L*1b")).toBe(true);
    expect(game.isLegal("N*1c")).toBe(true);
  });

  it("allows drops on any empty square, never on occupied ones", async () => {
    game = await newGame("4k4/9/9/9/9/9/9/9/4K4 b G 1");
    expect(game.legalMoves().filter((m) => m.startsWith("G*"))).toHaveLength(81 - 2);
  });

  // Gote king on 1a, gote lance on 2a blocks the escape, Sente gold on 2c guards 1b and 2b.
  const UCHIFUZUME = "7lk/9/7G1/9/9/9/9/9/4K4 b P 1";

  it("forbids uchifuzume (checkmate by a dropped pawn)", async () => {
    game = await newGame(UCHIFUZUME);
    expect(game.isLegal("P*1b")).toBe(false);
  });

  it("the same drop with a gold is a legal checkmate (control case)", async () => {
    game = await newGame(UCHIFUZUME.replace(" P ", " G "));
    game.push("G*1b");
    expect(game.result()).toEqual({ over: true, winner: "black", reason: "checkmate" });
  });

  it("allows a pawn-drop check that is not mate", async () => {
    game = await newGame("8k/9/7G1/9/9/9/9/9/4K4 b P 1"); // no lance: the king escapes to 2a
    expect(game.isLegal("P*1b")).toBe(true);
  });

  it("allows checkmate by a pawn that moves (not dropped)", async () => {
    game = await newGame("7lk/9/7GP/9/9/9/9/9/4K4 b - 1");
    game.push("1c1b");
    expect(game.result()).toEqual({ over: true, winner: "black", reason: "checkmate" });
  });
});

describe("checks and pins", () => {
  it("does not let a pinned piece leave the line", async () => {
    // Sente silver on 5h pinned by the Gote rook on 5a against the king on 5i.
    game = await newGame("k3r4/9/9/9/9/9/9/4S4/4K4 b - 1");
    const silverMoves = game.legalMoves().filter((m) => m.startsWith("5h"));
    expect(silverMoves).toEqual(["5h5g"]);
  });

  it("detects check and only allows moves that answer it", async () => {
    game = await newGame("4k4/9/9/9/9/9/9/9/r3K4 b - 1");
    expect(game.isCheck()).toBe(true);
    expect(game.legalMoves().sort()).toEqual(["5i4h", "5i5h", "5i6h"]);
  });
});

describe("game endings", () => {
  it("checkmate: Gote has no legal moves while in check", async () => {
    game = await newGame("4k4/4G4/4P4/9/9/9/9/9/4K4 w - 1");
    expect(game.isCheck()).toBe(true);
    expect(game.legalMoves()).toEqual([]);
    expect(game.result()).toEqual({ over: true, winner: "black", reason: "checkmate" });
  });

  it("checkmate of Sente", async () => {
    game = await newGame("4k4/9/9/9/9/9/4p4/4g4/4K4 b - 1");
    expect(game.result()).toEqual({ over: true, winner: "white", reason: "checkmate" });
  });

  it("no legal moves without check is a loss (not a draw as in chess)", async () => {
    // Sente king on 9i boxed in by gote golds on 8g and 7h.
    game = await newGame("4k4/9/9/9/9/9/1g7/2g6/K8 b - 1");
    expect(game.isCheck()).toBe(false);
    expect(game.result()).toEqual({ over: true, winner: "white", reason: "no-legal-moves" });
  });

  it("sennichite: 4th repetition is a draw, 3rd is not", async () => {
    game = await newGame();
    const cycle = ["2h3h", "8b7b", "3h2h", "7b8b"];
    playCycle(game, cycle, 2); // start position seen 3 times
    expect(game.result()).toEqual({ over: false });
    playCycle(game, cycle, 1); // 4th time
    expect(game.result()).toEqual({ over: true, winner: "draw", reason: "repetition" });
    expect(game.legalMoves()).toEqual([]);
  });

  it("perpetual check: the checking side loses", async () => {
    // Sente rook keeps checking the Gote king, which shuffles between 1a and 2a.
    game = await newGame("8k/9/9/9/9/9/9/9/K6R1 b - 1");
    playCycle(game, ["2i1i", "1a2a", "1i2i", "2a1a"], 2);
    game.push("2i1i");
    game.push("1a2a");
    game.push("1i2i");
    expect(game.result()).toEqual({ over: false });
    game.push("2a1a");
    expect(game.result()).toEqual({ over: true, winner: "white", reason: "perpetual-check" });
  });

  it("repetition with only some checks is a normal draw", async () => {
    // The rook checks, the silver blocks, the rook steps away (no check), the silver returns.
    game = await newGame("7sk/9/9/9/9/9/9/9/K6R1 b - 1");
    const cycle = ["2i1i", "2a1b", "1i2i", "1b2a"];
    playCycle(game, cycle, 3);
    expect(game.result()).toEqual({ over: true, winner: "draw", reason: "repetition" });
  });

  it("resignation, and undo cancels it", async () => {
    game = await newGame(START, ["7g7f"]);
    game.resign("white");
    expect(game.result()).toEqual({ over: true, winner: "black", reason: "resignation" });
    expect(game.legalMoves()).toEqual([]);
    expect(game.undo()).toBeNull();
    expect(game.result()).toEqual({ over: false });
    expect(game.history()).toEqual(["7g7f"]);
  });
});

describe("impasse (jishogi, 27-point declaration) — implemented in core/", () => {
  // Sente king on 5b with R, B, 4 G, 4 S in the enemy camp (18 points, 10 pieces).
  const blackCamp = (hand: string) => `RBGGGG3/SSSSK4/9/9/9/9/9/9/8k b ${hand} 1`;

  it("Sente can declare with 28 points and 10 pieces in the camp", async () => {
    game = await newGame(blackCamp("10P"));
    expect(game.impasse()).toMatchObject({ canDeclare: true, points: 28, requiredPoints: 28, piecesInZone: 10 });
    game.declareImpasse();
    expect(game.result()).toEqual({ over: true, winner: "black", reason: "impasse" });
  });

  it("Sente cannot declare with 27 points", async () => {
    game = await newGame(blackCamp("9P"));
    expect(game.impasse()).toMatchObject({ canDeclare: false, points: 27 });
    expect(() => game.declareImpasse()).toThrow();
  });

  it("Gote needs only 27 points", async () => {
    game = await newGame("8K/9/9/9/9/9/9/4kssss/3ggggbr w 9p 1");
    expect(game.impasse()).toMatchObject({ canDeclare: true, points: 27, requiredPoints: 27, piecesInZone: 10 });
  });

  it("needs 10 pieces in the camp (hand pieces do not count for this)", async () => {
    game = await newGame("RBGGGG3/SSS1K4/9/9/9/9/9/9/8k b S10P 1");
    expect(game.impasse()).toMatchObject({ canDeclare: false, piecesInZone: 9, points: 28 });
  });

  it("needs the king inside the camp", async () => {
    game = await newGame("RBGGGG3/SSSS5/4K4/9/9/9/9/9/8k b 10P 1");
    expect(game.impasse()).toMatchObject({ canDeclare: true });
    game.load("RBGGGG3/SSSS5/9/4K4/9/9/9/9/8k b 10P 1");
    expect(game.impasse()).toMatchObject({ canDeclare: false, kingInZone: false });
  });

  it("cannot declare while in check", async () => {
    game = await newGame("RBGGGG3/SSSSK4/9/9/9/9/9/9/4r3k b 10P 1");
    expect(game.impasse()).toMatchObject({ canDeclare: false, inCheck: true });
  });

  it("promoted rook/bishop still count 5 points", async () => {
    game = await newGame("+R+BGGGG3/SSSSK4/9/9/9/9/9/9/8k b 10P 1");
    expect(game.impasse()).toMatchObject({ canDeclare: true, points: 28 });
  });
});
