import type { EngineTransport } from "../ai/Engine";
import type { WorkerRequest, WorkerResponse } from "./protocol";

/** EngineTransport over the engine Web Worker (browser only). */
export class WorkerTransport implements EngineTransport {
  private readonly worker: Worker;
  private readonly listeners: ((line: string) => void)[] = [];

  constructor(onError: (message: string) => void) {
    this.worker = new Worker(new URL("./engine.worker.ts", import.meta.url), { type: "module" });
    this.worker.onmessage = (event: MessageEvent<WorkerResponse>) => {
      const message = event.data;
      if (message.type === "line") for (const listener of this.listeners) listener(message.line);
      else onError(message.message);
    };
    this.worker.onerror = (event) => onError(event.message || "Falha no Web Worker do motor");
    const engineBaseUrl = new URL(`${import.meta.env.BASE_URL}engine/`, location.href).href;
    this.post({ type: "init", engineBaseUrl });
  }

  send(command: string): void {
    this.post({ type: "command", command });
  }

  onLine(listener: (line: string) => void): void {
    this.listeners.push(listener);
  }

  terminate(): void {
    this.worker.terminate();
  }

  private post(message: WorkerRequest): void {
    this.worker.postMessage(message);
  }
}
