import { describeIllegal, explainBoardMove, explainMove } from "../core/explain";
import type { GameBackend } from "../core/GameBackend";
import { formatSquare, parseUsiMove } from "../core/notation";
import { findKing } from "../core/position";
import type { Piece, Square } from "../core/types";
import { completedCount, nextLesson, recommendedLesson, TRACKS } from "../learn/course";
import { LessonSession } from "../learn/LessonSession";
import type { CourseProgress, Lesson, Track } from "../learn/types";
import { boardCells, playerBar } from "./boardView";
import { element } from "./dialogs";
import { chooseMove, targetsFor, type Selection } from "./interaction";
import { pieceCard } from "./pieceCard";
import type { Glint, PieceLook } from "./pieceView";
import { PressHold } from "./pressHold";
import { askPromotion } from "./promotion";
import { starText, withKanji } from "./rich";
import { playSound } from "./sound";

function topbar(title: string, ...buttons: HTMLElement[]): HTMLElement {
  return element(
    "header",
    { class: "topbar" },
    element("h1", {}, element("span", { class: "mark", "aria-hidden": "true" }, "将棋"), title),
    element("div", { class: "topbar-actions" }, ...buttons),
  );
}

function button(label: string, handler: () => void, kind = ""): HTMLButtonElement {
  const b = element("button", { type: "button", class: kind }, label);
  b.addEventListener("click", handler);
  return b;
}

/** "Rei" + "Ōshō 王将" as a title with the term in smaller type. */
function titleWithTerm(tag: "h2" | "h3" | "strong", title: string, term?: string): HTMLElement {
  return element(tag, { class: "with-term" }, title, ...(term ? [element("span", { class: "term" }, ...withKanji(term))] : []));
}

// ---------------------------------------------------------------- course map

export interface CourseMapOptions {
  progress: CourseProgress;
  onOpen: (lesson: Lesson) => void;
  onHome: () => void;
}

/** The course: the tracks with their lessons (long tracks in parts), stars and the recommended next lesson. */
export function courseMap({ progress, onOpen, onHome }: CourseMapOptions): HTMLElement {
  const recommended = recommendedLesson(progress);
  const overall = completedCount(progress);
  const intro = element(
    "section",
    { class: "course-intro" },
    element("h2", {}, "Aprender a jogar"),
    element("p", {}, `${overall.done} de ${overall.total} lições concluídas. O caminho recomendado é Fundamentos → Táticas → Estratégia → Avançado, mas você pode abrir qualquer lição.`),
  );
  if (recommended) {
    const resume = button(overall.done === 0 ? `Começar: ${recommended.title}` : `Continuar: ${recommended.title}`, () => onOpen(recommended), "primary");
    intro.append(resume);
  } else {
    intro.append(element("p", { class: "course-done" }, "Você concluiu o curso inteiro! Repita as lições quando quiser ou vá jogar."));
  }
  const tracks = TRACKS.map((track, index) => {
    const count = completedCount(progress, track);
    const list = element("ol", { class: "lesson-list" });
    let part: string | undefined;
    for (const lesson of track.lessons) {
      if (lesson.part !== part) {
        part = lesson.part;
        const info = track.parts?.find((p) => p.id === part);
        if (info) list.append(element("li", { class: "lesson-part" }, titleWithTerm("h3", info.title, info.term), element("p", { class: "muted" }, info.description)));
      }
      const stars = progress.stars[lesson.id] ?? 0;
      const item = element(
        "button",
        { type: "button", class: `lesson-item${lesson === recommended ? " recommended" : ""}${stars ? " done" : ""}` },
        element("span", { class: "lesson-title" }, ...(lesson.game ? ["▶ "] : []), lesson.title),
        ...(lesson.term ? [element("span", { class: "term" }, ...withKanji(lesson.term))] : []),
        element("small", {}, lesson.summary),
        element("span", { class: "lesson-stars", "aria-label": stars ? `${stars} de 3 estrelas` : "não concluída" }, stars ? starText(stars) : "nova"),
      );
      item.addEventListener("click", () => onOpen(lesson));
      list.append(element("li", {}, item));
    }
    return element(
      "section",
      { class: "track" },
      element(
        "div",
        { class: "track-head" },
        element("span", { class: "track-letter", "aria-hidden": "true" }, String.fromCharCode(65 + index)),
        titleWithTerm("h2", track.title, track.term),
        element("small", {}, `${count.done}/${count.total}`),
      ),
      element("p", { class: "muted" }, track.description),
      list,
    );
  });
  return element(
    "div",
    { class: "app course-screen" },
    topbar("Aprender", button("Início", onHome)),
    element("main", { class: "course" }, intro, ...tracks),
  );
}

