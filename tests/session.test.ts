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
  const s = new GameSession(await newGame(), engine, () => notify(), 0);
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

describe("GameSession hints", () => {
  it("suggests a legal move with an explanation, and forgets it after a move", async () => {
    const { s } = await session();
    s.newGame({ mode: "local", humanColor: "black", level: 1 });
    s.restore({ initialSfen: "4k4/9/4P4/9/9/9/9/9/4K4 b G 1", moves: [], settings: { mode: "local", humanColor: "black", level: 1 } });
    await s.requestHint();
    expect(s.hint?.move).toBe("G*5b");
    expect(s.hint?.facts).toContain("dá xeque-mate!");
    expect(s.hint?.notation).toBe("G*5b");
    s.play("5i4h");
    expect(s.hint).toBeNull();
  });
});

describe("GameSession, handicap and impasse", () => {
  it("handicap: the computer plays Gote without the rook and moves first", async () => {
    const { s, settled } = await session();
    s.newGame({ mode: "ai", humanColor: "white", level: 1, handicap: "rook" });
    expect(s.settings.humanColor).toBe("black");
    expect(s.backend.initialSfen()).toBe("lnsgkgsnl/7b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1");
    await settled();
    expect(s.backend.history()).toHaveLength(1);
    expect(s.canHumanMove()).toBe(true);
  });

  it("the computer declares impasse when it can", async () => {
    const { s } = await session();
    s.restore({ initialSfen: "8K/9/9/9/9/9/9/4kssss/3ggggbr w 9p 1", moves: [], settings: vsAi("black") });
    expect(s.backend.result()).toEqual({ over: true, winner: "white", reason: "impasse" });
  });
});
