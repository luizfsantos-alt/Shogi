import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { FairyEngine } from "../src/ai/FairyEngine";
import { getVariant } from "../src/core/variants";
import { GameSession, type GameSettings } from "../src/ui/session";
import { newGame, nodeEngineTransport } from "./helpers";

let engine: FairyEngine;
beforeAll(async () => {
  engine = new FairyEngine(await nodeEngineTransport(), getVariant("shogi"));
  await engine.init();
});
afterAll(() => engine.dispose());

const vsAi = (humanColor: "black" | "white"): GameSettings => ({ mode: "ai", humanColor, level: 1 });

async function session(): Promise<{ s: GameSession; settled: () => Promise<void> }> {
  let notify = (): void => {};
  const s = new GameSession(await newGame(), engine, () => notify());
  const settled = () =>
    new Promise<void>((resolve) => {
      const check = (): void => {
        if (!s.thinking) resolve();
      };
      notify = () => setTimeout(check, 0);
      check();
    });
  return { s, settled };
}

describe("GameSession against the computer", () => {
  it("the computer answers the player's move", async () => {
    const { s, settled } = await session();
    s.newGame(vsAi("black"));
    s.play("7g7f");
    expect(s.thinking).toBe(true);
    expect(s.canHumanMove()).toBe(false);
    await settled();
    expect(s.backend.history()).toHaveLength(2);
    expect(s.notations).toHaveLength(2);
    expect(s.notations[0]).toBe("P-7f");
    expect(s.canHumanMove()).toBe(true);
  });

  it("the computer opens when the player is Gote", async () => {
    const { s, settled } = await session();
    s.newGame(vsAi("white"));
    await settled();
    expect(s.backend.history()).toHaveLength(1);
    expect(s.backend.sideToMove()).toBe("white");
  });

  it("undo takes back the computer's reply and the player's move", async () => {
    const { s, settled } = await session();
    s.newGame(vsAi("black"));
    s.play("7g7f");
    await settled();
    s.play("2g2f");
    await settled();
    s.undo();
    expect(s.backend.history()).toHaveLength(2);
    expect(s.notations).toHaveLength(2);
    expect(s.canHumanMove()).toBe(true);
  });

  it("undo while the computer is thinking cancels the search", async () => {
    const { s, settled } = await session();
    s.newGame({ ...vsAi("black"), level: 5 });
    s.play("7g7f");
    s.undo();
    await settled();
    expect(s.backend.history()).toEqual([]);
    expect(s.thinking).toBe(false);
  });

  it("resignation is saved and restored, and can be undone", async () => {
    const { s, settled } = await session();
    s.newGame(vsAi("black"));
    s.play("7g7f");
    await settled();
    s.resign();
    const saved = s.toSaved();
    expect(saved.resigned).toBe("black");

    const { s: other } = await session();
    other.restore(saved);
    expect(other.backend.result()).toEqual({ over: true, winner: "white", reason: "resignation" });
    expect(other.notations).toEqual(s.notations);
    other.undo();
    expect(other.backend.result()).toEqual({ over: false });
    expect(other.backend.history()).toHaveLength(2);
  });
});

describe("GameSession, two players on one device", () => {
  it("lets both sides move and undo one move at a time", async () => {
    const { s } = await session();
    s.newGame({ mode: "local", humanColor: "black", level: 1 });
    s.play("7g7f");
    s.play("3c3d");
    expect(s.thinking).toBe(false);
    s.undo();
    expect(s.backend.history()).toEqual(["7g7f"]);
    s.resign();
    expect(s.backend.result()).toEqual({ over: true, winner: "black", reason: "resignation" });
  });
});
