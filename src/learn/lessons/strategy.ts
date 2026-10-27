import type { Lesson } from "../types";

/**
 * Track C, strategy: proverbs, the phases of a game, Static Rook and Ranging Rook, castles and
 * one complete opening plan. Follows the opening and castle part of HIDETCHI's series, the
 * proverbs (kakugen) commonly taught to beginners and Wikipedia's "Shogi strategy" and
 * "Castle (shogi)" articles.
 */

const START = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1";

/** After 1.P-7f P-3d 2.P-6f P-8d 3.R-6h S-6b: Sente in Shikenbisha, both Kings still to castle. */
const SHIKENBISHA = "ln1gkgsnl/1r1s3b1/p1pppp1pp/1p4p2/9/2PP5/PP2PPPPP/1B1R5/LNSGKGSNL b - 7";

/** Both sides in Yagura: Sente's Gold Fortress (kin-yagura) is ready, Gote's still being built. */
const YAGURA = "ln4knl/1r1s2gb1/p1pp1gspp/1p2ppp2/9/2PPPB3/PPSG1PPPP/1KG4R1/LN4SNL w - 26";

export const STRATEGY: Lesson[] = [
  {
    id: "proverbs",
    title: "Os provérbios",
    term: "Kakugen 格言",
    summary: "Conselhos curtos que os mestres repetem.",
    steps: [
      {
        kind: "info",
        title: "Rei longe da Torre",
        sfen: START,
        focus: ["5i", "2h"],
        text: [
          "O conhecimento estratégico do shogi (将棋) é passado em provérbios, os kakugen (格言). Não são leis: há momentos para quebrá-los, mas no começo eles evitam muitos erros.",
          "Gyokuhi sekkin su bekarazu (玉飛接近すべからず): não deixe o Rei perto da Torre. A Torre é a peça de ataque e a luta acontece em volta dela; o Rei deve ir para o outro lado.",
        ],
      },
      {
        kind: "info",
        title: "Não deixe o Rei no centro",
        focus: ["5i"],
        text: [
          "Igyoku wa sakeyo (居玉は避けよ): evite o Rei parado na casa inicial. Antes de a luta começar, leve o Rei para um canto e cerque-o com Ouros e Pratas: um castelo (囲い, kakoi).",
          "E a divisão do trabalho: ataque com Torre, Bispo, Prata e Cavalo; defenda com os Ouros (e uma Prata).",
        ],
      },
      {
        kind: "info",
        title: "Peões e peças grandes",
        text: [
          "Fu no nai shōgi wa make shōgi (歩のない将棋は負け将棋): sem Peões na mão, a partida está perdida. Os Peões da mão são as ferramentas dos tesuji (手筋).",
          "Ryū wa tekijin ni, uma wa jijin ni (龍は敵陣に、馬は自陣に): o Dragão trabalha melhor no campo inimigo; o Cavalo-dragão, perto do seu Rei, como defensor.",
        ],
      },
      {
        kind: "info",
        title: "Ataque e mate",
        text: [
          "Kin wa naname ni sasoe (金は斜めに誘え): ataque o Ouro pela diagonal, onde ele é cego para trás. Gyoku wa gedan ni otose (玉は下段に落とせ): empurre o Rei inimigo para a última fileira.",
          "Shūban wa koma no sontoku yori sokudo (終盤は駒の損得より速度): no final, a velocidade do ataque vale mais que o material.",
        ],
      },
    ],
  },
  {
    id: "phases",
    title: "As fases da partida",
    term: "Joban 序盤 · Chūban 中盤 · Shūban 終盤",
    summary: "Abertura, meio-jogo e final: o que fazer em cada uma.",
    steps: [
      {
        kind: "info",
        title: "Abertura",
        sfen: SHIKENBISHA,
        text: [
          "Abertura (序盤, joban): decida onde fica a Torre, monte o castelo do Rei e prepare o ataque. Ninguém captura nada ainda.",
          "Um plano simples e sólido vale mais que lances espertos. Abrir a diagonal do Bispo, posicionar a Torre e levar o Rei para o castelo são os três passos.",
        ],
      },
      {
        kind: "info",
        title: "Meio-jogo",
        text: [
          "Meio-jogo (中盤, chūban): a luta começa, geralmente com uma troca de Peões que abre uma coluna para a Torre. Cada lado tenta ganhar material ou romper o castelo adversário.",
          "Conte sempre: quantas peças atacam uma casa e quantas a defendem. E lembre que toda peça capturada volta como drop.",
        ],
      },
      {
        kind: "info",
        title: "Final",
        text: [
          "Final (終盤, shūban): corrida de mate. Quem dá mate primeiro vence, mesmo com menos peças.",
          "Antes de cada lance pergunte: tenho mate? Tenho um xeque que ganha algo? O adversário ameaça mate? Se sim, defenda ou ataque mais rápido.",
        ],
      },
    ],
  },
  {
    id: "rook-styles",
    title: "Torre parada ou Torre lateral",
    term: "Ibisha 居飛車 · Furibisha 振り飛車",
    summary: "As duas grandes famílias de abertura.",
    steps: [
      {
        kind: "info",
        title: "Duas famílias",
        sfen: START,
        focus: ["2h"],
        text: [
          "Toda abertura começa com uma escolha: onde fica a Torre. Na Torre parada (居飛車, ibisha) ela fica na coluna 2 e ataca pela direita. Na Torre lateral (振り飛車, furibisha) ela vai para o centro ou para a esquerda.",
          "Com a Torre lateral, o Rei vai para a direita, longe da Torre, como manda o provérbio. Ela é mais fácil de aprender: o plano é sempre parecido.",
        ],
      },
      {
        kind: "info",
        title: "As colunas da Torre lateral",
        focus: ["5h", "6h", "7h"],
        text: [
          "Cada coluna tem nome: Torre central (中飛車, nakabisha) na 5; Torre na quarta coluna (四間飛車, shikenbisha) na 6; Torre na terceira coluna (三間飛車, sangenbisha) na 7; Torre em frente (向かい飛車, mukaibisha) na 8.",
          "As colunas são contadas a partir da borda do jogador: para Sente (先手), a 6 é a quarta coluna vista da esquerda.",
        ],
      },
      {
        kind: "exercise",
        title: "Mova a Torre",
        sfen: START,
        text: ["Coloque a Torre na coluna 6: a posição do shikenbisha (四間飛車)."],
        goal: { type: "formation", pieces: { "6h": "R" }, solution: ["2h6h"] },
        hint: "A Torre atravessa a fileira h num lance.",
        success: "Shikenbisha (四間飛車)! A Torre está do lado esquerdo; o Rei agora vai para a direita.",
      },
    ],
  },
  {
    id: "mino",
    title: "O castelo Mino",
    term: "Mino-gakoi 美濃囲い",
    summary: "O castelo mais usado com a Torre lateral.",
    steps: [
      {
        kind: "info",
        title: "Castelos",
        sfen: SHIKENBISHA,
        text: [
          "Um castelo (囲い, kakoi) é uma formação de Ouros e Pratas em volta do Rei. Há dezenas: os mais famosos são o Mino (美濃囲い), a Fortaleza (矢倉, yagura), o Barco (舟囲い, funa-gakoi) e o Urso na toca (穴熊, anaguma).",
          "O Mino (美濃囲い, mino-gakoi) é considerado fácil para iniciantes e é usado até por profissionais: o Rei fica num canto seguro e as três peças de defesa se protegem umas às outras.",
        ],
      },
      {
        kind: "exercise",
        title: "Monte o Mino (美濃)",
        sfen: SHIKENBISHA,
        focus: ["2h", "3h", "5h", "4i"],
        text: [
          "Monte o castelo Mino (美濃囲い): Rei em 2h, Prata em 3h, um Ouro em 5h e o outro fica em 4i.",
          "O adversário também leva o Rei dele para longe da Torre. Comece pelo Rei: ele atravessa 4h e 3h até 2h.",
        ],
        goal: {
          type: "line",
          line: ["5i4h", "5a4b", "4h3h", "4b3b", "3h2h", "6a5b", "3i3h", "1c1d", "6i5h"],
          strong: {
            0: { "7i7h": "A Prata em 7h faz parte do shikenbisha (四間飛車) e pode vir antes do castelo." },
            6: { "6i5h": "O Ouro em 5h antes da Prata monta o mesmo Mino (美濃囲い)." },
          },
        },
        hint: "Primeiro leve o Rei até 2h (passando por 4h e 3h); depois a Prata sobe para 3h e o Ouro de 6i vai para 5h.",
        success: "Mino-gakoi (美濃囲い)! O Rei está longe da Torre, e Prata e Ouros se defendem em diagonal.",
      },
      {
        kind: "info",
        title: "Forças e fraquezas",
        focus: ["1g", "1i"],
        text: [
          "O Mino (美濃囲い) é forte contra ataques pelos lados e se monta em poucos lances. O ponto fraco é a borda: o ataque pela coluna 1 (端攻め, hashizeme) e pelas diagonais perto do Rei.",
          "Por isso, muitos jogadores avançam o Peão da borda (1g1f) para dar mais espaço ao Rei.",
        ],
      },
      {
        kind: "info",
        title: "A Fortaleza",
        sfen: YAGURA,
        focus: ["8h", "7h", "7g", "6g"],
        text: [
          "Com a Torre parada, o castelo clássico é a Fortaleza (矢倉, yagura): Rei em 8h, Ouros em 7h e 6g, Prata em 7g. Muitos a consideram a defesa mais forte quando as duas Torres ficam paradas.",
          "Ela leva mais lances para montar e é difícil de romper pela frente, porém mais fraca pelo lado.",
        ],
      },
    ],
  },
  {
    id: "opening-plan",
    title: "Um plano completo",
    term: "Shikenbisha 四間飛車",
    summary: "Nove lances que montam uma abertura sólida.",
    steps: [
      {
        kind: "info",
        title: "O plano",
        sfen: START,
        text: [
          "Vamos montar do zero uma abertura completa de Torre lateral: o shikenbisha (四間飛車) com o castelo Mino (美濃囲い).",
          "1. Abra o Bispo (7g7f). 2. Avance o Peão de 6g para 6f: ele fecha a diagonal e evita a troca de Bispos. 3. Torre para 6h. 4. Prata de 7i para 7h. 5. Rei para 2h, Prata para 3h, Ouro para 5h.",
        ],
      },
      {
        kind: "exercise",
        title: "Monte a abertura",
        sfen: START,
        focus: ["7f", "6f", "6h", "7h", "2h", "3h", "5h"],
        text: ["Monte a formação completa, na ordem do plano. O adversário joga de Torre parada (居飛車, ibisha) e também guarda o Rei."],
        goal: {
          type: "line",
          line: ["7g7f", "3c3d", "6g6f", "8c8d", "2h6h", "7a6b", "7i7h", "5a4b", "5i4h", "4b3b", "4h3h", "6a5b", "3h2h", "1c1d", "3i3h", "7c7d", "6i5h"],
          strong: {
            6: { "5i4h": "Levar o Rei para o castelo antes da Prata também é bom." },
            14: { "6i5h": "O Ouro em 5h antes da Prata monta o mesmo Mino (美濃囲い)." },
          },
        },
        hint: "Siga a ordem: Peões de 7g e 6g, Torre para 6h, Prata de 7i, e então o Mino (美濃囲い).",
        success: "Pronto: shikenbisha (四間飛車) com Mino (美濃囲い). Daqui o plano é esperar o ataque adversário, trocar peões na coluna 6 ou 7 e contra-atacar.",
      },
    ],
  },
  {
    id: "open-file",
    title: "Abrindo uma coluna",
    term: "Fu no kōkan 歩の交換",
    summary: "A troca de Peões que coloca a Torre em jogo.",
    steps: [
      {
        kind: "exercise",
        title: "Troque os Peões",
        sfen: START,
        text: [
          "Na Torre parada, o ataque clássico é avançar o Peão da coluna 2 até ele encontrar o Peão adversário. Depois da troca (歩の交換, fu no kōkan), a Torre chega à 4ª fileira e você ganha um Peão na mão.",
          "Avance o Peão da coluna 2 três vezes e recapture com a Torre.",
        ],
        goal: { type: "line", line: ["2g2f", "8c8d", "2f2e", "8d8e", "2e2d", "2c2d", "2h2d"] },
        hint: "Sempre o Peão da coluna 2; quando o Peão vermelho capturar, recapture com a Torre.",
        success: "A Torre está em 2d, mirando o campo inimigo, e o Peão da mão já pode ser usado em um tesuji (手筋). Numa partida real o adversário defende 2c com Prata ou Ouro antes disso, mas a ideia é a mesma.",
      },
    ],
  },
  {
    id: "practice-game",
    title: "Pratique contra o computador",
    term: "Jissen 実戦",
    summary: "Uma partida para usar o plano e as táticas.",
    game: true,
    steps: [
      {
        kind: "info",
        title: "Partida de prática",
        sfen: START,
        text: [
          "Hora da prática (実戦, jissen). Tente o shikenbisha (四間飛車) com o Mino (美濃囲い), procure ataques duplos (両取り) e não entregue peças soltas.",
          "O treinador avisa quando o Rei ficar parado no centro, quando houver um ataque duplo ou uma peça sua sem defesa.",
        ],
      },
    ],
  },
];
