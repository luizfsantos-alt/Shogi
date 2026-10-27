import { setup } from "../board";
import type { Lesson, TrackPart } from "../types";

/**
 * Track D, advanced: openings and the reason behind their moves, advanced tactics, planning and
 * forced mates. Follows the joseki and castle chapters of HIDETCHI's series, the tesuji articles
 * of the i-tsu-tsu school, Wikipedia's "Shogi strategy", "Castle (shogi)" and "Tsume shogi" and
 * the endgame proverbs (kakugen). The tactical lines were played out with Fairy-Stockfish and
 * the mating problems were found with a solver; the tests (tests/lessons.test.ts) check them.
 */

export const ADVANCED_PARTS: TrackPart[] = [
  { id: "openings", title: "Aberturas", term: "Jōseki 定跡", description: "Os lances de abertura e a razão de cada um; castelos e como atacá-los." },
  { id: "tesuji", title: "Táticas avançadas", term: "Tesuji 手筋", description: "Golpes que pedem cálculo: armadilhas, garfos de Torre e sacrifícios." },
  { id: "planning", title: "Planejamento", term: "Taikyokukan 大局観", description: "Avaliar a posição, escolher o plano e ganhar a corrida do final." },
  { id: "tsume", title: "Mates forçados", term: "Tsume 詰め", description: "Formas de mate, sacrifícios, mates em 3 e 5 e o hisshi." },
];

const START = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1";

/** After 1.P-7f P-8d 2.P-2f G-3b 3.G-7h P-8e: Gote's Rook pawn is one step from 8f. */
const KAKUGAWARI = "lnsgk1snl/1r4gb1/p1ppppppp/9/1p7/2P4P1/PP1PPPP1P/1BG4R1/LNS1KGSNL b - 7";

/** Gote's starting pieces, for positions where only Sente has moved. */
const GOTE_START: Record<string, string> = {
  "9a": "l", "8a": "n", "7a": "s", "6a": "g", "5a": "k", "4a": "g", "3a": "s", "2a": "n", "1a": "l",
  "8b": "r", "2b": "b",
  ...Object.fromEntries([9, 8, 7, 6, 5, 4, 3, 2, 1].map((file) => [`${file}c`, "p"])),
};

const SENTE_BACK: Record<string, string> = { "9i": "L", "8i": "N", "2i": "N", "1i": "L" };

/** Sente's Gold Fortress (kin-yagura), with the Bishop out on 4f. */
const YAGURA = setup({
  ...GOTE_START,
  ...SENTE_BACK,
  "8h": "K", "7h": "G", "7g": "S", "6g": "G", "4f": "B", "3i": "S", "2h": "R",
  "9g": "P", "8g": "P", "7f": "P", "6f": "P", "5f": "P", "4g": "P", "3g": "P", "2g": "P", "1g": "P",
});

/** Sente in Shikenbisha (rook on file 6), before castling. */
const SHIKENBISHA = setup({
  ...GOTE_START,
  ...SENTE_BACK,
  "7i": "S", "6i": "G", "5i": "K", "4i": "G", "3i": "S", "8h": "B", "6h": "R",
  "9g": "P", "8g": "P", "7f": "P", "6f": "P", "5g": "P", "4g": "P", "3g": "P", "2g": "P", "1g": "P",
});

/** Shikenbisha with the Anaguma castle in the corner. */
const ANAGUMA = setup({
  ...GOTE_START,
  "9i": "L", "8i": "N", "2i": "N", "1h": "L",
  "7i": "S", "6i": "G", "1i": "K", "3i": "G", "2h": "S", "8h": "B", "6h": "R",
  "9g": "P", "8g": "P", "7f": "P", "6f": "P", "5g": "P", "4g": "P", "3g": "P", "2g": "P", "1g": "P",
});

/** Bōgin arrived: Silver on 1e and Pawn on 2e against a Static Rook camp. */
const BOGIN = setup({
  "6b": "k", "7b": "g", "5b": "g", "7a": "s", "3b": "s", "8b": "r", "2b": "b", "9a": "l", "8a": "n", "2a": "n", "1a": "l",
  "9c": "p", "8c": "p", "7c": "p", "6c": "p", "5c": "p", "4c": "p", "3d": "p", "2c": "p", "1c": "p",
  "7h": "K", "6h": "G", "5h": "G", "7g": "S", "8h": "B", "9i": "L", "8i": "N", "2i": "N", "1i": "L", "2h": "R", "1e": "S", "2e": "P",
  "9g": "P", "8g": "P", "7f": "P", "6g": "P", "5g": "P", "4g": "P", "3g": "P", "1g": "P",
});

