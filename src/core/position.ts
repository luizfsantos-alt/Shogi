import type { VariantDefinition } from "./variants";
import type { BoardDims, Color, Hand, Piece, Square } from "./types";

/**
 * A static snapshot of a position, independent of any rules library.
 * `board[row][col]`: row 0 is rank 1 (top), col 0 is the highest file (Black's left).
 */
export interface Position {
  board: (Piece | null)[][];
  sideToMove: Color;
  hands: Record<Color, Hand>;
  /** SFEN move number (1 at the start of the game, +1 per ply). */
  moveNumber: number;
}

export class SfenError extends Error {
  override name = "SfenError";
}

export function pieceAt(position: Position, square: Square, dims: BoardDims): Piece | null {
  return position.board[square.rank - 1]?.[dims.files - square.file] ?? null;
}

export function findKing(position: Position, color: Color, dims: BoardDims): Square | null {
  for (let row = 0; row < position.board.length; row++) {
    const col = position.board[row].findIndex((p) => p?.type === "K" && p.color === color);
    if (col >= 0) return squareOf(row, col, dims);
  }
  return null;
}

export function squareOf(row: number, col: number, dims: BoardDims): Square {
  return { file: dims.files - col, rank: row + 1 };
}

// ---------------------------------------------------------------- parsing

export function parseBoard(text: string, variant: VariantDefinition): (Piece | null)[][] {
  const { files, ranks } = variant.dims;
  const rows = text.split("/");
  if (rows.length !== ranks) {
    throw new SfenError(`O tabuleiro precisa de ${ranks} fileiras, mas tem ${rows.length}.`);
  }
  return rows.map((row, index) => {
    const cells = parseRow(row, variant);
    if (cells.length !== files) {
      throw new SfenError(`A fileira ${index + 1} tem ${cells.length} casas em vez de ${files}.`);
    }
    return cells;
  });
}

function parseRow(row: string, variant: VariantDefinition): (Piece | null)[] {
  const cells: (Piece | null)[] = [];
  const tokens = row.match(/\d+|\+?[A-Za-z]|./g) ?? [];
  for (const token of tokens) {
    if (/^\d+$/.test(token)) {
      for (let i = 0; i < Number(token); i++) cells.push(null);
      continue;
    }
    cells.push(parsePieceToken(token, variant));
  }
  return cells;
}

function parsePieceToken(token: string, variant: VariantDefinition): Piece {
  const promoted = token.startsWith("+");
  const letter = promoted ? token.slice(1) : token;
  const type = letter.toUpperCase();
  if (!/^[A-Za-z]$/.test(letter) || !variant.pieceTypes.includes(type)) {
    throw new SfenError(`Peça desconhecida: "${token}".`);
  }
  if (promoted && !variant.promotable.includes(type)) {
    throw new SfenError(`A peça "${letter}" não pode ser promovida.`);
  }
  return { color: letter === type ? "black" : "white", type, promoted };
}

export function parseHands(text: string, variant: VariantDefinition): Record<Color, Hand> {
  const hands: Record<Color, Hand> = { black: {}, white: {} };
  if (text === "-") return hands;
  const tokens = text.match(/\d*[A-Za-z]|./g) ?? [];
  for (const token of tokens) {
    const match = /^(\d*)([A-Za-z])$/.exec(token);
    const type = match?.[2].toUpperCase();
    if (!match || !type || type === "K" || !variant.pieceTypes.includes(type)) {
      throw new SfenError(`Peça inválida na mão: "${token}".`);
    }
    const color: Color = match[2] === type ? "black" : "white";
    const count = match[1] === "" ? 1 : Number(match[1]);
    hands[color][type] = (hands[color][type] ?? 0) + count;
  }
  return hands;
}

export function parseSfen(sfen: string, variant: VariantDefinition): Position {
  const parts = sfen.trim().split(/\s+/);
  if (parts.length < 3 || parts.length > 4) {
    throw new SfenError("Um SFEN tem 4 partes: tabuleiro, lado a jogar (b/w), mãos e número do lance.");
  }
  const [boardText, side, handText, moveText = "1"] = parts;
  if (side !== "b" && side !== "w") {
    throw new SfenError(`Lado a jogar deve ser "b" (Sente) ou "w" (Gote), não "${side}".`);
  }
  if (!/^\d+$/.test(moveText) || Number(moveText) < 1) {
    throw new SfenError(`Número do lance inválido: "${moveText}".`);
  }
  const position: Position = {
    board: parseBoard(boardText, variant),
    sideToMove: side === "b" ? "black" : "white",
    hands: parseHands(handText, variant),
    moveNumber: Number(moveText),
  };
  const problem = findSetupProblem(position, variant);
  if (problem) throw new SfenError(problem);
  return position;
}

// ---------------------------------------------------------------- formatting

export function formatBoard(board: (Piece | null)[][]): string {
  return board.map(formatRow).join("/");
}

function formatRow(row: (Piece | null)[]): string {
  let text = "";
  let empty = 0;
  for (const piece of row) {
    if (!piece) {
      empty++;
      continue;
    }
    if (empty) text += String(empty);
    empty = 0;
    const letter = piece.color === "black" ? piece.type : piece.type.toLowerCase();
    text += (piece.promoted ? "+" : "") + letter;
  }
  return empty ? text + String(empty) : text;
}

