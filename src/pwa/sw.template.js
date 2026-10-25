/*
 * Service worker: makes the game work offline and adds the COOP/COEP headers that the
 * threaded AI engine needs (on hosts that cannot send them, like GitHub Pages).
 *
 * This is a template: at build time vite.config.ts writes dist/sw.js from it, filling in
 * the list of files to cache and a version derived from their contents.
 */
const VERSION = "__VERSION__";
const PRECACHE = __PRECACHE__;
const CACHE = `shogi-${VERSION}`;

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      await cache.addAll(PRECACHE);
      // First install (or replacing the coi-serviceworker used by older versions): take control
      // right away. An update of this worker waits until the page asks (the player presses
      // "Atualizar"), so a game in progress is never interrupted.
      const active = self.registration.active;
      if (!active || !active.scriptURL.endsWith("/sw.js")) await self.skipWaiting();
    })(),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) {
        if (key.startsWith("shogi-") && key !== CACHE) await caches.delete(key);
      }
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "skip-waiting") self.skipWaiting();
});

/** Adds the headers that make the page cross-origin isolated (SharedArrayBuffer for the engine). */
function isolate(response) {
  if (response.status === 0) return response; // opaque or redirect responses cannot be changed
  const headers = new Headers(response.headers);
  headers.set("Cross-Origin-Embedder-Policy", "require-corp");
  headers.set("Cross-Origin-Opener-Policy", "same-origin");
  headers.set("Cross-Origin-Resource-Policy", "cross-origin");
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

async function respond(request) {
  const cache = await caches.open(CACHE);
  if (request.mode === "navigate") {
    // Pages: network first (fresh when online), the cached app when offline.
    try {
      return isolate(await fetch(request));
    } catch {
      const cached = (await cache.match("./index.html")) || (await cache.match("./"));
      return cached ? isolate(cached) : Response.error();
    }
  }
  // Everything else (hashed assets, engine, font): cache first.
  const cached = await cache.match(request, { ignoreSearch: true });
  if (cached) return isolate(cached);
  try {
    return isolate(await fetch(request));
  } catch {
    return Response.error();
  }
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  if (request.cache === "only-if-cached" && request.mode !== "same-origin") return;
  event.respondWith(respond(request));
});
