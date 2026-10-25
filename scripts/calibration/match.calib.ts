import { it } from "vitest";
import { report } from "./harness";
import { getLevel, type LevelConfig } from "../../src/ai/levels";
import { newGame } from "../../tests/helpers";
import { newEngine, playGame, seededRandom } from "./harness";

/**
 * Plays GAMES games (default 10) between two levels, alternating colours.
 * Env: PAIR="1,2" (level ids) or LEVELS_JSON='[{...},{...}]' for custom configs.
 */
it("match between two levels", async () => {
  const [a, b]: LevelConfig[] = process.env.LEVELS_JSON
    ? JSON.parse(process.env.LEVELS_JSON)
    : (process.env.PAIR ?? "1,2").split(",").map((id) => getLevel(Number(id)));
  const games = Number(process.env.GAMES ?? 10);
  const random = seededRandom(Number(process.env.SEED ?? 1));
  const engines = { a: await newEngine(), b: await newEngine() };
  const game = await newGame();
  const score = { a: 0, b: 0, draw: 0 };
  for (let i = 0; i < games; i++) {
    const outcome = await playGame(game, engines, { a, b }, i % 2 === 0, random);
    score[outcome.winner]++;
    report(`game ${i + 1}: ${outcome.winner === "draw" ? "draw" : outcome.winner === "a" ? a.name : b.name} (${outcome.reason}, ${outcome.plies} plies)`);
  }
  report(`RESULT ${a.name} ${score.a} - ${score.b} ${b.name} (draws ${score.draw})`);
  engines.a.dispose();
  engines.b.dispose();
  game.dispose();
}, 12 * 60 * 60 * 1000);
