import type { UsiMove } from "../core/types";
import type { LevelConfig } from "./levels";

/** The position to search: the game's starting SFEN plus every move played (needed for repetition rules). */
export interface SearchRequest {
  initialSfen: string;
  moves: readonly UsiMove[];
}

/**
 * An AI opponent. Kept independent of Fairy-Stockfish so another engine
 * (e.g. YaneuraOu) can be plugged in later.
 */
export interface Engine {
  /** Loads the engine; must resolve before the first search. */
  init(): Promise<void>;
  /** Clears the engine's memory between games. */
  newGame(): Promise<void>;
  /** Best move for the side to move, or null if the search was cancelled with stop(). */
  bestMove(request: SearchRequest, level: LevelConfig): Promise<UsiMove | null>;
  /** Cancels the current (and any queued) search. */
  stop(): void;
  dispose(): void;
}

/** Text channel to a UCI engine (a Web Worker in the browser, the module directly in tests). */
export interface EngineTransport {
  send(command: string): void;
  onLine(listener: (line: string) => void): void;
  terminate(): void;
}
