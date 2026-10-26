import { attackersOf, attacksFrom, forEachPiece } from "../core/attacks";
import { applyMove } from "../core/explain";
import type { GameBackend } from "../core/GameBackend";
import { formatSquare, parseUsiMove } from "../core/notation";
import { pieceInfo, withArticle } from "../core/pieces";
import { findKing, pieceAt } from "../core/position";
import { opposite, type Color, type Piece, type Square } from "../core/types";

/**
 * The coach of the guided game: short tips at the moments a beginner needs them (the first
 * capture, a chance to promote, a fork on the board…). Each tip shows once per game.
 */

export interface CoachTip {
  id: string;
  title: string;
  text: string;
  /** Squares to highlight on the board. */
  squares: Square[];
}

/** Rough piece values for a beginner (the table taught in the "values" lesson). */
const VALUE: Record<string, number> = { P: 1, L: 3, N: 4, S: 5, G: 6, B: 8, R: 10, K: 100 };
const PROMOTED_VALUE: Record<string, number> = { P: 6, L: 6, N: 6, S: 6, B: 10, R: 12 };

export function pieceValue(piece: Pick<Piece, "type" | "promoted">): number {
  return (piece.promoted ? PROMOTED_VALUE[piece.type] : VALUE[piece.type]) ?? 1;
}

/** The tip to show now, for the player `human` whose turn it is; null when nothing new is worth saying. */
export function coachTip(backend: GameBackend, human: Color, seen: ReadonlySet<string>): CoachTip | null {
  if (backend.result().over || backend.sideToMove() !== human) return null;
  const finders = [checkTip, forkTip, hangingTip, openingTip, handTip, promotionTip, sittingKingTip];
  for (const find of finders) {
    const tip = find(backend, human);
    if (tip && !seen.has(tip.id)) return tip;
  }
  return null;
}

function checkTip(backend: GameBackend): CoachTip | null {
  if (!backend.isCheck()) return null;
  return {
    id: "check",
    title: "Xeque! (王手, ōte)",
    text: "Seu Rei está atacado. Lembre as três saídas: fugir com o Rei, capturar a peça que ataca ou colocar uma peça no caminho (合駒, aigoma). As peças que atacam estão marcadas.",
    squares: [],
  };
}

function openingTip(backend: GameBackend, human: Color): CoachTip | null {
  if (backend.history().length > 1) return null;
  const black = human === "black";
  return {
    id: "opening",
    title: "Primeiro lance",
    text: black
      ? "Comece abrindo a diagonal do Bispo (Peão 7g→7f) ou avançando o Peão da Torre (2g→2f). Depois tire o Rei do centro e monte um castelo (囲い, kakoi)."
      : "Você é Gote: abra a diagonal do Bispo (Peão 3c→3d) ou avance o Peão da Torre (8c→8d). Depois tire o Rei do centro e monte um castelo (囲い, kakoi).",
    squares: black ? [{ file: 7, rank: 7 }, { file: 2, rank: 7 }] : [{ file: 3, rank: 3 }, { file: 8, rank: 3 }],
  };
}

function handTip(backend: GameBackend, human: Color): CoachTip | null {
  const types = Object.keys(backend.hand(human)).filter((type) => backend.hand(human)[type] > 0);
  if (types.length === 0) return null;
  const piece = withArticle({ type: types[0], promoted: false });
  return {
    id: "hand",
    title: "Uma peça na mão (持ち駒, mochigoma)",
    text: `Você tem ${piece} na mão. Em vez de mover, você pode colocá-la (打つ, utsu) em qualquer casa vazia: toque nela e depois na casa. Guarde-a para um ataque duplo ou para defender.`,
    squares: [],
  };
}

