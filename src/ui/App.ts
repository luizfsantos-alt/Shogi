import { LEVELS } from "../ai/levels";
import { formatSquare, parseUsiMove } from "../core/notation";
import { findKing, SfenError } from "../core/position";
import { opposite, type Color, type Piece, type Square, type UsiMove } from "../core/types";
import { formatUsiRecord, parseUsiRecord, RecordFormatError } from "../core/usiRecord";
import { IllegalMoveError } from "../core/GameBackend";
import { element, showDialog } from "./dialogs";
import { chooseMove, targetsFor, type Selection } from "./interaction";
import { describePiece, PIECE_STYLES, renderPiece, type PieceStyle } from "./pieceView";
import { DEFAULT_SETTINGS, type GameSession, type GameSettings } from "./session";
import * as storage from "./storage";
import { resultReason, resultTitle, sideName, turnText } from "./text";

type SideChoice = Color | "random";

/** The game screen: renders the session and turns clicks into moves. */
export class App {
  private selection: Selection | null = null;
  private flipped = false;
  private notice = "";
  private overlayHidden = false;
  private preferences = storage.loadPreferences();
  private readonly els: Record<"board" | "top" | "bottom" | "status" | "notice" | "moves" | "actions" | "overlay", HTMLElement>;

  constructor(
    private readonly root: HTMLElement,
    private readonly session: GameSession,
  ) {
    root.replaceChildren(this.buildLayout());
    const get = (id: string): HTMLElement => root.querySelector<HTMLElement>(`#${id}`)!;
    this.els = {
      board: get("board"),
      top: get("hand-top"),
      bottom: get("hand-bottom"),
      status: get("status"),
      notice: get("notice"),
      moves: get("moves"),
      actions: get("actions"),
      overlay: get("overlay"),
    };
  }

  /** Called by the session whenever the game changes. */
  onGameChange(): void {
    this.overlayHidden = false;
    storage.saveCurrentGame(this.session.toSaved());
    this.render();
  }

  start(): void {
    const saved = storage.loadCurrentGame();
    if (saved && saved.variant === this.session.backend.variant.id) {
      try {
        this.session.restore(saved);
        this.flipped = this.defaultFlip();
        this.render();
        return;
      } catch {
        // Corrupted autosave: start a fresh game instead.
      }
    }
    this.startGame(this.preferences.lastSettings ?? DEFAULT_SETTINGS);
  }

  // ---------------------------------------------------------------- layout

  private buildLayout(): HTMLElement {
    const button = (id: string, label: string) => element("button", { id, type: "button" }, label);
    const header = element(
      "header",
      { class: "topbar" },
      element("h1", {}, "Shogi"),
      element("div", { class: "topbar-actions" }, button("btn-new", "Nova partida")),
    );
    const play = element(
      "section",
      { class: "play-area" },
      element("div", { id: "hand-top", class: "player-bar top" }),
      element(
        "div",
        { class: "board-frame" },
        element("div", { id: "board", class: "board", role: "grid", "aria-label": "Tabuleiro" }),
        element("div", { id: "overlay", class: "overlay", hidden: "" }),
      ),
      element("div", { id: "hand-bottom", class: "player-bar bottom" }),
    );
    const styleSelect = element("select", { id: "piece-style" });
    for (const style of PIECE_STYLES) styleSelect.append(element("option", { value: style.id }, style.label));
    const panel = element(
      "aside",
      { class: "panel" },
      element("div", { id: "status", class: "status", "aria-live": "polite" }),
      element("div", { id: "notice", class: "notice", role: "status" }),
      element("div", { id: "actions", class: "actions" }),
      element("h2", {}, "Jogadas"),
      element("ol", { id: "moves", class: "move-list" }),
      element("label", { class: "field" }, "Estilo das peças ", styleSelect),
      element(
        "div",
        { class: "actions secondary" },
        button("btn-save", "Salvar"),
        button("btn-load", "Carregar"),
        button("btn-export", "Exportar / Importar"),
      ),
    );
    const layout = element("div", { class: "app" }, header, element("main", { class: "layout" }, play, panel));

    styleSelect.value = this.preferences.pieceStyle;
    styleSelect.addEventListener("change", () => {
      this.preferences.pieceStyle = styleSelect.value as PieceStyle;
      storage.savePreferences(this.preferences);
      this.render();
    });
    layout.querySelector("#btn-new")!.addEventListener("click", () => void this.askNewGame());
    layout.querySelector("#btn-save")!.addEventListener("click", () => void this.saveGame());
    layout.querySelector("#btn-load")!.addEventListener("click", () => void this.loadGame());
    layout.querySelector("#btn-export")!.addEventListener("click", () => void this.exportImport());
    return layout;
  }

