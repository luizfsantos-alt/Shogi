// Exports the course of the PWA (src/learn/) to godot/learn/course.json, the data the Godot app
// plays its lessons from. The PWA stays the source of the lessons: edit them there and run
//   node scripts/export-lessons.mjs          (writes the file)
//   node scripts/export-lessons.mjs --check  (fails if the file is out of date; used by CI)
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createServer } from "vite";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const out = resolve(root, "godot/learn/course.json");

const server = await createServer({ root, logLevel: "error", server: { middlewareMode: true }, appType: "custom" });
try {
  const { TRACKS } = await server.ssrLoadModule("/src/learn/course.ts");
  const json = JSON.stringify({ source: "src/learn (PWA), by scripts/export-lessons.mjs", tracks: TRACKS }, null, 1) + "\n";
  if (process.argv.includes("--check")) {
    let current = "";
    try {
      current = readFileSync(out, "utf8");
    } catch {}
    if (current !== json) {
      console.error("godot/learn/course.json is out of date: run node scripts/export-lessons.mjs");
      process.exitCode = 1;
    } else console.log("godot/learn/course.json is up to date");
  } else {
    writeFileSync(out, json);
    const lessons = TRACKS.reduce((n, t) => n + t.lessons.length, 0);
    console.log(`wrote ${out}: ${TRACKS.length} tracks, ${lessons} lessons`);
  }
} finally {
  await server.close();
}