// ---------------------------------------------------------------- lesson

export interface LessonScreenOptions {
  backend: GameBackend;
  lesson: Lesson;
  track: Track;
  look: () => PieceLook;
  sound: () => boolean;
  onCourse: () => void;
  onHome: () => void;
  /** The lesson ended with this many stars (0 when exercises were skipped). */
  onFinished: (lesson: Lesson, stars: number) => void;
  onOpen: (lesson: Lesson) => void;
  /** A game lesson: start the guided game. */
  onStartGame: (lesson: Lesson) => void;
}

/** A lesson being played: the board on one side, the explanation and the goal on the other. */
export class LessonScreen {
  readonly element: HTMLElement;
  private readonly session: LessonSession;
  private readonly hold = new PressHold();
  private selection: Selection | null = null;
  private selectedAt = 0;
  private notice = "";
  private noticeKind: "info" | "warning" = "info";
  private infoPiece: Piece | null = null;
  private lastPlies = 0;
  private readonly els: Record<"board" | "top" | "bottom" | "overlay" | "panel", HTMLElement>;

  constructor(private readonly options: LessonScreenOptions) {
    this.session = new LessonSession(options.backend, options.lesson, () => this.onSessionChange());
    const board = element("div", { class: "board", role: "grid", "aria-label": "Tabuleiro da lição" });
    const overlay = element("div", { class: "overlay", hidden: "" });
    const top = element("div", { class: "player-bar top" });
    const bottom = element("div", { class: "player-bar bottom" });
    const panel = element("aside", { class: "panel lesson-panel", "aria-live": "polite" });
    this.els = { board, top, bottom, overlay, panel };
    this.element = element(
      "div",
      { class: "app lesson-screen" },
      topbar(options.track.title, button("Curso", options.onCourse), button("Início", options.onHome)),
      element(
        "main",
        { class: "layout" },
        element("section", { class: "play-area" }, top, element("div", { class: "board-frame" }, board, overlay), bottom),
        panel,
      ),
    );
    this.element.style.setProperty("--files", "9");
    this.element.style.setProperty("--ranks", "9");
    this.render();
  }

  private onSessionChange(): void {
    const plies = this.session.backend.history().length;
    if (this.options.sound() && plies > this.lastPlies) playSound(this.session.backend.isCheck() ? "check" : "move");
    this.lastPlies = plies;
    if (this.session.finished) this.options.onFinished(this.options.lesson, this.session.score);
    this.render();
  }

  render(): void {
    this.renderBoard();
    this.renderPlayers();
    this.renderPanel();
    this.renderOverlay();
  }

  private renderBoard(): void {
    const session = this.session;
    const backend = session.backend;
    const legal = session.legalMoves();
    const last = session.lastMove ? parseUsiMove(session.lastMove) : null;
    const selected = this.selection?.kind === "board" ? this.selection.square : null;
    const same = (a: Square | null, b: Square) => !!a && a.file === b.file && a.rank === b.rank;
    const cells = boardCells({
      backend,
      flipped: false,
      look: this.options.look(),
      marks: {
        selected,
        targets: this.selection ? targetsFor(this.selection, legal) : [],
        last: last ? [...(last.from ? [last.from] : []), last.to] : [],
        check: backend.isCheck() ? findKing(backend.position(), backend.sideToMove(), backend.variant.dims) : null,
        hint: [...session.hintSquares, ...session.cueSquares],
        stars: session.remainingStars,
        focus: session.focus,
      },
      glint: (square): Glint | undefined => (same(selected, square) ? { kind: "select", since: this.selectedAt } : undefined),
      onClick: (square, piece) => void this.clickSquare(square, piece),
      onHold: (target, piece) => this.hold.attach(target, piece),
    });
    this.els.board.replaceChildren(...cells);
  }

