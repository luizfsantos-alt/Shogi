import { PIECE_SCALE, pieceFace, pieceInfo, type Direction, type Movement } from "../core/pieces";
import type { Piece } from "../core/types";

/**
 * How pieces are drawn. By default they carry their traditional kanji (brush lettering);
 * "reading" mode replaces the kanji with marks that show how the piece moves, plus its name.
 * Sente's pieces are pearl and Gote's red lacquer; promoted pieces get gold.
 */
export interface PieceLook {
  reading: boolean;
  /** Language of the names written in reading mode. */
  labels: "pt" | "en";
}

/**
 * A light that sweeps across the piece: in a loop while it is selected, once (in gold) when it
 * has just promoted. `since` (a performance.now() time) keeps the sweep going smoothly when the
 * board is redrawn in the middle of it.
 */
export interface Glint {
  kind: "select" | "promote";
  since: number;
}

const SVG_NS = "http://www.w3.org/2000/svg";
/** Wedge-shaped koma, pointing up (towards the opponent), with sharp corners. */
const OUTLINE = "M50 2 L79 12.5 L90.5 96 L9.5 96 L21 12.5 Z";
/** The band at the base of the piece that holds its name in reading mode. */
const BAND = "M11.84 79 L88.16 79 L90.5 96 L9.5 96 Z";
/** Centre of the movement marks. */
const CX = 50;
const CY = 45;
/** Pieces stand on their base, so they are scaled around the bottom centre. */
const BASE: [number, number] = [50, 96];

function svg<K extends keyof SVGElementTagNameMap>(tag: K, attributes: Record<string, string | number>): SVGElementTagNameMap[K] {
  const element = document.createElementNS(SVG_NS, tag);
  for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, String(value));
  return element;
}

type Stops = [offset: number, color: string, opacity?: number][];

function gradient(id: string, [x1, y1, x2, y2]: number[], stops: Stops): SVGLinearGradientElement {
  const element = svg("linearGradient", { id, x1, y1, x2, y2 });
  for (const [offset, color, opacity = 1] of stops) element.append(svg("stop", { offset, "stop-color": color, "stop-opacity": opacity }));
  return element;
}

function radial(id: string, [cx, cy, r]: number[], stops: Stops): SVGRadialGradientElement {
  const element = svg("radialGradient", { id, cx, cy, r });
  for (const [offset, color, opacity = 1] of stops) element.append(svg("stop", { offset, "stop-color": color, "stop-opacity": opacity }));
  return element;
}

/** Materials shared by every piece (defined once per document). */
function ensureDefinitions(): void {
  if (document.getElementById("koma-defs")) return;
  const root = svg("svg", { id: "koma-defs", width: 0, height: 0, "aria-hidden": "true", style: "position:absolute" });
  const defs = svg("defs", {});
  const clip = svg("clipPath", { id: "koma-clip" });
  clip.append(svg("path", { d: OUTLINE }));
  defs.append(
    clip,
    // Pearl: a pale base with lilac and mint, an iridescent sweep, shaded edges and a highlight.
    gradient("koma-perola", [0.1, 0, 0.85, 1], [[0, "#fffdf9"], [0.3, "#f4eff6"], [0.55, "#fbf6ee"], [0.78, "#ebf2f0"], [1, "#e2d9d6"]]),
    gradient("koma-nacar", [0, 0.15, 1, 0.85], [
      [0.12, "#ffc9e0", 0], [0.24, "#ffc9e0", 0.55], [0.36, "#ffffff", 0], [0.5, "#bfe3ff", 0.5],
      [0.63, "#ffffff", 0], [0.78, "#d8f5d0", 0.45], [0.9, "#ffe6c4", 0.35], [1, "#ffe6c4", 0],
    ]),
    radial("koma-volume", [0.5, 0.42, 0.72], [[0.55, "#9c90a8", 0], [1, "#9c90a8", 0.5]]),
    // Red lacquer.
    gradient("koma-laca", [0.1, 0, 0.8, 1], [[0, "#e5412f"], [0.55, "#b8231a"], [1, "#7d110c"]]),
    radial("koma-brilho", [0.34, 0.2, 0.55], [[0, "#ffffff", 0.95], [0.35, "#ffffff", 0.35], [1, "#ffffff", 0]]),
    // Gold leaf: bands of light and shadow.
    gradient("koma-ouro", [0, 0, 0.35, 1], [[0, "#fff6c2"], [0.22, "#f3c94a"], [0.46, "#9c6a14"], [0.6, "#e9b93c"], [0.74, "#fff1a8"], [1, "#8a5a10"]]),
    gradient("koma-ouro-texto", [0, 0, 0, 1], [[0, "#fff6c4"], [0.28, "#f6cf52"], [0.52, "#a87114"], [0.68, "#f3c94e"], [0.8, "#fff0a6"], [1, "#8e5c10"]]),
    gradient("koma-ouro-faixa", [0, 0, 0, 1], [[0, "#fff3b4"], [0.35, "#e8b73a"], [0.55, "#9a6612"], [0.8, "#f0c75a"], [1, "#7c4f0c"]]),
    // Glints: white on lacquer, iridescent on pearl, gold on promotion.
    gradient("koma-glint", [0, 0, 1, 0], [[0, "#ffffff", 0], [0.5, "#ffffff", 0.85], [1, "#ffffff", 0]]),
    gradient("koma-glint-perola", [0, 0, 1, 0], [
      [0, "#ff7fb8", 0], [0.22, "#ff7fb8", 0.75], [0.42, "#ffe9a8", 0.8], [0.5, "#ffffff", 1],
      [0.6, "#9fe6c8", 0.8], [0.78, "#7fb8ff", 0.75], [1, "#7fb8ff", 0],
    ]),
    gradient("koma-glint-ouro", [0, 0, 1, 0], [[0, "#ffd75a", 0], [0.35, "#ffd75a", 0.55], [0.5, "#fffbe6", 0.95], [0.65, "#ffd75a", 0.55], [1, "#ffd75a", 0]]),
  );
  root.append(defs);
  document.body.append(root);
}

