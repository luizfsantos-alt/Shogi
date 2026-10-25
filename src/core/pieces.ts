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
  /** How it moves, in plain Portuguese. */
  movePt: string;
  movement: Movement;
}

const ORTHOGONAL: Direction[] = [[0, 1], [0, -1], [1, 0], [-1, 0]];
const DIAGONAL: Direction[] = [[1, 1], [-1, 1], [1, -1], [-1, -1]];
const GOLD: Movement = { steps: [[0, 1], [1, 1], [-1, 1], [1, 0], [-1, 0], [0, -1]], slides: [], jumps: [] };

const move = (steps: Direction[], slides: Direction[] = [], jumps: Direction[] = []): Movement => ({ steps, slides, jumps });

const BASE: Record<string, PieceInfo> = {
  K: { labelPt: "Rei", labelEn: "King", kanji: "王", namePt: "Rei", nameEn: "King", romaji: "Ōshō / Gyokushō", kanjiName: "王将 / 玉将", movePt: "Uma casa em qualquer direção. Se ele não tiver como escapar de um ataque, é xeque-mate.", movement: move([...ORTHOGONAL, ...DIAGONAL]) },
  R: { labelPt: "Torre", labelEn: "Rook", kanji: "飛", namePt: "Torre", nameEn: "Rook", romaji: "Hisha", kanjiName: "飛車", movePt: "Quantas casas quiser na horizontal ou na vertical, sem pular peças.", movement: move([], ORTHOGONAL) },
  B: { labelPt: "Bispo", labelEn: "Bishop", kanji: "角", namePt: "Bispo", nameEn: "Bishop", romaji: "Kakugyō", kanjiName: "角行", movePt: "Quantas casas quiser na diagonal, sem pular peças.", movement: move([], DIAGONAL) },
  G: { labelPt: "Ouro", labelEn: "Gold", kanji: "金", namePt: "General de Ouro", nameEn: "Gold general", romaji: "Kinshō", kanjiName: "金将", movePt: "Uma casa para frente, para os lados, para trás ou nas duas diagonais da frente (não vai nas diagonais de trás).", movement: GOLD },
  S: { labelPt: "Prata", labelEn: "Silver", kanji: "銀", namePt: "General de Prata", nameEn: "Silver general", romaji: "Ginshō", kanjiName: "銀将", movePt: "Uma casa para frente ou em qualquer diagonal (não vai para os lados nem direto para trás).", movement: move([[0, 1], ...DIAGONAL]) },
  N: { labelPt: "Cavalo", labelEn: "Knight", kanji: "桂", namePt: "Cavalo", nameEn: "Knight", romaji: "Keima", kanjiName: "桂馬", movePt: "Salta para uma das duas casas duas à frente e uma para o lado, pulando qualquer peça. Só anda para frente.", movement: move([], [], [[1, 2], [-1, 2]]) },
  L: { labelPt: "Lança", labelEn: "Lance", kanji: "香", namePt: "Lança", nameEn: "Lance", romaji: "Kyōsha", kanjiName: "香車", movePt: "Quantas casas quiser, só para frente, sem pular peças.", movement: move([], [[0, 1]]) },
  P: { labelPt: "Peão", labelEn: "Pawn", kanji: "歩", namePt: "Peão", nameEn: "Pawn", romaji: "Fuhyō", kanjiName: "歩兵", movePt: "Uma casa para frente. Captura do mesmo jeito que anda (diferente do xadrez).", movement: move([[0, 1]]) },
};

const PROMOTED: Record<string, PieceInfo> = {
  R: { labelPt: "Torre+", labelEn: "Dragon", kanji: "龍", namePt: "Torre promovida (Dragão)", nameEn: "Dragon king", romaji: "Ryūō", kanjiName: "龍王", movePt: "Como a torre (linhas retas, qualquer distância) e também uma casa nas diagonais.", movement: move(DIAGONAL, ORTHOGONAL) },
  B: { labelPt: "Bispo+", labelEn: "Horse", kanji: "馬", namePt: "Bispo promovido (Cavalo-dragão)", nameEn: "Dragon horse", romaji: "Ryūma", kanjiName: "龍馬", movePt: "Como o bispo (diagonais, qualquer distância) e também uma casa na horizontal ou vertical.", movement: move(ORTHOGONAL, DIAGONAL) },
  S: { labelPt: "Prata+", labelEn: "+Silver", kanji: "全", namePt: "Prata promovida", nameEn: "Promoted silver", romaji: "Narigin", kanjiName: "成銀", movePt: "Passa a andar como o Ouro.", movement: GOLD },
  N: { labelPt: "Cavalo+", labelEn: "+Knight", kanji: "圭", namePt: "Cavalo promovido", nameEn: "Promoted knight", romaji: "Narikei", kanjiName: "成桂", movePt: "Passa a andar como o Ouro.", movement: GOLD },
  L: { labelPt: "Lança+", labelEn: "+Lance", kanji: "杏", namePt: "Lança promovida", nameEn: "Promoted lance", romaji: "Narikyō", kanjiName: "成香", movePt: "Passa a andar como o Ouro.", movement: GOLD },
  P: { labelPt: "Peão+", labelEn: "Tokin", kanji: "と", namePt: "Peão promovido (Tokin)", nameEn: "Tokin", romaji: "Tokin", kanjiName: "と金", movePt: "Passa a andar como o Ouro.", movement: GOLD },
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

/**
 * What is written on a traditional piece: two kanji, read top to bottom (飛車, 角行…).
 * The promoted side of silver, knight, lance and pawn carries a single cursive character
 * (全, 圭, 杏, と); dragon and horse keep two (龍王, 龍馬). Sente's king is 玉将, Gote's 王将.
 */
export function pieceFace(piece: Piece): string {
  if (piece.type === "K") return piece.color === "black" ? "玉将" : "王将";
  if (piece.promoted && piece.type !== "R" && piece.type !== "B") return pieceInfo(piece).kanji;
  return pieceInfo(piece).kanjiName;
}

/** Relative size of a traditional piece: the king is the largest, the pawn the smallest. */
export const PIECE_SCALE: Readonly<Record<string, number>> = { K: 1, R: 0.97, B: 0.97, G: 0.93, S: 0.93, N: 0.9, L: 0.88, P: 0.85 };

/** "o Bispo", "a Torre", "a Lança promovida". */
export function withArticle(piece: Pick<Piece, "type" | "promoted">): string {
  const feminine = piece.type === "R" || piece.type === "L" || (piece.promoted && piece.type === "S");
  return `${feminine ? "a" : "o"} ${pieceInfo(piece).namePt}`;
}
