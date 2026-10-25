import type { Engine } from "../ai/Engine";
import { getLevel, HINT_LEVEL } from "../ai/levels";
import { describeMove } from "../core/coach";
import type { GameBackend } from "../core/GameBackend";
import { formatWesternMove } from "../core/kifu";
import { opposite, type Color, type UsiMove } from "../core/types";

export type GameMode = "ai" | "local";

export interface GameSettings {
  mode: GameMode;
  /** The human's side when playing against the computer. */
  humanColor: Color;
  level: number;
}

/** Everything needed to restore a game (saved to localStorage). */
export interface SavedGame {
  variant: string;
  initialSfen: string;
  moves: UsiMove[];
  settings: GameSettings;
  resigned?: Color;
  impasseDeclared?: boolean;
  savedAt: string;
}

export interface Hint {
  move: UsiMove;
  notation: string;
  /** Plain-language facts about the move ("captura a Torre", "dá xeque"…). */
  facts: string[];
}

export const DEFAULT_SETTINGS: GameSettings = { mode: "ai", humanColor: "black", level: 2 };

/**
 * One game being played: the rules backend plus turn handling, the computer's moves,
 * undo and the move list. No DOM here; the UI renders from this state and calls these methods.
 */
export class GameSession {
  settings: GameSettings = { ...DEFAULT_SETTINGS };
  /** Readable notation of each move in history order. */
  notations: string[] = [];
  thinking = false;
  engineError: string | null = null;
  hint: Hint | null = null;
  hintPending = false;
  private aiTurnId = 0;
  private hintId = 0;

  constructor(
    readonly backend: GameBackend,
    private readonly engine: Engine | null,
    private readonly onChange: () => void,
  ) {}

  get engineAvailable(): boolean {
    return this.engine !== null && this.engineError === null;
  }

  newGame(settings: GameSettings, sfen?: string): void {
    this.cancelAi();
    this.settings = { ...settings };
    this.backend.load(sfen);
    this.notations = [];
    void this.engine?.newGame();
    this.afterChange();
  }

  /** Restores a game; throws (and leaves the current game intact) if the record is invalid. */
  restore(saved: Pick<SavedGame, "initialSfen" | "moves" | "settings" | "resigned" | "impasseDeclared">): void {
    this.cancelAi();
    this.backend.load(saved.initialSfen, saved.moves);
    this.settings = { ...saved.settings };
    this.rebuildNotations();
    if (saved.impasseDeclared) this.backend.declareImpasse();
    else if (saved.resigned) this.backend.resign(saved.resigned);
    this.afterChange();
  }

  toSaved(): SavedGame {
    const result = this.backend.result();
    const ended = result.over ? result : null;
    return {
      variant: this.backend.variant.id,
      initialSfen: this.backend.initialSfen(),
      moves: this.backend.history(),
      settings: { ...this.settings },
      resigned: ended?.reason === "resignation" && ended.winner !== "draw" ? opposite(ended.winner) : undefined,
      impasseDeclared: ended?.reason === "impasse" || undefined,
      savedAt: new Date().toISOString(),
    };
  }

  isComputer(color: Color): boolean {
    return this.settings.mode === "ai" && color !== this.settings.humanColor;
  }

  /** True when a person may move now. */
  canHumanMove(): boolean {
    return !this.backend.result().over && !this.isComputer(this.backend.sideToMove());
  }

  play(move: UsiMove): void {
    if (!this.canHumanMove()) throw new Error("It is not the player's turn");
    this.pushWithNotation(move);
    this.afterChange();
  }

  /**
   * Against the computer, takes back the computer's reply and the player's move, so that it is
   * the player's turn again. A resignation or impasse declaration is undone first, on its own.
   */
  undo(): void {
    this.cancelAi();
    const result = this.backend.result();
    if (result.over && (result.reason === "resignation" || result.reason === "impasse")) this.backend.undo();
    else this.undoOne();
    while (this.isComputer(this.backend.sideToMove()) && this.undoOne());
    this.afterChange();
  }

