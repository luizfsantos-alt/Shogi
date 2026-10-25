/**
 * AI difficulty levels: the only place to tune the computer's strength.
 *
 * Engine controls available in fairy-stockfish-nnue.wasm 1.1.12 (checked with the "uci" command):
 * - "Skill Level" (-20..20): below 20 the engine looks at several candidate moves and
 *   deliberately picks a weaker one, so its mistakes stay plausible (never random moves).
 * - "UCI_LimitStrength" + "UCI_Elo" (500..2850): calibrated for chess, not shogi; not used.
 * - search limits: "go depth N", "go movetime MS" (whichever is reached first).
 *
 * Calibration (npm run calibrate:quality / calibrate:match, see README):
 * - Move quality on 24-40 sample positions, judged by a depth-10 search:
 *   with 500 ms per move, Skill 0..20 barely differ (average loss 60-70 cp); negative skills
 *   jump to ~230 cp with ~20% serious mistakes (>= 400 cp). Depth limits matter much more:
 *   full strength at depth 1-6 loses ~100-130 cp per move, at 1 s ~55 cp.
 * - Matches between neighbouring levels (engine vs engine, 10-12 games, random openings):
 *   Iniciante 1 x 11 Fácil; Fácil 0 x 12 Médio; Médio 0 x 12 Difícil; Difícil vs Mestre:
 *   Mestre wins, in longer games (130+ plies). Every step is clearly stronger than the last.
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
  { id: 1, name: "Iniciante", description: "Erra com frequência, inclusive deixando peças sem defesa.", skill: -15, depth: 1 },
  { id: 2, name: "Fácil", description: "Vê ameaças simples, mas ainda erra bastante.", skill: -5, depth: 3 },
  { id: 3, name: "Médio", description: "Joga a sério, com visão tática curta.", skill: 10, depth: 3 },
  { id: 4, name: "Difícil", description: "Forte: pensa cerca de 1 s por jogada.", skill: 20, movetimeMs: 1000 },
  { id: 5, name: "Mestre", description: "Força máxima: pensa cerca de 4 s por jogada.", skill: 20, movetimeMs: 4000 },
];

/** Default for new players: the weakest level. */
export const DEFAULT_LEVEL = 1;

export function getLevel(id: number): LevelConfig {
  return LEVELS.find((level) => level.id === id) ?? LEVELS[DEFAULT_LEVEL - 1];
}

/** Strength used for the "hint" button: full strength, short search. */
export const HINT_LEVEL: LevelConfig = { id: 0, name: "Dica", description: "", skill: 20, depth: 14, movetimeMs: 1500 };
