import type { Piece, UsiMove } from "../core/types";
import { element, showDialog } from "./dialogs";
import { renderPiece, type PieceLook } from "./pieceView";

/** Asks whether to promote `piece`; resolves with the chosen move, or null if dismissed. */
export function askPromotion(piece: Piece, look: PieceLook, promote: UsiMove, stay: UsiMove): Promise<UsiMove | null> {
  const option = (promoted: boolean, label: string) => {
    const box = element("div", { class: "promotion-option" });
    box.append(renderPiece({ ...piece, promoted }, look, false), element("span", {}, label));
    return box;
  };
  const body = element("div", { class: "promotion-choice" }, option(true, "Promover"), option(false, "Não promover"));
  return showDialog<UsiMove | null>({
    title: "Promover a peça?",
    body,
    actions: [
      { label: "Não promover", value: stay },
      { label: "Promover", value: promote, kind: "primary" },
    ],
    dismissValue: null,
  });
}
