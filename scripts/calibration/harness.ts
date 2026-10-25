import { FairyEngine } from "../../src/ai/FairyEngine";
import type { EngineTransport, SearchRequest } from "../../src/ai/Engine";
import type { LevelConfig } from "../../src/ai/levels";
import { positionCommand } from "../../src/ai/uci";
import { usiToFairy } from "../../src/core/notation";
import { getVariant } from "../../src/core/variants";
import type { FairyBackend } from "../../src/core/FairyBackend";
import type { UsiMove } from "../../src/core/types";
import { newGame, nodeEngineTransport } from "../../tests/helpers";

export const shogi = getVariant("shogi");

/** Deterministic pseudo-random numbers, so calibration runs are reproducible. */
export function seededRandom(seed: number): () => number {
  let state = seed;
  return () => (state = (state * 1103515245 + 12345) % 2 ** 31) / 2 ** 31;
}

export async function newEngine(): Promise<FairyEngine> {
  const engine = new FairyEngine(await nodeEngineTransport(), shogi, { threads: 1, hashMb: 16 });
  await engine.init();
  return engine;
}

/** Strong engine used to judge moves: score (centipawns, side to move) of the best move or of a given move. */
export class Referee {
  private constructor(private readonly transport: EngineTransport) {}
  private lines: ((line: string) => void)[] = [];

  static async create(): Promise<Referee> {
    const referee = new Referee(await nodeEngineTransport());
    referee.transport.onLine((line) => referee.lines.forEach((listener) => listener(line)));
    referee.transport.send("uci");
    referee.transport.send(`setoption name UCI_Variant value ${shogi.id}`);
    referee.transport.send("setoption name Threads value 1");
    return referee;
  }

  /** Score in centipawns from the mover's point of view; mates are mapped to ±10000. */
  score(request: SearchRequest, depth: number, onlyMove?: UsiMove): Promise<number> {
    return new Promise((resolve) => {
      let last = 0;
      const listener = (line: string): void => {
        const cp = / score cp (-?\d+)/.exec(line);
        const mate = / score mate (-?\d+)/.exec(line);
        if (cp) last = Number(cp[1]);
        if (mate) last = Number(mate[1]) > 0 ? 10_000 : -10_000;
        if (line.startsWith("bestmove")) {
          this.lines = this.lines.filter((l) => l !== listener);
          resolve(last);
        }
      };
      this.lines.push(listener);
      this.transport.send(positionCommand(request, shogi));
      const restrict = onlyMove ? ` searchmoves ${usiToFairy(onlyMove, shogi.dims)}` : "";
      this.transport.send(`go depth ${depth}${restrict}`);
    });
  }

  dispose(): void {
    this.transport.terminate();
  }
}

export interface SamplePosition {
  initialSfen: string;
  moves: UsiMove[];
}

/** Positions from fast engine games with a randomised opening, sampled every few plies. */
export async function collectPositions(count: number, seed = 7): Promise<SamplePosition[]> {
  const random = seededRandom(seed);
  const engine = await newEngine();
  const game = await newGame();
  const fast: LevelConfig = { id: 0, name: "fast", description: "", skill: 20, movetimeMs: 60 };
  const positions: SamplePosition[] = [];
  while (positions.length < count) {
    game.load();
    for (let ply = 0; ply < 140 && !game.result().over && positions.length < count; ply++) {
      if (ply >= 10 && ply % 9 === 0) positions.push({ initialSfen: game.initialSfen(), moves: game.history() });
      const legal = game.legalMoves();
      const move = ply < 6 ? legal[Math.floor(random() * legal.length)] : await engine.bestMove({ initialSfen: game.initialSfen(), moves: game.history() }, fast);
      game.push(move!);
    }
  }
  engine.dispose();
  game.dispose();
  return positions;
}

export interface GameOutcome {
  winner: "a" | "b" | "draw";
  plies: number;
  reason: string;
}

/** Plays one game between two level configs; `aIsBlack` picks colours. */
export async function playGame(
  game: FairyBackend,
  engines: { a: FairyEngine; b: FairyEngine },
  levels: { a: LevelConfig; b: LevelConfig },
  aIsBlack: boolean,
  random: () => number,
  maxPlies = 260,
): Promise<GameOutcome> {
  game.load();
  // Two random opening moves per side keep the games varied.
  for (let i = 0; i < 4; i++) {
    const legal = game.legalMoves();
    game.push(legal[Math.floor(random() * legal.length)]);
  }
  while (!game.result().over && game.history().length < maxPlies) {
    const aToMove = (game.sideToMove() === "black") === aIsBlack;
    if (game.impasse()?.canDeclare) {
      game.declareImpasse();
      break;
    }
    const request = { initialSfen: game.initialSfen(), moves: game.history() };
    const move = await (aToMove ? engines.a : engines.b).bestMove(request, aToMove ? levels.a : levels.b);
    if (!move || !game.isLegal(move)) throw new Error(`Engine returned ${move}`);
    game.push(move);
  }
  const result = game.result();
  if (!result.over) return { winner: "draw", plies: game.history().length, reason: "move limit" };
  if (result.winner === "draw") return { winner: "draw", plies: game.history().length, reason: result.reason };
  const aWon = (result.winner === "black") === aIsBlack;
  return { winner: aWon ? "a" : "b", plies: game.history().length, reason: result.reason };
}

/** Prints a result line (bypasses Vitest's console capture). */
export function report(line: string): void {
  process.stdout.write(`${line}\n`);
}
