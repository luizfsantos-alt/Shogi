import { attackersOf, distanceToLastRank, inPromotionZone, reach } from "./attacks";
import type { GameBackend } from "./GameBackend";
import { formatSquare, parseUsiMove } from "./notation";
import { pieceInfo, withArticle } from "./pieces";
import { findKing, pieceAt, type Position } from "./position";
import type { VariantDefinition } from "./variants";
import { opposite, type BoardDims, type Color, type ParsedMove, type Piece, type Square, type UsiMove } from "./types";

/**
 * Explains WHY a move is illegal. Fairy-Stockfish only tells us "not in the legal move list",
 * so the rules are re-checked here one by one, in the order a player would think about them.
 */

export type IllegalReason =
  | { code: "legal" }
  | { code: "game-over" }
  | { code: "no-piece" }
  | { code: "not-your-piece"; piece: Piece }
  | { code: "not-in-hand"; type: string }
  | { code: "same-square" }
  | { code: "own-piece-on-target"; piece: Piece }
  | { code: "drop-on-occupied" }
  | { code: "cannot-move-like-that"; piece: Piece }
  | { code: "path-blocked"; piece: Piece }
  | { code: "dead-piece"; type: string; drop: boolean }
  | { code: "must-promote"; type: string }
  | { code: "cannot-promote"; piece: Piece }
  | { code: "promotion-outside-zone" }
  | { code: "nifu"; file: number }
  | { code: "uchifuzume" }
  | { code: "king-into-check"; attackers: Square[] }
  | { code: "still-in-check"; attackers: Square[] }
  | { code: "pinned"; attackers: Square[] }
  | { code: "unknown" };

export function explainMove(backend: GameBackend, move: UsiMove): IllegalReason {
  if (backend.result().over) return { code: "game-over" };
  if (backend.isLegal(move)) return { code: "legal" };
  const parsed = parseUsiMove(move);
  if (!parsed) return { code: "unknown" };
  const position = backend.position();
  const side = backend.sideToMove();
  const variant = backend.variant;
  const ruleProblem = parsed.drop
    ? dropProblem(position, parsed, side, variant)
    : boardMoveProblem(position, parsed, side, variant);
  if (ruleProblem) return ruleProblem;
  return kingSafetyProblem(position, parsed, side, variant) ?? uchifuzumeProblem(position, parsed, side, variant);
}

/** Explanation for a board move from `from` to `to`, trying the non-promoting move first. */
export function explainBoardMove(backend: GameBackend, from: Square, to: Square): IllegalReason {
  const plain = `${formatSquare(from)}${formatSquare(to)}`;
  if (backend.isLegal(plain) || backend.isLegal(`${plain}+`)) return { code: "legal" };
  return explainMove(backend, plain);
}

function dropProblem(position: Position, move: ParsedMove, side: Color, variant: VariantDefinition): IllegalReason | null {
  const type = move.drop!;
  const dims = variant.dims;
  if ((position.hands[side][type] ?? 0) === 0) return { code: "not-in-hand", type };
  if (pieceAt(position, move.to, dims)) return { code: "drop-on-occupied" };
  if (distanceToLastRank(move.to, side, dims) < (variant.immobileRanks[type] ?? 0)) {
    return { code: "dead-piece", type, drop: true };
  }
  if (type === "P" && variant.noDoubledPawns) {
    for (let rank = 1; rank <= dims.ranks; rank++) {
      const piece = pieceAt(position, { file: move.to.file, rank }, dims);
      if (piece?.type === "P" && !piece.promoted && piece.color === side) return { code: "nifu", file: move.to.file };
    }
  }
  return null;
}

function boardMoveProblem(position: Position, move: ParsedMove, side: Color, variant: VariantDefinition): IllegalReason | null {
  const dims = variant.dims;
  const from = move.from!;
  const piece = pieceAt(position, from, dims);
  if (!piece) return { code: "no-piece" };
  if (piece.color !== side) return { code: "not-your-piece", piece };
  if (from.file === move.to.file && from.rank === move.to.rank) return { code: "same-square" };
  const target = pieceAt(position, move.to, dims);
  if (target?.color === side) return { code: "own-piece-on-target", piece: target };
  const pathResult = reach(position, from, piece, move.to, dims);
  if (pathResult === "never") return { code: "cannot-move-like-that", piece };
  if (pathResult === "blocked") return { code: "path-blocked", piece };

  if (move.promote) {
    if (piece.promoted || !variant.promotable.includes(piece.type)) return { code: "cannot-promote", piece };
    if (!inPromotionZone(from, side, variant) && !inPromotionZone(move.to, side, variant)) {
      return { code: "promotion-outside-zone" };
    }
  } else if (!piece.promoted && distanceToLastRank(move.to, side, dims) < (variant.immobileRanks[piece.type] ?? 0)) {
    return { code: "must-promote", type: piece.type };
  }
  return null;
}

