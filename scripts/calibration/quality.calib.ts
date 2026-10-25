import { it } from "vitest";
import { report } from "./harness";
import { LEVELS, type LevelConfig } from "../../src/ai/levels";
import { collectPositions, newEngine, Referee } from "./harness";

/**
 * Move quality of each level: for sample positions, how many centipawns the level's move
 * loses compared with the best move found by a strong referee (depth 10).
 * Env: POSITIONS (default 40), LEVELS_JSON (override configs to compare).
 */
it("move quality per level", async () => {
  const levels: LevelConfig[] = process.env.LEVELS_JSON ? JSON.parse(process.env.LEVELS_JSON) : [...LEVELS];
  const positions = await collectPositions(Number(process.env.POSITIONS ?? 40));
  const referee = await Referee.create();
  const engine = await newEngine();
  const depth = 10;

  const best = [];
  for (const position of positions) best.push(await referee.score(position, depth));

  report(`positions: ${positions.length}, referee depth ${depth}`);
  report("level            | avg loss | best move | loss>=150 | loss>=400 | loss>=1000 | avg ms");
  for (const level of levels) {
    const losses: number[] = [];
    let sameAsBest = 0;
    let totalMs = 0;
    for (const [index, position] of positions.entries()) {
      const started = Date.now();
      const move = (await engine.bestMove(position, level))!;
      totalMs += Date.now() - started;
      const played = await referee.score(position, depth, move);
      const loss = Math.max(0, Math.min(2000, best[index] - played));
      if (loss <= 10) sameAsBest++;
      losses.push(loss);
    }
    const share = (limit: number) => `${Math.round((100 * losses.filter((l) => l >= limit).length) / losses.length)}%`.padStart(9);
    const avg = Math.round(losses.reduce((a, b) => a + b, 0) / losses.length);
    report(
      `${`${level.id}. ${level.name} (skill ${level.skill})`.padEnd(16)} | ${String(avg).padStart(8)} | ${`${Math.round((100 * sameAsBest) / losses.length)}%`.padStart(9)} | ${share(150)} | ${share(400)} | ${share(1000).padStart(10)} | ${Math.round(totalMs / losses.length)}`,
    );
  }
  engine.dispose();
  referee.dispose();
}, 6 * 60 * 60 * 1000);
