import type { GameBackend } from "../src/core/GameBackend";
import type { UsiMove } from "../src/core/types";

function mated(game: GameBackend): boolean {
  const result = game.result();
  return result.over && result.reason === "checkmate";
}

/**
 * Moves of the side to move that force checkmate within `moves` of its own moves, giving
 * check every time (the tsume-shogi convention). Small positions only: it is a plain search.
 */
export function forcedMates(game: GameBackend, moves: number): UsiMove[] {
  return game.legalMoves().filter((move) => {
    game.push(move);
    try {
      if (!game.isCheck()) return false;
      if (mated(game)) return true;
      if (moves <= 1) return false;
      return game.legalMoves().every((reply) => {
        game.push(reply);
        try {
          return forcedMates(game, moves - 1).length > 0;
        } finally {
          game.undo();
        }
      });
    } finally {
      game.undo();
    }
  });
}
