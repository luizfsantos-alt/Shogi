import { pieceInfo, pieceKanji } from "../core/pieces";
import type { VariantDefinition } from "../core/variants";
import type { Color, Piece } from "../core/types";
import { movementDiagram } from "./diagram";
import { element } from "./dialogs";
import type { PieceStyle } from "./pieceView";
import { sideName } from "./text";

/** Learning card for a piece: names, movement diagram and promotion. */
export function pieceCard(piece: Piece, variant: VariantDefinition, style: PieceStyle, viewer: Color | null): HTMLElement {
  const info = pieceInfo(piece);
  const owner = viewer === null ? sideName(piece.color) : piece.color === viewer ? `${sideName(piece.color)} (sua)` : `${sideName(piece.color)} (do adversário)`;
  const card = element(
    "div",
    { class: "piece-card" },
    element(
      "div",
      { class: "piece-card-head" },
      element("strong", {}, info.namePt),
      element("span", {}, `${info.romaji} · ${info.kanjiName} (${pieceKanji(piece)})`),
      element("small", {}, `Peça de ${owner}`),
    ),
    element("div", { class: "piece-card-row" }, movementDiagram(piece, style), element("p", {}, info.movePt)),
  );

  if (piece.promoted) {
    const base = pieceInfo({ type: piece.type, promoted: false });
    card.append(element("p", { class: "piece-card-note" }, `Peça promovida. Se for capturada, volta para a mão de quem capturou como ${base.namePt} normal.`));
  } else if (variant.promotable.includes(piece.type)) {
    const promoted = { ...piece, promoted: true };
    const mandatory = variant.immobileRanks[piece.type];
    const rule = mandatory
      ? ` A promoção é obrigatória ${mandatory === 1 ? "na última fileira" : `nas ${mandatory} últimas fileiras`}, onde ela ficaria sem jogadas.`
      : "";
    card.append(
      element("h3", {}, `Promovida: ${pieceInfo(promoted).namePt}`),
      element("div", { class: "piece-card-row" }, movementDiagram(promoted, style), element("p", {}, `${pieceInfo(promoted).movePt}${rule}`)),
    );
  } else {
    card.append(element("p", { class: "piece-card-note" }, piece.type === "K" ? "O rei não promove." : `${info.namePt} não promove.`));
  }
  return card;
}
