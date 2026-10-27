import { ADVANCED, ADVANCED_PARTS } from "./lessons/advanced";
import { BASICS } from "./lessons/basics";
import { STRATEGY } from "./lessons/strategy";
import { TACTICS } from "./lessons/tactics";
import type { CourseProgress, Lesson, Track } from "./types";

/** The whole course, in the recommended order: A → B → C, then the advanced track D. */
export const TRACKS: readonly Track[] = [
  {
    id: "basics",
    title: "Fundamentos",
    term: "Kihon 基本",
    description: "As regras, uma peça de cada vez, até a primeira partida.",
    lessons: BASICS,
  },
  {
    id: "tactics",
    title: "Táticas",
    term: "Tesuji 手筋",
    description: "Ataques duplos, golpes de Peão e problemas de mate.",
    lessons: TACTICS,
  },
  {
    id: "strategy",
    title: "Estratégia",
    term: "Senryaku 戦略",
    description: "Provérbios, aberturas e castelos.",
    lessons: STRATEGY,
  },
  {
    id: "advanced",
    title: "Avançado",
    term: "Jōkyū 上級",
    description: "Aberturas e seus motivos, táticas avançadas, planejamento e mates forçados.",
    advanced: true,
    parts: ADVANCED_PARTS,
    lessons: ADVANCED,
  },
];

export function allLessons(): Lesson[] {
  return TRACKS.flatMap((track) => track.lessons);
}

export function findLesson(id: string): { lesson: Lesson; track: Track } | null {
  for (const track of TRACKS) {
    const lesson = track.lessons.find((l) => l.id === id);
    if (lesson) return { lesson, track };
  }
  return null;
}

/** The lesson after `id` in the course order, or null at the end. */
export function nextLesson(id: string): Lesson | null {
  const lessons = allLessons();
  const index = lessons.findIndex((l) => l.id === id);
  return index >= 0 ? (lessons[index + 1] ?? null) : null;
}

/** The first lesson not done yet, following the recommended order. */
export function recommendedLesson(progress: CourseProgress): Lesson | null {
  return allLessons().find((lesson) => !progress.stars[lesson.id]) ?? null;
}

export function completedCount(progress: CourseProgress, track?: Track): { done: number; total: number } {
  const lessons = track ? track.lessons : allLessons();
  return { done: lessons.filter((l) => progress.stars[l.id]).length, total: lessons.length };
}
