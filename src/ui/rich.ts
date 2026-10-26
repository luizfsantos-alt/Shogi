import { element } from "./dialogs";

/** Runs of Japanese characters (kana, kanji and the repetition mark). */
const JAPANESE = /([\u3040-\u30ff\u3400-\u9fff\u3005]+)/;

/**
 * Text with its Japanese words wrapped in `<span class="jp" lang="ja">`, so the kanji get the
 * brush font and are read by screen readers in Japanese.
 */
export function withKanji(text: string): (Node | string)[] {
  return text
    .split(JAPANESE)
    .filter((part) => part !== "")
    .map((part) => (JAPANESE.test(part) ? element("span", { class: "jp", lang: "ja" }, part) : part));
}

/** "★★☆" for 2 of 3 stars. */
export function starText(stars: number, total = 3): string {
  return "★".repeat(stars) + "☆".repeat(Math.max(0, total - stars));
}
