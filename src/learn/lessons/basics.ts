import { setup } from "../board";
import type { Lesson } from "../types";

/**
 * Track A, the basics: the board, every piece, captures and drops, promotion, the forbidden
 * moves, check and mate, how a game ends and the starting position. Order and scope follow
 * the beginner part of HIDETCHI's "How to Play Shogi" series.
 */

const START = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1";
/** Both kings in their usual places, for positions about one piece. */
const KINGS = { "5i": "K", "5a": "k" };
/** The enemy camp (promotion zone) of Sente: ranks a to c. */
const ZONE = ["a", "b", "c"].flatMap((rank) => [9, 8, 7, 6, 5, 4, 3, 2, 1].map((file) => `${file}${rank}`));

export const BASICS: Lesson[] = [
  {
    id: "board",
    title: "O tabuleiro e o objetivo",
    term: "Shōgi 将棋",
    summary: "Os dois lados, as casas e como se vence.",
    steps: [
      {
        kind: "info",
        title: "Bem-vindo ao shogi (将棋)",
        sfen: START,
        text: [
          "O shogi (将棋) é o xadrez japonês. Joga-se num tabuleiro de 9 × 9 casas, com 20 peças de cada lado.",
          "Você joga de Sente (先手), \"quem joga primeiro\": as peças de pérola, embaixo. O adversário é Gote (後手), \"quem joga depois\": as peças de laca vermelha, em cima.",
        ],
      },
      {
        kind: "info",
        title: "Para onde as peças apontam",
        text: [
          "No shogi (将棋) de madeira, as peças dos dois lados têm a mesma cor; o que diz de quem é a peça é a ponta, que aponta para o adversário. Aqui, além disso, Sente (先手) é pérola e Gote (後手) é vermelho.",
          "Cada peça tem seu nome em kanji. Toque numa peça para ver o nome e o movimento no painel, ou segure o dedo sobre ela para ver o nome rapidamente. O botão Leitura troca o kanji por marcas que mostram como a peça anda.",
        ],
      },
      {
        kind: "info",
        title: "As casas",
        text: [
          "As colunas são numeradas de 1 a 9, da direita para a esquerda (do seu ponto de vista). As fileiras vão de a (em cima) até i (embaixo).",
          "Uma casa se escreve com a coluna e a fileira: a casa destacada é 5e, o centro do tabuleiro. Seu rei começa em 5i.",
        ],
        focus: ["5e", "5i"],
      },
      {
        kind: "info",
        title: "O objetivo",
        text: [
          "Vence quem der xeque-mate no rei adversário: atacá-lo de um jeito que ele não tenha como escapar. Atacar o rei se chama ōte (王手, xeque); o mate se chama tsumi (詰み).",
          "A grande diferença para o xadrez: a peça que você captura vai para a sua mão e pode voltar ao tabuleiro do seu lado. Por isso o jogo raramente fica vazio, e o ataque nunca acaba.",
          "Agora vamos conhecer as peças, uma de cada vez.",
        ],
      },
    ],
  },
  {
    id: "king",
    title: "O Rei",
    term: "Ōshō 王将 · Gyokushō 玉将",
    summary: "Uma casa em qualquer direção.",
    steps: [
      {
        kind: "info",
        title: "O Rei",
        sfen: setup({ "5e": "K", "5a": "k" }),
        piece: "K",
        focus: ["4d", "5d", "6d", "4e", "6e", "4f", "5f", "6f"],
        text: [
          "O Rei anda uma casa em qualquer direção. Há dois kanji para ele: Sente (先手) usa 玉将 (gyokushō, \"general de jade\") e Gote (後手) usa 王将 (ōshō, \"general rei\"). É a mesma peça.",
          "Proteger o seu rei é a coisa mais importante do jogo.",
        ],
      },
      {
        kind: "exercise",
        title: "Passeio do Rei",
        sfen: setup(KINGS),
        text: ["Leve o Rei até as estrelas (★). O adversário fica parado. Toque no Rei e depois na casa de destino."],
        goal: { type: "reach", stars: ["5g", "4f"], solution: ["5i5h", "5h5g", "5g4f"] },
        hint: "Uma casa por vez: suba pela coluna 5 e depois vá na diagonal.",
        success: "Isso! O Rei anda devagar, uma casa por vez, mas em qualquer direção.",
      },
      {
        kind: "exercise",
        title: "Casas proibidas",
        sfen: setup({ "5h": "K", "1g": "r", "9a": "k" }),
        focus: ["4g", "5g", "6g"],
        text: [
          "A Torre (飛車) vermelha em 1g ataca toda a fileira g. O Rei nunca pode ir para uma casa atacada.",
          "Tente subir o Rei para a fileira g e veja o que acontece.",
        ],
        goal: { type: "illegal", code: "king-into-check", solution: "5h5g" },
        hint: "Toque no Rei e depois numa casa da fileira g.",
        success: "O jogo não deixa: o Rei se colocaria em xeque. Ele pode ir para qualquer outra casa vizinha.",
      },
    ],
  },
  {
    id: "pawn",
    title: "O Peão",
    term: "Fuhyō 歩兵",
    summary: "Uma casa para frente, e captura do mesmo jeito.",
    steps: [
      {
        kind: "info",
        title: "O Peão",
        sfen: setup({ "5g": "P", ...KINGS }),
        piece: "P",
        focus: ["5f"],
        text: [
          "O Peão (歩兵, fuhyō, ou só fu 歩) anda uma casa para frente. Cada lado tem nove.",
          "Diferente do xadrez, ele captura do mesmo jeito que anda: só a peça que está bem à sua frente. Ele não captura na diagonal.",
        ],
      },
      {
        kind: "exercise",
        title: "Capture as peças",
        sfen: setup({ "5h": "P", "5f": "p", "5e": "g", "9i": "K", "1a": "k" }),
        text: ["Avance o Peão e capture as duas peças vermelhas que estão na frente dele."],
        goal: { type: "capture", solution: ["5h5g", "5g5f", "5f5e"] },
        hint: "Sempre em frente: o Peão captura a peça que estiver na casa logo à frente.",
        success: "Muito bem! As peças capturadas foram para a sua mão (aparecem ao lado do seu nome). Logo você vai aprender a usá-las.",
      },
    ],
  },
  {
    id: "lance",
    title: "A Lança",
    term: "Kyōsha 香車",
    summary: "Quantas casas quiser, só para frente.",
    steps: [
      {
        kind: "info",
        title: "A Lança",
        sfen: setup({ "9i": "L", ...KINGS }),
        piece: "L",
        focus: ["9h", "9g", "9f", "9e", "9d", "9c", "9b", "9a"],
        text: [
          "A Lança (香車, kyōsha) anda quantas casas quiser, mas só para frente, e não pula peças. Começa nos cantos do tabuleiro.",
          "Ela é como uma Torre que só anda para frente.",
        ],
      },
      {
        kind: "exercise",
        title: "Na mira da Lança",
        sfen: setup({ "9i": "L", "9f": "p", "9d": "s", ...KINGS }),
        text: ["Capture as duas peças da coluna 9."],
        goal: { type: "capture", solution: ["9i9f", "9f9d"] },
        hint: "A Lança vai longe num lance só, mas para na primeira peça que encontrar.",
        success: "Isso! Dois lances, duas capturas.",
      },
      {
        kind: "exercise",
        title: "Sem marcha a ré",
        sfen: setup({ "1e": "L", ...KINGS }),
        text: ["Tente mover a Lança para trás."],
        goal: { type: "illegal", code: "cannot-move-like-that", solution: "1e1f" },
        hint: "Toque na Lança e depois na casa logo abaixo dela.",
        success: "A Lança nunca volta. Por isso, antes de avançá-la, pense se ela não vai ficar presa lá na frente.",
      },
    ],
  },
  {
    id: "rook",
    title: "A Torre",
    term: "Hisha 飛車",
    summary: "Linhas retas, qualquer distância.",
    steps: [
      {
        kind: "info",
        title: "A Torre",
        sfen: setup({ "5e": "R", "5i": "K", "1a": "k" }),
        piece: "R",
        focus: ["5a", "5b", "5c", "5d", "5f", "5g", "5h", "1e", "2e", "3e", "4e", "6e", "7e", "8e", "9e"],
        text: [
          "A Torre (飛車, hisha, \"carro voador\") anda quantas casas quiser na horizontal ou na vertical, sem pular peças.",
          "Junto com o Bispo, é a peça mais forte. Perder a Torre costuma decidir a partida.",
        ],
      },
      {
        kind: "exercise",
        title: "Três estrelas",
        sfen: setup({ "8h": "R", ...KINGS }),
        text: ["Passe a Torre pelas três estrelas no menor número de lances."],
        goal: { type: "reach", stars: ["8d", "3d", "3h"], solution: ["8h8d", "8d3d", "3d3h"] },
        hint: "Cada lance pode ser longo: dá para fazer em três.",
        success: "Perfeito: a Torre cruza o tabuleiro num lance.",
      },
      {
        kind: "exercise",
        title: "Caçada",
        sfen: setup({ "2h": "R", "2e": "p", "6e": "p", ...KINGS }),
        text: ["Capture os dois peões vermelhos."],
        goal: { type: "capture", solution: ["2h2e", "2e6e"] },
        hint: "Primeiro suba pela coluna 2; depois atravesse a fileira e.",
        success: "Ótimo! Repare que a Torre não pode pular o primeiro peão para pegar o que está atrás.",
      },
    ],
  },
  {
    id: "bishop",
    title: "O Bispo",
    term: "Kakugyō 角行",
    summary: "Diagonais, qualquer distância.",
    steps: [
      {
        kind: "info",
        title: "O Bispo",
        sfen: setup({ "5e": "B", ...KINGS }),
        piece: "B",
        focus: ["4d", "3c", "2b", "1a", "6d", "7c", "8b", "9a", "4f", "3g", "2h", "1i", "6f", "7g", "8h", "9i"],
        text: [
          "O Bispo (角行, kakugyō, ou kaku 角) anda quantas casas quiser nas diagonais, sem pular peças.",
          "No começo do jogo ele fica preso atrás dos peões: abrir a diagonal dele costuma ser o primeiro lance.",
        ],
      },
      {
        kind: "exercise",
        title: "Pela diagonal",
        sfen: setup({ "8h": "B", ...KINGS }),
        text: ["Passe o Bispo pelas duas estrelas."],
        goal: { type: "reach", stars: ["4d", "2f"], solution: ["8h4d", "4d2f"] },
        hint: "A primeira estrela está na mesma diagonal do Bispo.",
        success: "Isso! Duas diagonais, dois lances.",
      },
      {
        kind: "exercise",
        title: "Zigue-zague",
        sfen: setup({ "2h": "B", "4f": "p", "6d": "g", ...KINGS }),
        text: ["Capture o peão e depois o Ouro."],
        goal: { type: "capture", solution: ["2h4f", "4f6d"] },
        hint: "De 4f, o Ouro está na diagonal de cima, para a esquerda.",
        success: "Muito bem! Um Ouro vale bem mais que um peão.",
      },
    ],
  },
  {
    id: "gold",
    title: "O General de Ouro",
    term: "Kinshō 金将",
    summary: "Uma casa, menos nas diagonais de trás.",
    steps: [
      {
        kind: "info",
        title: "O Ouro",
        sfen: setup({ "5e": "G", ...KINGS }),
        piece: "G",
        focus: ["4d", "5d", "6d", "4e", "6e", "5f"],
        text: [
          "O General de Ouro (金将, kinshō, ou kin 金) anda uma casa para frente, para os lados, para trás ou nas duas diagonais da frente.",
          "Ele não vai nas diagonais de trás. É o melhor defensor do Rei, e várias peças promovidas passam a andar como ele.",
        ],
      },
      {
        kind: "exercise",
        title: "O ponto cego",
        sfen: setup({ "5h": "G", ...KINGS }),
        text: ["Passe o Ouro pelas duas estrelas. Lembre: ele não anda nas diagonais de trás."],
        goal: { type: "reach", stars: ["6g", "7h"], solution: ["5h6g", "6g7g", "7g7h"] },
        hint: "De 6g, a casa 7h fica na diagonal de trás: são precisos dois lances para chegar lá.",
        success: "Isso! Esse \"ponto cego\" nas diagonais de trás é a fraqueza do Ouro, e muitos ataques exploram exatamente isso.",
      },
      {
        kind: "exercise",
        title: "Dois peões",
        sfen: setup({ "5g": "G", "4f": "p", "6f": "p", ...KINGS }),
        text: ["Capture os dois peões."],
        goal: { type: "capture", solution: ["5g4f", "4f5f", "5f6f"] },
        hint: "Capture um deles na diagonal da frente e ande de lado até o outro.",
        success: "Muito bem!",
      },
    ],
  },
  {
    id: "silver",
    title: "O General de Prata",
    term: "Ginshō 銀将",
    summary: "Uma casa para frente ou nas diagonais.",
    steps: [
      {
        kind: "info",
        title: "A Prata",
        sfen: setup({ "5e": "S", ...KINGS }),
        piece: "S",
        focus: ["4d", "5d", "6d", "4f", "6f"],
        text: [
          "O General de Prata (銀将, ginshō, ou gin 銀) anda uma casa para frente ou em qualquer uma das quatro diagonais.",
          "Ele não anda para os lados nem direto para trás. É uma peça de ataque ágil, que avança e recua em zigue-zague.",
        ],
      },
      {
        kind: "exercise",
        title: "Zigue-zague",
        sfen: setup({ "5h": "S", ...KINGS }),
        text: ["Passe a Prata pelas duas estrelas. Ela não anda para o lado!"],
        goal: { type: "reach", stars: ["4g", "6g"], solution: ["5h4g", "4g5f", "5f6g"] },
        hint: "Para ir de 4g até 6g, suba na diagonal e desça na outra diagonal.",
        success: "Isso! Um provérbio diz: gin wa chidori ni tsukae (銀は千鳥に使え), \"use a Prata em zigue-zague, como o voo do maçarico\".",
      },
      {
        kind: "exercise",
        title: "Para o lado, não",
        sfen: setup({ "5e": "S", ...KINGS }),
        text: ["Tente mover a Prata uma casa para o lado."],
        goal: { type: "illegal", code: "cannot-move-like-that", solution: "5e4e" },
        hint: "Toque na Prata e depois na casa ao lado dela.",
        success: "Não pode: os lados e a casa de trás são os pontos cegos da Prata.",
      },
    ],
  },
  {
    id: "knight",
    title: "O Cavalo",
    term: "Keima 桂馬",
    summary: "Salta duas para frente e uma para o lado.",
    steps: [
      {
        kind: "info",
        title: "O Cavalo",
        sfen: setup({ "5e": "N", ...KINGS }),
        piece: "N",
        focus: ["4c", "6c"],
        text: [
          "O Cavalo (桂馬, keima, ou kei 桂) salta para uma das duas casas que ficam duas à frente e uma para o lado. Ele pula qualquer peça no caminho.",
          "Ao contrário do cavalo do xadrez, ele só tem esses dois saltos, e só para frente.",
        ],
      },
      {
        kind: "exercise",
        title: "Saltos",
        sfen: setup({ "8i": "N", "8h": "P", "7h": "P", ...KINGS }),
        text: ["Leve o Cavalo pelas duas estrelas, pulando os seus peões."],
        goal: { type: "reach", stars: ["7g", "8e"], solution: ["8i7g", "7g8e"] },
        hint: "De 8i, o Cavalo salta para 7g ou 9g.",
        success: "Isso! O Cavalo é a única peça que pula as outras.",
      },
      {
        kind: "exercise",
        title: "Ataque de Cavalo",
        sfen: setup({ "2i": "N", "2h": "P", "3h": "P", "4e": "g", ...KINGS }),
        text: ["Capture o Ouro com o Cavalo."],
        goal: { type: "capture", solution: ["2i3g", "3g4e"] },
        hint: "São dois saltos.",
        success: "Muito bem! O Ouro não consegue se defender do Cavalo: o salto não passa por nenhuma das casas que ele controla.",
      },
      {
        kind: "exercise",
        title: "Sem volta",
        sfen: setup({ "5e": "N", ...KINGS }),
        text: ["Tente fazer o Cavalo voltar para trás."],
        goal: { type: "illegal", code: "cannot-move-like-that", solution: "5e4g" },
        hint: "Toque no Cavalo e depois numa casa atrás dele.",
        success: "O Cavalo nunca volta. Um provérbio avisa: keima no takatobi fu no ejiki (桂馬の高跳び歩の餌食), \"o Cavalo que salta alto vira comida de peão\".",
      },
    ],
  },
  {
    id: "hand",
    title: "Capturas e drops",
    term: "Mochigoma 持ち駒 · Uchi 打ち",
    summary: "A peça capturada muda de lado e volta ao jogo.",
    steps: [
      {
        kind: "info",
        title: "A peça muda de dono",
        sfen: setup({ "2h": "R", "2d": "b", ...KINGS }),
        text: [
          "No shogi (将棋), a peça capturada não sai do jogo: ela vai para a sua mão e passa a ser sua. As peças na mão se chamam mochigoma (持ち駒).",
        ],
      },
      {
        kind: "exercise",
        title: "Capture o Bispo",
        sfen: setup({ "2h": "R", "2d": "b", ...KINGS }),
        text: ["Capture o Bispo vermelho e veja ele aparecer na sua mão, ao lado do seu nome."],
        goal: { type: "capture", solution: ["2h2d"] },
        hint: "A Torre sobe pela coluna 2.",
        success: "O Bispo agora é seu: está na sua mão, virado para o adversário.",
      },
      {
        kind: "info",
        title: "O drop",
        sfen: setup(KINGS, "B"),
        text: [
          "Na sua vez, em vez de mover uma peça, você pode colocar uma peça da mão em qualquer casa vazia. Isso se chama uchi (打ち), \"drop\" em inglês.",
          "A peça entra sem promoção, mesmo dentro do campo inimigo. Algumas casas são proibidas para certas peças; você vai ver isso daqui a pouco.",
        ],
      },
      {
        kind: "exercise",
        title: "Seu primeiro drop",
        sfen: setup(KINGS, "B"),
        text: ["Toque no Bispo da sua mão e depois na estrela."],
        goal: { type: "reach", stars: ["5e"], solution: ["B*5e"] },
        hint: "O Bispo está na sua mão, embaixo do tabuleiro.",
        success: "Isso! O drop (打ち) é a arma mais poderosa do shogi (将棋): uma peça pode surgir em qualquer lugar.",
      },
      {
        kind: "exercise",
        title: "Promovida volta normal",
        sfen: setup({ "2h": "R", "2d": "+r", ...KINGS }),
        text: [
          "A peça vermelha em 2d é uma Torre promovida, o Dragão (龍王, ryūō). Capture-a e veja como ela chega à sua mão.",
        ],
        goal: { type: "capture", solution: ["2h2d"] },
        hint: "Suba a Torre pela coluna 2.",
        success: "Na mão ela é uma Torre comum: a peça capturada sempre perde a promoção.",
      },
    ],
  },
  {
    id: "promotion",
    title: "Promoção",
    term: "Naru 成る",
    summary: "No campo inimigo, a peça vira e fica mais forte.",
    steps: [
      {
        kind: "info",
        title: "O campo inimigo",
        sfen: setup(KINGS),
        focus: ZONE,
        text: [
          "As três últimas fileiras do lado do adversário são o campo inimigo (敵陣, tekijin): a zona de promoção.",
          "Quando uma peça entra, sai ou se move dentro dessa zona, você pode virá-la: ela promove (成る, naru) e ganha um movimento novo. Aqui, a peça promovida ganha ouro.",
        ],
      },
      {
        kind: "exercise",
        title: "Vire Dragão",
        sfen: setup({ "2e": "R", ...KINGS }),
        piece: "+R",
        text: [
          "Leve a Torre para o campo inimigo e promova. A Torre promovida é o Dragão (龍王, ryūō): anda como a Torre e também uma casa nas diagonais.",
        ],
        goal: { type: "line", line: [["2e2b+", "2e2c+", "2e2a+"]] },
        wrong: {
          "2e2a": "Você entrou no campo inimigo sem promover. Aqui não há motivo para isso: escolha \"Promover\".",
          "2e2b": "Você entrou no campo inimigo sem promover. Aqui não há motivo para isso: escolha \"Promover\".",
          "2e2c": "Você entrou no campo inimigo sem promover. Aqui não há motivo para isso: escolha \"Promover\".",
        },
        hint: "Suba a Torre pela coluna 2 até a fileira c, b ou a e escolha \"Promover\".",
        success: "Seu Dragão está pronto! O Bispo promovido também ganha um nome: Cavalo-dragão (龍馬, ryūma), que anda como o Bispo e também uma casa na horizontal e na vertical.",
      },
      {
        kind: "info",
        title: "Tokin (と金)",
        sfen: setup({ "2d": "P", ...KINGS }),
        piece: "+P",
        text: [
          "O Peão promovido se chama tokin (と金) e anda como o Ouro. Prata, Cavalo e Lança promovidos também passam a andar como o Ouro.",
          "Ouro e Rei não promovem.",
        ],
      },
      {
        kind: "exercise",
        title: "Peão que vira Ouro",
        sfen: setup({ "2d": "P", ...KINGS }),
        text: ["Passe pelas duas estrelas. Só um Peão promovido consegue andar para o lado…"],
        goal: { type: "reach", stars: ["2c", "3c"], solution: ["2d2c+", "2c3c"] },
        hint: "Ao entrar em 2c, escolha \"Promover\": o tokin (と金) anda para o lado.",
        success: "Isso! Um tokin (と金) custa só um Peão, mas tem a força de um Ouro. E, se o adversário capturá-lo, ganha só um Peão.",
      },
      {
        kind: "exercise",
        title: "Promoção obrigatória",
        sfen: setup({ "3d": "N", ...KINGS }),
        text: [
          "A promoção é opcional, com uma exceção: quando a peça ficaria sem nenhum lance possível. Peão e Lança na última fileira, Cavalo nas duas últimas: nesses casos ela promove sozinha.",
          "Salte com o Cavalo até a estrela.",
        ],
        goal: { type: "reach", stars: ["2b"], solution: ["3d2b+"] },
        hint: "De 3d, o Cavalo salta para 2b ou 4b.",
        success: "O Cavalo promoveu sozinho: em 2b, sem promover, ele não teria mais para onde saltar.",
      },
    ],
  },
  {
    id: "forbidden",
    title: "Os drops proibidos",
    term: "Nifu 二歩 · Uchifuzume 打ち歩詰め",
    summary: "Três regras que todo iniciante esquece.",
    steps: [
      {
        kind: "exercise",
        title: "Dois peões na coluna",
        sfen: setup({ "5g": "P", ...KINGS }, "P"),
        focus: ["5g"],
        text: [
          "Você não pode ter dois peões não promovidos na mesma coluna. Isso se chama nifu (二歩, \"dois peões\"), e é o erro mais comum de quem está começando.",
          "Tente colocar o Peão da sua mão em 5e, na mesma coluna do seu Peão.",
        ],
        goal: { type: "illegal", code: "nifu", solution: "P*5e" },
        hint: "Toque no Peão da sua mão e depois em 5e.",
        success: "Proibido: nifu (二歩). Em qualquer outra coluna o drop seria permitido. (Um tokin (と金) não conta: ele já não é Peão.)",
      },
      {
        kind: "exercise",
        title: "Peça sem saída",
        sfen: setup(KINGS, "N"),
        text: [
          "Também não se pode colocar uma peça onde ela nunca mais poderia se mexer: Peão ou Lança na última fileira, Cavalo nas duas últimas. São as peças sem saída (行き所のない駒, ikidokoro no nai koma).",
          "Tente colocar o Cavalo da mão em 4b.",
        ],
        goal: { type: "illegal", code: "dead-piece", solution: "N*4b" },
        hint: "Toque no Cavalo da sua mão e depois em 4b.",
        success: "Proibido: em 4b o Cavalo não teria para onde saltar. Lembre que a peça da mão entra sem promover.",
      },
      {
        kind: "exercise",
        title: "Mate com Peão da mão",
        sfen: "7lk/9/7G1/9/9/9/9/9/4K4 b P 1",
        focus: ["1b"],
        text: [
          "A última: é proibido dar xeque-mate colocando um Peão da mão. Isso se chama uchifuzume (打ち歩詰め).",
          "Aqui, um Peão em 1b daria mate. Tente.",
        ],
        goal: { type: "illegal", code: "uchifuzume", solution: "P*1b" },
        hint: "Toque no Peão da sua mão e depois em 1b.",
        success: "Proibido: uchifuzume (打ち歩詰め). Mas dar mate avançando um Peão que já está no tabuleiro é permitido (突き歩詰め, tsukifuzume), e dar xeque sem mate com o Peão da mão também.",
      },
    ],
  },
  {
    id: "check",
    title: "Xeque e xeque-mate",
    term: "Ōte 王手 · Tsumi 詰み",
    summary: "Fugir, capturar ou bloquear; e o primeiro mate.",
    steps: [
      {
        kind: "info",
        title: "Três saídas",
        sfen: setup({ "5i": "K", "5c": "r", "5a": "k" }),
        focus: ["5c"],
        text: [
          "Quando o seu Rei é atacado, ele está em xeque (王手, ōte), e você precisa resolver isso já. Há três jeitos:",
          "1. fugir com o Rei; 2. capturar a peça que ataca; 3. colocar uma peça no caminho, do tabuleiro ou da mão. Uma peça colocada para bloquear um xeque se chama aigoma (合駒).",
        ],
      },
      {
        kind: "exercise",
        title: "Fuja",
        sfen: setup({ "5i": "K", "5c": "r", "5a": "k" }),
        text: ["A Torre vermelha dá xeque pela coluna 5. Tire o Rei de lá."],
        goal: { type: "line", line: ["*"] },
        hint: "Saia da coluna 5: qualquer casa vizinha fora dela serve.",
        success: "Salvo! Fora da coluna 5 a Torre não alcança o Rei.",
      },
      {
        kind: "exercise",
        title: "Capture",
        sfen: setup({ "5i": "K", "8g": "B", "5d": "r", "5a": "k" }),
        text: ["Xeque de novo. Desta vez há uma saída muito melhor que fugir."],
        goal: { type: "line", line: ["8g5d"] },
        wrong: Object.fromEntries(
          ["5i4h", "5i6h", "5i4i", "5i6i"].map((move) => [move, "Fugir tira do xeque, mas olhe o seu Bispo: dá para capturar a Torre de graça!"]),
        ),
        hint: "O seu Bispo alcança a Torre pela diagonal.",
        success: "Excelente! Você saiu do xeque e ainda ganhou a Torre.",
      },
      {
        kind: "exercise",
        title: "Bloqueie",
        sfen: setup({ "5i": "K", "4i": "G", "6i": "G", "4h": "S", "6h": "S", "5b": "l", "1a": "k" }, "P"),
        text: ["A Lança vermelha dá xeque e o seu Rei está cercado pelas próprias peças. Coloque uma peça no caminho."],
        goal: { type: "line", line: ["*"] },
        hint: "Uma das suas peças pode entrar na coluna 5, ou você pode colocar o Peão da mão em qualquer casa entre a Lança e o Rei.",
        success: "Bloqueado! Repare como o Rei, cercado pelas próprias peças, só tinha essa saída.",
      },
      {
        kind: "exercise",
        title: "Seu primeiro mate",
        sfen: "4k4/9/4P4/9/9/9/9/9/4K4 b G 1",
        text: [
          "Agora é você quem ataca. Dê xeque-mate (詰み, tsumi) com o Ouro da mão: o Rei vermelho não pode ter nenhuma saída.",
        ],
        goal: { type: "mate", solution: "G*5b" },
        hint: "Coloque o Ouro bem na frente do Rei, onde o seu Peão o protege.",
        success: "Mate! Esse padrão se chama atama-kin (頭金), \"Ouro na cabeça\": o mate mais comum do shogi (将棋).",
      },
      {
        kind: "exercise",
        title: "Mate no corredor",
        sfen: setup({ "5a": "k", "4b": "p", "5b": "p", "6b": "p", "5i": "K" }, "R"),
        text: ["O Rei vermelho está preso atrás dos próprios peões. Dê mate com a Torre da mão."],
        goal: { type: "mate", solution: "R*9a" },
        hint: "Ataque o Rei pela fileira a, de longe.",
        success: "Mate! O Rei não tinha para onde ir, e ninguém conseguia bloquear.",
      },
    ],
  },
  {
    id: "ending",
    title: "Como a partida termina",
    term: "Tōryō 投了 · Sennichite 千日手",
    summary: "Mate, desistência, repetição e impasse.",
    steps: [
      {
        kind: "info",
        title: "Mate e desistência",
        sfen: setup(KINGS),
        text: [
          "A partida acaba no xeque-mate (詰み, tsumi). Ficar sem nenhum lance legal também é derrota (é raríssimo).",
          "Na prática, quase toda partida termina antes, com a desistência (投了, tōryō): quem vê que vai levar mate desiste. No shogi (将棋) isso é normal e educado.",
        ],
      },
      {
        kind: "info",
        title: "Repetição",
        text: [
          "Se a mesma posição (com as mesmas peças na mão e o mesmo jogador da vez) aparecer quatro vezes, é empate: sennichite (千日手, \"mil dias de lances\").",
          "Exceção: se a repetição vier de xeques seguidos de um lado só (連続王手の千日手, renzoku ōte no sennichite), quem dava os xeques perde.",
        ],
      },
      {
        kind: "info",
        title: "Impasse",
        text: [
          "Quando os dois Reis entram no campo inimigo (入玉, nyūgyoku), pode ficar impossível dar mate. Então o jogador da vez pode declarar o impasse (持将棋, jishōgi): vence quem tiver pontos suficientes.",
          "Torre e Bispo valem 5 pontos, as outras peças (menos o Rei) 1. Os detalhes estão no botão Regras. Você vai ver isso pouco no começo.",
        ],
      },
    ],
  },
  {
    id: "setup",
    title: "A posição inicial",
    term: "Shoki haichi 初期配置",
    summary: "Onde cada peça começa e os primeiros lances.",
    steps: [
      {
        kind: "info",
        title: "A posição inicial",
        sfen: START,
        focus: ["1i", "2i", "3i", "4i", "5i", "6i", "7i", "8i", "9i"],
        text: [
          "Na fileira de trás, do centro para fora: Rei, os dois Ouros, as duas Pratas, os dois Cavalos e as duas Lanças.",
          "Na fileira do meio, o Bispo à esquerda (8h) e a Torre à direita (2h). Na frente, os nove peões. O adversário tem a mesma posição, espelhada.",
        ],
      },
      {
        kind: "exercise",
        title: "Abra o Bispo",
        sfen: START,
        text: [
          "O primeiro lance mais popular é avançar o Peão da coluna 7 (7g7f): ele abre a diagonal do Bispo.",
          "Depois avance o Peão da coluna 2 (2g2f), que abre caminho para a Torre atacar. Jogue os dois; o computador responde.",
        ],
        goal: { type: "line", line: ["7g7f", "3c3d", "2g2f", "8c8d"] },
        wrong: { "2g2f": "Também é um ótimo lance! Mas vamos começar pelo Peão da coluna 7 (7g7f)." },
        hint: "Primeiro o Peão de 7g, depois o de 2g.",
        success: "Ótimo começo: o Bispo respira e a Torre já mira o campo inimigo. Gote (後手) fez o mesmo do lado dele.",
      },
    ],
  },
  {
    id: "first-game",
    title: "Sua primeira partida",
    term: "Taikyoku 対局",
    summary: "Contra o computador, com dicas no caminho.",
    game: true,
    steps: [
      {
        kind: "info",
        title: "Hora de jogar",
        sfen: START,
        text: [
          "Você já conhece todas as regras. Agora jogue uma partida (対局, taikyoku) contra o computador no nível Iniciante.",
          "Durante a partida, um treinador vai comentar momentos importantes: a primeira captura, a chance de promover, um xeque, uma peça desprotegida… Use o botão Dica quando quiser.",
        ],
      },
    ],
  },
];
