import { pieceInfo, type Direction } from "./pieces";
import { pieceAt, squareOf, type Position } from "./position";
import type { VariantDefinition } from "./variants";
import type { BoardDims, Color, Piece, Square } from "./types";

/**
 * Piece reach computed from the movement table in pieces.ts (pure TypeScript, no ffish).
 * Used to explain illegal moves and to show attacked squares; the legal moves themselves
 * always come from Fairy-Stockfish.
 */

/** Converts a direction in the owner's frame (dy = forward) to a board offset. */
function boardOffset([dx, dy]: Direction, color: Color): { dFile: number; dRank: number } {
  // Sente faces rank 1 and has file 1 on its right; Gote is mirrored.
  return color === "black" ? { dFile: -dx, dRank: -dy } : { dFile: dx, dRank: dy };
}

function inside(square: Square, dims: BoardDims): boolean {
  return square.file >= 1 && square.file <= dims.files && square.rank >= 1 && square.rank <= dims.ranks;
}

function shift(square: Square, direction: Direction, color: Color, times = 1): Square {
  const { dFile, dRank } = boardOffset(direction, color);
  return { file: square.file + dFile * times, rank: square.rank + dRank * times };
}

/** Squares a piece on `from` attacks (it could capture there), stopping at the first piece on slides. */
export function attacksFrom(position: Position, from: Square, piece: Piece, dims: BoardDims): Square[] {
  const { steps, slides, jumps } = pieceInfo(piece).movement;
  const result: Square[] = [];
  for (const direction of [...steps, ...jumps]) {
    const to = shift(from, direction, piece.color);
    if (inside(to, dims)) result.push(to);
  }
  for (const direction of slides) {
    for (let n = 1; ; n++) {
      const to = shift(from, direction, piece.color, n);
      if (!inside(to, dims)) break;
      result.push(to);
      if (pieceAt(position, to, dims)) break;
    }
  }
  return result;
}

export type Reach = "reachable" | "blocked" | "never";

/**
 * Whether the piece's movement pattern can bring it from `from` to `to`:
 * "blocked" means it moves that way but another piece is in the path.
 */
export function reach(position: Position, from: Square, piece: Piece, to: Square, dims: BoardDims): Reach {
  const { steps, slides, jumps } = pieceInfo(piece).movement;
  const same = (a: Square) => a.file === to.file && a.rank === to.rank;
  if ([...steps, ...jumps].some((direction) => same(shift(from, direction, piece.color)))) return "reachable";
  for (const direction of slides) {
    for (let n = 1; ; n++) {
      const square = shift(from, direction, piece.color, n);
      if (!inside(square, dims)) break;
      if (same(square)) return "reachable";
      if (pieceAt(position, square, dims)) {
        // Is the target further along this line?
        for (let m = n + 1; ; m++) {
          const further = shift(from, direction, piece.color, m);
          if (!inside(further, dims)) break;
          if (same(further)) return "blocked";
        }
        break;
      }
    }
  }
  return "never";
}

export function forEachPiece(position: Position, dims: BoardDims, visit: (square: Square, piece: Piece) => void): void {
  position.board.forEach((row, rowIndex) =>
    row.forEach((piece, col) => {
      if (piece) visit(squareOf(rowIndex, col, dims), piece);
    }),
  );
}

/** Pieces of `color` attacking `target`. */
export function attackersOf(position: Position, target: Square, color: Color, dims: BoardDims): Square[] {
  const result: Square[] = [];
  forEachPiece(position, dims, (square, piece) => {
    if (piece.color !== color) return;
    if (attacksFrom(position, square, piece, dims).some((s) => s.file === target.file && s.rank === target.rank)) {
      result.push(square);
    }
  });
  return result;
}

/** Every square attacked by `color`, with the number of attackers. Keys are "file,rank". */
export function attackMap(position: Position, color: Color, dims: BoardDims): Map<string, number> {
  const map = new Map<string, number>();
  forEachPiece(position, dims, (square, piece) => {
    if (piece.color !== color) return;
    for (const target of attacksFrom(position, square, piece, dims)) {
      const key = `${target.file},${target.rank}`;
      map.set(key, (map.get(key) ?? 0) + 1);
    }
  });
  return map;
}

/** Ranks from the far end of the board for `color` (0 = the last rank). */
export function distanceToLastRank(square: Square, color: Color, dims: BoardDims): number {
  return color === "black" ? square.rank - 1 : dims.ranks - square.rank;
}

export function inPromotionZone(square: Square, color: Color, variant: VariantDefinition): boolean {
  return distanceToLastRank(square, color, variant.dims) < variant.promotionZoneRanks;
}