  // ---------------------------------------------------------------- rendering

  private render(): void {
    const { files, ranks } = this.session.backend.variant.dims;
    this.root.style.setProperty("--files", String(files));
    this.root.style.setProperty("--ranks", String(ranks));
    this.renderBoard();
    this.renderPlayers();
    this.renderStatus();
    this.renderActions();
    this.renderMoves();
    this.renderOverlay();
  }

  private bottomColor(): Color {
    return this.flipped ? "white" : "black";
  }

  private renderBoard(): void {
    const backend = this.session.backend;
    const { files, ranks } = backend.variant.dims;
    const style = this.preferences.pieceStyle;
    const legal = this.session.canHumanMove() ? backend.legalMoves() : [];
    const targets = this.selection ? targetsFor(this.selection, legal) : [];
    const last = this.session.lastMove();
    const lastMove = last ? parseUsiMove(last) : null;
    const checkedKing = backend.isCheck() ? findKing(backend.position(), backend.sideToMove(), backend.variant.dims) : null;
    const same = (a: Square | null | undefined, b: Square) => !!a && a.file === b.file && a.rank === b.rank;

    const cells: HTMLElement[] = [];
    // Column labels (file numbers) above the board.
    for (let col = 0; col < files; col++) {
      cells.push(element("div", { class: "coord file" }, String(this.flipped ? col + 1 : files - col)));
    }
    cells.push(element("div", { class: "coord corner" }));
    for (let row = 0; row < ranks; row++) {
      for (let col = 0; col < files; col++) {
        const square = this.flipped ? { file: col + 1, rank: ranks - row } : { file: files - col, rank: row + 1 };
        const piece = backend.pieceAt(square);
        const cell = element("button", { type: "button", class: "sq", role: "gridcell" });
        if (row === 0) cell.classList.add("edge-top");
        if (col === 0) cell.classList.add("edge-left");
        cell.setAttribute("aria-label", `${formatSquare(square)}${piece ? `, ${describePiece(piece)}` : ""}`);
        if (piece) cell.append(renderPiece(piece, style, piece.color !== this.bottomColor()));
        if (this.selection?.kind === "board" && same(this.selection.square, square)) cell.classList.add("selected");
        if (targets.some((t) => same(t, square))) cell.classList.add(piece ? "target-capture" : "target");
        if (lastMove && (same(lastMove.from, square) || same(lastMove.to, square))) cell.classList.add("last");
        if (same(checkedKing, square)) cell.classList.add("check");
        cell.addEventListener("click", () => void this.clickSquare(square, piece));
        cells.push(cell);
      }
      cells.push(element("div", { class: "coord rank" }, String.fromCharCode(97 + (this.flipped ? ranks - 1 - row : row))));
    }
    this.els.board.replaceChildren(...cells);
  }

  private renderPlayers(): void {
    this.renderPlayer(this.els.bottom, this.bottomColor());
    this.renderPlayer(this.els.top, opposite(this.bottomColor()));
  }

  private renderPlayer(container: HTMLElement, color: Color): void {
    const backend = this.session.backend;
    const hand = backend.hand(color);
    const who = this.session.settings.mode === "ai" ? (this.session.isComputer(color) ? " — Computador" : " — Você") : "";
    const toMove = !backend.result().over && backend.sideToMove() === color;
    const name = element("div", { class: `player-name${toMove ? " to-move" : ""}` }, `${sideName(color)}${who}`);
    const pieces = element("div", { class: "hand", "aria-label": `Peças na mão de ${sideName(color)}` });
    const types = backend.variant.pieceTypes.filter((type) => (hand[type] ?? 0) > 0);
    if (types.length === 0) pieces.append(element("span", { class: "hand-empty" }, "sem peças na mão"));
    for (const type of types) {
      const piece: Piece = { color, type, promoted: false };
      const button = element("button", { type: "button", class: "hand-piece", "aria-label": `${describePiece(piece)}, ${hand[type]}` });
      button.append(renderPiece(piece, this.preferences.pieceStyle, color !== this.bottomColor()));
      if (hand[type] > 1) button.append(element("span", { class: "count" }, String(hand[type])));
      if (this.selection?.kind === "hand" && this.selection.type === type && backend.sideToMove() === color) {
        button.classList.add("selected");
      }
      button.addEventListener("click", () => this.clickHand(color, type));
      pieces.append(button);
    }
    container.replaceChildren(name, pieces);
  }

