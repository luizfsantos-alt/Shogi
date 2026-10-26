import { describe, expect, it } from "vitest";
import { pieceInfo } from "../src/core/pieces";
import { movementGlyph, pieceLabel } from "../src/ui/pieceView";
import { migratePreferences } from "../src/ui/storage";

/** Number of closed shapes (one per "Z") in SVG path data. */
const shapes = (path: string) => (path.match(/Z/g) ?? []).length;

describe("reading-mode marks", () => {
  it("draws one cut per line, one tooth per step and one diamond per jump", () => {
    const cases: [string, boolean, number, number, number][] = [
      // type, promoted, cuts, teeth, jumps
      ["K", false, 0, 8, 0],
      ["R", false, 4, 0, 0],
      ["B", false, 4, 0, 0],
      ["G", false, 0, 6, 0],
      ["S", false, 0, 5, 0],
      ["N", false, 0, 0, 2],
      ["L", false, 1, 0, 0],
      ["P", false, 0, 1, 0],
      ["R", true, 4, 4, 0],
      ["B", true, 4, 4, 0],
      ["P", true, 0, 6, 0],
    ];
    for (const [type, promoted, cuts, teeth, jumps] of cases) {
      const glyph = movementGlyph(pieceInfo({ type, promoted }).movement, type === "K");
      // Every piece also has a filled centre.
      expect(shapes(glyph.fills), `${type}${promoted ? "+" : ""}`).toBe(cuts + teeth + 1);
      expect(shapes(glyph.rings)).toBe(jumps);
      expect(glyph.hooks === "").toBe(jumps === 0);
      expect(glyph.kingCut === "").toBe(type !== "K");
    }
  });

  it("points forward: the lance's cut goes up the piece", () => {
    const { fills } = movementGlyph(pieceInfo({ type: "L", promoted: false }).movement, false);
    const ys = [...fills.split("Z")[0].matchAll(/-?\d+(\.\d+)? (-?\d+(\.\d+)?)/g)].map((m) => Number(m[2]));
    expect(Math.min(...ys)).toBeLessThan(0);
  });

  it("writes the names in capitals, in Portuguese or English", () => {
    expect(pieceLabel({ type: "L", promoted: false }, "pt")).toBe("LANÇA");
    expect(pieceLabel({ type: "R", promoted: true }, "pt")).toBe("DRAGÃO");
    expect(pieceLabel({ type: "B", promoted: true }, "en")).toBe("HORSE");
  });
});

describe("preferences", () => {
  it("defaults to kanji pieces with Portuguese names for reading mode", () => {
    expect(migratePreferences({})).toMatchObject({ version: 3, reading: false, labels: "pt", sound: true, showAttacks: false });
  });

  it("turns reading mode on for players who chose names or movement marks", () => {
    expect(migratePreferences({ version: 2, pieceStyle: "pt" })).toMatchObject({ reading: true, labels: "pt" });
    expect(migratePreferences({ version: 2, pieceStyle: "en" })).toMatchObject({ reading: true, labels: "en" });
    expect(migratePreferences({ version: 2, pieceStyle: "kanji", showMarks: true })).toMatchObject({ reading: true });
    expect(migratePreferences({ version: 2, pieceStyle: "kanji", showMarks: false })).toMatchObject({ reading: false });
  });

  it("keeps kanji for players from before version 2, whose names were the old default", () => {
    expect(migratePreferences({ pieceStyle: "pt", showMarks: true })).toMatchObject({ reading: false });
  });

  it("drops the old fields and keeps the current ones", () => {
    const migrated = migratePreferences({ version: 2, pieceStyle: "en", showMarks: true, sound: false });
    expect(migrated).not.toHaveProperty("pieceStyle");
    expect(migrated).not.toHaveProperty("showMarks");
    expect(migrated.sound).toBe(false);
    expect(migratePreferences({ version: 3, reading: true, labels: "en" })).toMatchObject({ reading: true, labels: "en" });
  });
});
