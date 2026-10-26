import { pieceInfo } from "../core/pieces";
import type { Piece } from "../core/types";
import { element } from "./dialogs";
import { sideName } from "./text";

/** Press and hold a piece (mouse or touch) to see its Portuguese name while holding. */
export class PressHold {
  /** When a press-and-hold last showed a piece's name, so its release does not also count as a click. */
  private endedAt = 0;
  private tooltip: HTMLElement | null = null;

  attach(target: HTMLElement, piece: Piece): void {
    let timer = 0;
    let start = { x: 0, y: 0 };
    const cancel = (): void => {
      window.clearTimeout(timer);
      timer = 0;
    };
    target.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      start = { x: event.clientX, y: event.clientY };
      cancel();
      timer = window.setTimeout(() => {
        timer = 0;
        this.show(target, piece);
      }, 450);
    });
    target.addEventListener("pointermove", (event) => {
      if (Math.hypot(event.clientX - start.x, event.clientY - start.y) > 10) cancel();
    });
    for (const type of ["pointerup", "pointercancel", "pointerleave"]) target.addEventListener(type, cancel);
    // Long presses on phones would otherwise open the system menu.
    target.addEventListener("contextmenu", (event) => event.preventDefault());
  }

  /**
   * True (once) if the click that is arriving is the release of a press-and-hold. Some phones
   * send no click after a long press, so the mark expires quickly instead of waiting for one.
   */
  consume(): boolean {
    const recent = Date.now() - this.endedAt < 400;
    this.endedAt = 0;
    return recent;
  }

  private show(target: HTMLElement, piece: Piece): void {
    this.hide();
    const info = pieceInfo(piece);
    const rect = target.getBoundingClientRect();
    const tooltip = element(
      "div",
      { class: "piece-tooltip", role: "tooltip" },
      info.namePt,
      element("small", {}, `${info.romaji} · ${info.kanjiName} · ${sideName(piece.color)}`),
    );
    tooltip.style.left = `${Math.min(Math.max(rect.left + rect.width / 2, 90), window.innerWidth - 90)}px`;
    tooltip.style.top = `${Math.max(rect.top, 60)}px`;
    document.body.append(tooltip);
    this.tooltip = tooltip;
    const hide = (): void => {
      this.endedAt = Date.now();
      this.hide();
      window.removeEventListener("pointerup", hide);
      window.removeEventListener("pointercancel", hide);
    };
    window.addEventListener("pointerup", hide);
    window.addEventListener("pointercancel", hide);
  }

  private hide(): void {
    this.tooltip?.remove();
    this.tooltip = null;
  }
}
