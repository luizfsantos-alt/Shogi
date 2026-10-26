import { LEVELS } from "../ai/levels";
import { attackMap } from "../core/attacks";
import { checkHelp, describeCheckHelp } from "../core/coach";
import { describeIllegal, explainBoardMove, explainMove } from "../core/explain";
import { formatSquare, parseUsiMove } from "../core/notation";
import { pieceInfo } from "../core/pieces";
import { onInstallAvailable, onUpdateAvailable } from "../pwa/register";
import { findKing, SfenError } from "../core/position";
import { opposite, type Color, type Piece, type Square, type UsiMove } from "../core/types";
import { formatUsiRecord, parseUsiRecord, RecordFormatError } from "../core/usiRecord";
import { IllegalMoveError } from "../core/GameBackend";
import { element, showDialog } from "./dialogs";
import { chooseMove, targetsFor, type Selection } from "./interaction";
import { describePiece, renderPiece, type Glint, type PieceLook } from "./pieceView";
import { pieceCard } from "./pieceCard";
import { showRules } from "./rules";
import { playSound } from "./sound";
import { DEFAULT_SETTINGS, type GameSession, type GameSettings } from "./session";
import * as storage from "./storage";
import { resultReason, resultTitle, sideName, turnText } from "./text";

type SideChoice = Color | "random";

/** Where the source code is published (required by the GPL when the game is distributed). */
const SOURCE_URL = "https://github.com/luizfsantos-alt/Shogi";

