import "./ui/styles.css";
import { FairyEngine } from "./ai/FairyEngine";
import { App } from "./ui/App";
import { loadBackend } from "./ui/loadBackend";
import { GameSession } from "./ui/session";
import type { VariantDefinition } from "./core/variants";
import { WorkerTransport } from "./worker/WorkerTransport";
import { setupServiceWorker } from "./pwa/register";

const root = document.querySelector<HTMLElement>("#app")!;

function createEngine(variant: VariantDefinition, onError: (message: string) => void): FairyEngine | null {
  // The threaded engine needs SharedArrayBuffer, only available on cross-origin isolated pages.
  if (!self.crossOriginIsolated) {
    onError("A IA não pôde ser ativada neste navegador (em janelas anônimas isso costuma ser bloqueado). Tente uma janela normal e recarregue a página. Por enquanto, só o modo dois jogadores está disponível.");
    return null;
  }
  const threads = Math.max(1, Math.min(4, (navigator.hardwareConcurrency || 2) - 1));
  return new FairyEngine(new WorkerTransport(onError), variant, { threads, hashMb: 32 });
}

async function main(): Promise<void> {
  await setupServiceWorker();
  const backend = await loadBackend();
  let app: App | null = null;
  let session: GameSession | null = null;
  let pendingError: string | null = null;
  let failInit: (error: Error) => void = () => {};
  const initFailed = new Promise<never>((_, reject) => (failInit = reject));
  initFailed.catch(() => {}); // later engine errors are reported through the session
  const reportEngineError = (message: string): void => {
    failInit(new Error(message));
    if (session) session.setEngineError(message);
    else pendingError = message;
  };
  const engine = createEngine(backend.variant, reportEngineError);
  session = new GameSession(backend, engine, () => app?.onGameChange());
  if (pendingError) session.setEngineError(pendingError);
  app = new App(root, session);

  if (engine) {
    root.classList.add("engine-loading");
    const timeout = new Promise<never>((_, reject) => setTimeout(() => reject(new Error("tempo esgotado")), 30_000));
    await Promise.race([engine.init(), initFailed, timeout]).catch((error: unknown) => {
      engine.dispose();
      reportEngineError(`Não foi possível iniciar o motor de IA (${error instanceof Error ? error.message : String(error)}).`);
    });
    root.classList.remove("engine-loading");
  }
  app.start();
  root.dataset.ready = "true";
}

main().catch((error: unknown) => {
  root.textContent = `Erro ao carregar o jogo: ${String(error)}`;
});
