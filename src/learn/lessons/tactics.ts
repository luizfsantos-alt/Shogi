import { setup } from "../board";
import type { Lesson } from "../types";

/**
 * Track B, tactics (tesuji 手筋). Ideas and names follow the tesuji articles of the i-tsu-tsu
 * shogi school and Wikipedia's "Shogi tactics"; the mating problems were found with a solver
 * and are checked by the tests (tests/lessons.test.ts), as are the moves Fairy-Stockfish must agree with.
 */

const KINGS = { "5i": "K", "5a": "k" };
/** Sente's king in a small castle, so the exercise is about the tactic and not about a counterattack. */
const SAFE_KING = { "2h": "K", "3h": "S", "3i": "G", "2g": "P", "1g": "P" };

export const TACTICS: Lesson[] = [
  {
    id: "values",
    title: "Quanto vale cada peça",
    term: "Koma no kachi 駒の価値",
    summary: "Ganhe peças de graça e não entregue as suas.",
    steps: [
      {
        kind: "info",
        title: "Uma tabela para começar",
        sfen: setup(KINGS),
        text: [
          "Uma tabela comum para iniciantes: Peão 1, Lança 3, Cavalo 4, Prata 5, Ouro 6, Bispo 8, Torre 10. Promovidas valem mais: Cavalo-dragão (龍馬) cerca de 10 e Dragão (龍王) cerca de 12.",
          "No shogi (将棋), perder uma peça dói em dobro: ela vai para a mão do adversário e volta contra você. Por isso o erro número um do iniciante é a troca ruim, entregar uma peça boa por uma pior.",
        ],
      },
      {
        kind: "exercise",
        title: "Peça solta",
        sfen: setup({ "5f": "R", "5c": "g", "4b": "s", "1f": "b", ...KINGS }),
        text: ["Duas peças vermelhas estão ao alcance da sua Torre. Qual delas dá para capturar sem perder nada?"],
        goal: { type: "line", line: ["5f1f"] },
        wrong: {
          "5f5c": "A Prata em 4b recaptura: você trocaria a Torre (10) por um Ouro (6). O Bispo em 1f não tem defesa.",
          "5f5c+": "A Prata em 4b recaptura o Dragão: você trocaria a Torre (10) por um Ouro (6). O Bispo em 1f não tem defesa.",
        },
        hint: "Veja quem defende cada peça. Uma delas está protegida pela Prata.",
        success: "Isso! O Bispo estava solto (sem defensor). Antes de capturar, pergunte sempre: quem pode recapturar?",
        engineCheck: true,
      },
      {
        kind: "exercise",
        title: "Troca boa",
        sfen: setup({ "7f": "P", "7e": "b", "7d": "g", "3h": "R", "3e": "p", ...KINGS }),
        text: ["Você pode ganhar um Peão de graça com a Torre ou trocar um Peão por algo bem maior. Escolha a melhor captura."],
        goal: { type: "line", line: ["7f7e"] },
        wrong: { "3h3e": "Ganhar um Peão é bom, mas o seu Peão em 7f pode capturar o Bispo. Mesmo que o Ouro recapture, você troca 1 por 8." },
        hint: "Mesmo que a peça esteja defendida, a troca pode valer a pena se você entrega uma peça bem mais barata.",
        success: "Ótimo: o Ouro pode recapturar, mas você entregou um Peão e levou um Bispo.",
        engineCheck: true,
      },
    ],
  },
  {
    id: "fork",
    title: "Ataque duplo",
    term: "Ryōtori 両取り",
    summary: "Atacar duas peças de uma vez: uma delas cai.",
    steps: [
      {
        kind: "info",
        title: "Duas ameaças, uma resposta",
        sfen: setup({ "5a": "k", "7c": "r", "5c": "g", ...SAFE_KING }, "N"),
        focus: ["7c", "5c"],
        text: [
          "O tesuji (手筋, \"lance de técnica\") mais básico é o ataque duplo, ryōtori (両取り): uma peça ataca duas ao mesmo tempo. O adversário só consegue salvar uma.",
          "O drop torna o ataque duplo muito comum: a peça da mão surge exatamente onde ataca as duas.",
        ],
      },
      {
        kind: "exercise",
        title: "Garfo de Cavalo",
        sfen: setup({ "5a": "k", "7c": "r", "5c": "g", ...SAFE_KING }, "N"),
        text: ["Coloque o Cavalo da mão atacando a Torre e o Ouro ao mesmo tempo. Depois capture o que sobrar."],
        goal: { type: "line", line: ["N*6e", "7c7f", ["6e5c+", "6e5c"]], guide: ["", "A Torre fugiu. Agora capture o que sobrou."] },
        hint: "O Cavalo salta duas para frente e uma para o lado: procure a casa de onde ele alcança 7c e 5c.",
        success: "Garfo de Cavalo! A Torre fugiu e o Ouro caiu. O Cavalo é ótimo para isso porque nenhuma das duas peças consegue capturá-lo.",
        engineCheck: true,
      },
      {
        kind: "exercise",
        title: "Xeque e Torre",
        sfen: setup({ "5a": "k", "9e": "r", "5i": "K" }, "B"),
        text: [
          "O ataque duplo mais famoso é dar xeque e atacar a Torre ao mesmo tempo: ōte-bisha (王手飛車). O Rei precisa sair do xeque, e a Torre fica.",
          "Encontre o drop de Bispo que faz isso.",
        ],
        goal: { type: "line", line: [["B*7c", "B*8d"], "5a5b", ["7c9e", "7c9e+", "8d9e"]] },
        hint: "O Rei e a Torre estão na mesma diagonal: coloque o Bispo entre eles.",
        success: "Ōte-bisha (王手飛車)! O Rei teve que fugir e a Torre caiu. Esse golpe decide muitas partidas de iniciantes: cuidado com o seu Rei e a sua Torre na mesma diagonal.",
        engineCheck: true,
      },
    ],
  },
  {
    id: "wariuchi",
    title: "A Prata pelas costas",
    term: "Wariuchi no gin 割打ちの銀",
    summary: "A Prata ataca para trás, onde o Ouro e a Torre não alcançam.",
    steps: [
      {
        kind: "exercise",
        title: "A Prata que racha",
        sfen: setup({ "3a": "k", "6b": "g", "8b": "r", "7b": "p", ...SAFE_KING }, "S"),
        focus: ["6b", "8b"],
        text: [
          "A Prata anda nas diagonais de trás, e o Ouro não. Uma Prata colocada atrás de duas peças, atacando as duas pelas diagonais de trás, é o wariuchi no gin (割打ちの銀, \"Prata que racha\").",
          "Coloque a Prata da mão atacando o Ouro e a Torre, num lugar onde nenhum dos dois possa capturá-la.",
        ],
        goal: { type: "line", line: ["S*7a", "8b8c", ["7a6b", "7a6b+"]] },
        wrong: { "S*7c": "Daqui a Prata ataca as duas peças, mas o Ouro em 6b a captura (7c é uma diagonal da frente dele)." },
        hint: "Coloque a Prata na fileira a, entre as duas peças.",
        success: "Isso! O Ouro não anda nas diagonais de trás e a Torre não anda na diagonal: a Prata fica intocável. É o provérbio kin wa naname ni sasoe (金は斜めに誘え): ataque o Ouro pela diagonal.",
        engineCheck: true,
      },
    ],
  },
  {
    id: "skewer",
    title: "O espeto",
    term: "Kushizashi 串刺し",
    summary: "Ataque uma peça grande e pegue a que está atrás.",
    steps: [
      {
        kind: "exercise",
        title: "Espeto de Lança",
        sfen: setup({ "5a": "k", "2c": "r", "2a": "g", "3i": "K", "3g": "P" }, "L"),
        focus: ["2c", "2a"],
        text: [
          "A Torre e o Ouro vermelhos estão na mesma coluna. Uma Lança colocada embaixo deles ataca a Torre; se a Torre sair, a Lança pega o Ouro. Isso é o kushizashi (串刺し, \"espeto\").",
          "Coloque a Lança onde o seu Rei a defenda: se a Torre capturar, o Rei recaptura.",
        ],
        goal: { type: "line", line: [["L*2h", "L*2i"], "2c5c", ["2h2a+", "2i2a+"]] },
        wrong: {
          "L*2d": "A Torre captura a Lança e ninguém recaptura. Coloque-a mais embaixo, perto do seu Rei.",
          "L*2e": "A Torre captura a Lança e ninguém recaptura. Coloque-a mais embaixo, perto do seu Rei.",
          "L*2f": "A Torre captura a Lança e ninguém recaptura. Coloque-a mais embaixo, perto do seu Rei.",
          "L*2g": "A Torre captura a Lança e ninguém recaptura. Coloque-a mais embaixo, perto do seu Rei.",
        },
        hint: "O seu Rei em 3i protege 2h e 2i.",
        success: "Espeto! A Torre fugiu e a Lança pegou o Ouro (promovendo, obrigatoriamente, na última fileira).",
      },
    ],
  },
  {
    id: "tataki",
    title: "O Peão de batida",
    term: "Tataki no fu 叩きの歩",
    summary: "Um Peão sacrificado puxa a peça para uma casa ruim.",
    steps: [
      {
        kind: "info",
        title: "Bater com o Peão",
        sfen: setup({ "6a": "k", "4b": "g", "2c": "r", "5i": "K" }, "PN"),
        focus: ["4b", "2c"],
        text: [
          "O tataki no fu (叩きの歩, \"Peão de batida\") é colocar um Peão bem na frente de uma peça inimiga. Se ela capturar, sai do lugar; se não capturar, o Peão avança e promove.",
          "Aqui o Ouro em 4b e a Torre em 2c estão longe para um garfo. Mas se o Ouro descer para 4c…",
        ],
      },
      {
        kind: "exercise",
        title: "Puxe o Ouro",
        sfen: setup({ "6a": "k", "4b": "g", "2c": "r", "5i": "K" }, "PN"),
        text: ["Bata com o Peão na frente do Ouro e, quando ele capturar, faça o garfo de Cavalo."],
        goal: { type: "line", line: ["P*4c", "4b4c", "N*3e"], guide: ["", "O Ouro capturou e desceu para 4c. Agora faça o garfo de Cavalo."] },
        wrong: { "N*3e": "Ainda não: o Cavalo em 3e ataca 4c, mas o Ouro está em 4b. Primeiro puxe o Ouro para 4c." },
        hint: "Primeiro o Peão em 4c. Depois o Cavalo numa casa que alcance 4c e 2c.",
        success: "Garfo! Um Peão sacrificado trouxe o Ouro para a casa do garfo. Por isso dizem fu no nai shōgi wa make shōgi (歩のない将棋は負け将棋): sem Peões na mão, faltam ferramentas.",
      },
      {
        kind: "info",
        title: "O Peão de oposição",
        sfen: setup({ "2h": "R", "2d": "p", "2e": "P", ...KINGS }),
        focus: ["2d", "2e"],
        text: [
          "Primo do tataki é o awase no fu (合わせの歩, \"Peão de oposição\"): colocar um Peão bem na frente de um Peão inimigo, cara a cara, como o Peão em 2e.",
          "Ele força uma troca de Peões no lugar que você escolheu, ou impede o avanço do Peão adversário. Aqui, se o Peão vermelho capturar, a Torre recaptura e a coluna 2 se abre.",
        ],
      },
    ],
  },
  {
    id: "tarefu",
    title: "O Peão pendurado",
    term: "Tarefu 垂れ歩",
    summary: "Um Peão na 4ª fileira que ameaça virar tokin.",
    steps: [
      {
        kind: "exercise",
        title: "Pendure o Peão",
        sfen: setup({ "5a": "k", "3a": "g", "2h": "R", "5i": "K" }, "P"),
        text: [
          "O tarefu (垂れ歩, \"Peão pendurado\") é colocar um Peão uma fileira antes do campo inimigo, apoiado por trás pela Torre. Ele ameaça entrar e virar tokin (と金), e é difícil de parar.",
          "Pendure o Peão na coluna da sua Torre, avance-o e use a Torre quando o adversário capturar.",
        ],
        goal: { type: "line", line: ["P*2d", "3a2b", ["2d2c+", "2d2c"], "2b2c", ["2h2c+", "2h2c"]], guide: ["", "O Ouro veio defender. Avance o Peão mesmo assim.", "O Ouro capturou. Agora use a Torre."] },
        hint: "O Peão vai em 2d, na frente da Torre.",
        success: "O Ouro capturou o tokin (と金) e a Torre levou o Ouro: você trocou um Peão por um Ouro, e a Torre chegou ao campo inimigo.",
      },
    ],
  },
  {
    id: "sokofu",
    title: "O Peão do fundo",
    term: "Sokofu 底歩",
    summary: "Um Peão na última fileira segura a Torre inimiga.",
    steps: [
      {
        kind: "exercise",
        title: "Feche o fundo",
        sfen: setup({ "1i": "K", "2h": "G", "9i": "+r", "5a": "k" }, "P"),
        focus: ["9i"],
        text: [
          "O Dragão vermelho dá xeque pela sua última fileira. Bloqueie com o Peão da mão, numa casa onde ele fique protegido.",
          "Um Peão na sua última fileira é o sokofu (底歩, \"Peão do fundo\").",
        ],
        goal: { type: "line", line: ["P*2i"] },
        wrong: {
          ...Object.fromEntries(
            ["3i", "4i", "5i", "6i", "7i", "8i"].map((square) => [`P*${square}`, "O Dragão captura esse Peão e o xeque continua. Coloque-o onde o Ouro e o Rei o protejam."]),
          ),
          "1i1h": "Fugir sai do xeque, mas o Rei fica sem abrigo. Um Peão no fundo resolve de vez.",
          "2h2i": "Bloquear com o Ouro funciona, mas tira o Ouro da defesa. Um Peão basta.",
        },
        hint: "Coloque o Peão logo abaixo do seu Ouro.",
        success: "Isso! O provérbio diz kinzoko no fu, iwa yori katashi (金底の歩、岩より堅し): \"o Peão embaixo do Ouro é mais firme que uma rocha\".",
      },
    ],
  },
  {
    id: "mate1",
    title: "Mates em 1",
    term: "Ittezume 1手詰め",
    summary: "Padrões de mate para reconhecer na hora.",
    steps: [
      {
        kind: "info",
        title: "Problemas de mate",
        sfen: setup({ "2a": "k", "1a": "l", "3a": "n", "2c": "P", "9i": "K" }, "G"),
        text: [
          "Os japoneses treinam com problemas de mate, o tsume shōgi (詰将棋). Os mais curtos são de um lance (1手詰め, ittezume).",
          "O segredo é olhar para as casas de fuga do Rei: quais estão ocupadas, quais estão atacadas, e o que falta cobrir.",
        ],
      },
      {
        kind: "exercise",
        title: "Ouro na cabeça",
        sfen: setup({ "2a": "k", "1a": "l", "3a": "n", "2c": "P", "9i": "K" }, "G"),
        text: ["Dê mate em um lance."],
        goal: { type: "mate", solution: "G*2b" },
        hint: "Atama-kin (頭金): o Ouro na cabeça do Rei, protegido pelo Peão.",
        success: "Mate! As próprias peças vermelhas tiram as casas de fuga do Rei.",
      },
      {
        kind: "exercise",
        title: "Cavalo no canto",
        sfen: setup({ "1a": "k", "2a": "n", "1b": "p", "3c": "S", "9i": "K" }, "N"),
        text: ["Dê mate em um lance."],
        goal: { type: "mate", solution: "N*2c" },
        hint: "O Cavalo pula: nenhuma peça consegue bloquear o xeque dele.",
        success: "Mate! A Prata cobre 2b e o Rei está preso no canto.",
      },
    ],
  },
  {
    id: "mate3",
    title: "Mates em 3",
    term: "Santezume 3手詰め",
    summary: "Sacrificar para dar mate.",
    steps: [
      {
        kind: "exercise",
        title: "Sacrifício de Torre",
        sfen: "8l/8k/6G2/9/9/9/9/9/K8 b R 1",
        text: [
          "Mate em 3 lances (3手詰め, santezume): você joga, o adversário responde, você dá mate. Todos os seus lances devem dar xeque.",
          "Às vezes é preciso entregar uma peça grande.",
        ],
        goal: { type: "line", line: ["R*2b", "1b1c", "2b2c+"], mate: true },
        hint: "Coloque a Torre colada ao Rei, onde o Ouro a protege.",
        success: "Mate! A Torre empurrou o Rei para 1c e o Dragão fechou a rede.",
      },
      {
        kind: "exercise",
        title: "Sacrifício de Ouro",
        sfen: "9/8k/5sG2/9/9/9/9/9/K8 b G 1",
        text: ["Mate em 3. Comece entregando o Ouro da mão."],
        goal: { type: "line", line: ["G*2c", "1b1a", ["3c2b", "2c2b"]], mate: true },
        hint: "O Ouro da mão vai colado ao Rei, protegido pelo Ouro em 3c.",
        success: "Mate! Um provérbio diz gyoku wa gedan ni otose (玉は下段に落とせ): empurre o Rei para a última fileira, onde ele tem menos saídas.",
      },
      {
        kind: "info",
        title: "Hisshi (必至)",
        text: [
          "Quando não há mate imediato, o objetivo pode ser o hisshi (必至): uma ameaça de mate que o adversário não consegue parar.",
          "No final da partida, quem cria o hisshi (必至) primeiro geralmente vence, mesmo com menos peças. É a ideia do provérbio shūban wa koma no sontoku yori sokudo (終盤は駒の損得より速度): no final, a velocidade vale mais que o material.",
        ],
      },
    ],
  },
];
