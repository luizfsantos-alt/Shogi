import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { FairyEngine } from "../src/ai/FairyEngine";
import type { LevelConfig } from "../src/ai/levels";
import { explainMove } from "../src/core/explain";
import type { FairyBackend } from "../src/core/FairyBackend";
import { getVariant } from "../src/core/variants";
import { squares } from "../src/learn/board";
import { allLessons, findLesson, nextLesson, recommendedLesson, TRACKS } from "../src/learn/course";
import { exerciseStars, LessonSession } from "../src/learn/LessonSession";
import type { Accept, ExerciseStep, Lesson } from "../src/learn/types";
import { newGame, nodeEngineTransport } from "./helpers";
import { forcedMates } from "./mate";

const CJK = /[\u3040-\u30ff\u4e00-\u9fff]/;
const options = (accept: Accept): readonly string[] => (typeof accept === "string" ? [accept] : accept);

let game: FairyBackend;
beforeAll(async () => {
  game = await newGame();
});
afterAll(() => game.dispose());

/** A session on `step` of `lesson`, with scripted replies played at once. */
function sessionAt(lesson: Lesson, step: number): LessonSession {
  const session = new LessonSession(game, lesson, () => {}, (reply) => reply());
  session.goTo(step);
  return session;
}

const exercises = allLessons().flatMap((lesson) =>
  lesson.steps.flatMap((step, index) => (step.kind === "exercise" ? [{ lesson, index, step, name: `${lesson.id} #${index + 1} ${step.title}` }] : [])),
);

describe("course structure", () => {
  it("has unique lesson ids and Japanese terms written with kanji", () => {
    const ids = allLessons().map((l) => l.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const track of TRACKS) expect(track.term).toMatch(CJK);
    for (const lesson of allLessons()) {
      if (lesson.term) expect(lesson.term, lesson.id).toMatch(CJK);
      expect(lesson.steps.length, lesson.id).toBeGreaterThan(0);
    }
  });

  it("writes every Japanese term with its kanji in the same step", () => {
    const terms: Record<string, string> = {
      "shogi|shōgi": "将棋", tesuji: "手筋", tokin: "と金", mino: "美濃", yagura: "矢倉", sente: "先手", gote: "後手",
      nifu: "二歩", uchifuzume: "打ち歩詰め", sennichite: "千日手", "tsume shōgi": "詰将棋", hisshi: "必至", "ryōtori": "両取り",
      shikenbisha: "四間飛車", ibisha: "居飛車", furibisha: "振り飛車", kakugen: "格言", igyoku: "居玉", "ōte": "王手",
      tsumi: "詰み", aigoma: "合駒", mochigoma: "持ち駒", "jishōgi": "持将棋", "tōryō": "投了", kakoi: "囲い", tekijin: "敵陣",
    };
    const missing: string[] = [];
    for (const lesson of allLessons()) {
      for (const step of lesson.steps) {
        const extra = step.kind === "exercise" ? [step.hint, step.success, ...Object.values(step.wrong ?? {})] : [];
        for (const text of [step.title, ...step.text, ...extra]) {
          for (const [romaji, kanji] of Object.entries(terms)) {
            if (new RegExp(`(^|[^a-zà-ú])(${romaji})([^a-zà-ú]|$)`, "i").test(text) && !text.includes(kanji)) missing.push(`${lesson.id}: ${romaji} in "${text}"`);
          }
        }
      }
    }
    expect(missing).toEqual([]);
  });

  it("loads every position and parses every square", () => {
    for (const lesson of allLessons()) {
      for (const step of lesson.steps) {
        if (step.sfen) expect(() => game.load(step.sfen), `${lesson.id}: ${step.title}`).not.toThrow();
        expect(() => squares(step.focus)).not.toThrow();
      }
    }
  });

  it("orders lessons and recommends the first one not done", () => {
    expect(recommendedLesson({ stars: {} })?.id).toBe("board");
    expect(recommendedLesson({ stars: { board: 3 } })?.id).toBe("king");
    expect(nextLesson("first-game")?.id).toBe(TRACKS[1].lessons[0].id);
    expect(findLesson("mino")?.track.id).toBe("strategy");
  });
});

describe.each(exercises)("$name", ({ lesson, index, step }) => {
  const goal = (step as ExerciseStep).goal;

  it("can be solved", () => {
    const session = sessionAt(lesson, index);
    expect(session.solved).toBe(goal.type === "free");
    switch (goal.type) {
      case "reach":
      case "capture":
      case "formation":
        goal.solution.forEach((move, i) => {
          expect(session.solved, `solved before ${move}`).toBe(false);
          expect(session.backend.isLegal(move), move).toBe(true);
          session.play(move);
          expect(session.feedback?.kind, `${move}: ${session.feedback?.text}`).not.toBe("error");
          if (i < goal.solution.length - 1) expect(session.lastMove).toBe(move);
        });
        break;
      case "line":
        goal.line.forEach((accept, i) => {
          if (i % 2 === 1) return; // the opponent's replies are played by the session
          if (accept === "*") return session.play(session.backend.legalMoves()[0]);
          // Later options may belong to another branch of the line (after a different first move).
          const moves = i === 0 ? options(accept) : options(accept).slice(0, 1);
          for (const move of moves) expect(session.backend.isLegal(move), `${move} at ply ${i}`).toBe(true);
          session.play(options(accept)[0]);
        });
        break;
      case "mate":
        session.play(goal.solution);
        break;
      case "illegal":
        expect(session.backend.isLegal(goal.solution)).toBe(false);
        expect(explainMove(session.backend, goal.solution).code).toBe(goal.code);
        expect(session.attemptIllegal(explainMove(session.backend, goal.solution))).toBe(true);
        break;
      case "free":
        break;
    }
    expect(session.solved, session.feedback?.text).toBe(true);
    expect(session.feedback?.kind ?? "success").toBe("success");
  });

  it("offers only legal moves in its feedback for wrong moves", () => {
    game.load(step.sfen);
    for (const move of Object.keys((step as ExerciseStep).wrong ?? {})) {
      // Wrong-move notes for later moves of a line would be legal later; all of ours are first moves.
      expect(game.isLegal(move), move).toBe(true);
    }
  });

  if (goal.type === "mate") {
    it("is a real mate in one", () => {
      game.load(step.sfen);
      expect(forcedMates(game, 1)).toContain(goal.solution);
    });
  }

  if (goal.type === "line" && goal.mate) {
    it("is a forced mate whose key move is the only one", () => {
      game.load(step.sfen);
      const moves = Math.ceil(goal.line.length / 2);
      expect(forcedMates(game, moves - 1)).toEqual([]);
      expect([...forcedMates(game, moves)].sort()).toEqual([...options(goal.line[0])].sort());
    });
  }
});