  private renderStatus(): void {
    const { backend, settings, thinking } = this.session;
    const result = backend.result();
    const status = this.els.status;
    status.replaceChildren();
    if (result.over) {
      status.append(element("strong", {}, resultTitle(result, settings)), " ", resultReason(result));
    } else {
      status.append(turnText(backend.sideToMove(), settings, thinking));
      if (thinking) status.append(element("span", { class: "spinner", "aria-hidden": "true" }));
      if (backend.isCheck()) status.append(element("div", { class: "check-warning" }, "Xeque! O rei está sendo atacado."));
    }
    if (this.session.engineError) status.append(element("div", { class: "error" }, this.session.engineError));
    this.els.notice.textContent = this.notice;
  }

  private renderActions(): void {
    const { backend } = this.session;
    const over = backend.result().over;
    const button = (label: string, handler: () => void, enabled = true, kind = "") => {
      const b = element("button", { type: "button", class: kind }, label);
      b.disabled = !enabled;
      b.addEventListener("click", handler);
      return b;
    };
    const buttons = [
      button("Desfazer", () => this.act(() => this.session.undo()), this.session.canUndo()),
      button("Virar tabuleiro", () => {
        this.flipped = !this.flipped;
        this.render();
      }),
      button("Desistir", () => void this.confirmResign(), !over, "danger"),
    ];
    const impasse = backend.impasse();
    if (!over && impasse?.kingInZone && this.session.canHumanMove()) {
      buttons.push(button("Declarar impasse", () => this.act(() => this.session.declareImpasse()), impasse.canDeclare));
    }
    this.els.actions.replaceChildren(...buttons);
  }

  private renderMoves(): void {
    const items = this.session.notations.map((text, index) => {
      const mover: Color = (index % 2 === 0) === (this.session.backend.initialSfen().split(" ")[1] === "b") ? "black" : "white";
      return element("li", {}, `${mover === "black" ? "☗" : "☖"} ${text}`);
    });
    this.els.moves.replaceChildren(...items);
    this.els.moves.scrollTop = this.els.moves.scrollHeight;
  }

  private renderOverlay(): void {
    const result = this.session.backend.result();
    const overlay = this.els.overlay;
    overlay.hidden = !result.over || this.overlayHidden;
    if (overlay.hidden || !result.over) return;
    const again = element("button", { type: "button", class: "primary" }, "Nova partida");
    again.addEventListener("click", () => void this.askNewGame());
    const close = element("button", { type: "button" }, "Ver tabuleiro");
    close.addEventListener("click", () => {
      this.overlayHidden = true;
      this.render();
    });
    overlay.replaceChildren(
      element(
        "div",
        { class: "overlay-card" },
        element("h2", {}, resultTitle(result, this.session.settings)),
        element("p", {}, resultReason(result)),
        element("div", { class: "dialog-actions" }, close, again),
      ),
    );
  }

  // ---------------------------------------------------------------- interaction

  private setNotice(text: string): void {
    this.notice = text;
    this.els.notice.textContent = text;
  }

  private act(action: () => void): void {
    this.selection = null;
    this.notice = "";
    try {
      action();
    } catch (error) {
      this.notice = error instanceof Error ? error.message : String(error);
    }
    this.render();
  }

  private async clickSquare(square: Square, piece: Piece | null): Promise<void> {
    const backend = this.session.backend;
    if (backend.result().over) return this.setNotice("A partida terminou. Comece uma nova partida ou desfaça a última jogada.");
    if (!this.session.canHumanMove()) return this.setNotice("Aguarde: é a vez do computador.");

    const side = backend.sideToMove();
    if (this.selection) {
      const choice = chooseMove(this.selection, square, backend.legalMoves());
      if (choice.kind !== "none") {
        const move = choice.kind === "move" ? choice.move : await this.askPromotion(choice.promote, choice.stay);
        if (move) this.act(() => this.session.play(move));
        return;
      }
    }
    if (piece && piece.color === side) {
      this.selection = { kind: "board", square };
      this.notice = targetsFor(this.selection, backend.legalMoves()).length === 0 ? "Essa peça não tem jogadas legais agora." : "";
      this.render();
      return;
    }
    const hadSelection = this.selection !== null;
    this.selection = null;
    this.render();
    if (hadSelection) this.setNotice("Jogada ilegal.");
    else if (piece) this.setNotice(`Essa peça é de ${sideName(piece.color)}. Agora é a vez de ${sideName(side)}.`);
  }

