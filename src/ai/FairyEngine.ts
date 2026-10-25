import type { VariantDefinition } from "../core/variants";
import type { UsiMove } from "../core/types";
import type { Engine, EngineTransport, SearchRequest } from "./Engine";
import type { LevelConfig } from "./levels";
import { goCommand, levelCommands, parseBestMove, positionCommand } from "./uci";

export interface FairyEngineOptions {
  threads?: number;
  hashMb?: number;
}

/**
 * Engine backed by Fairy-Stockfish over UCI. Searches run one at a time: a new request
 * waits until the previous search has fully finished (its "bestmove" arrived), so stale
 * answers never get mixed up with new ones.
 */
export class FairyEngine implements Engine {
  private readonly listeners = new Set<(line: string) => void>();
  private queue: Promise<unknown> = Promise.resolve();
  private requested = 0;
  private cancelledUpTo = 0;
  private searching = false;

  constructor(
    private readonly transport: EngineTransport,
    private readonly variant: VariantDefinition,
    private readonly options: FairyEngineOptions = {},
  ) {
    transport.onLine((line) => {
      for (const listener of [...this.listeners]) listener(line);
    });
  }

  init(): Promise<void> {
    return this.enqueue(async () => {
      this.transport.send("uci");
      await this.waitFor((line) => line === "uciok");
      this.transport.send(`setoption name UCI_Variant value ${this.variant.id}`);
      this.transport.send(`setoption name Threads value ${this.options.threads ?? 1}`);
      this.transport.send(`setoption name Hash value ${this.options.hashMb ?? 32}`);
      await this.ready();
    });
  }

  newGame(): Promise<void> {
    return this.enqueue(async () => {
      this.transport.send("ucinewgame");
      await this.ready();
    });
  }

  bestMove(request: SearchRequest, level: LevelConfig): Promise<UsiMove | null> {
    const id = ++this.requested;
    return this.enqueue(async () => {
      if (id <= this.cancelledUpTo) return null;
      for (const command of levelCommands(level)) this.transport.send(command);
      this.transport.send(positionCommand(request, this.variant));
      await this.ready();
      if (id <= this.cancelledUpTo) return null;
      const answer = this.waitFor((line) => line.startsWith("bestmove"));
      this.searching = true;
      this.transport.send(goCommand(level));
      const line = await answer;
      this.searching = false;
      return id <= this.cancelledUpTo ? null : parseBestMove(line, this.variant);
    });
  }

  stop(): void {
    this.cancelledUpTo = this.requested;
    if (this.searching) this.transport.send("stop");
  }

  dispose(): void {
    this.stop();
    this.listeners.clear();
    this.transport.terminate();
  }

  private ready(): Promise<string> {
    const answer = this.waitFor((line) => line === "readyok");
    this.transport.send("isready");
    return answer;
  }

  private waitFor(predicate: (line: string) => boolean): Promise<string> {
    return new Promise((resolve) => {
      const listener = (line: string): void => {
        if (!predicate(line)) return;
        this.listeners.delete(listener);
        resolve(line);
      };
      this.listeners.add(listener);
    });
  }

  private enqueue<T>(task: () => Promise<T>): Promise<T> {
    const result = this.queue.then(task);
    this.queue = result.catch(() => undefined);
    return result;
  }
}
