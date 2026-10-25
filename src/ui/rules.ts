import { pieceInfo } from "../core/pieces";
import type { VariantDefinition } from "../core/variants";
import { diagramLegend, movementDiagram } from "./diagram";
import { element, showDialog } from "./dialogs";
import type { PieceStyle } from "./pieceView";

function section(title: string, ...content: (Node | string)[]): HTMLElement {
  return element("section", { class: "rules-section" }, element("h3", {}, title), ...content);
}

function list(...items: string[]): HTMLElement {
  return element("ul", {}, ...items.map((item) => element("li", {}, item)));
}

/** A small board with the promotion zones shaded. */
function zoneBoard(variant: VariantDefinition): HTMLElement {
  const { files, ranks } = variant.dims;
  const board = element("div", { class: "zone-board", "aria-hidden": "true" });
  board.style.setProperty("--files", String(files));
  for (let row = 0; row < ranks; row++) {
    for (let col = 0; col < files; col++) {
      const zone = row < variant.promotionZoneRanks ? "zone-black" : row >= ranks - variant.promotionZoneRanks ? "zone-white" : "";
      board.append(element("div", { class: `zone-cell ${zone}` }));
    }
  }
  return board;
}

function piecesSection(variant: VariantDefinition, style: PieceStyle): HTMLElement {
  const rows = variant.pieceTypes.map((type) => {
    const info = pieceInfo({ type, promoted: false });
    const promotes = variant.promotable.includes(type)
      ? `Promovida: ${pieceInfo({ type, promoted: true }).namePt}.`
      : "Não promove.";
    return element(
      "div",
      { class: "rules-piece" },
      movementDiagram({ type, promoted: false }, style),
      element("div", {}, element("strong", {}, info.namePt), element("small", {}, ` ${info.romaji} · ${info.kanjiName}`), element("p", {}, `${info.movePt} ${promotes}`)),
    );
  });
  return section("As peças", diagramLegend(), element("p", {}, "Diagramas vistos do lado do dono da peça (para cima = em direção ao adversário)."), ...rows);
}

export function showRules(variant: VariantDefinition, style: PieceStyle): Promise<null> {
  const zone = variant.promotionZoneRanks;
  const body = element(
    "div",
    { class: "rules" },
    section(
      "Objetivo",
      element("p", {}, "Dar xeque-mate no rei do adversário: atacá-lo de um jeito que ele não consiga escapar. Sente (☗) joga primeiro, depois as jogadas se alternam."),
    ),
    piecesSection(variant, style),
    section(
      "Promoção",
      element(
        "div",
        { class: "rules-row" },
        zoneBoard(variant),
        element(
          "div",
          {},
          list(
            `As ${zone} últimas fileiras do lado do adversário são a zona de promoção (o campo inimigo). Na figura: em cima a zona de Sente, embaixo a de Gote.`,
            "Quando uma peça entra, sai ou se move dentro dessa zona, você pode virá-la: ela fica promovida (nome em vermelho) e muda de movimento.",
            "A promoção é opcional, exceto quando a peça ficaria sem jogadas: peão e lança na última fileira, cavalo nas duas últimas.",
            "Ouro e rei não promovem. Uma peça promovida continua promovida até ser capturada.",
          ),
        ),
      ),
    ),
    section(
      "Capturas e drops (peças da mão)",
      list(
        "Ao capturar, a peça vai para a sua mão, já sem promoção.",
        "Na sua vez, em vez de mover, você pode colocar (\"dropar\") uma peça da mão em qualquer casa vazia. Ela entra sem promoção, mesmo dentro da zona.",
        "Proibido: nifu (dois peões seus não promovidos na mesma coluna), deixar uma peça sem jogadas (peão/lança na última fileira, cavalo nas duas últimas) e uchifuzume (dar xeque-mate colocando um peão da mão).",
      ),
    ),
    section(
      "Fim da partida",
      list(
        "Xeque-mate: vence quem deu o mate. Ficar sem jogadas legais também é derrota.",
        "Sennichite: se a mesma posição (com as mesmas peças na mão e o mesmo jogador da vez) aparecer 4 vezes, é empate.",
        "Xeque perpétuo: se a repetição vier de xeques seguidos, quem dava os xeques perde.",
        "Impasse (jishogi): se os reis entram no campo inimigo e ninguém consegue dar mate, o jogador da vez pode declarar vitória. Precisa ter o rei no campo inimigo, sem estar em xeque, 10 ou mais peças lá, e pontos suficientes (torre e bispo valem 5, as demais 1, contando o campo inimigo e a mão): Sente precisa de 28 e Gote de 27.",
        "Desistência: o jogador pode desistir a qualquer momento.",
      ),
    ),
  );
  return showDialog({ title: "Regras do Shogi", body, actions: [{ label: "Fechar", value: null, kind: "primary" }], dismissValue: null, className: "rules-dialog" });
}
