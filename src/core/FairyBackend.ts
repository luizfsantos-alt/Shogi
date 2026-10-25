import type { Board, FairyStockfish } from "ffish-es6";
import { IllegalMoveError, type GameBackend } from "./GameBackend";
import { evaluateImpasse, type ImpasseEvaluation } from "./impasse";
import { fairyToUsi, parseUsiMove, usiToFairy } from "./notation";
import {
  findKing,
  formatSfen,
  fromFairyFen,
  parseSfen,
  pieceAt,
  SfenError,
  toFairyFen,
  type Position,
} from "./position";
import { DEFAULT_VARIANT, getVariant, type VariantDefinition } from "./variants";
import { opposite, type Color, type GameResult, type Hand, type Piece, type Square, type UsiMove } from "./types";

/** GameBackend implemented with ffish.js (Fairy-Stockfish compiled to WebAssembly). */
export class FairyBackend implements GameBackend {
  private board: Board | null = null;
  private startSfen = "";
  private startMoveNumber = 1;
  private moves: UsiMove[] = [];
  /** Endings Fairy-Stockfish does not know about: resignation and impasse declaration. */
  private manualResult: GameResult | null = null;
  private legalCache: UsiMove[] | null = null;
  private positionCache: Position | null = null;

  private constructor(
    private readonly ffish: FairyStockfish,
    readonly variant: VariantDefinition,
  ) {}

  static create(ffish: FairyStockfish, variantName = DEFAULT_VARIANT, sfen?: string, moves?: UsiMove[]): FairyBackend {
    const variant = getVariant(variantName);
    if (variant.ini) ffish.loadVariantConfig(variant.ini);
    const backend = new FairyBackend(ffish, variant);
    backend.load(sfen, moves);
    return backend;
  }

  // ---------------------------------------------------------------- loading

  load(sfen: string = this.variant.startSfen, moves: UsiMove[] = []): void {
    const previous = this.board ? { sfen: this.startSfen, moves: [...this.moves] } : null;
    const position = parseSfen(sfen, this.variant);
    this.assertSideNotToMoveIsSafe(position);
    this.replaceBoard(new this.ffish.Board(this.variant.id, toFairyFen(position, this.variant)));
    this.startSfen = formatSfen(position, this.variant);
    this.startMoveNumber = position.moveNumber;
    try {
      for (const move of moves) this.push(move);
    } catch (error) {
      if (previous) this.load(previous.sfen, previous.moves);
      throw error;
    }
  }

  private assertSideNotToMoveIsSafe(position: Position): void {
    const flipped = { ...position, sideToMove: opposite(position.sideToMove) };
    const probe = new this.ffish.Board(this.variant.id, toFairyFen(flipped, this.variant));
    const inCheck = probe.isCheck();
    probe.delete();
    if (inCheck) throw new SfenError("Posição impossível: o lado que acabou de jogar está em xeque.");
  }

  private replaceBoard(board: Board): void {
    this.board?.delete();
    this.board = board;
    this.moves = [];
    this.manualResult = null;
    this.invalidate();
  }

  private invalidate(): void {
    this.legalCache = null;
    this.positionCache = null;
  }

  private get b(): Board {
    if (!this.board) throw new Error("Backend has been disposed");
    return this.board;
  }

  dispose(): void {
    this.board?.delete();
    this.board = null;
  }

  // ---------------------------------------------------------------- moves

  sideToMove(): Color {
    // Fairy-Stockfish calls the first player "white"; turn() is true for it.
    return this.b.turn() ? "black" : "white";
  }

  legalMoves(): UsiMove[] {
    if (this.result().over) return [];
    this.legalCache ??= this.b
      .legalMoves()
      .split(" ")
      .filter((move) => move !== "")
      .map((move) => fairyToUsi(move, this.variant.dims))
      .filter((move) => !this.isPawnDropMate(move));
    return [...this.legalCache];
  }

  /**
   * Uchifuzume. Fairy-Stockfish generates the move and only scores it as a loss afterwards,
   * but the official rules forbid it. A dropped pawn can only check from the square right in
   * front of the enemy king, so at most one drop per position needs the (cheap) mate test.
   */
  private isPawnDropMate(move: UsiMove): boolean {
    if (!this.variant.pawnDropMateIllegal || !move.startsWith("P*")) return false;
    const target = parseUsiMove(move)!.to;
    const mover = this.sideToMove();
    const king = findKing(this.snapshot(), opposite(mover), this.variant.dims);
    const forward = mover === "black" ? -1 : 1;
    if (!king || king.file !== target.file || king.rank !== target.rank + forward) return false;
    this.b.push(usiToFairy(move, this.variant.dims));
    const mate = this.b.isCheck() && this.b.numberLegalMoves() === 0;
    this.b.pop();
    return mate;
  }

  isLegal(move: UsiMove): boolean {
    return this.legalMoves().includes(move);
  }

  push(move: UsiMove): void {
    if (!this.isLegal(move)) throw new IllegalMoveError(move);
    this.b.push(usiToFairy(move, this.variant.dims));
    this.moves.push(move);
    this.invalidate();
  }

  undo(): UsiMove | null {
    if (this.manualResult) {
      this.manualResult = null;
      return null;
    }
    const move = this.moves.pop();
    if (!move) return null;
    this.b.pop();
    this.invalidate();
    return move;
  }

  history(): UsiMove[] {
    return [...this.moves];
  }

  // ---------------------------------------------------------------- game state

  isCheck(): boolean {
    return this.b.isCheck();
  }

  result(): GameResult {
    if (this.manualResult) return this.manualResult;
    // claimDraw = true makes Fairy-Stockfish report sennichite (4-fold repetition);
    // with perpetual check it reports a win for the side being checked.
    const text = this.b.result(true);
    if (text === "*") return { over: false };
    const winner = text === "1-0" ? "black" : text === "0-1" ? "white" : "draw";
    if (this.b.numberLegalMoves() === 0) {
      return { over: true, winner, reason: this.b.isCheck() ? "checkmate" : "no-legal-moves" };
    }
    return { over: true, winner, reason: winner === "draw" ? "repetition" : "perpetual-check" };
  }

  resign(color: Color): void {
    if (this.result().over) throw new Error("The game is already over");
    this.manualResult = { over: true, winner: opposite(color), reason: "resignation" };
  }

  impasse(): ImpasseEvaluation | null {
    return evaluateImpasse(this.snapshot(), this.variant, this.sideToMove(), this.isCheck());
  }

  declareImpasse(): void {
    if (this.result().over) throw new Error("The game is already over");
    if (!this.impasse()?.canDeclare) throw new Error("Impasse declaration conditions are not met");
    this.manualResult = { over: true, winner: this.sideToMove(), reason: "impasse" };
  }

  // ---------------------------------------------------------------- position

  toSfen(): string {
    return formatSfen(this.position(), this.variant);
  }

  initialSfen(): string {
    return this.startSfen;
  }

  position(): Position {
    return structuredClone(this.snapshot());
  }

  pieceAt(square: Square): Piece | null {
    const piece = pieceAt(this.snapshot(), square, this.variant.dims);
    return piece ? { ...piece } : null;
  }

  hand(color: Color): Hand {
    return { ...this.snapshot().hands[color] };
  }

  private snapshot(): Position {
    this.positionCache ??= fromFairyFen(this.b.fen(), this.variant, this.startMoveNumber + this.moves.length);
    return this.positionCache;
  }
}
