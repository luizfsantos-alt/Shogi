import type { ImpasseEvaluation } from "./impasse";
import type { Position } from "./position";
import type { VariantDefinition } from "./variants";
import type { Color, GameResult, Hand, Piece, Square, UsiMove } from "./types";

/**
 * Everything the UI and the AI need from the rules. The UI must only talk to this
 * interface, never to ffish directly, so the rules library can be swapped.
 *
 * All moves are in USI notation and all positions in SFEN.
 */
export interface GameBackend {
  readonly variant: VariantDefinition;

  sideToMove(): Color;
  /** Legal moves for the side to move; empty once the game is over. */
  legalMoves(): UsiMove[];
  isLegal(move: UsiMove): boolean;
  /** Plays a move. Throws IllegalMoveError if it is not legal. */
  push(move: UsiMove): void;
  /**
   * Takes back the last move and returns it. If the game ended by resignation or
   * declaration, the first undo only cancels that ending and returns null.
   */
  undo(): UsiMove | null;
  /** Moves played since the loaded position. */
  history(): UsiMove[];

  isCheck(): boolean;
  result(): GameResult;
  resign(color: Color): void;
  /** Entering-king (27-point) evaluation for the side to move, or null if the variant has no such rule. */
  impasse(): ImpasseEvaluation | null;
  /** Declares an entering-king win for the side to move. Throws if the conditions are not met. */
  declareImpasse(): void;

  toSfen(): string;
  /** SFEN of the position the current game started from. */
  initialSfen(): string;
  /** Loads a position (default: the variant start) and optionally replays USI moves on it. */
  load(sfen?: string, moves?: UsiMove[]): void;
  position(): Position;
  pieceAt(square: Square): Piece | null;
  hand(color: Color): Hand;

  /** Frees library resources. The backend cannot be used afterwards. */
  dispose(): void;
}

export class IllegalMoveError extends Error {
  override name = "IllegalMoveError";
  constructor(readonly move: UsiMove) {
    super(`Illegal move: ${move}`);
  }
}
