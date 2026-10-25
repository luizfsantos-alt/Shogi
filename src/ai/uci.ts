import { fairyToUsi, usiToFairy } from "../core/notation";
import { parseSfen, toFairyFen } from "../core/position";
import type { VariantDefinition } from "../core/variants";
import type { UsiMove } from "../core/types";
import type { SearchRequest } from "./Engine";
import type { LevelConfig } from "./levels";

/**
 * Fairy-Stockfish is driven with the UCI protocol, so positions and moves use its internal
 * chess-like notation; these helpers convert from/to our SFEN + USI.
 */

export function positionCommand(request: SearchRequest, variant: VariantDefinition): string {
  const fen = toFairyFen(parseSfen(request.initialSfen, variant), variant);
  const moves = request.moves.map((move) => usiToFairy(move, variant.dims));
  return `position fen ${fen}${moves.length ? ` moves ${moves.join(" ")}` : ""}`;
}

export function levelCommands(level: LevelConfig): string[] {
  return [`setoption name Skill Level value ${level.skill}`];
}

export function goCommand(level: LevelConfig): string {
  const limits: string[] = [];
  if (level.depth !== undefined) limits.push(`depth ${level.depth}`);
  if (level.movetimeMs !== undefined) limits.push(`movetime ${level.movetimeMs}`);
  return `go ${limits.join(" ") || "depth 10"}`;
}

/** Parses "bestmove c3c4 ponder g7g6"; returns null for "bestmove (none)". */
export function parseBestMove(line: string, variant: VariantDefinition): UsiMove | null {
  const move = line.split(/\s+/)[1];
  if (!move || move === "(none)") return null;
  return fairyToUsi(move, variant.dims);
}
