import { loadBackend } from "./ui/loadBackend";

// Phase 1 placeholder: proves the rules library loads in the browser.
// The playable interface arrives in Phase 2.
const app = document.querySelector<HTMLElement>("#app")!;

loadBackend()
  .then((game) => {
    app.innerHTML = "";
    const lines = [
      "Fairy-Stockfish (ffish.js) carregado.",
      `Posição: ${game.toSfen()}`,
      `Jogadas legais: ${game.legalMoves().length}`,
      `Isolamento cross-origin (necessário para o motor): ${self.crossOriginIsolated ? "sim" : "não"}`,
    ];
    for (const line of lines) {
      const p = document.createElement("p");
      p.textContent = line;
      app.append(p);
    }
    app.dataset.ready = "true";
  })
  .catch((error: unknown) => {
    app.textContent = `Erro ao carregar: ${String(error)}`;
  });