/** The game screen: renders the session and turns clicks into moves. */
export class App {
  private selection: Selection | null = null;
  private flipped = false;
  private notice = "";
  private noticeKind: "info" | "warning" = "info";
  /** Plies and game state at the last change, to know which sound to play. */
  private lastPlies = 0;
  private lastOver = false;
  /** No sounds while the saved game is being restored at startup. */
  private soundsReady = false;
  /** When a press-and-hold last showed a piece's name, so its release does not also count as a click. */
  private longPressEndedAt = 0;
  private tooltip: HTMLElement | null = null;
  /** Piece shown in the learning panel. */
  private infoPiece: Piece | null = null;
  private overlayHidden = false;
  /** When the current selection was made, so its glint keeps running across redraws. */
  private selectedAt = 0;
  private selectionKey = "";
  /** The ply at which a piece last promoted, and when: its gold glint plays once. */
  private promotionGlint: { ply: number; at: number } | null = null;
  private preferences = storage.loadPreferences();
  private readonly els: Record<"board" | "top" | "bottom" | "status" | "coach" | "notice" | "moves" | "actions" | "overlay" | "pieceInfo", HTMLElement>;

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
      coach: get("coach"),
      pieceInfo: get("piece-info"),
      notice: get("notice"),
      moves: get("moves"),
      actions: get("actions"),
      overlay: get("overlay"),
    };
  }

  /** Called by the session whenever the game changes. */
  onGameChange(): void {
    this.overlayHidden = false;
    const plies = this.session.backend.history().length;
    if (this.soundsReady && plies === this.lastPlies + 1 && this.session.lastMove()?.endsWith("+")) {
      this.promotionGlint = { ply: plies, at: performance.now() };
    }
    storage.saveCurrentGame(this.session.toSaved());
    this.playSounds();
    this.render();
  }

  private playSounds(): void {
    const backend = this.session.backend;
    const plies = backend.history().length;
    const over = backend.result().over;
    if (this.preferences.sound && this.soundsReady) {
      if (over && !this.lastOver) playSound("end");
      else if (plies === this.lastPlies + 1) {
        const capture = this.session.notations.at(-1)?.includes("x") ?? false;
        playSound(backend.isCheck() ? "check" : capture ? "capture" : "move");
      }
    }
    this.lastPlies = plies;
    this.lastOver = over;
  }

  start(): void {
    this.restoreOrStartGame();
    this.soundsReady = true;
  }

  private restoreOrStartGame(): void {
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
    const readingToggle = element(
      "button",
      { id: "btn-reading", type: "button", class: "reading-toggle", "aria-pressed": String(this.preferences.reading), title: "Mostrar como cada peça anda, no lugar do kanji" },
      element("span", {}, "Leitura"),
      element("span", { class: "switch", "aria-hidden": "true" }),
    );
    readingToggle.addEventListener("click", () => {
      this.preferences.reading = !this.preferences.reading;
      readingToggle.setAttribute("aria-pressed", String(this.preferences.reading));
      storage.savePreferences(this.preferences);
      this.render();
    });
    const header = element(
      "header",
      { class: "topbar" },
      element("h1", {}, element("span", { class: "mark", "aria-hidden": "true" }, "将棋"), "Shogi"),
      element("div", { class: "topbar-actions" }, button("btn-install", "Instalar app"), readingToggle, button("btn-rules", "Regras"), button("btn-new", "Nova partida")),
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
    const attacksToggle = element("input", { type: "checkbox", id: "show-attacks" });
    attacksToggle.checked = this.preferences.showAttacks;
    attacksToggle.addEventListener("change", () => {
      this.preferences.showAttacks = attacksToggle.checked;
      storage.savePreferences(this.preferences);
      this.render();
    });
    const soundToggle = element("input", { type: "checkbox", id: "sound" });
    soundToggle.checked = this.preferences.sound;
    soundToggle.addEventListener("change", () => {
      this.preferences.sound = soundToggle.checked;
      storage.savePreferences(this.preferences);
      if (soundToggle.checked) playSound("move");
    });
    const labelsSelect = element("select", { id: "piece-labels" }, element("option", { value: "pt" }, "Português"), element("option", { value: "en" }, "English"));
    const panel = element(
      "aside",
      { class: "panel" },
      element("div", { id: "status", class: "status", "aria-live": "polite" }),
      element("div", { id: "notice", class: "notice", role: "status" }),
      element("div", { id: "coach", class: "coach", "aria-live": "polite" }),
      element("div", { id: "actions", class: "actions" }),
      element("section", { id: "piece-info", class: "piece-info", "aria-live": "polite" }),
      element("h2", {}, "Jogadas"),
      element("ol", { id: "moves", class: "move-list" }),
      element("label", { class: "field" }, "Nomes das peças no modo leitura ", labelsSelect),
      element("label", { class: "choice" }, attacksToggle, " Mostrar as casas atacadas pelo adversário"),
      element("label", { class: "choice" }, soundToggle, " Sons"),
      element(
        "div",
        { class: "actions secondary" },
        button("btn-save", "Salvar"),
        button("btn-load", "Carregar"),
        button("btn-export", "Exportar / Importar"),
      ),
    );
    const link = (href: string, text: string) => element("a", { href, target: "_blank", rel: "noopener" }, text);
    const footer = element(
      "footer",
      { class: "footer" },
      "Software livre (GPL-3.0). Regras e IA: ",
      link("https://github.com/fairy-stockfish/Fairy-Stockfish", "Fairy-Stockfish"),
      ". ",
      link(SOURCE_URL, "Código-fonte"),
      ".",
    );
    const updateBanner = element("div", { id: "update-banner", class: "update-banner", role: "status", hidden: "" });
    const layout = element("div", { class: "app" }, updateBanner, header, element("main", { class: "layout" }, play, panel), footer);
    this.setupPwaControls(layout);

    labelsSelect.value = this.preferences.labels;
    labelsSelect.addEventListener("change", () => {
      this.preferences.labels = labelsSelect.value === "en" ? "en" : "pt";
      storage.savePreferences(this.preferences);
      this.render();
    });
    layout.querySelector("#btn-rules")!.addEventListener("click", () => void showRules(this.session.backend.variant, this.look()));
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
    this.renderCoach();
    this.renderActions();
    this.renderPieceInfo();
    this.renderMoves();
    this.renderOverlay();
  }

  private look(): PieceLook {
    return { reading: this.preferences.reading, labels: this.preferences.labels };
  }

  /** Glint for the selected piece; the selection's start time survives redraws. */
  private selectionGlint(): Glint {
    const key = JSON.stringify(this.selection);
    if (key !== this.selectionKey) {
      this.selectionKey = key;
      this.selectedAt = performance.now();
    }
    return { kind: "select", since: this.selectedAt };
  }

  private bottomColor(): Color {
    return this.flipped ? "white" : "black";
  }

  private renderBoard(): void {
    const backend = this.session.backend;
    const { files, ranks } = backend.variant.dims;
    const look = this.look();
    const legal = this.session.canHumanMove() ? backend.legalMoves() : [];
    const targets = this.selection ? targetsFor(this.selection, legal) : [];
    const last = this.session.lastMove();
    const lastMove = last ? parseUsiMove(last) : null;
    const checkedKing = backend.isCheck() ? findKing(backend.position(), backend.sideToMove(), backend.variant.dims) : null;
    const same = (a: Square | null | undefined, b: Square) => !!a && a.file === b.file && a.rank === b.rank;
    const hint = this.session.hint ? parseUsiMove(this.session.hint.move) : null;
    const attacks = this.preferences.showAttacks && !backend.result().over ? attackMap(backend.position(), this.opponentColor(), backend.variant.dims) : null;
    const attackers = this.session.canHumanMove() ? (checkHelp(backend)?.attackers ?? []) : [];
    // The gold sweep of a promotion lasts 1.6 s; later redraws leave it out.
    const promotion = this.promotionGlint;
    const promoted =
      promotion && promotion.ply === backend.history().length && performance.now() - promotion.at < 1600 ? lastMove?.to : null;

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
        if (piece) {
          const selected = this.selection?.kind === "board" && same(this.selection.square, square);
          const glint: Glint | undefined = selected
            ? this.selectionGlint()
            : promotion && same(promoted, square)
              ? { kind: "promote", since: promotion.at }
              : undefined;
          cell.append(renderPiece(piece, look, piece.color !== this.bottomColor(), glint));
          this.pressAndHold(cell, piece);
        }
        if (this.selection?.kind === "board" && same(this.selection.square, square)) cell.classList.add("selected");
        if (targets.some((t) => same(t, square))) cell.classList.add(piece ? "target-capture" : "target");
        if (lastMove && (same(lastMove.from, square) || same(lastMove.to, square))) cell.classList.add("last");
        if (same(checkedKing, square)) cell.classList.add("check");
        if (attackers.some((a) => same(a, square))) cell.classList.add("attacker");
        if (hint && (same(hint.from, square) || same(hint.to, square))) cell.classList.add("hint");
        const attackCount = attacks?.get(`${square.file},${square.rank}`);
        if (attackCount) {
          cell.classList.add("attacked");
          if (attackCount > 1) cell.dataset.attacks = String(attackCount);
        }
        cell.addEventListener("click", () => void this.clickSquare(square, piece));
        cells.push(cell);
      }
      cells.push(element("div", { class: "coord rank" }, String.fromCharCode(97 + (this.flipped ? ranks - 1 - row : row))));
    }
    this.els.board.replaceChildren(...cells);
  }

  /** Whose attacks are shown: the computer's, or in a local game the side not to move. */
  private opponentColor(): Color {
    const { settings, backend } = this.session;
    return settings.mode === "ai" ? opposite(settings.humanColor) : opposite(backend.sideToMove());
  }

  /** The player looking at the screen, or null in a two-player game. */
  private viewer(): Color | null {
    return this.session.settings.mode === "ai" ? this.session.settings.humanColor : null;
  }

  private renderPlayers(): void {
    this.renderPlayer(this.els.bottom, this.bottomColor());
    this.renderPlayer(this.els.top, opposite(this.bottomColor()));
  }

  private renderPlayer(container: HTMLElement, color: Color): void {
    const backend = this.session.backend;
    const hand = backend.hand(color);
    const team = color === "black" ? "Brancas" : "Vermelhas";
    const who = this.session.settings.mode === "ai" ? (this.session.isComputer(color) ? "Computador" : "Você") : team;
    const toMove = !backend.result().over && backend.sideToMove() === color;
    const name = element(
      "div",
      { class: `player-name${toMove ? " to-move" : ""}` },
      element("span", { class: `team-mark ${color === "black" ? "sente" : "gote"}`, "aria-hidden": "true" }),
      element("strong", {}, sideName(color)),
      element("small", {}, who),
    );
    const pieces = element("div", { class: "hand", "aria-label": `Peças na mão de ${sideName(color)}` });
    const types = backend.variant.pieceTypes.filter((type) => (hand[type] ?? 0) > 0);
    if (types.length === 0) pieces.append(element("span", { class: "hand-empty" }, "sem peças na mão"));
    for (const type of types) {
      const piece: Piece = { color, type, promoted: false };
      const button = element("button", { type: "button", class: "hand-piece", "aria-label": `${describePiece(piece)}, ${hand[type]}` });
      const selected = this.selection?.kind === "hand" && this.selection.type === type && backend.sideToMove() === color;
      button.append(renderPiece(piece, this.look(), color !== this.bottomColor(), selected ? this.selectionGlint() : undefined));
      this.pressAndHold(button, piece);
      if (hand[type] > 1) button.append(element("span", { class: "count" }, String(hand[type])));
      if (selected) button.classList.add("selected");
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
    this.renderNotice();
  }

  private renderNotice(): void {
    this.els.notice.textContent = this.notice;
    this.els.notice.className = `notice ${this.noticeKind}`;
  }

  private renderCoach(): void {
    const { backend } = this.session;
    const coach = this.els.coach;
    coach.replaceChildren();
    if (backend.result().over) return;
    const help = this.session.canHumanMove() ? checkHelp(backend) : null;
    if (help) coach.append(element("p", { class: "check-help" }, describeCheckHelp(help, backend)));
    if (this.session.hintPending) {
      coach.append(element("p", { class: "hint-text" }, "Procurando uma boa jogada…", element("span", { class: "spinner", "aria-hidden": "true" })));
    }
    const hint = this.session.hint;
    if (hint) {
      const why = hint.facts.length ? hint.facts.join(", ") : "melhora a posição das suas peças (segundo o computador, é a melhor jogada aqui)";
      const play = element("button", { type: "button", class: "primary" }, "Jogar a dica");
      play.addEventListener("click", () => this.act(() => this.session.play(hint.move)));
      coach.append(element("div", { class: "hint-text" }, element("p", {}, element("strong", {}, `Dica: ${hint.notation}`), ` — ${why}.`), play));
    }
  }

  private renderPieceInfo(): void {
    const container = this.els.pieceInfo;
    if (!this.infoPiece) {
      container.replaceChildren(element("p", { class: "muted" }, "Toque em qualquer peça (sua ou do adversário) para ver o nome e como ela se move."));
      return;
    }
    const close = element("button", { type: "button", class: "close", "aria-label": "Fechar painel da peça" }, "×");
    close.addEventListener("click", () => {
      this.infoPiece = null;
      this.render();
    });
    container.replaceChildren(close, pieceCard(this.infoPiece, this.session.backend.variant, this.look(), this.viewer()));
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
    const canHint = this.session.engineAvailable && this.session.canHumanMove() && !this.session.hintPending;
    const buttons = [
      button("Dica", () => void this.session.requestHint(), canHint, "primary"),
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

  /** "Instalar app" while the browser offers it, and the "new version" banner. */
  private setupPwaControls(layout: HTMLElement): void {
    const installButton = layout.querySelector<HTMLButtonElement>("#btn-install")!;
    installButton.hidden = true;
    let install: (() => Promise<void>) | null = null;
    installButton.addEventListener("click", () => void install?.());
    onInstallAvailable((available) => {
      install = available;
      installButton.hidden = available === null;
    });

    const banner = layout.querySelector<HTMLElement>("#update-banner")!;
    onUpdateAvailable((apply) => {
      const update = element("button", { type: "button", class: "primary" }, "Atualizar");
      update.addEventListener("click", () => {
        update.disabled = true;
        apply();
      });
      const later = element("button", { type: "button" }, "Depois");
      later.addEventListener("click", () => (banner.hidden = true));
      banner.replaceChildren(element("span", {}, "Nova versão disponível. A partida atual fica salva."), update, later);
      banner.hidden = false;
    });
  }

  /** Press and hold a piece (mouse or touch) to see its Portuguese name while holding. */
  private pressAndHold(target: HTMLElement, piece: Piece): void {
    let timer = 0;
    let start = { x: 0, y: 0 };
    const cancel = (): void => {
      window.clearTimeout(timer);
      timer = 0;
    };
    target.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) return;
      start = { x: event.clientX, y: event.clientY };
      cancel();
      timer = window.setTimeout(() => {
        timer = 0;
        this.showTooltip(target, piece);
      }, 450);
    });
    target.addEventListener("pointermove", (event) => {
      if (Math.hypot(event.clientX - start.x, event.clientY - start.y) > 10) cancel();
    });
    for (const type of ["pointerup", "pointercancel", "pointerleave"]) target.addEventListener(type, cancel);
    // Long presses on phones would otherwise open the system menu.
    target.addEventListener("contextmenu", (event) => event.preventDefault());
  }

  private showTooltip(target: HTMLElement, piece: Piece): void {
    this.hideTooltip();
    const info = pieceInfo(piece);
    const rect = target.getBoundingClientRect();
    const tooltip = element("div", { class: "piece-tooltip", role: "tooltip" }, info.namePt, element("small", {}, `${info.romaji} · ${sideName(piece.color)}`));
    tooltip.style.left = `${Math.min(Math.max(rect.left + rect.width / 2, 90), window.innerWidth - 90)}px`;
    tooltip.style.top = `${Math.max(rect.top, 60)}px`;
    document.body.append(tooltip);
    this.tooltip = tooltip;
    const hide = (): void => {
      this.longPressEndedAt = Date.now();
      this.hideTooltip();
      window.removeEventListener("pointerup", hide);
      window.removeEventListener("pointercancel", hide);
    };
    window.addEventListener("pointerup", hide);
    window.addEventListener("pointercancel", hide);
  }

  private hideTooltip(): void {
    this.tooltip?.remove();
    this.tooltip = null;
  }

  /**
   * True (once) if the click that is arriving is the release of a press-and-hold. Some phones
   * send no click after a long press, so the mark expires quickly instead of waiting for one.
   */
  private consumeLongPress(): boolean {
    const recent = Date.now() - this.longPressEndedAt < 400;
    this.longPressEndedAt = 0;
    return recent;
  }

  private setNotice(text: string, kind: "info" | "warning" = "info"): void {
    this.notice = text;
    this.noticeKind = kind;
    this.renderNotice();
  }

  private act(action: () => void): void {
    this.selection = null;
    this.notice = "";
    try {
      action();
    } catch (error) {
      this.notice = error instanceof Error ? error.message : String(error);
      this.noticeKind = "warning";
    }
    this.render();
  }

  private async clickSquare(square: Square, piece: Piece | null): Promise<void> {
    if (this.consumeLongPress()) return;
    const backend = this.session.backend;
    if (piece) this.infoPiece = piece;
    if (backend.result().over || !this.session.canHumanMove()) {
      this.render();
      return this.setNotice(backend.result().over ? "A partida terminou. Comece uma nova partida ou desfaça a última jogada." : "Aguarde: é a vez do computador.");
    }
    const side = backend.sideToMove();
    const selection = this.selection;

    if (selection) {
      const legal = backend.legalMoves();
      const choice = chooseMove(selection, square, legal);
      if (choice.kind !== "none") {
        const move = choice.kind === "move" ? choice.move : await this.askPromotion(choice.promote, choice.stay);
        if (!move) return;
        const forced = move.endsWith("+") && !legal.includes(move.slice(0, -1));
        this.act(() => this.session.play(move));
        if (forced) this.setNotice("Promoção obrigatória: nessa casa a peça ficaria sem jogadas, então ela foi promovida automaticamente.");
        return;
      }
      const sameSquare = selection.kind === "board" && selection.square.file === square.file && selection.square.rank === square.rank;
      if (sameSquare || !(piece && piece.color === side)) {
        this.selection = null;
        this.render();
        if (sameSquare) return this.setNotice("");
        const reason = selection.kind === "board"
          ? explainBoardMove(backend, selection.square, square)
          : explainMove(backend, `${selection.type}*${formatSquare(square)}`);
        return this.setNotice(describeIllegal(reason, backend.position(), backend.variant), "warning");
      }
    }

    if (piece && piece.color === side) {
      this.selection = { kind: "board", square };
      this.notice = "";
      if (targetsFor(this.selection, backend.legalMoves()).length === 0) {
        this.notice = backend.isCheck()
          ? "Seu rei está em xeque, e essa peça não consegue tirá-lo do xeque."
          : "Essa peça não tem jogadas legais agora (está bloqueada ou cravada protegendo o rei).";
        this.noticeKind = "warning";
      }
      this.render();
      return;
    }
    this.render();
    if (piece) this.setNotice(`Essa peça é de ${sideName(piece.color)}${this.viewer() === null ? "" : " (o adversário)"}. Veja no painel como ela se move.`);
    else this.setNotice("Toque primeiro numa peça sua (no tabuleiro ou na sua mão) e depois na casa de destino.");
  }

  private clickHand(color: Color, type: string): void {
    if (this.consumeLongPress()) return;
    const backend = this.session.backend;
    this.infoPiece = { color, type, promoted: false };
    if (!this.session.canHumanMove() || color !== backend.sideToMove()) {
      this.selection = null;
      this.render();
      if (backend.result().over) return this.setNotice("A partida terminou.");
      if (!this.session.canHumanMove()) return this.setNotice("Aguarde: é a vez do computador.");
      return this.setNotice(`Essas peças são de ${sideName(color)}. Veja no painel como elas se movem.`);
    }
    const same = this.selection?.kind === "hand" && this.selection.type === type;
    this.selection = same ? null : { kind: "hand", type };
    this.notice = "";
    if (this.selection) {
      if (targetsFor(this.selection, backend.legalMoves()).length === 0) {
        this.notice = "Não há casa legal para colocar essa peça agora.";
        this.noticeKind = "warning";
      } else {
        this.notice = "Toque numa casa destacada para colocar a peça.";
        this.noticeKind = "info";
      }
    }
    this.render();
  }

  private async askPromotion(promote: UsiMove, stay: UsiMove): Promise<UsiMove | null> {
    const from = parseUsiMove(promote)!.from!;
    const piece = this.session.backend.pieceAt(from)!;
    const option = (promoted: boolean, label: string) => {
      const box = element("div", { class: "promotion-option" });
      box.append(renderPiece({ ...piece, promoted }, this.look(), false), element("span", {}, label));
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
    const handicapSelect = element("select", { name: "handicap" });
    handicapSelect.append(element("option", { value: "none" }, "Nenhum (partida normal)"));
    for (const handicap of this.session.backend.variant.handicaps ?? []) {
      handicapSelect.append(element("option", { value: handicap.id }, `Gote joga sem: ${handicap.label}`));
    }
    handicapSelect.value = last.handicap ?? "none";
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
      element(
        "label",
        { class: "field" },
        "Handicap ",
        handicapSelect,
        element("small", { class: "muted" }, "Com handicap, Gote (o computador) joga sem essas peças e começa a partida; você joga de Sente. Bom para aprender."),
      ),
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
      handicap: String(data.get("handicap") ?? "none"),
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