const round = (n: number) => Math.round(n * 100) / 100;
const diamond = (x: number, y: number, r: number) => `M${round(x)} ${round(y - r)} L${round(x + r)} ${round(y)} L${round(x)} ${round(y + r)} L${round(x - r)} ${round(y)} Z `;

/** Unit vector of a direction in SVG coordinates (y down), and its perpendicular. */
function axes([dx, dy]: Direction): [number, number, number, number] {
  const length = Math.hypot(dx, dy);
  const ux = dx / length;
  const uy = -dy / length;
  return [ux, uy, -uy, ux];
}

export interface MovementGlyph {
  /** Filled shapes: cuts (any distance), teeth (one square) and the centre. */
  fills: string;
  /** The knight's hooked path. */
  hooks: string;
  /** Hollow diamonds where a jump lands. */
  rings: string;
  /** Hole in the king's centre. */
  kingCut: string;
}

/**
 * The reading-mode marks, in the piece's own frame (forward = up):
 * a cut that runs off the edge = any distance, a tooth = one square, a hook to a diamond = jump.
 */
export function movementGlyph({ steps, slides, jumps }: Movement, king: boolean): MovementGlyph {
  let fills = "";
  let hooks = "";
  let rings = "";
  for (const direction of slides) {
    const [ux, uy, px, py] = axes(direction);
    const at = (t: number, w: number) => `${round(CX + ux * t + px * w)} ${round(CY + uy * t + py * w)}`;
    fills += `M${at(-2, 7)} L${at(72, 2.2)} L${at(72, -2.2)} L${at(-2, -7)} Z `;
  }
  for (const direction of steps) {
    const [ux, uy, px, py] = axes(direction);
    const at = (t: number, w: number) => `${round(CX + ux * t + px * w)} ${round(CY + uy * t + py * w)}`;
    const distance = direction[0] && direction[1] ? 23 : 21;
    fills += `M${at(distance - 6, 7.8)} L${at(distance + 7.5, 0)} L${at(distance - 6, -7.8)} Z `;
  }
  for (const [dx] of jumps) {
    const x = CX + dx * 14;
    const y = CY - 30;
    hooks += `M${CX} ${CY + 2} L${CX} ${CY - 15} L${round(x - dx * 5.2)} ${round(y + 5.2)} `;
    rings += diamond(x, y, 6.8);
  }
  fills += diamond(CX, CY, king ? 10 : 6);
  return { fills, hooks, rings, kingCut: king ? diamond(CX, CY, 4.6) : "" };
}

/** Name written on the band in reading mode. */
export function pieceLabel(piece: Pick<Piece, "type" | "promoted">, labels: PieceLook["labels"]): string {
  const info = pieceInfo(piece);
  return (labels === "en" ? info.labelEn : info.labelPt).toUpperCase();
}

/** The two kanji of a traditional piece, or one large cursive one. */
function kanjiFace(piece: Piece): SVGTextElement[] {
  const face = [...pieceFace(piece)];
  if (face.length === 1) {
    const text = svg("text", { x: 50, y: 76, "font-size": 52, class: "piece-kanji", "text-anchor": "middle" });
    text.textContent = face[0];
    return [text];
  }
  return face.map((char, index) => {
    const text = svg("text", { x: 50, y: index === 0 ? 47 : 83, "font-size": 33, class: "piece-kanji", "text-anchor": "middle" });
    text.textContent = char;
    return text;
  });
}

