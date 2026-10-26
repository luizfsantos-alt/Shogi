import type { Color, EndReason, GameResult } from "../core/types";
import type { GameSettings } from "./session";

/** Portuguese texts shown to the player. */

export function sideName(color: Color): string {
  return color === "black" ? "Sente 先手 ☗" : "Gote 後手 ☖";
}

const REASONS: Record<EndReason, string> = {
  checkmate: "Xeque-mate.",
  "no-legal-moves": "Sem nenhuma jogada legal (no shogi isso é derrota).",
  repetition: "Sennichite (千日手): a mesma posição se repetiu 4 vezes. Empate.",
  "perpetual-check": "Xeque perpétuo: a posição se repetiu 4 vezes com xeques seguidos, e quem dava os xeques perde.",
  impasse: "Impasse declarado (jishōgi 持将棋, regra dos 27 pontos).",
  resignation: "Desistência.",
};

export function resultTitle(result: GameResult, settings: GameSettings): string {
  if (!result.over) return "";
  if (result.winner === "draw") return "Empate";
  if (settings.mode === "ai") return result.winner === settings.humanColor ? "Você venceu!" : "O computador venceu";
  return `${sideName(result.winner)} venceu`;
}

export function resultReason(result: GameResult): string {
  return result.over ? REASONS[result.reason] : "";
}

export function turnText(side: Color, settings: GameSettings, thinking: boolean): string {
  if (settings.mode === "ai") {
    if (side === settings.humanColor) return `Sua vez (${sideName(side)})`;
    return thinking ? "O computador está pensando…" : `Vez do computador (${sideName(side)})`;
  }
  return `Vez de ${sideName(side)}`;
}
