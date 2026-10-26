import type { IllegalReason } from "../core/explain";
import type { GameBackend } from "../core/GameBackend";
import { parseUsiMove } from "../core/notation";
import type { Square, UsiMove } from "../core/types";
import { squares } from "./board";
import type { Accept, ExerciseStep, Goal, Lesson, Step } from "./types";

export interface Feedback {
  kind: "info" | "success" | "error";
  text: string;
}

/** Exercises where the opponent stands still: after each move the turn comes back to Sente. */
const STILL_GOALS: readonly Goal["type"][] = ["reach", "capture", "formation", "free"];

const accepted = (accept: Accept): readonly UsiMove[] => (accept === "*" ? [] : typeof accept === "string" ? [accept] : accept);
const accepts = (accept: Accept, move: UsiMove): boolean => accept === "*" || accepted(accept).includes(move);

/** Stars for one exercise: 3 when solved cleanly, fewer with extra moves, mistakes or hints. */
export function exerciseStars(goal: Goal, moves: number, mistakes: number, hinted: boolean): number {
  let stars: number;
  if (goal.type === "reach" || goal.type === "capture" || goal.type === "formation") {
    const extra = moves - goal.solution.length;
    stars = extra <= 0 ? 3 : extra <= 2 ? 2 : 1;
  } else {
    stars = 3 - mistakes;
  }
  if (hinted) stars--;
  return Math.max(1, Math.min(3, stars));
}

/**
 * One lesson being played: which step is showing, the position, the goal and how the learner
 * is doing. No DOM: the UI renders from this state and forwards the learner's moves here.
 * The learner always plays Sente.
 */
export class LessonSession {
  stepIndex = 0;
  feedback: Feedback | null = null;
  /** The current exercise is solved (or the step is not an exercise). */
  solved = false;
  /** The lesson is over; `score` holds its stars (1-3), or 0 if exercises were skipped. */
  finished = false;
  score = 0;
  /** The opponent is about to answer (scripted reply). */
  replying = false;
  lastMove: UsiMove | null = null;
  /** Stars still to walk over. */
  private starSquares: Square[] = [];
  /** Squares highlighted by the last hint. */
  hintSquares: Square[] = [];
  private played: UsiMove[] = [];
  private lineIndex = 0;
  private mistakes = 0;
  private hinted = false;
  /** Stars of each solved exercise, by step index. */
  private results = new Map<number, number>();
  /** Bumped on every step change, so a late scripted reply cannot land in another step. */
  private stepToken = 0;

  constructor(
    readonly backend: GameBackend,
    readonly lesson: Lesson,
    private readonly onChange: () => void,
    /** Runs the opponent's scripted reply; the default waits a little so the learner sees it. */
    private readonly schedule: (reply: () => void) => void = (reply) => setTimeout(reply, 650),
  ) {
    this.loadStep(0);
  }

  get step(): Step {
    return this.lesson.steps[this.stepIndex];
  }

  get exercise(): ExerciseStep | null {
    return this.step.kind === "exercise" ? this.step : null;
  }

  get isLast(): boolean {
    return this.stepIndex === this.lesson.steps.length - 1;
  }

  /** Squares the current step talks about. */
  get focus(): Square[] {
    return squares(this.step.focus);
  }

  /** Stars left on the board in a "reach" exercise. */
  get remainingStars(): Square[] {
    return this.starSquares;
  }

  /** True when the learner may move a piece now. */
  canMove(): boolean {
    const exercise = this.exercise;
    if (!exercise || this.replying || this.backend.sideToMove() !== "black" || this.backend.result().over) return false;
    return exercise.goal.type === "free" || !this.solved;
  }

  legalMoves(): UsiMove[] {
    return this.canMove() ? this.backend.legalMoves() : [];
  }

  /** The step can be left: info steps, free play and solved exercises. */
  canContinue(): boolean {
    return !this.exercise || this.solved;
  }

  // ---------------------------------------------------------------- navigation

  next(): void {
    if (!this.canContinue()) return;
    if (this.exercise && this.exercise.goal.type !== "free") this.results.set(this.stepIndex, exerciseStars(this.exercise.goal, this.played.length, this.mistakes, this.hinted));
    if (this.isLast) {
      this.finished = true;
      this.score = this.lessonScore();
      this.onChange();
      return;
    }
    this.loadStep(this.stepIndex + 1);
    this.onChange();
  }

