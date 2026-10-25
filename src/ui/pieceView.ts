import { PIECE_SCALE, pieceFace, pieceInfo, type Direction } from "../core/pieces";
import type { Piece } from "../core/types";

/**
 * "kanji": traditional pieces (two kanji, promoted side in red), the default.
 * "pt" and "en": short Latin name, for learning. Any style can show movement marks
 * (dots = one step, bars = any distance, small diamonds = knight jumps).
 */
export type PieceStyle = "kanji" | "pt" | "en";

export const PIECE_STYLES: { id: PieceStyle; label: string }[] = [
  { id: "kanji", label: "Tradicional (kanji)" },
  { id: "pt", label: "Nomes em português" },
  { id: "en", label: "English names" },
];

const SVG_NS = "http://www.w3.org/2000/svg";
/** Wedge-shaped koma, pointing up (towards the opponent), with slightly rounded corners. */
const OUTLINE =
  "M50 3 L78.5 13 Q81 14 81.4 16.5 L90.6 94.5 Q90.8 97 88.3 97 L11.7 97 Q9.2 97 9.4 94.5 L18.6 16.5 Q19 14 21.5 13 Z";
const CENTER: [number, number] = [50, 58];
/** Pieces stand on their base, so they are scaled around the bottom centre. */
const BASE: [number, number] = [50, 97];

function svg<K extends keyof SVGElementTagNameMap>(tag: K, attributes: Record<string, string | number>): SVGElementTagNameMap[K] {
  const element = document.createElementNS(SVG_NS, tag);
  for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, String(value));
  return element;
}

/** Wood gradients shared by every piece (defined once per document). */
function ensureDefinitions(): void {
  if (document.getElementById("koma-defs")) return;
  const root = svg("svg", { id: "koma-defs", width: 0, height: 0, "aria-hidden": "true", style: "position:absolute" });
  const defs = svg("defs", {});
  const wood = svg("linearGradient", { id: "koma-wood", x1: 0, y1: 0, x2: 0.9, y2: 1 });
  for (const [offset, color] of [["0", "#f8e2b0"], ["0.55", "#eecb86"], ["1", "#ddb068"]] as const) {
    wood.append(svg("stop", { offset, "stop-color": color }));
  }
  const edge = svg("linearGradient", { id: "koma-edge", x1: 0, y1: 0, x2: 0, y2: 1 });
  edge.append(svg("stop", { offset: "0", "stop-color": "#a87a3e" }), svg("stop", { offset: "1", "stop-color": "#7a5225" }));
  defs.append(wood, edge);
  root.append(defs);
  document.body.append(root);
}

/** Point at `distance` from the centre in direction (dx, dy), in the piece's own frame. */
function towards([dx, dy]: Direction, distance: number): [number, number] {
  const length = Math.hypot(dx, dy);
  return [CENTER[0] + (dx / length) * distance, CENTER[1] - (dy / length) * distance];
}

/** Movement marks; with kanji they stay near the edge so the characters remain readable. */
function movementMarks(piece: Piece, nearEdge: boolean): SVGGElement {
  const group = svg("g", { class: "piece-marks" });
  const { steps, slides, jumps } = pieceInfo(piece).movement;
  for (const direction of steps) {
    const straightAhead = direction[1] > 0 && direction[0] === 0;
    const [x, y] = towards(direction, straightAhead ? 40 : direction[1] === 0 ? 38 : 37);
    group.append(svg("circle", { cx: x, cy: y, r: 4.2 }));
  }
  for (const direction of slides) {
    const [x1, y1] = towards(direction, nearEdge ? 37 : 29);
    const [x2, y2] = towards(direction, direction[1] > 0 && direction[0] === 0 ? 47 : 42);
    group.append(svg("line", { x1, y1, x2, y2, "stroke-width": 5, "stroke-linecap": "round" }));
  }
  for (const [dx] of jumps) {
    const x = 50 + dx * 17;
    group.append(svg("path", { d: `M${x} 4 l5 6 l-5 6 l-5 -6 z` }));
  }
  return group;
}

/** The characters of a traditional piece: two stacked kanji, or one large cursive one. */
function kanjiFace(piece: Piece): SVGTextElement[] {
  const face = [...pieceFace(piece)];
  if (face.length === 1) {
    const text = svg("text", { x: 50, y: 77, "font-size": 48, class: "piece-label kanji", "text-anchor": "middle" });
    text.textContent = face[0];
    return [text];
  }
  return face.map((char, index) => {
    const text = svg("text", { x: 50, y: index === 0 ? 50 : 86, "font-size": 33, class: "piece-label kanji", "text-anchor": "middle" });
    text.textContent = char;
    return text;
  });
}

function latinFace(piece: Piece, style: "pt" | "en"): SVGTextElement {
  const info = pieceInfo(piece);
  const label = style === "pt" ? info.labelPt : info.labelEn;
  // Keep labels within ~60 units so they clear the movement marks on the sides.
  const fontSize = label.length <= 4 ? 24 : label.length <= 5 ? 20 : label.length <= 6 ? 17 : 15;
  const text = svg("text", { x: CENTER[0], y: CENTER[1] + fontSize * 0.35, "font-size": fontSize, class: "piece-label latin", "text-anchor": "middle" });
  text.textContent = label;
  return text;
}

/**
 * Builds the SVG of a piece. `upsideDown` is true for pieces of the player at the top;
 * `marks` adds the movement marks.
 */
export function renderPiece(piece: Piece, style: PieceStyle, upsideDown: boolean, marks = false): SVGSVGElement {
  ensureDefinitions();
  const root = svg("svg", {
    viewBox: "0 0 100 100",
    class: `piece${piece.promoted ? " promoted" : ""}${upsideDown ? " upside-down" : ""}`,
    "aria-hidden": "true",
  });
  const scale = PIECE_SCALE[piece.type] ?? 1;
  const body = svg("g", { transform: `translate(${BASE[0]} ${BASE[1]}) scale(${scale}) translate(${-BASE[0]} ${-BASE[1]})` });
  // The visible side of the wooden block, then the top face.
  body.append(svg("path", { d: OUTLINE, class: "piece-edge", transform: "translate(1.6 2.2)" }));
  body.append(svg("path", { d: OUTLINE, class: "piece-body" }));
  if (marks) body.append(movementMarks(piece, style === "kanji"));
  if (style === "kanji") body.append(...kanjiFace(piece));
  else body.append(latinFace(piece, style));
  root.append(body);
  return root;
}

/** Accessible description, e.g. "Torre promovida (Dragão) de Gote". */
export function describePiece(piece: Piece): string {
  return `${pieceInfo(piece).namePt} de ${piece.color === "black" ? "Sente" : "Gote"}`;
}
