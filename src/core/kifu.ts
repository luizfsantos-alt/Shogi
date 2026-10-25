import { parseUsiMove } from "./notation";
import { pieceAt, type Position } from "./position";
import type { BoardDims, UsiMove } from "./types";

/**
 * Western (Hodges) move notation for the move list, e.g. "P-7f", "Bx2b+", "S6h-5g", "P*5e".
 * The origin is shown only when another piece of the same kind could reach the same square;
 * "=" marks a promotion that was available but declined.
 */
export function formatWesternMove(position: Position, legalMoves: readonly UsiMove[], move: UsiMove, dims: BoardDims): string {
  const parsed = parseUsiMove(move);
  if (!parsed) return move;
  const to = move.match(/\d+[a-z]/g)!.at(-1)!;
  if (parsed.drop) return `${parsed.drop}*${to}`;

  const piece = pieceAt(position, parsed.from!, dims);
  if (!piece) return move;
  const letter = (piece.promoted ? "+" : "") + piece.type;
  const from = move.slice(0, move.length - to.length - (parsed.promote ? 1 : 0));
  const capture = pieceAt(position, parsed.to, dims) !== null;
  const ambiguous = legalMoves.some((other) => {
    const o = parseUsiMove(other);
    if (!o?.from || o.drop || other.startsWith(from)) return false;
    if (o.to.file !== parsed.to.file || o.to.rank !== parsed.to.rank) return false;
    const otherPiece = pieceAt(position, o.from, dims);
    return otherPiece?.type === piece.type && otherPiece.promoted === piece.promoted;
  });
  const promotion = parsed.promote ? "+" : legalMoves.includes(`${move}+`) ? "=" : "";
  return `${letter}${ambiguous ? from : ""}${capture ? "x" : "-"}${to}${promotion}`;
}