  private renderPlayers(): void {
    const backend = this.session.backend;
    const bar = (color: "black" | "white") =>
      playerBar({
        backend,
        color,
        look: this.options.look(),
        flipped: false,
        who: color === "black" ? "Você" : "Adversário",
        toMove: this.session.exercise !== null && backend.sideToMove() === color,
        selectedType: color === "black" && this.selection?.kind === "hand" ? this.selection.type : null,
        glint: { kind: "select", since: this.selectedAt },
        onClick: (type) => this.clickHand(color, type),
        onHold: (target, piece) => this.hold.attach(target, piece),
      });
    this.els.top.replaceChildren(...bar("white"));
    this.els.bottom.replaceChildren(...bar("black"));
  }

  private renderPanel(): void {
    const { session } = this;
    const { lesson } = this.options;
    const step = session.step;
    const dots = element("ol", { class: "step-dots", "aria-label": "Passos da lição" });
    lesson.steps.forEach((s, i) => {
      const dot = element("button", { type: "button", class: `step-dot${i === session.stepIndex ? " current" : ""}${i < session.stepIndex ? " passed" : ""}${s.kind === "exercise" ? " exercise" : ""}`, "aria-label": `Passo ${i + 1}: ${s.title}` });
      if (i === session.stepIndex) dot.setAttribute("aria-current", "step");
      dot.addEventListener("click", () => {
        this.reset();
        session.goTo(i);
      });
      dots.append(element("li", {}, dot));
    });

    const content: HTMLElement[] = [
      element("div", { class: "lesson-head" }, titleWithTerm("h2", lesson.title, lesson.term)),
      dots,
      element("h3", { class: "step-title" }, step.kind === "exercise" ? "Exercício · " : "", step.title),
      ...step.text.map((paragraph) => element("p", { class: "step-text" }, ...withKanji(paragraph))),
    ];
    if (this.notice) content.push(element("div", { class: `notice ${this.noticeKind}` }, ...withKanji(this.notice)));
    if (session.feedback) content.push(element("div", { class: `lesson-feedback ${session.feedback.kind}`, role: "status" }, ...withKanji(session.feedback.text)));

    const actions = element("div", { class: "actions" });
    if (session.exercise && !session.solved) {
      actions.append(button("Dica", () => session.hint()), button("Recomeçar", () => this.restart()));
    } else if (session.exercise && session.exercise.goal.type !== "free") {
      actions.append(button("Refazer", () => this.restart()));
    }
    if (session.stepIndex > 0) actions.append(button("Voltar", () => this.previous()));
    const continueLabel = session.isLast ? (lesson.game ? "Começar a partida" : "Concluir lição") : "Continuar";
    const next = button(continueLabel, () => this.continue(), "primary");
    next.disabled = !session.canContinue();
    actions.append(next);
    content.push(actions);

    const piece = this.infoPiece ?? stepPiece(step.piece);
    if (piece) content.push(element("section", { class: "piece-info" }, pieceCard(piece, session.backend.variant, this.options.look(), "black")));
    this.els.panel.replaceChildren(...content);
  }