  previous(): void {
    // Going back forgets the result of the step we return to, so it counts again when redone.
    if (this.stepIndex > 0) this.goTo(this.stepIndex - 1);
  }

  /** Jumps to a step (the step dots in the UI); results of the steps from there on are forgotten. */
  goTo(index: number): void {
    if (index < 0 || index >= this.lesson.steps.length) return;
    for (const step of [...this.results.keys()]) if (step >= index) this.results.delete(step);
    this.finished = false;
    this.loadStep(index);
    this.onChange();
  }

  /** Average stars of the exercises, or 0 when some exercise was skipped. */
  private lessonScore(): number {
    const exercises = this.lesson.steps.flatMap((step, i) => (step.kind === "exercise" && step.goal.type !== "free" ? [i] : []));
    if (exercises.some((i) => !this.results.has(i))) return 0;
    if (exercises.length === 0) return 3;
    return Math.round(exercises.reduce((sum, i) => sum + this.results.get(i)!, 0) / exercises.length);
  }

  restartStep(): void {
    this.loadStep(this.stepIndex);
    this.onChange();
  }

  private loadStep(index: number): void {
    this.stepToken++;
    this.stepIndex = index;
    const step = this.step;
    this.feedback = null;
    this.solved = step.kind === "info" || (step.kind === "exercise" && step.goal.type === "free");
    this.replying = false;
    this.lastMove = null;
    this.played = [];
    this.lineIndex = 0;
    this.mistakes = 0;
    this.hinted = false;
    this.hintSquares = [];
    this.starSquares = step.kind === "exercise" && step.goal.type === "reach" ? squares(step.goal.stars) : [];
    const sfen = step.sfen ?? this.previousSfen(index);
    if (sfen) this.backend.load(sfen);
    else if (index === 0) this.backend.load();
  }

  /** Info steps without their own board keep showing the position of the step before. */
  private previousSfen(index: number): string | undefined {
    for (let i = index - 1; i >= 0; i--) {
      const sfen = this.lesson.steps[i].sfen;
      if (sfen) return sfen;
    }
    return undefined;
  }

  // ---------------------------------------------------------------- moves

  /** The learner plays a legal move. */
  play(move: UsiMove): void {
    const exercise = this.exercise;
    if (!exercise || !this.canMove() || !this.backend.isLegal(move)) return;
    this.hintSquares = [];
    const goal = exercise.goal;
    if (STILL_GOALS.includes(goal.type)) this.playStill(exercise, move);
    else if (goal.type === "line") this.playLine(exercise, goal, move);
    else if (goal.type === "mate") this.playMate(exercise, move);
    else if (goal.type === "illegal") {
      this.feedback = { kind: "info", text: "Esse lance é permitido. Tente o lance proibido que o texto descreve." };
    }
    this.onChange();
  }

  /**
   * The learner tried an illegal move. In an "illegal" exercise trying the forbidden kind of move
   * is the goal; returns true when that solved it (the UI then shows the rule).
   */
  attemptIllegal(reason: IllegalReason): boolean {
    const exercise = this.exercise;
    if (!exercise || exercise.goal.type !== "illegal" || this.solved || reason.code !== exercise.goal.code) return false;
    this.solve(exercise);
    this.onChange();
    return true;
  }

  private playStill(exercise: ExerciseStep, move: UsiMove): void {
    const goal = exercise.goal;
    this.backend.push(move);
    if (this.backend.isCheck()) {
      this.backend.undo();
      this.feedback = { kind: "error", text: "Aqui o rei adversário fica de fora: escolha um lance que não dê xeque." };
      return;
    }
    // The opponent "passes": the same position with Sente to move again.
    const parts = this.backend.toSfen().split(" ");
    parts[1] = "b";
    this.backend.load(parts.join(" "));
    this.lastMove = move;
    this.played.push(move);
    this.feedback = null;
    const to = parseUsiMove(move)!.to;
    if (goal.type === "reach") {
      this.starSquares = this.starSquares.filter((s) => s.file !== to.file || s.rank !== to.rank);
      if (this.starSquares.length === 0) this.solve(exercise);
    } else if (goal.type === "capture") {
      if (!this.enemyPiecesLeft()) this.solve(exercise);
    } else if (goal.type === "formation") {
      if (this.formationDone(goal.pieces)) this.solve(exercise);
    }
  }

