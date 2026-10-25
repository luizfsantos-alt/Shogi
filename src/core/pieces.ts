import type { Piece } from "./types";

/**
 * Piece catalogue: names and movement, used to draw pieces and (later) movement diagrams.
 *
 * Directions are from the owner's point of view: dy = +1 is "forward" (towards the enemy),
 * dx = +1 is to the owner's right.
 */

export type Direction = readonly [dx: number, dy: number];

export interface Movement {
  /** One square in these directions. */
  steps: readonly Direction[];
  /** Any number of empty squares in these directions. */
  slides: readonly Direction[];
  /** Jumps to these offsets, over other pieces. */
  jumps: readonly Direction[];
}

export interface PieceInfo {
  /** Short Portuguese label, fits on a piece. */
  labelPt: string;
  labelEn: string;
  /** Single-character kanji used on traditional pieces. */
  kanji: string;
  namePt: string;
  nameEn: string;
  romaji: string;
  /** Full kanji name. */
  kanjiName: string;
  movement: Movement;
}

const ORTHOGONAL: Direction[] = [[0, 1], [0, -1], [1, 0], [-1, 0]];
const DIAGONAL: Direction[] = [[1, 1], [-1, 1], [1, -1], [-1, -1]];
const GOLD: Movement = { steps: [[0, 1], [1, 1], [-1, 1], [1, 0], [-1, 0], [0, -1]], slides: [], jumps: [] };

const move = (steps: Direction[], slides: Direction[] = [], jumps: Direction[] = []): Movement => ({ steps, slides, jumps });

const BASE: Record<string, PieceInfo> = {
  K: { labelPt: "Rei", labelEn: "King", kanji: "王", namePt: "Rei", nameEn: "King", romaji: "Ōshō / Gyokushō", kanjiName: "王将 / 玉将", movement: move([...ORTHOGONAL, ...DIAGONAL]) },
  R: { labelPt: "Torre", labelEn: "Rook", kanji: "飛", namePt: "Torre", nameEn: "Rook", romaji: "Hisha", kanjiName: "飛車", movement: move([], ORTHOGONAL) },
  B: { labelPt: "Bispo", labelEn: "Bishop", kanji: "角", namePt: "Bispo", nameEn: "Bishop", romaji: "Kakugyō", kanjiName: "角行", movement: move([], DIAGONAL) },
  G: { labelPt: "Ouro", labelEn: "Gold", kanji: "金", namePt: "General de Ouro", nameEn: "Gold general", romaji: "Kinshō", kanjiName: "金将", movement: GOLD },
  S: { labelPt: "Prata", labelEn: "Silver", kanji: "銀", namePt: "General de Prata", nameEn: "Silver general", romaji: "Ginshō", kanjiName: "銀将", movement: move([[0, 1], ...DIAGONAL]) },
  N: { labelPt: "Cavalo", labelEn: "Knight", kanji: "桂", namePt: "Cavalo", nameEn: "Knight", romaji: "Keima", kanjiName: "桂馬", movement: move([], [], [[1, 2], [-1, 2]]) },
  L: { labelPt: "Lança", labelEn: "Lance", kanji: "香", namePt: "Lança", nameEn: "Lance", romaji: "Kyōsha", kanjiName: "香車", movement: move([], [[0, 1]]) },
  P: { labelPt: "Peão", labelEn: "Pawn", kanji: "歩", namePt: "Peão", nameEn: "Pawn", romaji: "Fuhyō", kanjiName: "歩兵", movement: move([[0, 1]]) },
};

const PROMOTED: Record<string, PieceInfo> = {
  R: { labelPt: "Torre+", labelEn: "Dragon", kanji: "龍", namePt: "Torre promovida (Dragão)", nameEn: "Dragon king", romaji: "Ryūō", kanjiName: "龍王", movement: move(DIAGONAL, ORTHOGONAL) },
  B: { labelPt: "Bispo+", labelEn: "Horse", kanji: "馬", namePt: "Bispo promovido (Cavalo-dragão)", nameEn: "Dragon horse", romaji: "Ryūma", kanjiName: "龍馬", movement: move(ORTHOGONAL, DIAGONAL) },
  S: { labelPt: "Prata+", labelEn: "+Silver", kanji: "全", namePt: "Prata promovida", nameEn: "Promoted silver", romaji: "Narigin", kanjiName: "成銀", movement: GOLD },
  N: { labelPt: "Cavalo+", labelEn: "+Knight", kanji: "圭", namePt: "Cavalo promovido", nameEn: "Promoted knight", romaji: "Narikei", kanjiName: "成桂", movement: GOLD },
  L: { labelPt: "Lança+", labelEn: "+Lance", kanji: "杏", namePt: "Lança promovida", nameEn: "Promoted lance", romaji: "Narikyō", kanjiName: "成香", movement: GOLD },
  P: { labelPt: "Peão+", labelEn: "Tokin", kanji: "と", namePt: "Peão promovido (Tokin)", nameEn: "Tokin", romaji: "Tokin", kanjiName: "と金", movement: GOLD },
};

export function pieceInfo(piece: Pick<Piece, "type" | "promoted">): PieceInfo {
  const info = piece.promoted ? PROMOTED[piece.type] : BASE[piece.type];
  if (!info) throw new Error(`No piece info for ${piece.promoted ? "+" : ""}${piece.type}`);
  return info;
}

/** Kanji for a piece; by convention Sente's king is 玉 and Gote's is 王. */
export function pieceKanji(piece: Piece): string {
  if (piece.type === "K") return piece.color === "black" ? "玉" : "王";
  return pieceInfo(piece).kanji;
}
