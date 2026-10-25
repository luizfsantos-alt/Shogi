/** Messages exchanged between the page and the engine Web Worker. */
export type WorkerRequest = { type: "init"; engineBaseUrl: string } | { type: "command"; command: string };
export type WorkerResponse = { type: "line"; line: string } | { type: "error"; message: string };
