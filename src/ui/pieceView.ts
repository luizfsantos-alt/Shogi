import { pieceInfo, pieceKanji, type Direction } from "../core/pieces";
import type { Piece } from "../core/types";

/**
 * "pt" and "en": short name plus movement marks (dots = one step, bars = any distance,
 * small diamonds = knight jumps) — the easiest way to learn. "kanji": traditional pieces.
 */
export type PieceStyle = "pt" | "en" | "kanji";

export const PIECE_STYLES: { id: PieceStyle; label: string }[] = [
  { id: "pt", label: "Português + movimentos" },
  { id: "en", label: "English + moves" },
  { id: "kanji", label: "Kanji (tradicional)" },
];

const SVG_NS = "http://www.w3.org/2000/svg";
// Wedge-shaped (pentagon) piece, pointing up = towards the opponent.
const OUTLINE = "50,3 82,15 94,97 6,97 18,15";
const CENTER: [number, number] = [50, 58];

function svg<K extends keyof SVGElementTagNameMap>(tag: K, attributes: Record<string, string | number>): SVGElementTagNameMap[K] {
  const element = document.createElementNS(SVG_NS, tag);
  for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, String(value));
  return element;
}

/** Point at `distance` from the centre in direction (dx, dy), in the piece's own frame. */
function towards([dx, dy]: Direction, distance: number): [number, number] {
  const length = Math.hypot(dx, dy);
  return [CENTER[0] + (dx / length) * distance, CENTER[1] - (dy / length) * distance];
}

function movementMarks(piece: Piece): SVGGElement {
  const group = svg("g", { class: "piece-marks" });
  const { steps, slides, jumps } = pieceInfo(piece).movement;
  for (const direction of steps) {
    const sideways = direction[1] === 0;
    const [x, y] = towards(direction, direction[1] > 0 && direction[0] === 0 ? 40 : sideways ? 38 : 37);
    group.append(svg("circle", { cx: x, cy: y, r: 4.2 }));
  }
  for (const direction of slides) {
    const [x1, y1] = towards(direction, 29);
    const [x2, y2] = towards(direction, direction[1] > 0 && direction[0] === 0 ? 47 : 42);
    group.append(svg("line", { x1, y1, x2, y2, "stroke-width": 5, "stroke-linecap": "round" }));
  }
  for (const [dx] of jumps) {
    const x = 50 + dx * 17;
    group.append(svg("path", { d: `M${x} 4 l5 6 l-5 6 l-5 -6 z` }));
  }
  return group;
}

function label(piece: Piece, style: PieceStyle): string {
  if (style === "kanji") return pieceKanji(piece);
  const info = pieceInfo(piece);
  return style === "pt" ? info.labelPt : info.labelEn;
}

/** Builds the SVG of a piece. `upsideDown` is true for pieces of the player at the top. */
export function renderPiece(piece: Piece, style: PieceStyle, upsideDown: boolean): SVGSVGElement {
  const root = svg("svg", {
    viewBox: "0 0 100 100",
    class: `piece${piece.promoted ? " promoted" : ""}${upsideDown ? " upside-down" : ""}`,
    "aria-hidden": "true",
  });
  root.append(svg("polygon", { points: OUTLINE, class: "piece-body" }));
  if (style !== "kanji") root.append(movementMarks(piece));

  const text = label(piece, style);
  // Keep Latin labels within ~60 units so they clear the movement marks on the sides.
  const fontSize = style === "kanji" ? 52 : text.length <= 4 ? 24 : text.length <= 5 ? 20 : text.length <= 6 ? 17 : 15;
  const textNode = svg("text", {
    x: CENTER[0],
    y: style === "kanji" ? 76 : CENTER[1] + fontSize * 0.35,
    "font-size": fontSize,
    class: "piece-label",
    "text-anchor": "middle",
  });
  textNode.textContent = text;
  root.append(textNode);
  return root;
}

/** Accessible description, e.g. "Torre promovida (Dragão) de Gote". */
export function describePiece(piece: Piece): string {
  return `${pieceInfo(piece).namePt} de ${piece.color === "black" ? "Sente" : "Gote"}`;
}