/** A promotion on a square the opponent does not attack (promoting into a recapture is no tip). */
function promotionTip(backend: GameBackend, human: Color): CoachTip | null {
  const position = backend.position();
  const dims = backend.variant.dims;
  const move = backend.legalMoves().find((m) => {
    if (!m.endsWith("+")) return false;
    const parsed = parseUsiMove(m)!;
    return attackersOf(applyMove(position, parsed, human, dims), parsed.to, opposite(human), dims).length === 0;
  });
  if (!move) return null;
  const parsed = parseUsiMove(move)!;
  const piece = backend.pieceAt(parsed.from!)!;
  return {
    id: "promotion",
    title: "Chance de promover (成る, naru)",
    text: `${capitalize(withArticle(piece))} em ${formatSquare(parsed.from!)} pode entrar no campo inimigo e promover. Promover quase sempre vale a pena: ${pieceInfo({ ...piece, promoted: true }).movePt.toLowerCase()}`,
    squares: [parsed.from!, parsed.to],
  };
}

function sittingKingTip(backend: GameBackend, human: Color): CoachTip | null {
  if (backend.history().length < 16) return null;
  const king = findKing(backend.position(), human, backend.variant.dims);
  const home = human === "black" ? { file: 5, rank: 9 } : { file: 5, rank: 1 };
  if (!king || king.file !== home.file || king.rank !== home.rank) return null;
  return {
    id: "sitting-king",
    title: "Rei parado (居玉, igyoku)",
    text: "O seu Rei ainda está na casa inicial, no meio da luta. O provérbio diz igyoku wa sakeyo (居玉は避けよ): leve-o para o lado oposto ao da Torre e cerque-o com Ouros e Pratas.",
    squares: [king],
  };
}

/** A piece of the player that the opponent attacks and nobody defends. */
function hangingTip(backend: GameBackend, human: Color): CoachTip | null {
  const position = backend.position();
  const dims = backend.variant.dims;
  let found: { square: Square; piece: Piece } | null = null;
  forEachPiece(position, dims, (square, piece) => {
    if (found || piece.color !== human || piece.type === "K" || pieceValue(piece) < 3) return;
    if (attackersOf(position, square, opposite(human), dims).length === 0) return;
    if (attackersOf(position, square, human, dims).length > 0) return;
    found = { square, piece };
  });
  if (!found) return null;
  const { square, piece } = found as { square: Square; piece: Piece };
  return {
    id: "hanging",
    title: "Peça sem defesa",
    text: `${capitalize(withArticle(piece))} em ${formatSquare(square)} está sob ataque e sem defesa. Tire a peça de lá ou proteja-a: lembre que a peça capturada vira arma do adversário.`,
    squares: [square],
  };
}

/** A move that attacks two valuable enemy pieces (or the king and a piece) from a safe square. */
function forkTip(backend: GameBackend, human: Color): CoachTip | null {
  const position = backend.position();
  const dims = backend.variant.dims;
  const enemy = opposite(human);
  for (const move of backend.legalMoves()) {
    const parsed = parseUsiMove(move)!;
    const mover = parsed.drop ? null : pieceAt(position, parsed.from!, dims);
    if (mover?.type === "K") continue;
    const after = applyMove(position, parsed, human, dims);
    const piece = pieceAt(after, parsed.to, dims)!;
    if (attackersOf(after, parsed.to, enemy, dims).length > 0) continue;
    const targets = attacksFrom(after, parsed.to, piece, dims).filter((square) => {
      const target = pieceAt(after, square, dims);
      return target?.color === enemy && pieceValue(target) >= 5;
    });
    if (targets.length < 2) continue;
    const names = targets.map((square) => withArticle(pieceAt(after, square, dims)!)).join(" e ");
    return {
      id: "fork",
      title: "Ataque duplo! (両取り, ryōtori)",
      text: `Há um lance que ataca ${names} ao mesmo tempo, de uma casa onde ninguém pode capturar a sua peça. Procure-o: as casas marcadas mostram as peças atacadas.`,
      squares: targets,
    };
  }
  return null;
}

function capitalize(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1);
}