const OPENINGS: Lesson[] = [
  {
    id: "joseki",
    part: "openings",
    title: "Cada lance tem um motivo",
    term: "Jōseki 定跡",
    summary: "Os primeiros lances, os alvos de cada lado e a troca de Bispos.",
    steps: [
      {
        kind: "info",
        title: "O que é jōseki (定跡)",
        sfen: START,
        text: [
          "Jōseki (定跡) são as sequências de abertura que os mestres testaram por séculos. Decorar não basta: cada lance responde a uma ameaça ou prepara um plano, e quem entende o motivo sabe o que fazer quando o adversário sai do roteiro.",
          "Nesta parte você vai jogar aberturas de verdade, lance a lance, e ver por que cada um existe.",
        ],
      },
      {
        kind: "info",
        title: "Os dois primeiros lances",
        sfen: START,
        focus: ["7g", "2g"],
        text: [
          "7g7f abre a diagonal do Bispo: ele passa a enxergar até o campo inimigo. 2g2f mostra que a Torre vai atacar pela coluna 2, a Torre parada (居飛車, ibisha).",
          "Quase toda partida começa com um desses dois. O primeiro dá atividade; o segundo começa o ataque mais direto do shogi (将棋): empurrar o Peão da Torre até a troca.",
        ],
      },
      {
        kind: "info",
        title: "Os alvos",
        sfen: START,
        focus: ["2c", "2b", "8g", "8h"],
        text: [
          "A Torre de Sente (先手) ataca 2c, logo na frente do Bispo de Gote (後手): a cabeça do Bispo (角頭, kakutō). A Torre de Gote faz o mesmo do outro lado, contra 8g e o seu Bispo em 8h.",
          "Boa parte dos lances de abertura serve para defender a sua cabeça do Bispo a tempo e atacar a do adversário.",
        ],
      },
      {
        kind: "exercise",
        title: "Troca de Bispos",
        sfen: KAKUGAWARI,
        focus: ["8e", "8f"],
        text: [
          "Lances jogados: 7g7f 8c8d 2g2f 4a3b 6i7h 8d8e. O Peão vermelho está em 8e e ameaça 8e8f, trocando Peões e levando a Torre dele para 8f.",
          "Jogue a abertura do Kakugawari (角換わり): 1) Bispo para 7g, vigiando 8f. 2) Prata de 7i para 8h, pronta para recapturar. 3) Quando o adversário trocar os Bispos, recapture com a Prata.",
        ],
        goal: { type: "line", line: ["8h7g", "3c3d", "7i8h", "2b7g+", "8h7g"] },
        hint: "Primeiro o Bispo sobe uma casa na diagonal, para 7g.",
        success: "Kakugawari (角換わり)! Os Bispos foram trocados e cada lado tem um na mão. A Prata em 7g protege a cabeça do Peão 7f e não deixou nenhum Ouro sair do lugar.",
      },
      {
        kind: "info",
        title: "Bispo na mão, cuidado com os buracos",
        focus: ["7g", "8h"],
        text: [
          "Depois da troca, os dois lados têm um Bispo na mão, e um Bispo da mão pode cair em qualquer casa vazia. Toda casa que nenhuma peça sua defende é um buraco (隙, suki), e um drop de Bispo num buraco (打ち込み, uchikomi) costuma atacar duas peças de uma vez.",
          "Por isso, no Kakugawari (角換わり) os dois lados montam formações compactas, sem buracos, antes de atacar. Antes de cada lance, pergunte: onde o Bispo da mão do adversário entraria?",
        ],
      },
    ],
  },
  {
    id: "yagura",
    part: "openings",
    title: "A Fortaleza lance a lance",
    term: "Yagura 矢倉",
    summary: "O castelo clássico da Torre parada, e por que ele é assim.",
    steps: [
      {
        kind: "info",
        title: "Por que a Fortaleza",
        sfen: YAGURA,
        focus: ["8h", "7h", "7g", "6g"],
        text: [
          "Quando as duas Torres ficam paradas e os Bispos não são trocados, a luta é pela frente: Peões e Pratas avançando pelas colunas centrais. A Fortaleza (矢倉, yagura) foi feita para isso: três peças de defesa empilhadas na frente do Rei.",
          "Ouro em 7h e Ouro em 6g se defendem; a Prata em 7g fecha a cabeça; o Rei em 8h fica atrás de todos. Os Peões 6f e 7f na frente são a muralha.",
        ],
      },
      {
        kind: "exercise",
        title: "Monte a Fortaleza",
        sfen: START,
        focus: ["8h", "7h", "7g", "6g", "4f"],
        text: [
          "Monte a Fortaleza a partir da posição inicial: Peões em 7f, 6f e 5f; Prata em 7g; Ouros em 7h e 6g; o Bispo sai por 7i até 4f; o Rei vai para 8h. O adversário espera.",
        ],
        goal: {
          type: "formation",
          pieces: { "7f": "P", "6f": "P", "5f": "P", "7g": "S", "7h": "G", "6g": "G", "4f": "B", "8h": "K" },
          solution: ["7g7f", "7i6h", "6g6f", "5g5f", "6i7h", "4i5h", "5h6g", "6h7g", "8h7i", "7i4f", "5i6h", "6h7i", "7i8h"],
        },
        hint: "Abra caminho primeiro: Peões 7f e 6f, a Prata de 7i passa por 6h até 7g, e o Bispo recua para 7i e sai pela diagonal de 5g. Só então o Rei atravessa 6h e 7i até 8h.",
        success: "Kin-yagura (金矢倉)! O Bispo saiu antes do Rei porque o Rei precisava da casa dele. Na abertura, a ordem dos lances importa tanto quanto o destino.",
      },
      {
        kind: "info",
        title: "Forças e fraquezas",
        sfen: YAGURA,
        focus: ["7g", "8g", "9g"],
        text: [
          "Pela frente, a Fortaleza (矢倉) aguenta muito: cada casa diante do Rei é defendida duas ou três vezes. Pelo lado e pela diagonal ela é mais fraca, e o Rei em 8h fica perto da borda.",
          "Contra ela, o atacante soma peças na coluna do ataque: Peão, Prata, Cavalo, Torre e Bispo contra 7g e 8g. É uma conta: se há mais atacantes que defensores numa casa, a casa cai.",
        ],
      },
    ],
  },
  {
    id: "bogin",
    part: "openings",
    title: "A Prata que avança",
    term: "Bōgin 棒銀",
    summary: "Peão, Prata e Torre juntos rompem a coluna 2.",
    steps: [
      {
        kind: "info",
        title: "O Bōgin (棒銀)",
        sfen: START,
        focus: ["2h", "3i", "2g"],
        text: [
          "Bōgin (棒銀, \"Prata em bastão\") é o ataque mais simples da Torre parada: a Prata sobe pela coluna 2, apoiada pela Torre, e o Peão vai na frente. São três atacantes contra a casa 2c, que no começo tem só o Peão vermelho.",
          "O caminho: o Peão vai a 2e, a Prata sai de 3i, passa por 3h, 2g e 2f e chega a 1e, ao lado do Peão.",
        ],
      },
      {
        kind: "exercise",
        title: "Leve a Prata",
        sfen: START,
        focus: ["2e", "1e"],
        text: ["Avance o Peão da coluna 2 até 2e e leve a Prata de 3i até 1e. O adversário espera."],
        goal: { type: "formation", pieces: { "2e": "P", "1e": "S" }, solution: ["2g2f", "2f2e", "3i3h", "3h2g", "2g2f", "2f1e"] },
        hint: "O Peão sai primeiro, porque a Prata precisa passar por 2g e 2f.",
        success: "A Prata chegou. Em 1e ela apoia o avanço 2e2d e, quando o Peão for trocado, entra em 2d.",
      },
      {
        kind: "exercise",
        title: "Rompa a coluna 2",
        sfen: BOGIN,
        focus: ["2e", "1e", "2h", "2c"],
        text: [
          "A Prata está em 1e, o Peão em 2e e a Torre atrás. Avance o Peão, recapture com a Prata e continue entrando na coluna 2, até a Torre chegar ao campo inimigo.",
        ],
        goal: { type: "line", line: ["2e2d", "2c2d", "1e2d", "5b4b", ["2d2c+", "2d2c"], "3b2c", ["2h2c+", "2h2c"]] },
        hint: "O Peão vai a 2d; quando o Peão vermelho capturar, a Prata retoma em 2d.",
        success: "A Torre virou Dragão (龍) em 2c. As trocas foram iguais, Peão por Peão e Prata por Prata, mas a coluna se abriu: três atacantes contra dois defensores, a casa 2c cedeu.",
        engineCheck: true,
      },
    ],
  },
  {
    id: "anaguma",
    part: "openings",
    title: "O Urso na toca",
    term: "Anaguma 穴熊",
    summary: "O castelo mais fechado, o que ele custa e onde ele cai.",
    steps: [
      {
        kind: "info",
        title: "O Rei no buraco",
        sfen: ANAGUMA,
        focus: ["1i", "1h", "2h", "3i"],
        text: [
          "No Anaguma (穴熊, \"urso na toca\"), o Rei desce até o canto (1i), a Lança sobe uma casa para abrir o buraco (1h), a Prata fecha 2h e um Ouro fica em 3i.",
          "Ali o adversário quase não consegue dar xeque: nenhuma casa em volta do Rei fica livre. Quem joga de Anaguma pode atacar trocando peças sem medo, porque o próprio Rei está longe do perigo.",
        ],
      },
      {
        kind: "exercise",
        title: "Entre na toca",
        sfen: SHIKENBISHA,
        focus: ["1i", "1h", "2h", "3i"],
        text: ["Monte o Anaguma (穴熊) com a Torre já em 6h: Lança em 1h, Rei em 1i, Prata em 2h e Ouro em 3i. O adversário espera."],
        goal: { type: "formation", pieces: { "1h": "L", "1i": "K", "2h": "S", "3i": "G" }, solution: ["1i1h", "5i4h", "4h3h", "3h2h", "2h1i", "3i2h", "4i3i"] },
        hint: "A Lança sobe primeiro para liberar o canto. O Rei anda por 4h, 3h e 2h; depois a Prata e o Ouro fecham a porta.",
        success: "O Urso está na toca. Foram sete lances só para isso: o Mino (美濃囲い) fica pronto em cinco.",
      },
      {
        kind: "info",
        title: "O preço e o ponto fraco",
        focus: ["1g", "1h", "2g"],
        text: [
          "O Anaguma (穴熊) custa tempo: enquanto você monta, o adversário ataca. E o Rei, encostado no canto, não tem para onde fugir quando a toca é aberta.",
          "O ataque contra ele vem pela borda (端攻め, hashizeme): Peões e Lança na coluna 1 e Cavalos saltando para 2e. Contra o Mino (美濃囲い) e a Fortaleza (矢倉) também: a borda é o lado que o castelo não cobre.",
        ],
      },
    ],
  },
];