/** Plays a move on a copy of the position (no legality checks). */
export function applyMove(position: Position, move: ParsedMove, side: Color, dims: BoardDims): Position {
  const next = structuredClone(position);
  const cell = (s: Square) => ({ row: s.rank - 1, col: dims.files - s.file });
  const to = cell(move.to);
  if (move.drop) {
    next.hands[side][move.drop] -= 1;
    if (next.hands[side][move.drop] === 0) delete next.hands[side][move.drop];
    next.board[to.row][to.col] = { color: side, type: move.drop, promoted: false };
  } else {
    const from = cell(move.from!);
    const moving = next.board[from.row][from.col]!;
    const captured = next.board[to.row][to.col];
    if (captured) next.hands[side][captured.type] = (next.hands[side][captured.type] ?? 0) + 1;
    next.board[from.row][from.col] = null;
    next.board[to.row][to.col] = { ...moving, promoted: moving.promoted || move.promote };
  }
  next.sideToMove = opposite(side);
  next.moveNumber += 1;
  return next;
}

function kingSafetyProblem(position: Position, move: ParsedMove, side: Color, variant: VariantDefinition): IllegalReason | null {
  const dims = variant.dims;
  const after = applyMove(position, move, side, dims);
  const king = findKing(after, side, dims);
  if (!king) return null;
  const attackers = attackersOf(after, king, opposite(side), dims);
  if (attackers.length === 0) return null;

  const kingBefore = findKing(position, side, dims)!;
  const wasInCheck = attackersOf(position, kingBefore, opposite(side), dims).length > 0;
  const movingKing = move.from !== null && pieceAt(position, move.from, dims)?.type === "K";
  if (movingKing) return { code: "king-into-check", attackers };
  if (wasInCheck) return { code: "still-in-check", attackers };
  return { code: "pinned", attackers };
}

function uchifuzumeProblem(position: Position, move: ParsedMove, side: Color, variant: VariantDefinition): IllegalReason {
  if (move.drop !== "P" || !variant.pawnDropMateIllegal) return { code: "unknown" };
  const enemyKing = findKing(position, opposite(side), variant.dims);
  const forward = side === "black" ? -1 : 1;
  const givesCheck = enemyKing?.file === move.to.file && enemyKing.rank === move.to.rank + forward;
  // Every other rule passed, so the only remaining reason for a checking pawn drop is uchifuzume.
  return givesCheck ? { code: "uchifuzume" } : { code: "unknown" };
}

// ---------------------------------------------------------------- messages

function name(piece: Pick<Piece, "type" | "promoted">): string {
  return pieceInfo(piece).namePt;
}

function squares(list: Square[], position: Position, dims: BoardDims): string {
  return list.map((s) => `${pieceInfo(pieceAt(position, s, dims)!).namePt} em ${formatSquare(s)}`).join(", ");
}

/** Clear Portuguese message for a reason; `position` is the position before the move. */
export function describeIllegal(reason: IllegalReason, position: Position, variant: VariantDefinition): string {
  const dims = variant.dims;
  switch (reason.code) {
    case "legal":
      return "A jogada é legal.";
    case "game-over":
      return "A partida já terminou.";
    case "no-piece":
      return "Não há peça nessa casa.";
    case "not-your-piece":
      return `Essa peça (${name(reason.piece)}) é do adversário.`;
    case "not-in-hand":
      return `Você não tem ${name({ type: reason.type, promoted: false })} na mão.`;
    case "same-square":
      return "A peça já está nessa casa.";
    case "own-piece-on-target":
      return `Essa casa já tem uma peça sua (${name(reason.piece)}). Não dá para capturar a própria peça.`;
    case "drop-on-occupied":
      return "Peças da mão só podem ser colocadas em casas vazias.";
    case "cannot-move-like-that":
      return `${name(reason.piece)} não anda assim. ${pieceInfo(reason.piece).movePt}`;
    case "path-blocked":
      return `Há uma peça no caminho: ${name(reason.piece)} não pode pular peças.`;
    case "dead-piece":
      return reason.drop
        ? `Essa peça ficaria sem jogadas: não dá para colocar ${withArticle({ type: reason.type, promoted: false })} ${reason.type === "N" ? "nas duas últimas fileiras" : "na última fileira"}.`
        : "Essa peça ficaria sem jogadas.";
    case "must-promote":
      return `Você precisa promover: ${name({ type: reason.type, promoted: false })} ficaria sem jogadas nessa casa, então a promoção é obrigatória.`;
    case "cannot-promote":
      return reason.piece.promoted ? "Essa peça já está promovida." : `${name(reason.piece)} não pode ser promovido.`;
    case "promotion-outside-zone":
      return `Só dá para promover quando a peça entra, sai ou se move dentro das ${variant.promotionZoneRanks} últimas fileiras (o campo do adversário).`;
    case "nifu":
      return `Nifu: você já tem um peão (não promovido) na coluna ${reason.file}. Não pode haver dois peões seus na mesma coluna.`;
    case "uchifuzume":
      return "Uchifuzume: esse peão colocado da mão daria xeque-mate, e isso é proibido. (Dar mate movendo um peão do tabuleiro é permitido.)";
    case "king-into-check":
      // The attackers are still on the board before the move (the king cannot have captured them).
      return `O rei não pode ir para uma casa atacada (${squares(reason.attackers, position, dims)}).`;
    case "still-in-check":
      return "Seu rei está em xeque e essa jogada não resolve o xeque.";
    case "pinned":
      return "Isso deixaria seu rei em xeque: essa peça está cravada, protegendo o rei de um ataque.";
    case "unknown":
      return "Jogada ilegal.";
  }
}
