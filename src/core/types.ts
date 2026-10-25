/**
 * Shared types for the rules layer. Nothing here depends on ffish or the DOM.
 *
 * Conventions (same as USI / SFEN):
 * - "black" is sente (moves first, uppercase letters in SFEN); "white" is gote.
 * - File 1 is on Black's right-hand side; rank 1 ("a") is the top row, on White's side.
 */

export type Color = "black" | "white";

/** A move in USI notation, e.g. "7g7f", "P*5e", "8h2b+". */
export type UsiMove = string;

export interface BoardDims {
  files: number;
  ranks: number;
}

/** Square in USI numbering, both 1-based. */
export interface Square {
  file: number;
  rank: number;
}

export interface Piece {
  color: Color;
  /** Base piece letter, uppercase (e.g. "P", "R", "K"). */
  type: string;
  promoted: boolean;
}

/** Pieces in hand: base letter (uppercase) -> count. */
export type Hand = Record<string, number>;

export type Winner = Color | "draw";

export type EndReason =
  | "checkmate"
  /** No legal moves without being in check: also a loss in shogi. */
  | "no-legal-moves"
  /** Sennichite: same position for the 4th time. */
  | "repetition"
  /** Sennichite caused by continuous checks: the checking side loses. */
  | "perpetual-check"
  /** Entering-king declaration (jishogi, 27-point rule). */
  | "impasse"
  | "resignation";

export type GameResult =
  | { over: false }
  | { over: true; winner: Winner; reason: EndReason };

export interface ParsedMove {
  from: Square | null;
  to: Square;
  /** Base letter of the dropped piece, when the move is a drop. */
  drop: string | null;
  promote: boolean;
}

export function opposite(color: Color): Color {
  return color === "black" ? "white" : "black";
}
