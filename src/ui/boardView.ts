import { formatSquare } from "../core/notation";
import type { GameBackend } from "../core/GameBackend";
import { opposite, type Color, type Piece, type Square } from "../core/types";
import { element } from "./dialogs";
import { describePiece, renderPiece, type Glint, type PieceLook } from "./pieceView";
import { sideName } from "./text";

/**
 * The board and the two player bars, shared by the game screen and the lessons. Pure
 * rendering: callers say what to highlight and what to do on clicks.
 */

export interface BoardMarks {
  selected?: Square | null;
  targets?: readonly Square[];
  /** Squares of the last move (from and to). */
  last?: readonly Square[];
  check?: Square | null;
  attackers?: readonly Square[];
  hint?: readonly Square[];
  /** Lesson goals: a star on the square. */
  stars?: readonly Square[];
  /** Lesson focus: squares the text talks about. */
  focus?: readonly Square[];
  /** Number of enemy attacks on each square ("file,rank"). */
  attacks?: ReadonlyMap<string, number> | null;
}

export interface BoardOptions {
  backend: GameBackend;
  flipped: boolean;
  look: PieceLook;
  marks: BoardMarks;
  glint?: (square: Square, piece: Piece) => Glint | undefined;
  onClick: (square: Square, piece: Piece | null) => void;
  /** Wires press-and-hold on a piece. */
  onHold?: (target: HTMLElement, piece: Piece) => void;
}

const same = (a: Square | null | undefined, b: Square) => !!a && a.file === b.file && a.rank === b.rank;
const has = (list: readonly Square[] | undefined, square: Square) => !!list?.some((s) => same(s, square));

/** Cells of the board grid: file numbers above, rank letters on the right. */
export function boardCells(options: BoardOptions): HTMLElement[] {
  const { backend, flipped, look, marks } = options;
  const { files, ranks } = backend.variant.dims;
  const bottom: Color = flipped ? "white" : "black";
  const cells: HTMLElement[] = [];
  for (let col = 0; col < files; col++) {
    cells.push(element("div", { class: "coord file" }, String(flipped ? col + 1 : files - col)));
  }
  cells.push(element("div", { class: "coord corner" }));
  for (let row = 0; row < ranks; row++) {
    for (let col = 0; col < files; col++) {
      const square = flipped ? { file: col + 1, rank: ranks - row } : { file: files - col, rank: row + 1 };
      const piece = backend.pieceAt(square);
      const cell = element("button", { type: "button", class: "sq", role: "gridcell" });
      if (row === 0) cell.classList.add("edge-top");
      if (col === 0) cell.classList.add("edge-left");
      const star = has(marks.stars, square);
      cell.setAttribute("aria-label", `${formatSquare(square)}${piece ? `, ${describePiece(piece)}` : ""}${star ? ", objetivo" : ""}`);
      if (piece) {
        cell.append(renderPiece(piece, look, piece.color !== bottom, options.glint?.(square, piece)));
        options.onHold?.(cell, piece);
      }
      if (star) cell.append(element("span", { class: "star", "aria-hidden": "true" }, "★"));
      if (same(marks.selected, square)) cell.classList.add("selected");
      if (has(marks.targets, square)) cell.classList.add(piece ? "target-capture" : "target");
      if (has(marks.last, square)) cell.classList.add("last");
      if (same(marks.check, square)) cell.classList.add("check");
      if (has(marks.attackers, square)) cell.classList.add("attacker");
      if (has(marks.hint, square)) cell.classList.add("hint");
      if (has(marks.focus, square)) cell.classList.add("focus");
      const attackCount = marks.attacks?.get(`${square.file},${square.rank}`);
      if (attackCount) {
        cell.classList.add("attacked");
        if (attackCount > 1) cell.dataset.attacks = String(attackCount);
      }
      cell.addEventListener("click", () => options.onClick(square, piece));
      cells.push(cell);
    }
    cells.push(element("div", { class: "coord rank" }, String.fromCharCode(97 + (flipped ? ranks - 1 - row : row))));
  }
  return cells;
}

export interface PlayerBarOptions {
  backend: GameBackend;
  color: Color;
  look: PieceLook;
  flipped: boolean;
  /** "Você", "Computador"… */
  who: string;
  toMove: boolean;
  /** Piece type selected in this player's hand. */
  selectedType?: string | null;
  glint?: Glint;
  onClick: (type: string) => void;
  onHold?: (target: HTMLElement, piece: Piece) => void;
}

/** Name of the player and the pieces in their hand. */
export function playerBar(options: PlayerBarOptions): HTMLElement[] {
  const { backend, color, look } = options;
  const bottom: Color = options.flipped ? "white" : "black";
  const hand = backend.hand(color);
  const name = element(
    "div",
    { class: `player-name${options.toMove ? " to-move" : ""}` },
    element("span", { class: `team-mark ${color === "black" ? "sente" : "gote"}`, "aria-hidden": "true" }),
    element("strong", {}, sideName(color)),
    element("small", {}, options.who),
  );
  const pieces = element("div", { class: "hand", "aria-label": `Peças na mão de ${sideName(color)}` });
  const types = backend.variant.pieceTypes.filter((type) => (hand[type] ?? 0) > 0);
  if (types.length === 0) pieces.append(element("span", { class: "hand-empty" }, "sem peças na mão"));
  for (const type of types) {
    const piece: Piece = { color, type, promoted: false };
    const button = element("button", { type: "button", class: "hand-piece", "aria-label": `${describePiece(piece)}, ${hand[type]}` });
    const selected = options.selectedType === type;
    button.append(renderPiece(piece, look, color !== bottom, selected ? options.glint : undefined));
    options.onHold?.(button, piece);
    if (hand[type] > 1) button.append(element("span", { class: "count" }, String(hand[type])));
    if (selected) button.classList.add("selected");
    button.addEventListener("click", () => options.onClick(type));
    pieces.append(button);
  }
  return [name, pieces];
}

/** The colour drawn at the top of the board. */
export function topColor(flipped: boolean): Color {
  return opposite(flipped ? "white" : "black");
}
