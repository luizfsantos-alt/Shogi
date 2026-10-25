import type { BoardDims } from "./types";

/**
 * Entering-king declaration rule (jishogi / "27-point rule").
 * Fairy-Stockfish has no built-in support for it, so it is implemented in core/impasse.ts.
 */
export interface ImpasseRule {
  /** Points the declaring side needs, counting pieces in the enemy camp plus pieces in hand. */
  blackPoints: number;
  whitePoints: number;
  /** Pieces (other than the king) the declaring side must have inside the enemy camp. */
  minPiecesInZone: number;
  /** Base letters worth `bigPieceValue`; every other non-king piece is worth 1. */
  bigPieces: readonly string[];
  bigPieceValue: number;
}

export interface VariantDefinition {
  /** Variant name as known by Fairy-Stockfish (built-in or defined in `ini`). */
  id: string;
  label: string;
  dims: BoardDims;
  /** Starting position in SFEN. */
  startSfen: string;
  /** Number of ranks on the far side of the board that form the promotion zone (enemy camp). */
  promotionZoneRanks: number;
  /** All base piece letters of the variant, uppercase. */
  pieceTypes: readonly string[];
  /** Base letters that can promote. */
  promotable: readonly string[];
  /**
   * Unpromoted pieces that would have no legal move on the last N ranks (e.g. a pawn on the
   * last rank). They may not be dropped there and must promote when moving there.
   */
  immobileRanks: Readonly<Record<string, number>>;
  /** Nifu: two unpromoted pawns of the same side on one file are forbidden. */
  noDoubledPawns: boolean;
  /**
   * Uchifuzume: dropping a pawn that gives checkmate is illegal. Fairy-Stockfish accepts the
   * drop and scores it as a loss for the dropper, so FairyBackend removes it from the legal moves.
   */
  pawnDropMateIllegal: boolean;
  /** Maximum number of pieces of each base type in the whole game (board + hands), if fixed. */
  maxPieceCounts?: Readonly<Record<string, number>>;
  impasse?: ImpasseRule;
  /**
   * Fairy-Stockfish variants.ini section defining this variant. Leave undefined for variants
   * built into Fairy-Stockfish. See README ("Como adicionar uma variante").
   */
  ini?: string;
}

const SHOGI: VariantDefinition = {
  id: "shogi",
  label: "Shogi",
  dims: { files: 9, ranks: 9 },
  startSfen: "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1",
  promotionZoneRanks: 3,
  pieceTypes: ["K", "R", "B", "G", "S", "N", "L", "P"],
  promotable: ["R", "B", "S", "N", "L", "P"],
  immobileRanks: { P: 1, L: 1, N: 2 },
  noDoubledPawns: true,
  pawnDropMateIllegal: true,
  maxPieceCounts: { K: 2, R: 2, B: 2, G: 4, S: 4, N: 4, L: 4, P: 18 },
  impasse: {
    blackPoints: 28,
    whitePoints: 27,
    minPiecesInZone: 10,
    bigPieces: ["R", "B"],
    bigPieceValue: 5,
  },
};

const VARIANTS: Readonly<Record<string, VariantDefinition>> = {
  shogi: SHOGI,
};

export const DEFAULT_VARIANT = "shogi";

export function getVariant(name: string): VariantDefinition {
  const variant = VARIANTS[name];
  if (!variant) throw new Error(`Unknown variant: ${name}`);
  return variant;
}

export function listVariants(): VariantDefinition[] {
  return Object.values(VARIANTS);
}
