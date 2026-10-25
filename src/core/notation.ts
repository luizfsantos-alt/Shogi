import type { BoardDims, ParsedMove, Square, UsiMove } from "./types";

/**
 * Conversions between USI notation (used everywhere in this app) and the internal
 * notation of Fairy-Stockfish / ffish.
 *
 * Fairy-Stockfish names squares like chess: file letter "a" is Black's LEFT-most file
 * (USI file 9 on a 9x9 board) and rank 1 is Black's back rank (USI rank "i").
 * Example on 9x9: USI "7g7f" == Fairy "c3c4"; USI "P*5e" == Fairy "P@e5".
 */

const USI_SQUARE = /^(\d+)([a-z])/;
const FAIRY_SQUARE = /^([a-z])(\d+)/;

export function formatSquare(square: Square): string {
  return `${square.file}${String.fromCharCode(96 + square.rank)}`;
}

export function parseSquare(text: string): Square | null {
  const match = USI_SQUARE.exec(text);
  if (!match || match[0].length !== text.length) return null;
  return { file: Number(match[1]), rank: match[2].charCodeAt(0) - 96 };
}

export function isOnBoard(square: Square, dims: BoardDims): boolean {
  return square.file >= 1 && square.file <= dims.files && square.rank >= 1 && square.rank <= dims.ranks;
}

export function parseUsiMove(move: UsiMove): ParsedMove | null {
  const drop = /^([A-Z])\*(\d+[a-z])$/.exec(move);
  if (drop) {
    const to = parseSquare(drop[2]);
    return to ? { from: null, to, drop: drop[1], promote: false } : null;
  }
  const normal = /^(\d+[a-z])(\d+[a-z])(\+?)$/.exec(move);
  if (!normal) return null;
  const from = parseSquare(normal[1]);
  const to = parseSquare(normal[2]);
  if (!from || !to) return null;
  return { from, to, drop: null, promote: normal[3] === "+" };
}

export function formatUsiMove(move: ParsedMove): UsiMove {
  const to = formatSquare(move.to);
  if (move.drop) return `${move.drop}*${to}`;
  if (!move.from) throw new Error("A non-drop move needs an origin square");
  return `${formatSquare(move.from)}${to}${move.promote ? "+" : ""}`;
}

function usiSquareToFairy(square: Square, dims: BoardDims): string {
  const fileLetter = String.fromCharCode(97 + dims.files - square.file);
  return `${fileLetter}${dims.ranks + 1 - square.rank}`;
}

function fairySquareToUsi(text: string, dims: BoardDims): { square: Square; length: number } {
  const match = FAIRY_SQUARE.exec(text);
  if (!match) throw new Error(`Invalid Fairy-Stockfish square in "${text}"`);
  const fileIndex = match[1].charCodeAt(0) - 97;
  const square = { file: dims.files - fileIndex, rank: dims.ranks + 1 - Number(match[2]) };
  return { square, length: match[0].length };
}

export function usiToFairy(move: UsiMove, dims: BoardDims): string {
  const parsed = parseUsiMove(move);
  if (!parsed) throw new Error(`Invalid USI move: "${move}"`);
  const to = usiSquareToFairy(parsed.to, dims);
  if (parsed.drop) return `${parsed.drop}@${to}`;
  return `${usiSquareToFairy(parsed.from!, dims)}${to}${parsed.promote ? "+" : ""}`;
}

export function fairyToUsi(move: string, dims: BoardDims): UsiMove {
  const drop = /^([A-Za-z])@(.+)$/.exec(move);
  if (drop) {
    const { square } = fairySquareToUsi(drop[2], dims);
    return `${drop[1].toUpperCase()}*${formatSquare(square)}`;
  }
  const from = fairySquareToUsi(move, dims);
  const rest = move.slice(from.length);
  const to = fairySquareToUsi(rest, dims);
  const suffix = rest.slice(to.length);
  return `${formatSquare(from.square)}${formatSquare(to.square)}${suffix === "+" ? "+" : ""}`;
}