  canUndo(): boolean {
    return this.backend.history().length > 0 || this.backend.result().over;
  }

  /** The player resigns (in a local game, the side to move resigns). */
  resign(): void {
    this.cancelAi();
    const color = this.settings.mode === "ai" ? this.settings.humanColor : this.backend.sideToMove();
    this.backend.resign(color);
    this.afterChange();
  }

  declareImpasse(): void {
    this.backend.declareImpasse();
    this.afterChange();
  }

  /** Asks the engine for a good move for the player and explains it. */
  async requestHint(): Promise<void> {
    if (!this.engineAvailable || !this.canHumanMove() || this.hintPending) return;
    const id = ++this.hintId;
    this.hintPending = true;
    this.hint = null;
    this.onChange();
    const request = { initialSfen: this.backend.initialSfen(), moves: this.backend.history() };
    const move = await this.engine!.bestMove(request, HINT_LEVEL).catch(() => null);
    if (id !== this.hintId) return;
    this.hintPending = false;
    if (move && this.backend.isLegal(move)) {
      const position = this.backend.position();
      const notation = formatWesternMove(position, this.backend.legalMoves(), move, this.backend.variant.dims);
      this.hint = { move, notation, facts: describeMove(this.backend, move) };
    }
    this.onChange();
  }

  lastMove(): UsiMove | null {
    return this.backend.history().at(-1) ?? null;
  }

  dispose(): void {
    this.cancelAi();
  }

  // ---------------------------------------------------------------- internals

  private undoOne(): boolean {
    if (this.backend.undo() === null) return false;
    this.notations.pop();
    return true;
  }

  private pushWithNotation(move: UsiMove): void {
    const position = this.backend.position();
    const legal = this.backend.legalMoves();
    this.backend.push(move);
    this.notations.push(formatWesternMove(position, legal, move, this.backend.variant.dims));
  }

  private rebuildNotations(): void {
    const moves = this.backend.history();
    this.backend.load(this.backend.initialSfen());
    this.notations = [];
    for (const move of moves) this.pushWithNotation(move);
  }

  private afterChange(): void {
    this.cancelHint();
    this.onChange();
    this.maybeComputerTurn();
  }

  private cancelHint(): void {
    this.hint = null;
    if (!this.hintPending) return;
    this.hintPending = false;
    this.hintId++;
    this.engine?.stop();
  }

  private cancelAi(): void {
    this.aiTurnId++;
    if (this.thinking) this.engine?.stop();
    this.thinking = false;
  }

  private maybeComputerTurn(): void {
    const side = this.backend.sideToMove();
    if (this.thinking || this.backend.result().over || !this.isComputer(side) || !this.engineAvailable) return;
    if (this.backend.impasse()?.canDeclare) {
      this.backend.declareImpasse();
      this.onChange();
      return;
    }
    void this.computerMove();
  }

  private async computerMove(): Promise<void> {
    const turn = ++this.aiTurnId;
    this.thinking = true;
    this.onChange();
    try {
      const request = { initialSfen: this.backend.initialSfen(), moves: this.backend.history() };
      const move = await this.engine!.bestMove(request, getLevel(this.settings.level));
      if (turn !== this.aiTurnId) return;
      this.thinking = false;
      if (move && this.backend.isLegal(move)) this.pushWithNotation(move);
      else if (move) this.engineError = `O motor sugeriu uma jogada inválida (${move}).`;
    } catch (error) {
      if (turn !== this.aiTurnId) return;
      this.thinking = false;
      this.engineError = `Erro no motor: ${String(error)}`;
    }
    this.afterChange();
  }

  /** Reports a fatal engine problem (e.g. failed to load); the computer stops playing. */
  setEngineError(message: string): void {
    this.cancelAi();
    this.engineError = message;
    this.onChange();
  }
}
