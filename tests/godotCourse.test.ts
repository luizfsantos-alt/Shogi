import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { TRACKS } from "../src/learn/course";

/**
 * The Godot app plays the lessons from godot/learn/course.json, exported from src/learn by
 * scripts/export-lessons.mjs. After changing a lesson, run `node scripts/export-lessons.mjs`.
 */
describe("Godot course export", () => {
  it("matches the lessons of the PWA", () => {
    const exported = JSON.parse(readFileSync(new URL("../godot/learn/course.json", import.meta.url), "utf8"));
    expect(exported.tracks).toEqual(JSON.parse(JSON.stringify(TRACKS)));
  });
});