describe("tactics agree with Fairy-Stockfish", () => {
  let engine: FairyEngine;
  beforeAll(async () => {
    engine = new FairyEngine(await nodeEngineTransport(), getVariant("shogi"), { threads: 1 });
    await engine.init();
  });
  afterAll(() => engine.dispose());

  const level: LevelConfig = { id: 0, name: "test", description: "", skill: 20, depth: 12, movetimeMs: 3000 };
  const checked = exercises.filter(({ step }) => (step as ExerciseStep).engineCheck);

  it.each(checked)("$name", async ({ step }) => {
    const exercise = step as ExerciseStep;
    if (exercise.goal.type !== "line") throw new Error("engineCheck needs a line goal");
    const best = await engine.bestMove({ initialSfen: exercise.sfen, moves: [] }, level);
    expect(options(exercise.goal.line[0])).toContain(best);
  });
});

describe("LessonSession", () => {
  const lesson = (id: string) => findLesson(id)!.lesson;

  it("rejects a wrong move without playing it and explains why", () => {
    const values = lesson("values");
    const session = sessionAt(values, 1);
    const before = session.backend.toSfen();
    session.play("5f5c");
    expect(session.backend.toSfen()).toBe(before);
    expect(session.feedback?.kind).toBe("error");
    expect(session.feedback?.text).toContain("Prata");
    session.play("5f1f");
    expect(session.solved).toBe(true);
  });

  it("keeps the opponent still and gives the turn back to Sente", () => {
    const session = sessionAt(lesson("rook"), 1);
    session.play("8h8d");
    expect(session.backend.sideToMove()).toBe("black");
    expect(session.remainingStars).toHaveLength(2);
    expect(session.lastMove).toBe("8h8d");
  });

  it("does not let a still exercise check the enemy king", () => {
    const session = sessionAt(lesson("rook"), 1);
    session.play("8h5h");
    expect(session.feedback?.kind).toBe("error");
    expect(session.backend.pieceAt({ file: 8, rank: 8 })?.type).toBe("R");
  });

  it("highlights the next move of the solution as a hint and costs a star", () => {
    const session = sessionAt(lesson("bishop"), 1);
    session.hint();
    expect(session.hintSquares).toEqual([{ file: 8, rank: 8 }, { file: 4, rank: 4 }]);
    session.play("8h4d");
    session.play("4d2f");
    expect(session.solved).toBe(true);
    session.next();
    session.goTo(2);
    session.play("2h4f");
    session.play("4f6d");
    session.next();
    expect(session.finished).toBe(true);
    expect(session.score).toBe(3); // (2 + 3) / 2, rounded
  });

  it("scores 0 when an exercise was skipped", () => {
    const king = lesson("king");
    const session = sessionAt(king, king.steps.length - 1);
    session.attemptIllegal(explainMove(session.backend, "5h5g"));
    session.next();
    expect(session.finished).toBe(true);
    expect(session.score).toBe(0);
  });

  it("rates exercises by extra moves, mistakes and hints", () => {
    const reach = { type: "reach" as const, stars: [], solution: ["a", "b"] };
    expect(exerciseStars(reach, 2, 0, false)).toBe(3);
    expect(exerciseStars(reach, 4, 0, false)).toBe(2);
    expect(exerciseStars(reach, 5, 0, false)).toBe(1);
    expect(exerciseStars(reach, 2, 0, true)).toBe(2);
    expect(exerciseStars({ type: "mate", solution: "G*5b" }, 1, 1, false)).toBe(2);
    expect(exerciseStars({ type: "mate", solution: "G*5b" }, 1, 5, true)).toBe(1);
  });

  it("plays the opponent's scripted replies after a delay", () => {
    const pending: (() => void)[] = [];
    const fork = lesson("fork");
    const session = new LessonSession(game, fork, () => {}, (reply) => pending.push(reply));
    session.goTo(1);
    session.play("N*6e");
    expect(session.replying).toBe(true);
    expect(session.canMove()).toBe(false);
    pending.shift()!();
    expect(session.lastMove).toBe("7c7f");
    expect(session.canMove()).toBe(true);
    session.play("6e5c+");
    expect(session.solved).toBe(true);
  });

  it("drops a late reply after the learner left the step", () => {
    const pending: (() => void)[] = [];
    const session = new LessonSession(game, lesson("fork"), () => {}, (reply) => pending.push(reply));
    session.goTo(1);
    session.play("N*6e");
    session.restartStep();
    pending.shift()!();
    expect(session.backend.history()).toEqual([]);
  });
});