  private renderOverlay(): void {
    const overlay = this.els.overlay;
    overlay.hidden = !this.session.finished || this.options.lesson.game === true;
    if (overlay.hidden) return;
    const stars = this.session.score;
    const following = nextLesson(this.options.lesson.id);
    const buttons = [button("Repetir", () => this.again()), button("Curso", this.options.onCourse)];
    if (following) buttons.push(button(`Próxima: ${following.title}`, () => this.options.onOpen(following), "primary"));
    overlay.replaceChildren(
      element(
        "div",
        { class: "overlay-card lesson-done" },
        element("h2", {}, "Lição concluída!"),
        element("p", { class: "lesson-done-stars", "aria-label": `${stars} de 3 estrelas` }, stars ? starText(stars) : "☆☆☆"),
        element("p", {}, stars ? starMessage(stars) : "Você pulou algum exercício. Resolva todos para ganhar estrelas."),
        element("div", { class: "dialog-actions" }, ...buttons),
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  private reset(): void {
    this.selection = null;
    this.notice = "";
    this.infoPiece = null;
  }

  private restart(): void {
    this.reset();
    this.session.restartStep();
  }

  private previous(): void {
    this.reset();
    this.session.previous();
  }

  private again(): void {
    this.reset();
    this.session.goTo(0);
  }

  private continue(): void {
    if (this.session.isLast && this.options.lesson.game) {
      this.options.onStartGame(this.options.lesson);
      return;
    }
    this.reset();
    this.session.next();
  }

  private async clickSquare(square: Square, piece: Piece | null): Promise<void> {
    if (this.hold.consume()) return;
    const session = this.session;
    const backend = session.backend;
    if (piece) this.infoPiece = piece;
    if (!session.canMove()) {
      this.selection = null;
      this.render();
      return;
    }
    const selection = this.selection;
    if (selection) {
      const legal = session.legalMoves();
      const choice = chooseMove(selection, square, legal);
      if (choice.kind !== "none") {
        const move = choice.kind === "move" ? choice.move : await askPromotion(backend.pieceAt(parseUsiMove(choice.promote)!.from!)!, this.options.look(), choice.promote, choice.stay);
        if (!move) return;
        const forced = move.endsWith("+") && !legal.includes(move.slice(0, -1));
        this.selection = null;
        this.infoPiece = null;
        this.setNotice(forced ? "Promoção obrigatória: nessa casa a peça ficaria sem jogadas, então ela promoveu sozinha." : "");
        session.play(move);
        return;
      }
      const sameSquare = selection.kind === "board" && selection.square.file === square.file && selection.square.rank === square.rank;
      if (sameSquare || !(piece && piece.color === "black")) {
        this.selection = null;
        if (sameSquare) return this.setNotice("", "info", true);
        const reason = selection.kind === "board" ? explainBoardMove(backend, selection.square, square) : explainMove(backend, `${selection.type}*${formatSquare(square)}`);
        const text = describeIllegal(reason, backend.position(), backend.variant);
        // In an exercise about a forbidden move, trying it is the goal: the session says so.
        this.setNotice(text, session.attemptIllegal(reason) ? "info" : "warning", true);
        return;
      }
    }
    if (piece && piece.color === "black") {
      this.selection = { kind: "board", square };
      this.selectedAt = performance.now();
      const none = targetsFor(this.selection, session.legalMoves()).length === 0;
      this.setNotice(none ? "Essa peça não tem jogadas agora." : "", none ? "warning" : "info", true);
      return;
    }
    this.selection = null;
    this.setNotice(piece ? "Essa peça é do adversário. Veja no painel como ela se move." : "Toque primeiro numa peça sua (no tabuleiro ou na sua mão) e depois na casa de destino.", "info", true);
  }

  private clickHand(color: "black" | "white", type: string): void {
    if (this.hold.consume()) return;
    this.infoPiece = { color, type, promoted: false };
    if (color !== "black" || !this.session.canMove()) {
      this.selection = null;
      this.render();
      return;
    }
    const same = this.selection?.kind === "hand" && this.selection.type === type;
    this.selection = same ? null : { kind: "hand", type };
    this.selectedAt = performance.now();
    this.setNotice(this.selection ? "Toque numa casa para colocar a peça." : "", "info", true);
  }

  private setNotice(text: string, kind: "info" | "warning" = "info", render = false): void {
    this.notice = text;
    this.noticeKind = kind;
    if (render) this.render();
  }
}

function stepPiece(code: string | undefined): Piece | null {
  if (!code) return null;
  return { color: "black", type: code.replace("+", ""), promoted: code.startsWith("+") };
}

function starMessage(stars: number): string {
  return stars === 3 ? "Perfeito: sem erros e sem dicas." : stars === 2 ? "Muito bem! Refaça para tentar as três estrelas." : "Concluída! Dá para refazer com menos lances e menos dicas.";
}
