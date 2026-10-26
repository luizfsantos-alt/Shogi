import { parseSquare } from "../core/notation";
import { formatBoard } from "../core/position";
import type { Piece, Square } from "../core/types";

/**
 * Builds a lesson position from a list of pieces, which is much easier to read and check than
 * a hand-written SFEN: `setup({ "5i": "K", "5a": "k", "2c": "+P" }, "G")`.
 * Uppercase letters are Sente's, lowercase Gote's, "+" marks a promoted piece.
 * `hand` is the SFEN hand text ("G2P", "Pb"), "-" or empty for none.
 */
export function setup(pieces: Record<string, string>, hand = "", side: "b" | "w" = "b"): string {
  const board: (Piece | null)[][] = Array.from({ length: 9 }, () => Array<Piece | null>(9).fill(null));
  for (const [name, code] of Object.entries(pieces)) {
    const square = parseSquare(name);
    const match = /^(\+?)([KRBGSNLPkrbgsnlp])$/.exec(code);
    if (!square || !match) throw new Error(`Bad lesson piece: ${name}=${code}`);
    const letter = match[2];
    const row = square.rank - 1;
    const col = 9 - square.file;
    if (board[row][col]) throw new Error(`Two lesson pieces on ${name}`);
    board[row][col] = { color: letter === letter.toUpperCase() ? "black" : "white", type: letter.toUpperCase(), promoted: match[1] === "+" };
  }
  return `${formatBoard(board)} ${side} ${hand || "-"} 1`;
}

/** Squares from USI names; throws on a typo so a broken lesson fails its test. */
export function squares(names: readonly string[] | undefined): Square[] {
  return (names ?? []).map((name) => {
    const square = parseSquare(name);
    if (!square) throw new Error(`Bad lesson square: ${name}`);
    return square;
  });
}
