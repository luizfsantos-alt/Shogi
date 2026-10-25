/**
 * AI difficulty levels: the only place to tune the computer's strength.
 *
 * Engine controls available in fairy-stockfish-nnue.wasm 1.1.12 (checked with the "uci" command):
 * - "Skill Level" (-20..20): below 20 the engine searches several candidate moves and picks a
 *   weaker one on purpose, with a bias towards moves that are still reasonable.
 * - "UCI_LimitStrength" + "UCI_Elo" (500..2850): Elo calibrated for chess, not shogi.
 * - search limits: "go depth N", "go nodes N", "go movetime MS".
 *
 * PROVISIONAL values: they are calibrated by playing tests in Phase 4.
 */

export interface LevelConfig {
  id: number;
  name: string;
  description: string;
  /** Fairy-Stockfish "Skill Level", -20 (weakest) to 20 (full strength). */
  skill: number;
  /** Search limits; the engine stops at whichever comes first. */
  depth?: number;
  movetimeMs?: number;
}

export const LEVELS: readonly LevelConfig[] = [
  { id: 1, name: "Iniciante", description: "Comete erros com frequência. Bom para aprender.", skill: -10, depth: 3, movetimeMs: 300 },
  { id: 2, name: "Fácil", description: "Joga com cuidado, mas ainda deixa escapar oportunidades.", skill: -2, depth: 5, movetimeMs: 500 },
  { id: 3, name: "Médio", description: "Um adversário razoável.", skill: 6, depth: 8, movetimeMs: 1000 },
  { id: 4, name: "Difícil", description: "Forte; poucos erros.", skill: 14, movetimeMs: 2000 },
  { id: 5, name: "Mestre", description: "Força máxima (cerca de 4 s por jogada).", skill: 20, movetimeMs: 4000 },
];

export const DEFAULT_LEVEL = 2;

export function getLevel(id: number): LevelConfig {
  return LEVELS.find((level) => level.id === id) ?? LEVELS[DEFAULT_LEVEL - 1];
}