  private clickHand(color: Color, type: string): void {
    const backend = this.session.backend;
    if (!this.session.canHumanMove()) return this.setNotice(backend.result().over ? "A partida terminou." : "Aguarde: é a vez do computador.");
    if (color !== backend.sideToMove()) return this.setNotice(`Essas peças são de ${sideName(color)}.`);
    const same = this.selection?.kind === "hand" && this.selection.type === type;
    this.selection = same ? null : { kind: "hand", type };
    this.notice = "";
    if (this.selection && targetsFor(this.selection, backend.legalMoves()).length === 0) {
      this.notice = "Não há casa legal para colocar essa peça agora.";
    }
    this.render();
  }

  private async askPromotion(promote: UsiMove, stay: UsiMove): Promise<UsiMove | null> {
    const from = parseUsiMove(promote)!.from!;
    const piece = this.session.backend.pieceAt(from)!;
    const option = (promoted: boolean, label: string) => {
      const box = element("div", { class: "promotion-option" });
      box.append(renderPiece({ ...piece, promoted }, this.preferences.pieceStyle, false), element("span", {}, label));
      return box;
    };
    const body = element("div", { class: "promotion-choice" }, option(true, "Promover"), option(false, "Não promover"));
    return showDialog<UsiMove | null>({
      title: "Promover a peça?",
      body,
      actions: [
        { label: "Não promover", value: stay },
        { label: "Promover", value: promote, kind: "primary" },
      ],
      dismissValue: null,
    });
  }

  private async confirmResign(): Promise<void> {
    const who = this.session.settings.mode === "ai" ? "Você vai" : `${sideName(this.session.backend.sideToMove())} vai`;
    const ok = await showDialog({
      title: "Desistir da partida?",
      body: `${who} desistir. Dá para desfazer depois, se mudar de ideia.`,
      actions: [
        { label: "Continuar jogando", value: false },
        { label: "Desistir", value: true, kind: "danger" },
      ],
      dismissValue: false,
    });
    if (ok) this.act(() => this.session.resign());
  }

  // ---------------------------------------------------------------- new game

  private defaultFlip(): boolean {
    return this.session.settings.mode === "ai" && this.session.settings.humanColor === "white";
  }

  private startGame(settings: GameSettings, sfen?: string): void {
    const actual = this.session.engineAvailable ? settings : { ...settings, mode: "local" as const };
    this.selection = null;
    this.notice = "";
    this.session.newGame(actual, sfen);
    this.flipped = this.defaultFlip();
    this.render();
  }

  private async askNewGame(): Promise<void> {
    const last = this.preferences.lastSettings ?? DEFAULT_SETTINGS;
    const radio = (name: string, value: string, label: string, checked: boolean, disabled = false) => {
      const input = element("input", { type: "radio", name, value });
      input.checked = checked;
      input.disabled = disabled;
      return element("label", { class: "choice" }, input, ` ${label}`);
    };
    const engineOk = this.session.engineAvailable;
    const levelSelect = element("select", { name: "level" });
    for (const level of LEVELS) {
      const option = element("option", { value: String(level.id) }, `${level.id}. ${level.name} — ${level.description}`);
      levelSelect.append(option);
    }
    levelSelect.value = String(last.level);
    const form = element(
      "form",
      { class: "new-game" },
      element(
        "fieldset",
        {},
        element("legend", {}, "Adversário"),
        radio("mode", "ai", "Computador", last.mode === "ai" && engineOk, !engineOk),
        radio("mode", "local", "Dois jogadores neste aparelho", last.mode === "local" || !engineOk),
      ),
      element(
        "fieldset",
        {},
        element("legend", {}, "Seu lado (contra o computador)"),
        radio("side", "black", "Sente ☗ (joga primeiro)", last.humanColor === "black"),
        radio("side", "white", "Gote ☖", last.humanColor === "white"),
        radio("side", "random", "Aleatório", false),
      ),
      element("label", { class: "field" }, "Nível ", levelSelect),
    );
    if (!engineOk) form.prepend(element("p", { class: "error" }, "O motor de IA não está disponível neste navegador."));

    const start = await showDialog({
      title: "Nova partida",
      body: form,
      actions: [
        { label: "Cancelar", value: false },
        { label: "Começar", value: true, kind: "primary" },
      ],
      dismissValue: false,
    });
    if (!start) return;
    const data = new FormData(form);
    const side = (data.get("side") ?? "black") as SideChoice;
    const settings: GameSettings = {
      mode: data.get("mode") === "local" ? "local" : "ai",
      humanColor: side === "random" ? (Math.random() < 0.5 ? "black" : "white") : side,
      level: Number(data.get("level") ?? last.level),
    };
    this.preferences.lastSettings = { ...settings, humanColor: side === "random" ? last.humanColor : settings.humanColor };
    storage.savePreferences(this.preferences);
    this.startGame(settings);
  }

