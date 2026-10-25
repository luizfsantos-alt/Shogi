import { parseUsiMove } from "./notation";
import type { UsiMove } from "./types";

/** A game as text: start position + moves. */
export interface GameRecord {
  /** Starting SFEN; null means the variant's standard start. */
  sfen: string | null;
  moves: UsiMove[];
}

export class RecordFormatError extends Error {
  override name = "RecordFormatError";
}

/** Formats a game the way USI engines expect it: "position startpos moves ..." or "position sfen ... moves ...". */
export function formatUsiRecord(initialSfen: string, standardStart: string, moves: readonly UsiMove[]): string {
  const start = initialSfen === standardStart ? "startpos" : `sfen ${initialSfen}`;
  return `position ${start}${moves.length ? ` moves ${moves.join(" ")}` : ""}`;
}

/**
 * Accepts, from the most to the least explicit:
 *   "position startpos moves 7g7f 3c3d", "position sfen <sfen> moves ...",
 *   "startpos moves ...", "sfen <sfen> [moves ...]", a bare SFEN, or a bare list of USI moves.
 * Only the syntax is checked here; legality is checked when the moves are played.
 */
export function parseUsiRecord(text: string): GameRecord {
  let tokens = text.trim().split(/\s+/).filter(Boolean);
  if (tokens.length === 0) throw new RecordFormatError("O texto está vazio.");
  if (tokens[0] === "position") tokens = tokens.slice(1);

  let sfen: string | null = null;
  if (tokens[0] === "startpos") {
    tokens = tokens.slice(1);
  } else if (tokens[0] === "sfen" || tokens[0].includes("/")) {
    if (tokens[0] === "sfen") tokens = tokens.slice(1);
    const end = tokens.indexOf("moves");
    const sfenTokens = end === -1 ? tokens : tokens.slice(0, end);
    sfen = sfenTokens.join(" ");
    tokens = end === -1 ? [] : tokens.slice(end);
  }
  if (tokens[0] === "moves") tokens = tokens.slice(1);

  const bad = tokens.find((token) => !parseUsiMove(token));
  if (bad) throw new RecordFormatError(`"${bad}" não é uma jogada USI válida (exemplos: 7g7f, P*5e, 8h2b+).`);
  return { sfen, moves: tokens };
}
