import { element } from "./dialogs";
import { withKanji } from "./rich";

export interface HomeOptions {
  /** Description of the game in progress ("12 jogadas contra o computador"), or null if none. */
  current: string | null;
  /** "3 de 32 lições", or null for someone who has not started the course. */
  courseProgress: string | null;
  /** First visit: learning comes first. */
  newcomer: boolean;
  installButton: HTMLButtonElement;
  onContinue: () => void;
  onPlay: () => void;
  onLearn: () => void;
  onRules: () => void;
}

function choice(title: string, detail: string, handler: () => void, kind: string, kanji: string): HTMLButtonElement {
  const button = element(
    "button",
    { type: "button", class: `home-choice ${kind}` },
    element("span", { class: "home-kanji jp", lang: "ja", "aria-hidden": "true" }, kanji),
    element("span", { class: "home-choice-text" }, element("strong", {}, title), element("small", {}, ...withKanji(detail))),
  );
  button.addEventListener("click", handler);
  return button;
}

/** The start screen: play or learn. */
export function homeScreen(options: HomeOptions): HTMLElement {
  const learn = choice(
    "Aprender",
    options.courseProgress ?? "Nunca jogou? Comece aqui: das peças às táticas (手筋) e estratégias.",
    options.onLearn,
    options.newcomer ? "primary" : "",
    "学",
  );
  const play = choice("Jogar", "Contra o computador (5 níveis) ou a dois no mesmo aparelho.", options.onPlay, options.newcomer ? "" : "primary", "対局");
  const choices = element("nav", { class: "home-choices", "aria-label": "O que fazer" });
  if (options.current) choices.append(choice("Continuar partida", options.current, options.onContinue, "", "続"));
  choices.append(...(options.newcomer ? [learn, play] : [play, learn]));

  const rules = element("button", { type: "button" }, "Regras");
  rules.addEventListener("click", options.onRules);
  return element(
    "div",
    { class: "app home-screen" },
    element(
      "main",
      { class: "home" },
      element(
        "header",
        { class: "home-hero" },
        element("span", { class: "home-mark jp", lang: "ja", "aria-hidden": "true" }, "将棋"),
        element("h1", {}, "Shogi"),
        element("p", {}, "O xadrez japonês, fiel às regras oficiais. Aprenda jogando."),
      ),
      choices,
      element("div", { class: "home-extra" }, rules, options.installButton),
    ),
  );
}
