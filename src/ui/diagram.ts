import { pieceInfo } from "../core/pieces";
import type { Piece } from "../core/types";
import { element } from "./dialogs";
import { renderPiece, type PieceLook } from "./pieceView";

const SIZE = 5;
const CENTER = 2;

/**
 * 5x5 movement diagram, from the owner's point of view (forward = up):
 * dots = one square, shaded line = any distance, diamond = jump.
 */
export function movementDiagram(piece: Pick<Piece, "type" | "promoted">, look: PieceLook): HTMLElement {
  const { steps, slides, jumps } = pieceInfo(piece).movement;
  const kinds = new Map<string, string>();
  const key = (dx: number, dy: number) => `${CENTER - dy},${CENTER + dx}`;
  for (const [dx, dy] of slides) {
    for (let n = 1; Math.abs(dx * n) <= CENTER && Math.abs(dy * n) <= CENTER; n++) kinds.set(key(dx * n, dy * n), "slide");
  }
  for (const [dx, dy] of steps) kinds.set(key(dx, dy), "step");
  for (const [dx, dy] of jumps) kinds.set(key(dx, dy), "jump");

  const grid = element("div", { class: "diagram", role: "img", "aria-label": `Movimento: ${pieceInfo(piece).movePt}` });
  for (let row = 0; row < SIZE; row++) {
    for (let col = 0; col < SIZE; col++) {
      const cell = element("div", { class: `diagram-cell ${kinds.get(`${row},${col}`) ?? ""}` });
      if (row === CENTER && col === CENTER) cell.append(renderPiece({ color: "black", ...piece }, look, false));
      grid.append(cell);
    }
  }
  return grid;
}

export function diagramLegend(): HTMLElement {
  return element(
    "div",
    { class: "diagram-legend" },
    element("span", { class: "legend step" }, "uma casa"),
    element("span", { class: "legend slide" }, "qualquer distância"),
    element("span", { class: "legend jump" }, "salto"),
  );
}
