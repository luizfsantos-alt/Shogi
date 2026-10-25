import { formatSquare, parseUsiMove } from "../core/notation";
import type { Square, UsiMove } from "../core/types";

/** What the player has picked up: a piece on the board or a piece type from their hand. */
export type Selection = { kind: "board"; square: Square } | { kind: "hand"; type: string };

export type MoveChoice =
  | { kind: "none" }
  | { kind: "move"; move: UsiMove }
  /** Promotion is optional: the player must choose. */
  | { kind: "promotion"; promote: UsiMove; stay: UsiMove };

function sameSquare(a: Square, b: Square): boolean {
  return a.file === b.file && a.rank === b.rank;
}

/** Legal moves that start with the current selection. */
export function movesFor(selection: Selection, legalMoves: readonly UsiMove[]): UsiMove[] {
  const prefix = selection.kind === "board" ? formatSquare(selection.square) : `${selection.type}*`;
  return legalMoves.filter((move) => {
    if (selection.kind === "hand") return move.startsWith(prefix);
    const parsed = parseUsiMove(move);
    return parsed?.from ? sameSquare(parsed.from, selection.square) : false;
  });
}

/** Squares the selection can go to. */
export function targetsFor(selection: Selection, legalMoves: readonly UsiMove[]): Square[] {
  const seen = new Set<string>();
  const targets: Square[] = [];
  for (const move of movesFor(selection, legalMoves)) {
    const to = parseUsiMove(move)!.to;
    const key = formatSquare(to);
    if (seen.has(key)) continue;
    seen.add(key);
    targets.push(to);
  }
  return targets;
}

/** Resolves a click on `to` with the current selection into a move (or a promotion question). */
export function chooseMove(selection: Selection, to: Square, legalMoves: readonly UsiMove[]): MoveChoice {
  const candidates = movesFor(selection, legalMoves).filter((move) => sameSquare(parseUsiMove(move)!.to, to));
  if (candidates.length === 0) return { kind: "none" };
  if (candidates.length === 1) return { kind: "move", move: candidates[0] };
  const promote = candidates.find((move) => move.endsWith("+"))!;
  const stay = candidates.find((move) => !move.endsWith("+"))!;
  return { kind: "promotion", promote, stay };
}