const TESUJI: Lesson[] = [
  {
    id: "keima-trap",
    part: "tesuji",
    title: "O Cavalo que pulou demais",
    term: "Keima no takatobi 桂の高跳び",
    summary: "Um Cavalo avançado não volta: um Peão o captura.",
    steps: [
      {
        kind: "exercise",
        title: "Prenda o Cavalo",
        sfen: setup({
          "8b": "k", "7b": "s", "7a": "g", "9a": "l", "8a": "n", "9c": "p", "8c": "p", "7c": "p", "6c": "p", "5c": "p", "4c": "p", "3c": "p",
          "4e": "n", "3g": "P", "5g": "P", "6g": "P", "4h": "G", "2h": "K", "3h": "S", "3i": "G", "2g": "P", "1g": "P",
        }, "P"),
        focus: ["4e", "3g", "5g"],
        text: [
          "O provérbio diz keima no takatobi fu no ejiki (桂の高跳び歩の餌食): \"o Cavalo que pula alto vira comida de Peão\". O Cavalo só anda para a frente; longe de casa, ele não tem como recuar.",
          "O Cavalo vermelho em 4e só pode saltar para 3g ou 5g, e as duas casas estão defendidas. Ataque-o com o Peão da mão.",
        ],
        goal: { type: "line", line: ["P*4f"] },
        hint: "Coloque o Peão logo abaixo do Cavalo.",
        success: "O Cavalo está perdido: se ficar, o Peão o captura; se saltar para 3g ou 5g, a Prata ou o Ouro recaptura. Antes de saltar com o seu Cavalo, veja se ele terá para onde ir depois.",
      },
    ],
  },
  {
    id: "juji",
    part: "tesuji",
    title: "A Torre em cruz",
    term: "Jūji-bisha 十字飛車",
    summary: "Uma Torre da mão ataca na coluna e na fileira ao mesmo tempo.",
    steps: [
      {
        kind: "exercise",
        title: "Ataque em cruz",
        sfen: setup({
          "9i": "K", "8i": "G", "8h": "S", "9g": "P", "8g": "P", "7g": "P",
          "2e": "g", "5f": "s", "4a": "k", "3a": "s", "5a": "g", "4c": "p", "3c": "p", "2c": "p", "1c": "p", "2a": "n", "1a": "l",
        }, "R"),
        focus: ["2e", "5f"],
        text: [
          "A Torre ataca nas quatro direções. Colocada no cruzamento entre duas peças soltas, uma na mesma coluna e outra na mesma fileira, ela ataca as duas: é a Torre em cruz (十字飛車, jūji-bisha).",
          "O Ouro em 2e e a Prata em 5f estão sem defesa. Encontre a casa de onde a Torre ataca os dois e onde nenhum deles a alcança.",
        ],
        goal: { type: "line", line: ["R*5e", "2e2d", "5e5f"] },
        wrong: { "R*2f": "Daqui a Torre ataca os dois, mas o Ouro em 2e anda uma casa para a frente e a captura. Procure o outro cruzamento." },
        hint: "Há duas casas que alcançam as duas peças: 2f e 5e. Em uma delas o Ouro captura a Torre.",
        success: "O Ouro fugiu e a Prata caiu. Lembre do outro lado da moeda: peças soltas no meio do tabuleiro são alvos de drops.",
      },
    ],
  },
  {
    id: "ryo-ote",
    part: "tesuji",
    title: "Xeque duplo",
    term: "Ryō-ōte 両王手",
    summary: "Duas peças dão xeque de uma vez: só o Rei pode se mexer.",
    steps: [
      {
        kind: "exercise",
        title: "Abra a coluna",
        sfen: setup({ "5a": "k", "4a": "g", "6a": "g", "4b": "s", "6b": "s", "5e": "N", "5i": "R", "9i": "K" }),
        focus: ["5e", "5i"],
        text: [
          "O Cavalo em 5e está na frente da sua Torre. Quando ele sai, a Torre dá xeque pela coluna 5; se o Cavalo também der xeque, são dois xeques ao mesmo tempo: ryō-ōte (両王手).",
          "Contra o xeque duplo não adianta bloquear nem capturar uma das peças: o Rei precisa fugir. Aqui ele não tem para onde ir. Dê mate em um lance.",
        ],
        goal: { type: "mate", solution: "5e4c" },
        hint: "O Cavalo salta para uma casa de onde ataca 5a. Não promova: o Cavalo promovido anda como Ouro e não alcançaria o Rei.",
        success: "Mate com xeque duplo! As peças vermelhas fecharam o próprio Rei, e nenhum bloqueio parava os dois xeques.",
      },
    ],
  },
  {
    id: "uke",
    part: "tesuji",
    title: "Defender a tempo",
    term: "Uke 受け",
    summary: "Ache a ameaça do adversário e a desfaça antes de atacar.",
    steps: [
      {
        kind: "exercise",
        title: "Tire o atacante",
        sfen: setup({
          "9i": "K", "9g": "P", "8g": "P", "7g": "P", "8i": "N", "7h": "+p", "2h": "R",
          "5a": "k", "4a": "g", "6a": "g", "3c": "p", "4c": "p", "5c": "p",
        }, "Gg"),
        focus: ["7h", "8h"],
        text: [
          "Defender (受け, uke) começa por ver a ameaça. O tokin (と金) em 7h e o Ouro na mão do adversário ameaçam G*8h: mate.",
          "Você também tem um Ouro, mas atacar agora é lento. Encontre a defesa que acaba com a ameaça de vez.",
        ],
        goal: { type: "line", line: ["2h7h"] },
        wrong: {
          "G*8h": "Bloqueia, mas o tokin (と金) captura em 8h e o adversário continua atacando com peças da mão.",
          "G*9h": "O Ouro tapa uma saída, mas o tokin (と金) continua lá e o ataque segue. Elimine-o.",
        },
        hint: "A sua Torre alcança o tokin (と金) pela fileira h.",
        success: "Ameaça desfeita, e você ganhou uma peça. Antes de cada lance no final, pergunte: o que o adversário ameaça? A melhor defesa costuma capturar o atacante.",
        engineCheck: true,
      },
    ],
  },
];