  // ---------------------------------------------------------------- save / load / export

  private async saveGame(): Promise<void> {
    const input = element("input", { type: "text", maxlength: "60" });
    input.value = `Partida de ${new Date().toLocaleString("pt-BR")}`;
    const ok = await showDialog({
      title: "Salvar partida",
      body: element("label", { class: "field" }, "Nome ", input),
      actions: [
        { label: "Cancelar", value: false },
        { label: "Salvar", value: true, kind: "primary" },
      ],
      dismissValue: false,
    });
    if (!ok) return;
    const saved = storage.addSave(this.session.toSaved(), input.value.trim() || "Partida");
    this.setNotice(saved ? "Partida salva neste navegador." : "Não foi possível salvar (armazenamento do navegador indisponível).");
  }

  private async loadGame(): Promise<void> {
    const saves = storage.listSaves();
    const list = element("ul", { class: "save-list" });
    if (saves.length === 0) list.append(element("li", {}, "Nenhuma partida salva ainda."));
    let chosen: string | null = null;
    const dialogDone = showDialog<"load" | null>({
      title: "Carregar partida",
      body: list,
      actions: [{ label: "Fechar", value: null }],
      dismissValue: null,
      className: "load-dialog",
    });
    for (const save of saves) {
      const opponent = save.settings.mode === "ai" ? `contra o computador (nível ${save.settings.level})` : "dois jogadores";
      const load = element("button", { type: "button", class: "primary" }, "Carregar");
      const remove = element("button", { type: "button", class: "danger" }, "Apagar");
      const item = element(
        "li",
        {},
        element("div", {}, element("strong", {}, save.name), element("small", {}, `${save.moves.length} jogadas, ${opponent}`)),
        element("div", { class: "save-actions" }, remove, load),
      );
      load.addEventListener("click", () => {
        chosen = save.id;
        list.closest("dialog")?.close();
      });
      remove.addEventListener("click", () => {
        storage.deleteSave(save.id);
        item.remove();
      });
      list.append(item);
    }
    await dialogDone;
    const save = saves.find((s) => s.id === chosen);
    if (!save) return;
    this.act(() => {
      this.session.restore(save);
      this.flipped = this.defaultFlip();
    });
  }

  private async exportImport(): Promise<void> {
    const backend = this.session.backend;
    const record = formatUsiRecord(backend.initialSfen(), backend.variant.startSfen, backend.history());
    const readonlyField = (label: string, value: string) => {
      const area = element("textarea", { readonly: "", rows: "3" });
      area.value = value;
      area.addEventListener("focus", () => area.select());
      return element("label", { class: "field" }, label, area);
    };
    const importArea = element("textarea", { rows: "4", placeholder: "Cole um SFEN ou uma partida USI (position startpos moves 7g7f …)" });
    const body = element(
      "div",
      { class: "export" },
      readonlyField("SFEN da posição atual", backend.toSfen()),
      readonlyField("Partida (USI)", record),
      element("label", { class: "field" }, "Importar", importArea),
    );
    const action = await showDialog<"import" | null>({
      title: "Exportar / Importar",
      body,
      actions: [
        { label: "Fechar", value: null },
        { label: "Importar", value: "import", kind: "primary" },
      ],
      dismissValue: null,
    });
    if (action !== "import") return;
    try {
      const parsed = parseUsiRecord(importArea.value);
      this.session.restore({
        initialSfen: parsed.sfen ?? backend.variant.startSfen,
        moves: parsed.moves,
        settings: this.session.settings,
      });
      this.selection = null;
      this.setNotice("Partida importada.");
      this.render();
    } catch (error) {
      const known = error instanceof SfenError || error instanceof RecordFormatError;
      const message = error instanceof IllegalMoveError ? `A jogada ${error.move} é ilegal nessa posição.` : known ? (error as Error).message : String(error);
      await showDialog({ title: "Não foi possível importar", body: message, actions: [{ label: "OK", value: null }], dismissValue: null });
    }
  }
}
