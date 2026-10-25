import type { Position } from "./position";
import type { VariantDefinition } from "./variants";
import type { Color } from "./types";

/**
 * Entering-king declaration (jishogi), "27-point rule" as used by the Japan Shogi
 * Association in amateur play and by computer shogi (CSA):
 *
 * On their own turn, a player may declare a win when ALL of these hold:
 *  1. their king is inside the enemy camp (the promotion zone);
 *  2. they have at least 10 other pieces inside the enemy camp;
 *  3. pieces in the enemy camp + pieces in hand are worth at least 28 points (Sente)
 *     or 27 points (Gote); rook and bishop (promoted or not) are worth 5, others 1,
 *     the king 0;
 *  4. their king is not in check.
 *
 * Fairy-Stockfish does not implement this rule, so it lives here.
 */

export interface ImpasseEvaluation {
  canDeclare: boolean;
  kingInZone: boolean;
  piecesInZone: number;
  requiredPieces: number;
  points: number;
  requiredPoints: number;
  inCheck: boolean;
}

export function isInEnemyCamp(row: number, color: Color, variant: VariantDefinition): boolean {
  const zone = variant.promotionZoneRanks;
  return color === "black" ? row < zone : row >= variant.dims.ranks - zone;
}

export function evaluateImpasse(
  position: Position,
  variant: VariantDefinition,
  color: Color,
  inCheck: boolean,
): ImpasseEvaluation | null {
  const rule = variant.impasse;
  if (!rule) return null;
  const valueOf = (type: string): number => (rule.bigPieces.includes(type) ? rule.bigPieceValue : 1);

  let kingInZone = false;
  let piecesInZone = 0;
  let points = 0;
  position.board.forEach((row, rowIndex) => {
    if (!isInEnemyCamp(rowIndex, color, variant)) return;
    for (const piece of row) {
      if (!piece || piece.color !== color) continue;
      if (piece.type === "K") {
        kingInZone = true;
        continue;
      }
      piecesInZone++;
      points += valueOf(piece.type);
    }
  });
  for (const [type, count] of Object.entries(position.hands[color])) points += valueOf(type) * count;

  const requiredPoints = color === "black" ? rule.blackPoints : rule.whitePoints;
  return {
    canDeclare: kingInZone && piecesInZone >= rule.minPiecesInZone && points >= requiredPoints && !inCheck,
    kingInZone,
    piecesInZone,
    requiredPieces: rule.minPiecesInZone,
    points,
    requiredPoints,
    inCheck,
  };
}
