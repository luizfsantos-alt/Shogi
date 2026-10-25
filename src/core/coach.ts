import { attackersOf } from "./attacks";
import type { GameBackend } from "./GameBackend";
import { parseUsiMove } from "./notation";
import { withArticle } from "./pieces";
import { findKing, pieceAt } from "./position";
import { opposite, type Square, type UsiMove } from "./types";

/** Short explanations that help a beginner: how to get out of check, what a move does. */

export interface CheckHelp {
  king: Square;
  attackers: Square[];
  kingMoves: UsiMove[];
  captures: UsiMove[];
  blocks: UsiMove[];
}

/** Ways out of the current check, grouped the way a teacher would explain them. */
export function checkHelp(backend: GameBackend): CheckHelp | null {
  if (!backend.isCheck()) return null;
  const position = backend.position();
  const dims = backend.variant.dims;
  const side = backend.sideToMove();
  const king = findKing(position, side, dims)!;
  const attackers = attackersOf(position, king, opposite(side), dims);
  const help: CheckHelp = { king, attackers, kingMoves: [], captures: [], blocks: [] };
  for (const move of backend.legalMoves()) {
    const parsed = parseUsiMove(move)!;
    if (parsed.from && parsed.from.file === king.file && parsed.from.rank === king.rank) help.kingMoves.push(move);
    else if (attackers.some((a) => a.file === parsed.to.file && a.rank === parsed.to.rank)) help.captures.push(move);
    else help.blocks.push(move);
  }
  return help;
}

export function describeCheckHelp(help: CheckHelp, backend: GameBackend): string {
  const position = backend.position();
  const dims = backend.variant.dims;
  const who = help.attackers.map((s) => withArticle(pieceAt(position, s, dims)!)).join(" e ");
  const ways: string[] = [];
  if (help.kingMoves.length) ways.push("mover o rei para uma casa segura");
  if (help.captures.length) ways.push(`capturar ${help.attackers.length > 1 ? "uma das peças que atacam" : who}`);
  if (help.blocks.length) ways.push("colocar uma peça no caminho (do tabuleiro ou da mão)");
  return `Seu rei está em xeque! Quem ataca: ${who}. Para sair: ${ways.join("; ou ")}.`;
}

/**
 * Plain-language facts about a legal move, e.g. ["captura a Torre", "dá xeque"].
 * Plays the move on the backend and takes it back.
 */
export function describeMove(backend: GameBackend, move: UsiMove): string[] {
  const parsed = parseUsiMove(move);
  if (!parsed || !backend.isLegal(move)) return [];
  const position = backend.position();
  const dims = backend.variant.dims;
  const side = backend.sideToMove();
  const facts: string[] = [];
  const wasInCheck = backend.isCheck();

  if (parsed.drop) {
    facts.push(`coloca ${withArticle({ type: parsed.drop, promoted: false })} da mão no tabuleiro`);
  } else {
    const moving = pieceAt(position, parsed.from!, dims)!;
    const captured = pieceAt(position, parsed.to, dims);
    if (captured) facts.push(`captura ${withArticle(captured)} (a peça vai para a sua mão)`);
    if (parsed.promote) facts.push(`promove ${withArticle(moving)}`);
    const threatened = attackersOf(position, parsed.from!, opposite(side), dims).length > 0;
    if (!wasInCheck && !captured && threatened && moving.type !== "P") facts.push(`tira ${withArticle(moving)} de um ataque`);
  }
  if (wasInCheck) facts.push("tira o seu rei do xeque");

  backend.push(move);
  const result = backend.result();
  if (result.over && result.reason === "checkmate") facts.push("dá xeque-mate!");
  else if (backend.isCheck()) facts.push("dá xeque");
  backend.undo();

  return facts;
}