/** Sente's king under a mating threat: the tokin goes to 8h, backed by the Dragon. */
const THREATENED_KING = { "9i": "K", "9g": "P", "8g": "+p", "6h": "+r" };

const PLANNING: Lesson[] = [
  {
    id: "evaluation",
    part: "planning",
    title: "Quem está melhor?",
    term: "Keisei handan 形勢判断",
    summary: "Material, Rei, peças e tempo: as quatro perguntas.",
    steps: [
      {
        kind: "info",
        title: "Quatro perguntas",
        sfen: ANAGUMA,
        text: [
          "Antes de escolher um plano, avalie a posição (形勢判断, keisei handan). Os profissionais fazem quatro perguntas:",
          "1) Material (駒の損得, koma no sontoku): quem tem mais peças, contando as da mão? 2) Segurança do Rei (玉の堅さ, gyoku no katasa): qual castelo aguenta mais? 3) Eficiência (駒の効率, koma no kōritsu): as peças trabalham ou estão paradas? 4) A vez (手番, teban): quem ataca primeiro?",
        ],
      },
      {
        kind: "info",
        title: "O que pesa mais",
        text: [
          "No xadrez, material costuma decidir. No shogi (将棋) as peças capturadas voltam, então um Rei bem guardado e a iniciativa valem muito: é comum entregar uma Prata para abrir o castelo inimigo.",
          "Uma regra prática: na abertura conte material e tempo; no meio-jogo, o castelo de cada lado; no final, só a velocidade: quantos lances faltam para cada um dar mate.",
        ],
      },
      {
        kind: "info",
        title: "Escolhendo o plano",
        text: [
          "Se o seu Rei é mais seguro, troque peças e ataque: cada troca deixa o adversário mais exposto. Se o seu Rei é mais fraco, reforce antes, ou ataque só se o seu ataque for mais rápido.",
          "Se as suas peças estão paradas, melhore a pior delas antes de atacar: um Cavalo ou uma Prata que entram no jogo valem mais que um Peão a mais.",
        ],
      },
    ],
  },
  {
    id: "oute-oute",
    part: "planning",
    title: "Xeque só empurra o Rei",
    term: "Ōte wa oute 王手は追う手",
    summary: "Às vezes o lance mais forte não é xeque.",
    steps: [
      {
        kind: "exercise",
        title: "Prenda antes de dar xeque",
        sfen: "6k2/4ll3/4s4/8R/9/9/9/9/K8 b G 1",
        focus: ["3a", "1d"],
        text: [
          "O provérbio diz ōte wa oute (王手は追う手): \"o xeque é um lance que só empurra\". Xeques sem plano mandam o Rei para um lugar mais seguro.",
          "Aqui não há mate. Em vez de dar xeque, leve a Torre para o fundo e promova, fechando a fuga do Rei. Depois, dê o mate.",
        ],
        goal: { type: "line", line: ["1d1b+", "3a4a", "1b2a"] },
        wrong: {
          "1d1a+": "Xeque, mas o Rei sai para 4b ou 3b e escapa para o centro. Feche a fuga primeiro.",
          "G*3b": "O Rei captura o Ouro, que está sozinho. Primeiro a Torre.",
          "G*2b": "Xeque, mas o Rei foge para 4a ou 3b. Prenda o Rei antes.",
        },
        hint: "A Torre vai a 1b e promove: o Dragão (龍) cobre 2a e a fileira b, e ameaça Ouro em 3b.",
        success: "Mate! O Dragão em 1b ameaçava G*3b, e quando o Rei fugiu para 4a o Dragão o alcançou pela fileira a. Isso é um hisshi (必至): a ameaça que não tem defesa.",
      },
    ],
  },
  {
    id: "tsumero",
    part: "planning",
    title: "Ameaça de mate",
    term: "Tsumero 詰めろ",
    summary: "Tsumero, hisshi e o Rei que não leva mate.",
    steps: [
      {
        kind: "info",
        title: "Tsumero (詰めろ) e hisshi (必至)",
        text: [
          "Tsumero (詰めろ) é um lance que ameaça mate no próximo lance: se o adversário não se defender, leva mate. Hisshi (必至) é um tsumero sem defesa possível.",
          "No final, a pergunta é sempre: o meu lance é tsumero? E o lance do adversário, era tsumero contra mim? Quem ignora um tsumero perde na hora.",
        ],
      },
      {
        kind: "info",
        title: "Zetto (ゼット)",
        text: [
          "Os jogadores chamam de zetto (ゼット, \"Z\") um Rei que não leva mate nem se o adversário receber mais uma peça. Com o Rei em zetto, você pode atacar sem se preocupar com a defesa.",
          "O Anaguma (穴熊) é famoso por chegar a zetto (ゼット) com facilidade: por isso quem o usa pode trocar peças no ataque sem medo.",
        ],
      },
      {
        kind: "exercise",
        title: "Feche a rede",
        sfen: "6nk1/4G3n/9/9/8N/9/9/9/K8 b GR 1",
        focus: ["2a", "2b"],
        text: [
          "Não há mate agora. Coloque a Torre numa casa que não dê xeque, mas deixe o Ouro da mão pronto para o mate em 2b, de forma que nada adiante. Depois, dê o mate.",
        ],
        goal: { type: "line", line: ["R*4b", "2a1a", "G*2b"] },
        hint: "A Torre vai para a fileira b, do lado do seu Ouro, para defender 2b de longe.",
        success: "Hisshi (必至)! A Torre em 4b defendia 2b pela fileira e cobria a fuga para 3b: o Rei não tinha saída.",
      },
    ],
  },
  {
    id: "speed",
    part: "planning",
    title: "A corrida do final",
    term: "Sokudo 速度",
    summary: "Ameaçado de mate? Às vezes o ataque é a melhor defesa.",
    steps: [
      {
        kind: "info",
        title: "Contar lances",
        sfen: setup({ "3a": "k", "3c": "n", "2c": "p", "3e": "R", ...THREATENED_KING }, "G"),
        focus: ["8g", "8h", "6h"],
        text: [
          "O seu Rei está ameaçado: o tokin (と金) vermelho vai a 8h, protegido pelo Dragão, e é mate. Você precisa de um lance para se defender.",
          "Mas o provérbio diz shūban wa koma no sontoku yori sokudo (終盤は駒の損得より速度): no final, a velocidade vale mais que o material. Se você tem mate dando xeque a cada lance, o adversário nunca tem tempo de executar a ameaça.",
        ],
      },
      {
        kind: "exercise",
        title: "Mate antes",
        sfen: setup({ "3a": "k", "3c": "n", "2c": "p", "3e": "R", ...THREATENED_KING }, "G"),
        text: ["Mate em 3, ignorando a ameaça. Todos os seus lances devem dar xeque."],
        goal: { type: "line", line: ["3e3c+", "3a4a", "G*4b"], mate: true },
        hint: "A Torre captura o Cavalo e promove, dando xeque.",
        success: "Mate! Você estava a um lance de perder e ganhou primeiro. No final, conte sempre: quantos lances eu preciso, e quantos ele precisa?",
      },
    ],
  },
  {
    id: "endgame-proverbs",
    part: "planning",
    title: "Provérbios do final",
    term: "Kakugen 格言",
    summary: "O que os mestres repetem sobre ataque e defesa no final.",
    steps: [
      {
        kind: "info",
        title: "Atacar o Rei",
        text: [
          "Gyoku wa tsutsumu yō ni yoseyo (玉は包むように寄せよ): cerque o Rei como quem embrulha um pacote, fechando as saídas primeiro, em vez de empurrá-lo com xeques.",
          "Gyoku wa gedan ni otose (玉は下段に落とせ): empurre o Rei para a última fileira, onde ele tem menos saídas. E ataque o Rei pelo lado onde ele quer fugir.",
        ],
      },
      {
        kind: "info",
        title: "Defender o Rei",
        text: [
          "Gyoku no hayanige hatte no toku (玉の早逃げ八手の得): fugir com o Rei antes do ataque chegar vale oito lances. Um Rei que se afasta a tempo obriga o adversário a recomeçar.",
          "Teki no uchitai tokoro ni ute (敵の打ちたい所に打て): coloque uma peça na casa onde o adversário quer colocar a dele. Na defesa, isso fecha o buraco antes do drop.",
        ],
      },
      {
        kind: "info",
        title: "Escolher as trocas",
        text: [
          "Shūban wa koma no sontoku yori sokudo (終盤は駒の損得より速度): no final, a velocidade vale mais que o material. Entregue uma peça se isso dá um tsumero (詰めろ) e o adversário não tem um mais rápido.",
          "E o contrário: quando estiver na frente, troque peças e simplifique. Sem peças na mão, o adversário não consegue montar ataques.",
        ],
      },
    ],
  },
];