  private enemyPiecesLeft(): boolean {
    return this.backend.position().board.flat().some((p) => p && p.color === "white" && p.type !== "K");
  }

  private formationDone(pieces: Record<string, string>): boolean {
    return squares(Object.keys(pieces)).every((square, i) => {
      const code = Object.values(pieces)[i];
      const piece = this.backend.pieceAt(square);
      return piece?.color === "black" && piece.type === code.replace("+", "") && piece.promoted === code.startsWith("+");
    });
  }

  private playLine(exercise: ExerciseStep, goal: Extract<Goal, { type: "line" }>, move: UsiMove): void {
    if (goal.mate && this.mates(move)) {
      this.backend.push(move);
      this.lastMove = move;
      this.played.push(move);
      this.solve(exercise);
      return;
    }
    if (!accepts(goal.line[this.lineIndex], move)) return this.miss(exercise, move);
    this.backend.push(move);
    this.lastMove = move;
    this.played.push(move);
    this.lineIndex++;
    if (this.lineIndex >= goal.line.length) return this.solve(exercise);
    this.feedback = { kind: "info", text: "Boa! Veja a resposta do adversário…" };
    this.replying = true;
    const token = this.stepToken;
    this.schedule(() => {
      if (token !== this.stepToken) return;
      const reply = accepted(goal.line[this.lineIndex])[0];
      this.replying = false;
      this.backend.push(reply);
      this.lastMove = reply;
      this.lineIndex++;
      this.feedback = { kind: "info", text: "Sua vez." };
      if (this.lineIndex >= goal.line.length) this.solve(exercise);
      this.onChange();
    });
  }

  private playMate(exercise: ExerciseStep, move: UsiMove): void {
    if (!this.mates(move)) return this.miss(exercise, move);
    this.backend.push(move);
    this.lastMove = move;
    this.played.push(move);
    this.solve(exercise);
  }

  private mates(move: UsiMove): boolean {
    this.backend.push(move);
    const result = this.backend.result();
    this.backend.undo();
    return result.over && result.reason === "checkmate" && result.winner === "black";
  }

  private miss(exercise: ExerciseStep, move: UsiMove): void {
    this.mistakes++;
    let text = exercise.wrong?.[move];
    if (!text) {
      this.backend.push(move);
      const check = this.backend.isCheck();
      this.backend.undo();
      text = exercise.goal.type === "mate"
        ? check
          ? "É xeque, mas o rei ainda tem saída. Procure outro lance."
          : "Esse lance não dá xeque-mate. Procure outro."
        : "Não é esse o lance. Pense no que o texto explicou e tente de novo.";
    }
    this.feedback = { kind: "error", text };
  }

  private solve(exercise: ExerciseStep): void {
    this.solved = true;
    this.replying = false;
    this.feedback = { kind: "success", text: exercise.success };
  }

  // ---------------------------------------------------------------- help

  /** Shows where the next move of the solution goes (when the learner is still on its path). */
  hint(): void {
    const exercise = this.exercise;
    if (!exercise || this.solved) return;
    this.hinted = true;
    const move = this.nextSolutionMove(exercise.goal);
    const parsed = move ? parseUsiMove(move) : null;
    this.hintSquares = parsed ? [...(parsed.from ? [parsed.from] : []), parsed.to] : [];
    const where = parsed?.drop ? " A casa destacada é onde a peça da mão deve entrar." : parsed ? " Veja as casas destacadas: de onde sai e para onde vai." : "";
    this.feedback = { kind: "info", text: `${exercise.hint}${where}` };
    this.onChange();
  }

  private nextSolutionMove(goal: Goal): UsiMove | null {
    switch (goal.type) {
      case "reach":
      case "capture":
      case "formation": {
        const onPath = this.played.every((move, i) => goal.solution[i] === move);
        return onPath ? (goal.solution[this.played.length] ?? null) : null;
      }
      case "line":
        return accepted(goal.line[this.lineIndex])[0] ?? null;
      case "mate":
      case "illegal":
        return goal.solution;
      case "free":
        return null;
    }
  }
}