/** Hands in the standard SFEN order: Black then White, each R B G S N L P (variant order). */
export function formatHands(hands: Record<Color, Hand>, variant: VariantDefinition): string {
  let text = "";
  for (const color of ["black", "white"] as const) {
    for (const type of variant.pieceTypes) {
      const count = hands[color][type] ?? 0;
      if (count === 0) continue;
      const letter = color === "black" ? type : type.toLowerCase();
      text += (count > 1 ? String(count) : "") + letter;
    }
  }
  return text || "-";
}

export function formatSfen(position: Position, variant: VariantDefinition): string {
  const side = position.sideToMove === "black" ? "b" : "w";
  return `${formatBoard(position.board)} ${side} ${formatHands(position.hands, variant)} ${position.moveNumber}`;
}

// ---------------------------------------------------------------- setup validation

/**
 * Returns a human-readable problem with the setup, or null when it is acceptable.
 * Covers what can be checked without move generation (the backend additionally verifies
 * that the side that just moved is not left in check).
 */
export function findSetupProblem(position: Position, variant: VariantDefinition): string | null {
  return (
    checkKings(position) ??
    checkImmobilePieces(position, variant) ??
    checkDoubledPawns(position, variant) ??
    checkPieceCounts(position, variant)
  );
}

function allPieces(position: Position): Piece[] {
  return position.board.flat().filter((piece): piece is Piece => piece !== null);
}

function checkKings(position: Position): string | null {
  for (const color of ["black", "white"] as const) {
    const kings = allPieces(position).filter((p) => p.type === "K" && p.color === color).length;
    if (kings !== 1) return `Cada lado precisa de exatamente um rei (${colorName(color)} tem ${kings}).`;
  }
  return null;
}

function checkImmobilePieces(position: Position, variant: VariantDefinition): string | null {
  const ranks = variant.dims.ranks;
  for (let row = 0; row < ranks; row++) {
    for (const piece of position.board[row]) {
      if (!piece || piece.promoted) continue;
      const deadRanks = variant.immobileRanks[piece.type] ?? 0;
      const distanceToFarEnd = piece.color === "black" ? row : ranks - 1 - row;
      if (distanceToFarEnd < deadRanks) {
        return `A peça "${piece.type}" de ${colorName(piece.color)} na fileira ${row + 1} não teria jogadas.`;
      }
    }
  }
  return null;
}

function checkDoubledPawns(position: Position, variant: VariantDefinition): string | null {
  if (!variant.noDoubledPawns) return null;
  for (let col = 0; col < variant.dims.files; col++) {
    for (const color of ["black", "white"] as const) {
      const pawns = position.board.filter((row) => {
        const piece = row[col];
        return piece?.type === "P" && !piece.promoted && piece.color === color;
      }).length;
      if (pawns > 1) return `Nifu (二歩): ${colorName(color)} tem dois peões na coluna ${variant.dims.files - col}.`;
    }
  }
  return null;
}

function checkPieceCounts(position: Position, variant: VariantDefinition): string | null {
  if (!variant.maxPieceCounts) return null;
  const counts: Record<string, number> = {};
  for (const piece of allPieces(position)) counts[piece.type] = (counts[piece.type] ?? 0) + 1;
  for (const hand of [position.hands.black, position.hands.white]) {
    for (const [type, count] of Object.entries(hand)) counts[type] = (counts[type] ?? 0) + count;
  }
  for (const [type, count] of Object.entries(counts)) {
    const max = variant.maxPieceCounts[type] ?? 0;
    if (count > max) return `Há ${count} peças "${type}", mas o jogo só tem ${max}.`;
  }
  return null;
}

function colorName(color: Color): string {
  return color === "black" ? "Sente" : "Gote";
}

// ---------------------------------------------------------------- Fairy-Stockfish FEN

/**
 * Fairy-Stockfish FEN for shogi-like variants: same board text, pieces in hand inside
 * brackets, and the colours swapped ("w" = first player = Sente).
 */
export function toFairyFen(position: Position, variant: VariantDefinition): string {
  const pocket = formatHands(position.hands, variant).replace("-", "").replace(/(\d+)([A-Za-z])/g,
    (_, count: string, letter: string) => letter.repeat(Number(count)));
  const side = position.sideToMove === "black" ? "w" : "b";
  const fullMove = Math.floor((position.moveNumber - 1) / 2) + 1;
  return `${formatBoard(position.board)}[${pocket}] ${side} - - 0 ${fullMove}`;
}

/** Inverse of toFairyFen; the move number is not recoverable and must be supplied. */
export function fromFairyFen(fen: string, variant: VariantDefinition, moveNumber: number): Position {
  const match = /^([^\s[]+)\[([^\]]*)\]\s+([wb])/.exec(fen);
  if (!match) throw new Error(`Unexpected Fairy-Stockfish FEN: "${fen}"`);
  return {
    board: parseBoard(match[1], variant),
    sideToMove: match[3] === "w" ? "black" : "white",
    hands: parseHands(match[2] || "-", variant),
    moveNumber,
  };
}