const TSUME: Lesson[] = [
  {
    id: "tsume-rules",
    part: "tsume",
    title: "Problemas de mate",
    term: "Tsume shōgi 詰将棋",
    summary: "As regras dos problemas e duas formas de mate.",
    steps: [
      {
        kind: "info",
        title: "As regras",
        text: [
          "Num tsume shōgi (詰将棋), o atacante só joga lances de xeque, e o defensor escolhe a resposta que mais demora a levar mate. O defensor pode bloquear com qualquer peça que não esteja no tabuleiro nem na mão do atacante.",
          "Resolver problemas treina a visão de mate. Os profissionais resolvem dezenas por dia: os de 1 a 5 lances viram reflexo, e no final da partida eles aparecem sem que você precise procurar.",
        ],
      },
      {
        kind: "exercise",
        title: "Dragão a uma casa",
        sfen: setup({ "1b": "k", "1a": "l", "1c": "p", "2c": "p", "3f": "+R", "9i": "K" }),
        focus: ["1b"],
        text: [
          "Ikken-ryū (一間竜): o Dragão na mesma fileira do Rei, com uma casa vazia entre os dois. Ele ataca o Rei e as casas em volta pela diagonal, e o Rei não consegue capturá-lo.",
          "Dê mate em um lance.",
        ],
        goal: { type: "mate", solution: "3f3b" },
        hint: "O Dragão sobe pela coluna 3 até a fileira do Rei.",
        success: "Mate! Colado no Rei, o Dragão seria capturado; a uma casa de distância, ele domina tudo.",
      },
      {
        kind: "exercise",
        title: "Prata na cabeça",
        sfen: "6lk1/9/8R/9/7S1/9/9/9/K8 b S 1",
        text: ["Mate em 3. Primeiro a Torre dá xeque e promove; depois a Prata da mão termina."],
        goal: { type: "line", line: ["1c2c+", "2a1a", ["S*2b", "S*1b"]], mate: true },
        hint: "A Torre vai a 2c e promove, dando xeque de baixo.",
        success: "Mate! A Prata na frente do Rei, protegida pelo Dragão, é o atama-gin (頭銀), primo do atama-kin (頭金).",
      },
    ],
  },
  {
    id: "sutegoma",
    part: "tsume",
    title: "Sacrifícios",
    term: "Sutegoma 捨て駒",
    summary: "Entregue uma peça para tirar um defensor do lugar.",
    steps: [
      {
        kind: "exercise",
        title: "Desvie a Prata",
        sfen: "7sk/8n/7R1/6N2/9/9/9/9/K8 b S 1",
        focus: ["2a", "2b"],
        text: [
          "Sutegoma (捨て駒) é a peça entregue de propósito: o adversário captura, e a peça que capturou sai de onde estava defendendo.",
          "Mate em 3. A Prata vermelha em 2a defende 2b. Dê a ela outra coisa para fazer.",
        ],
        goal: { type: "line", line: ["S*2b", "2a2b", ["2c2b+", "3d2b+"]], mate: true },
        hint: "Coloque a Prata da mão em 2b, dando xeque.",
        success: "Mate! A Prata capturou e deixou 2a sem defesa... e a casa 2b ficou para o Dragão (龍).",
      },
      {
        kind: "exercise",
        title: "Puxe o Ouro",
        sfen: "8k/8g/6pLS/9/9/9/9/9/K8 b BS 1",
        focus: ["1b", "2b"],
        text: ["Mate em 3. O Ouro em 1b protege o Rei. Entregue uma peça para tirá-lo do lugar."],
        goal: { type: "line", line: ["S*2b", "1b2b", ["1c2b+", "2c2b+"]], mate: true },
        hint: "A Prata da mão vai a 2b, ao lado do Ouro.",
        success: "Mate! O Ouro saiu de 1b para capturar, e a sua Prata entrou no lugar dele.",
      },
    ],
  },
  {
    id: "uchifuzume-trap",
    part: "tsume",
    title: "Quando o Peão não pode",
    term: "Uchifuzume 打ち歩詰め",
    summary: "Mate com Peão da mão é proibido: encontre outro jeito.",
    steps: [
      {
        kind: "exercise",
        title: "Outra peça no lugar",
        sfen: setup({ "1a": "k", "2a": "n", "2b": "p", "2c": "S", "9i": "K" }, "PL"),
        focus: ["1b"],
        text: [
          "Colocar o Peão da mão em 1b daria mate, mas é proibido: uchifuzume (打ち歩詰め).",
          "Dê mate em um lance com outra peça da mão.",
        ],
        goal: { type: "mate", solution: "L*1b" },
        hint: "A Lança também anda para a frente: coloque-a no mesmo lugar.",
        success: "Mate! Os problemas usam essa regra o tempo todo: a solução \"óbvia\" com Peão é proibida, e o mate pede outra peça.",
      },
      {
        kind: "exercise",
        title: "Peão do tabuleiro pode",
        sfen: setup({ "1a": "k", "2a": "n", "2b": "p", "1c": "P", "4e": "B", "9i": "K" }),
        focus: ["1c"],
        text: [
          "A proibição vale só para o Peão colocado da mão. Empurrar um Peão que já está no tabuleiro e dar mate é permitido (突き歩詰め, tsukifuzume).",
          "Dê mate em um lance.",
        ],
        goal: { type: "mate", solution: "1c1b+" },
        hint: "O Bispo em 4e protege 1b de longe.",
        success: "Mate! O mesmo Peão em 1b, mas vindo do tabuleiro: vale.",
      },
    ],
  },
  {
    id: "tsume3",
    part: "tsume",
    title: "Mates em 3",
    term: "Santezume 3手詰め",
    summary: "Três problemas para treinar.",
    steps: [
      {
        kind: "exercise",
        title: "Duas Torres",
        sfen: "7k1/6p2/9/9/8R/9/9/9/K8 b R 1",
        text: ["Mate em 3."],
        goal: { type: "line", line: ["R*1a", "2a2b", ["1e1c+", "1e1c"]], mate: true },
        hint: "Uma Torre dá xeque pela fileira a, colada ao Rei; a outra termina pela coluna 1.",
        success: "Mate! As duas Torres trabalham em fileiras vizinhas: uma fecha a fileira a, a outra a fileira c.",
      },
      {
        kind: "exercise",
        title: "Capture e cubra",
        sfen: "6k2/9/6n2/9/6R2/9/9/9/K8 b G 1",
        text: ["Mate em 3."],
        goal: { type: "line", line: ["3e3c+", "3a2a", "G*2b"], mate: true },
        hint: "A Torre captura o Cavalo e promove.",
        success: "Mate! Atama-kin (頭金) protegido pelo Dragão (龍).",
      },
      {
        kind: "exercise",
        title: "Torre colada",
        sfen: "9/6k1p/8l/7l1/4B4/9/9/9/K8 b GR 1",
        text: ["Mate em 3. O Bispo de longe ajuda."],
        goal: { type: "line", line: ["R*2b", "3b3a", ["G*4b", "G*3b"]], mate: true },
        hint: "A Torre vai colada ao Rei, numa casa que o Bispo protege.",
        success: "Mate! O Bispo em 5e protegia a Torre de longe, pela diagonal: o Rei não pôde capturá-la.",
      },
    ],
  },
  {
    id: "tsume5",
    part: "tsume",
    title: "Mates em 5",
    term: "Gotezume 5手詰め",
    summary: "Cinco lances, todos de xeque.",
    steps: [
      {
        kind: "exercise",
        title: "A Torre no canto",
        sfen: "6k2/4l1s2/6g2/5+R3/4G4/9/9/9/K8 b GR 1",
        text: ["Mate em 5: você, o adversário, você, o adversário, você. Todos os seus lances dão xeque."],
        goal: { type: "line", line: ["R*1a", "3a2b", "G*1b", "2b2c", "1b1c"], mate: true },
        hint: "A Torre da mão começa de longe, pela fileira a.",
        success: "Mate! A Torre em 1a empurrou o Rei para a coluna 2 e o Ouro desceu pela coluna 1 atrás dele: o Rei foi levado até a casa onde o Dragão (龍) em 4d fechava as saídas.",
      },
      {
        kind: "exercise",
        title: "Torre e Dragão",
        sfen: "8g/4n1k2/5R2p/9/9/9/9/9/K8 b R 1",
        text: ["Mate em 5."],
        goal: { type: "line", line: ["R*4b", "3b3a", "4c3c+", "3a2a", ["3c3b", "4b3b+"]], mate: true },
        hint: "A Torre da mão vai colada ao Rei, na fileira b, protegida pela outra Torre.",
        success: "Mate! Uma Torre empurra pela fileira b, a outra promove na coluna 3, e o Rei fica preso entre o Dragão (龍) e o próprio Ouro.",
      },
    ],
  },
  {
    id: "hisshi",
    part: "tsume",
    title: "A rede sem saída",
    term: "Hisshi 必至",
    summary: "Quando não há mate, crie a ameaça que não tem defesa.",
    steps: [
      {
        kind: "exercise",
        title: "Capture sem dar xeque",
        sfen: "8k/9/7p1/6G2/9/9/9/9/K8 b G 1",
        focus: ["1a", "2c"],
        text: [
          "Não há mate agora. Encontre um lance que não seja xeque, mas depois do qual o Rei não escape mais. Depois, dê o mate.",
        ],
        goal: { type: "line", line: ["3d2c", "1a2a", ["G*2b", "G*3b"]] },
        hint: "O Ouro captura o Peão em 2c e fica perto do Rei.",
        success: "Hisshi (必至)! Com o Ouro em 2c, qualquer resposta deixava o Ouro da mão dar mate.",
      },
    ],
  },
  {
    id: "advanced-game",
    part: "tsume",
    title: "Partida avançada",
    term: "Jissen 実戦",
    summary: "Uma partida contra o nível Médio, com o treinador.",
    game: true,
    level: 3,
    steps: [
      {
        kind: "info",
        title: "Hora de jogar",
        sfen: START,
        text: [
          "Agora contra o nível Médio, que já não entrega peças de graça (実戦, jissen). Escolha uma abertura deste módulo: Kakugawari (角換わり), Fortaleza (矢倉), Bōgin (棒銀) ou Anaguma (穴熊).",
          "No final, conte os lances da corrida, procure tsumero (詰めろ) e hisshi (必至), e lembre: xeque só empurra o Rei.",
        ],
      },
    ],
  },
];

export const ADVANCED: Lesson[] = [...OPENINGS, ...TESUJI, ...PLANNING, ...TSUME];