function readingFace(piece: Piece, look: PieceLook, upsideDown: boolean): SVGGElement {
  const glyph = movementGlyph(pieceInfo(piece).movement, piece.type === "K");
  const group = svg("g", { "clip-path": "url(#koma-clip)" });
  group.append(svg("path", { d: glyph.fills, class: "piece-ink" }));
  if (glyph.hooks) group.append(svg("path", { d: glyph.hooks, class: "piece-ink-line", "stroke-width": 5.2 }));
  if (glyph.rings) group.append(svg("path", { d: glyph.rings, class: "piece-ink-line", "stroke-width": 3.8 }));
  if (glyph.kingCut) group.append(svg("path", { d: glyph.kingCut, class: "piece-king-cut" }));
  group.append(svg("path", { d: BAND, class: "piece-band" }));
  const label = pieceLabel(piece, look.labels);
  // Condensed capitals average about 0.62 em; keep the name inside the band.
  const fontSize = round(Math.min(15, 70 / Math.max(1, label.length * 0.62)));
  const text = svg("text", { x: 50, y: 92.6, "font-size": fontSize, class: "piece-label", "text-anchor": "middle" });
  // The marks turn with the piece, but the name stays readable for the player at the bottom.
  if (upsideDown) text.setAttribute("transform", "rotate(180 50 87.5)");
  text.textContent = label;
  group.append(text);
  return group;
}

function glintLayer(glint: Glint, piece: Piece): SVGGElement[] {
  const elapsed = Math.max(0, performance.now() - glint.since);
  const delay = `${-Math.round(elapsed)}ms`;
  const gold = glint.kind === "promote";
  const sweep = svg("g", { class: `piece-glint glint-${glint.kind}`, "clip-path": "url(#koma-clip)" });
  const move = svg("g", { class: "glint-move", style: `animation-delay:${delay}` });
  const fill = gold ? "koma-glint-ouro" : piece.color === "black" ? "koma-glint-perola" : "koma-glint";
  move.append(svg("rect", { x: -46, y: -10, width: gold ? 46 : piece.color === "black" ? 40 : 30, height: 130, fill: `url(#${fill})`, transform: "skewX(-22)" }));
  sweep.append(move);
  if (!gold) return [sweep];
  return [sweep, svg("path", { d: OUTLINE, class: "piece-pulse", style: `animation-delay:${delay}` })];
}

/**
 * Builds the SVG of a piece. `upsideDown` is true for pieces of the player at the top;
 * `glint` adds the light sweep of a selected or just-promoted piece.
 */
export function renderPiece(piece: Piece, look: PieceLook, upsideDown: boolean, glint?: Glint): SVGSVGElement {
  ensureDefinitions();
  const team = piece.color === "black" ? "sente" : "gote";
  const root = svg("svg", {
    viewBox: "0 0 100 100",
    class: `piece ${team}${piece.promoted ? " promoted" : ""}${upsideDown ? " upside-down" : ""}`,
    "aria-hidden": "true",
  });
  const scale = PIECE_SCALE[piece.type] ?? 1;
  const body = svg("g", { transform: `translate(${BASE[0]} ${BASE[1]}) scale(${scale}) translate(${-BASE[0]} ${-BASE[1]})` });
  // Cast shadow, then the body and its material.
  body.append(svg("path", { d: OUTLINE, class: "piece-shadow", transform: "translate(3.5 4.5)" }));
  body.append(svg("path", { d: OUTLINE, class: "piece-body" }));
  if (team === "sente") body.append(svg("path", { d: OUTLINE, class: "piece-nacar" }), svg("path", { d: OUTLINE, class: "piece-volume" }));
  body.append(svg("path", { d: OUTLINE, class: "piece-gloss" }));
  body.append(svg("path", { d: OUTLINE, class: "piece-bevel", transform: "translate(50 52) scale(0.93) translate(-50 -52)" }));
  if (look.reading) {
    body.append(readingFace(piece, look, upsideDown));
  } else {
    if (piece.promoted) body.append(svg("path", { d: OUTLINE, class: "piece-gold-rim", transform: "translate(50 56) scale(0.85) translate(-50 -56)" }));
    body.append(...kanjiFace(piece));
  }
  if (glint) body.append(...glintLayer(glint, piece));
  root.append(body);
  return root;
}

/** Accessible description, e.g. "Torre promovida (Dragão) de Gote". */
export function describePiece(piece: Piece): string {
  return `${pieceInfo(piece).namePt} de ${piece.color === "black" ? "Sente" : "Gote"}`;
}
