import type { IllegalReason } from "../core/explain";
import type { UsiMove } from "../core/types";

/**
 * The course is data: tracks hold lessons, lessons hold steps. The learner always plays
 * Sente (☗, at the bottom). Squares are written in USI ("5e"), moves in USI ("7g7f", "G*5b").
 */

export type TrackId = "basics" | "tactics" | "strategy" | "advanced";

export interface Track {
  id: TrackId;
  title: string;
  /** Japanese name with kanji, e.g. "Tesuji 手筋". */
  term?: string;
  description: string;
  /** The track continues the beginner course (A–C): the app shows it under "Avançado". */
  advanced?: boolean;
  /** Parts of a long track, in order; each lesson names its part. */
  parts?: TrackPart[];
  lessons: Lesson[];
}

export interface TrackPart {
  id: string;
  title: string;
  /** Japanese name with kanji. */
  term: string;
  description: string;
}

export interface Lesson {
  id: string;
  title: string;
  /** Japanese name of the concept with its kanji, e.g. "Ryōtori 両取り". */
  term?: string;
  /** One line for the course map. */
  summary: string;
  /** Id of the track part the lesson belongs to (tracks with parts only). */
  part?: string;
  steps: Step[];
  /** The lesson is a game against the computer with the coach's tips (it ends the course). */
  game?: boolean;
  /** Level of the computer in a game lesson (1-5); the weakest when absent. */
  level?: number;
}

interface StepBase {
  title: string;
  /** Paragraphs. Japanese terms always carry their kanji ("nifu (二歩)"). */
  text: string[];
  /** Position shown (SFEN); info steps without one show the previous step's board. */
  sfen?: string;
  /** Squares the text talks about. */
  focus?: string[];
  /** A piece to show in the side panel with its movement diagram ("R", "+P"…). */
  piece?: string;
}

/** Reading only: the learner presses "Continuar". */
export interface InfoStep extends StepBase {
  kind: "info";
}

export interface ExerciseStep extends StepBase {
  kind: "exercise";
  sfen: string;
  goal: Goal;
  /** Said when the learner asks for help. */
  hint: string;
  /** Said when the exercise is solved. */
  success: string;
  /** Feedback for tempting wrong moves. */
  wrong?: Record<UsiMove, string>;
  /** The tests check with Fairy-Stockfish that the first move of the solution is the best move. */
  engineCheck?: boolean;
}

export type Step = InfoStep | ExerciseStep;

/** A move the learner may play: one move, any of several equivalent ones, or "*" for any legal move. */
export type Accept = UsiMove | readonly UsiMove[];

export type Goal =
  /**
   * The opponent stands still; walk over every star. `solution` is a shortest way
   * (it sets the par for the stars and is checked by the tests).
   */
  | { type: "reach"; stars: string[]; solution: UsiMove[] }
  /** The opponent stands still; capture every enemy piece except the king. */
  | { type: "capture"; solution: UsiMove[] }
  /** The opponent stands still; put Sente's pieces on these squares ("8h": "K"). */
  | { type: "formation"; pieces: Record<string, string>; solution: UsiMove[] }
  /**
   * Moves alternate: the learner plays line[0], the opponent answers line[1], and so on.
   * With `mate`, any checkmating move also ends the exercise successfully.
   * `strong` lists, by index in `line`, moves as good as the one asked: they are praised but not
   * played (and not counted as mistakes), and the learner tries again the move of the lesson.
   */
  | { type: "line"; line: Accept[]; mate?: boolean; strong?: Record<number, Record<UsiMove, string>> }
  /** Find a checkmate (any mating move counts). */
  | { type: "mate"; solution: UsiMove }
  /** Try a forbidden move of this kind, to see the rule in action. */
  | { type: "illegal"; code: IllegalReason["code"]; solution: UsiMove }
  /** Free play on a still board; the learner continues whenever they like. */
  | { type: "free" };

/** Best result per lesson, saved in the browser. */
export interface CourseProgress {
  /** Lesson id -> stars (1-3). A lesson is done when it has stars. */
  stars: Record<string, number>;
}
