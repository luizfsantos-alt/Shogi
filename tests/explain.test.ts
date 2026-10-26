import { describe, expect, it } from "vitest";
import { checkHelp, describeCheckHelp, describeMove } from "../src/core/coach";
import { describeIllegal, explainBoardMove, explainMove } from "../src/core/explain";
import { newGame } from "./helpers";

async function why(sfen: string | undefined, move: string, moves: string[] = []): Promise<string> {
  const game = await newGame(sfen, moves);
  const reason = explainMove(game, move);
  game.dispose();
  return reason.code;
}

describe("explainMove", () => {
  it.each([
    ["nifu", "4k4/9/9/9/9/9/4P4/9/4K4 b P 1", "P*5e"],
    ["uchifuzume", "7lk/9/7G1/9/9/9/9/9/4K4 b P 1", "P*1b"],
    ["dead-piece", "4k4/9/9/9/9/9/9/9/4K4 b PN 1", "P*1a"],
    ["dead-piece", "4k4/9/9/9/9/9/9/9/4K4 b PN 1", "N*1b"],
    ["drop-on-occupied", "4k4/9/9/9/9/9/9/9/4K4 b P 1", "P*5a"],
    ["not-in-hand", "4k4/9/9/9/9/9/9/9/4K4 b P 1", "G*5e"],
    ["must-promote", "k8/4P4/9/9/9/9/9/9/4K4 b - 1", "5b5a"],
    ["must-promote", "k8/9/9/4N4/9/9/9/9/4K4 b - 1", "5d4b"],
    ["cannot-promote", "k8/4G4/9/9/9/9/9/9/4K4 b - 1", "5b5a+"],
    ["promotion-outside-zone", undefined, "7g7f+"],
    ["pinned", "k3r4/9/9/9/9/9/9/4S4/4K4 b - 1", "5h4g"],
    ["still-in-check", "4k4/9/9/9/9/9/9/8G/r3K4 b - 1", "1h1g"],
    ["king-into-check", "4k4/9/9/9/9/9/9/8G/r3K4 b - 1", "5i4i"],
    ["cannot-move-like-that", undefined, "7g7e"],
    ["path-blocked", undefined, "8h6f"],
    ["path-blocked", undefined, "2h2b"],
    ["own-piece-on-target", undefined, "9i9g"],
    ["not-your-piece", undefined, "3c3d"],
    ["legal", undefined, "7g7f"],
  ])("%s: %s %s", async (code, sfen, move) => {
    expect(await why(sfen, move)).toBe(code);
  });

  it("explains board clicks without caring about the promotion suffix", async () => {
    const game = await newGame("k8/4P4/9/9/9/9/9/9/4K4 b - 1");
    expect(explainBoardMove(game, { file: 5, rank: 2 }, { file: 5, rank: 1 }).code).toBe("legal");
    expect(explainBoardMove(game, { file: 5, rank: 2 }, { file: 4, rank: 1 }).code).toBe("cannot-move-like-that");
    game.dispose();
  });

  it("gives clear Portuguese messages", async () => {
    const game = await newGame("4k4/9/9/9/9/9/4P4/9/4K4 b P 1");
    const position = game.position();
    expect(describeIllegal(explainMove(game, "P*5e"), position, game.variant)).toMatch(/^Nifu \(二歩\): você já tem um peão/);
    game.load("7lk/9/7G1/9/9/9/9/9/4K4 b P 1");
    expect(describeIllegal(explainMove(game, "P*1b"), game.position(), game.variant)).toMatch(/^Uchifuzume/);
    game.load("4k4/9/9/9/9/9/9/8G/r3K4 b - 1");
    expect(describeIllegal(explainMove(game, "5i4i"), game.position(), game.variant)).toBe(
      "O rei não pode ir para uma casa atacada (Torre em 9i).",
    );
    game.dispose();
  });
});

describe("check help", () => {
  it("groups the ways out of check", async () => {
    // Sente king 5i checked by the rook on 9i; the gold on 6h can block on 6i, a bishop in hand can be dropped.
    const game = await newGame("4k4/9/9/9/9/9/9/3G5/r3K4 b B 1");
    const help = checkHelp(game)!;
    expect(help.attackers).toEqual([{ file: 9, rank: 9 }]);
    expect(help.kingMoves.length).toBeGreaterThan(0);
    expect(help.blocks).toContain("6h6i");
    expect(help.blocks).toContain("B*7i");
    expect(describeCheckHelp(help, game)).toMatch(/^Seu rei está em xeque! Quem ataca: a Torre\. Para sair: mover o rei/);
    game.dispose();
  });

  it("is null when not in check", async () => {
    const game = await newGame();
    expect(checkHelp(game)).toBeNull();
    game.dispose();
  });
});

describe("describeMove", () => {
  it("captures, promotions, checks and mates", async () => {
    const game = await newGame(undefined, ["7g7f", "3c3d"]);
    expect(describeMove(game, "8h2b+")).toEqual(["captura o Bispo (a peça vai para a sua mão)", "promove o Bispo"]);
    expect(game.history()).toEqual(["7g7f", "3c3d"]); // the backend was restored
    game.load("4k4/9/4P4/9/9/9/9/9/4K4 b G 1");
    expect(describeMove(game, "G*5b")).toEqual(["coloca o General de Ouro da mão no tabuleiro", "dá xeque-mate!"]);
    game.dispose();
  });
});

describe("every illegal move gets a specific explanation", () => {
  it("in positions from random games", async () => {
    let seed = 12345;
    const random = () => ((seed = (seed * 1103515245 + 12345) % 2 ** 31) / 2 ** 31);
    const game = await newGame();
    const unexplained: string[] = [];
    for (let gameIndex = 0; gameIndex < 6; gameIndex++) {
      game.load();
      for (let ply = 0; ply < 80 && !game.result().over; ply++) {
        if (ply % 8 === 7) {
          const position = game.position();
          const side = game.sideToMove();
          const all: { file: number; rank: number }[] = [];
          for (let file = 1; file <= 9; file++) for (let rank = 1; rank <= 9; rank++) all.push({ file, rank });
          for (const from of all) {
            if (game.pieceAt(from)?.color !== side) continue;
            for (const to of all) {
              const code = explainBoardMove(game, from, to).code;
              if (code === "unknown") unexplained.push(`${game.toSfen()} ${from.file}${from.rank}->${to.file}${to.rank}`);
            }
          }
          for (const type of Object.keys(position.hands[side])) {
            for (const to of all) {
              const move = `${type}*${to.file}${String.fromCharCode(96 + to.rank)}`;
              if (game.isLegal(move)) continue;
              if (explainMove(game, move).code === "unknown") unexplained.push(`${game.toSfen()} ${move}`);
            }
          }
        }
        const legal = game.legalMoves();
        // Prefer captures so that hands fill up and drops get exercised.
        const captures = legal.filter((m) => !m.includes("*") && game.pieceAt({ file: Number(m[2]), rank: m.charCodeAt(3) - 96 }));
        const pool = captures.length && random() < 0.7 ? captures : legal;
        game.push(pool[Math.floor(random() * pool.length)]);
      }
    }
    game.dispose();
    expect(unexplained.slice(0, 10)).toEqual([]);
  });
});
