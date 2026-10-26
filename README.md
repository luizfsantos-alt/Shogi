# Shogi Web

Shogi (xadrez japonês) no navegador, fiel às regras oficiais, para **aprender jogando contra o
computador**. As regras e a IA vêm do [Fairy-Stockfish](https://github.com/fairy-stockfish/Fairy-Stockfish)
compilado para WebAssembly. Funciona no computador e no celular; não precisa de servidor próprio.

## O que tem

- **Tela inicial**: continuar a partida em andamento, **Jogar** ou **Aprender**.
- **Curso interativo "Aprender a jogar"**, no próprio tabuleiro, em três trilhas (32 lições):
  - **A. Fundamentos** (基本): o tabuleiro, cada peça com exercícios ("leve até a ★", "capture",
    "tente o lance proibido"), capturas e drops, promoção, nifu e os outros drops proibidos,
    xeque e mate, fim da partida, posição inicial e uma **primeira partida guiada**;
  - **B. Táticas** (手筋): valor das peças, ataque duplo (両取り) e ōte-bisha, wariuchi no gin,
    espeto, tataki no fu, awase no fu, tarefu, sokofu, mates em 1 e em 3, hisshi;
  - **C. Estratégia** (戦略): provérbios (格言), fases da partida, ibisha × furibisha, o castelo
    Mino montado lance a lance, a Fortaleza, um plano completo de shikenbisha e a troca de peões;
    termina numa partida de prática.
  - Dica (mostra de onde sai e para onde vai), recomeçar, estrelas (1 a 3) por lição e progresso
    salvo no navegador. Todo termo japonês aparece com o seu kanji.
  - Na **partida guiada** um treinador comenta na hora certa: primeiro lance, xeque, ataque duplo
    disponível, peça sem defesa, peça na mão, chance de promover, rei parado no centro.
- **Contra o computador**, em 5 níveis (Iniciante → Mestre), escolhendo o lado (Sente, Gote ou
  aleatório) e, se quiser, um **handicap** (o computador joga sem lança, bispo, torre ou torre e bispo).
  Também dá para jogar a dois no mesmo aparelho.
- **Modo aprendizado**:
  - toda jogada inválida é explicada ("Nifu: você já tem um peão nessa coluna", "Uchifuzume…",
    "Isso deixaria seu rei em xeque", "Você precisa promover"…);
  - painel de cada peça (nome em português / romaji / kanji, diagrama de movimento e de promoção);
  - ajuda quando o rei está em xeque, com as formas de sair;
  - **Dica**: o computador sugere uma jogada e explica em palavras simples (captura, xeque, promoção…);
  - botão **Regras** com um resumo ilustrado;
  - opção para mostrar as casas atacadas pelo adversário.
- Peças com cara de material: o **Sente é pérola** e o **Gote é laca vermelha**, então se vê o time
  de longe; promovidas ganham **ouro**. Por padrão mostram o **kanji** em pincel pesado. O botão
  **Leitura** troca o kanji por marcas que mostram o movimento (talho = qualquer distância,
  dente = uma casa, losango = salto) e o nome da peça, em português ou inglês.
- Brilho na peça selecionada e na peça que acabou de promover (desligado quando o sistema pede
  menos movimento). Tabuleiro de madeira queimada com linhas douradas.
- Destaque da última jogada e do xeque, lista de jogadas, desfazer, virar o tabuleiro, desistir,
  declarar impasse, fim de partida com o motivo.
- Salvamento automático, partidas salvas no navegador, exportar/importar em **SFEN** e **USI**.
- Visual **Genpei**: escuro, com tipografia condensada pesada, rótulos em fonte mono, cantos retos e
  botões chanfrados; vermelho para ação, ouro para valor. Fontes incluídas no app (funciona offline).
- Sons opcionais (desligáveis), layout para celular (retrato e paisagem).
- **PWA**: dá para instalar como aplicativo (celular e computador) e **jogar offline, inclusive
  contra o computador**. Quando sai uma versão nova, o app avisa e atualiza com um toque.

## Como rodar

Requer **Node.js 22.12** ou mais recente.

```bash
npm install
npm run dev      # servidor de desenvolvimento: http://localhost:5173
npm test         # testes (Vitest)
npm run build    # build de produção em dist/
npm run preview  # serve o build localmente: http://localhost:4173
```

Os arquivos do motor de IA (`stockfish.js`, `stockfish.worker.js`, `stockfish.wasm`) são copiados
de `node_modules` para `public/engine/` automaticamente antes de `dev` e `build`
(`scripts/copy-vendor.mjs`).

## Estrutura

```
src/
  core/                 # regras; sem DOM
    types.ts            # tipos compartilhados (Color, Square, Piece, GameResult…)
    GameBackend.ts      # interface que a UI e a IA usam (USI + SFEN)
    FairyBackend.ts     # implementação com ffish.js
    variants.ts         # variantes (por enquanto "shogi"), handicaps, regra de impasse
    notation.ts         # USI <-> notação interna do Fairy-Stockfish
    position.ts         # SFEN: leitura, escrita e validação de posição
    impasse.ts          # declaração de impasse (jishogi, regra dos 27 pontos)
    pieces.ts           # nomes (PT / romaji / kanji) e movimentos de cada peça
    attacks.ts          # casas atacadas / alcance das peças (TS puro, a partir de pieces.ts)
    explain.ts          # POR QUE uma jogada é ilegal
    coach.ts            # ajuda para sair do xeque e explicação simples das dicas
    kifu.ts             # notação legível da lista de jogadas (P-7f, Bx2b+, P*5e)
    usiRecord.ts        # exportar/importar partidas em texto USI
    ffishLoader.ts      # carrega o WebAssembly do ffish.js
  ai/                   # IA; sem DOM
    Engine.ts           # interface do motor (trocável, ex.: YaneuraOu no futuro)
    FairyEngine.ts      # Fairy-Stockfish via protocolo UCI, com cancelamento
    levels.ts           # os 5 níveis (único lugar para ajustar a força)
    uci.ts              # conversão de posições/jogadas para o motor
  worker/               # Web Worker que roda o motor fora da thread da interface
  learn/                # o curso; sem DOM
    types.ts            # trilhas, lições, passos e objetivos (dados)
    board.ts            # monta posições das lições a partir de uma lista de peças
    LessonSession.ts    # uma lição em andamento: objetivo, respostas do adversário, dicas, estrelas
    coachTips.ts        # o treinador da partida guiada
    course.ts           # as três trilhas e a ordem recomendada
    lessons/            # basics.ts, tactics.ts, strategy.ts: o conteúdo
  pwa/
    sw.template.js      # service worker: cache offline + cabeçalhos COOP/COEP (vira dist/sw.js)
    register.ts         # registro, aviso de versão nova, botão "Instalar app"
  ui/
    session.ts          # partida em andamento: turnos, IA, desfazer, dicas (sem DOM, testado)
    App.ts              # telas: início, curso, jogo
    Home.ts             # tela inicial (jogar / aprender)
    CourseView.ts       # mapa do curso e tela da lição
    boardView.ts        # tabuleiro e barras dos jogadores (jogo e lições)
    pressHold.ts, promotion.ts, rich.ts  # nome ao segurar a peça, pergunta de promoção, kanji no texto
    pieceView.ts        # desenho das peças: materiais, kanji, modo leitura, brilho
    pieceCard.ts, diagram.ts, rules.ts   # painel da peça, diagramas, regras
    interaction.ts      # seleção → casas destacadas → jogada / pergunta de promoção
    storage.ts          # salvar/carregar no localStorage
    sound.ts            # sons sintetizados (Web Audio)
scripts/
  copy-vendor.mjs       # copia o motor para public/engine/
  make-icons.cjs        # gera os ícones do app em public/icons/ (precisa do Playwright)
  make-kanji-font.mjs   # refaz a fonte de kanji com todos os caracteres japoneses usados no app
  calibration/          # ferramentas para calibrar os níveis da IA
tests/                  # regras, notação, explicações, motor, sessão, interação, curso
```

A UI nunca fala com o ffish diretamente: tudo passa por `GameBackend`, usando notação USI
(`7g7f`, `P*5e`, `8h2b+`) e SFEN. Internamente o Fairy-Stockfish usa coordenadas de xadrez
(`c3c4`, `P@e5`), e `notation.ts` converte de um para o outro.

## Regras: o que vem do Fairy-Stockfish e o que é nosso

| Regra | Quem cuida |
|---|---|
| Movimentos, capturas para a mão, drops | Fairy-Stockfish |
| Promoção (zona de 3 fileiras; obrigatória para peão/lança na última e cavalo nas duas últimas) | Fairy-Stockfish |
| Nifu, drops sem jogadas futuras | Fairy-Stockfish |
| Xeque, peça cravada, xeque-mate, "sem jogadas = derrota" | Fairy-Stockfish |
| Sennichite (4ª repetição = empate) e xeque perpétuo (quem dá xeque perde) | Fairy-Stockfish, lido com `result(true)` |
| **Uchifuzume** (mate por drop de peão) | **nosso**: o Fairy-Stockfish aceita a jogada e só depois a pontua como derrota de quem dropou; `FairyBackend` a remove das jogadas legais |
| **Impasse / jishogi (27 pontos)** | **nosso** (`impasse.ts`): o Fairy-Stockfish não tem essa regra |
| Desistência | nosso |
| Validação de SFEN importado | nosso (`position.ts`): `validateFen` do ffish 0.7.10 não funciona para shogi |

Impasse: o jogador da vez pode declarar vitória se tiver o rei no campo inimigo, não estiver em
xeque, tiver 10 ou mais peças no campo inimigo e somar pontos suficientes (torre e bispo = 5,
demais = 1, contando campo inimigo e mão): Sente 28, Gote 27. Uma declaração que não cumpre as
condições é recusada (com o motivo) em vez de dar derrota. O computador declara sozinho quando pode.

## Como adicionar uma variante

O Fairy-Stockfish aceita variantes definidas em texto no formato
[`variants.ini`](https://github.com/fairy-stockfish/Fairy-Stockfish/blob/master/src/variants.ini).

1. Em `src/core/variants.ts`, crie um `VariantDefinition` e registre-o em `VARIANTS`.
2. Se a variante não for nativa do Fairy-Stockfish, coloque a seção do `variants.ini` no campo `ini`:

   ```ts
   const MY_SHOGI: VariantDefinition = {
     id: "myshogi",
     label: "Meu Shogi",
     dims: { files: 9, ranks: 9 },
     startSfen: "…",
     promotionZoneRanks: 3,
     pieceTypes: ["K", "R", "B", "G", "S", "N", "L", "P"],
     promotable: ["R", "B", "S", "N", "L", "P"],
     immobileRanks: { P: 1, L: 1, N: 2 },
     noDoubledPawns: true,
     pawnDropMateIllegal: true,
     ini: `
   [myshogi:shogi]
   # mude aqui as regras: peças, promoções, drops...
   `,
   };
   ```
3. `FairyBackend.create(ffish, "myshogi")` carrega a configuração e cria o jogo. Tamanho do
   tabuleiro, zona de promoção etc. vêm da definição; a interface se adapta (nada de "9" fixo).
4. Peças novas precisam de nome e movimento em `src/core/pieces.ts` (usados nos desenhos,
   diagramas e explicações).
5. Para o motor de IA jogar a mesma variante, ele precisa receber o mesmo texto `ini`
   (opção UCI `VariantPath`, gravando o arquivo no sistema de arquivos do WebAssembly no worker).
   Isso ainda não está ligado, porque hoje só existe o Shogi padrão, que já vem embutido.
6. Escreva testes em `tests/` para as regras novas.

## Como ajustar os níveis da IA

Tudo fica em `src/ai/levels.ts`. Cada nível combina:

- `skill` (`Skill Level` do Fairy-Stockfish, -20 a 20): abaixo de 20 o motor escolhe de propósito
  uma jogada pior entre as candidatas, então erra de forma plausível, não aleatória;
- `depth` e/ou `movetimeMs`: limite de profundidade e de tempo (vale o que chegar primeiro).

Para medir o efeito de uma mudança, há duas ferramentas (rodam o motor de verdade no Node):

```bash
# Qualidade das jogadas: quanto cada nível perde (em centipeões) em relação à melhor jogada
POSITIONS=40 npm run calibrate:quality

# Partidas entre dois níveis (cores alternadas, aberturas variadas)
PAIR=2,3 GAMES=12 npm run calibrate:match

# Comparar configurações novas sem editar o arquivo
LEVELS_JSON='[{"id":1,"name":"A","description":"","skill":0,"depth":2},{"id":2,"name":"B","description":"","skill":10,"depth":3}]' GAMES=10 npm run calibrate:match
```

Calibração atual (detalhes no comentário de `levels.ts`):

| Nível | Configuração | Partidas contra o nível anterior |
|---|---|---|
| 1. Iniciante | skill -15, profundidade 1 | — |
| 2. Fácil | skill -5, profundidade 3 | venceu 11 de 12 |
| 3. Médio | skill 10, profundidade 3 | venceu 12 de 12 |
| 4. Difícil | força total, 1 s por jogada | venceu 12 de 12 |
| 5. Mestre | força total, 4 s por jogada | venceu 6 de 6 (partidas mais longas e disputadas) |

Descobertas: com tempo de sobra, o `Skill Level` de 0 a 20 quase não muda a força; o que mais
pesa é o limite de profundidade/tempo, e os valores negativos de skill são os que produzem os
erros grosseiros (bons para iniciantes). `UCI_Elo` existe, mas é calibrado para xadrez e não foi usado.
Entre motores, qualquer diferença vira um placar elástico; contra pessoas os degraus são menores.

## Publicação: cabeçalhos COOP/COEP

O motor de IA (`fairy-stockfish-nnue.wasm`) usa threads de WebAssembly, que exigem
`SharedArrayBuffer`. Os navegadores só liberam isso em páginas "isoladas", então **o servidor
precisa enviar estes dois cabeçalhos** em todas as respostas:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Sem eles o jogo abre, mas só no modo "dois jogadores" (aparece um aviso).

- `npm run dev` e `npm run preview` já enviam os cabeçalhos (`vite.config.ts`).
- **Netlify**: pronto, `netlify.toml` (build) + `public/_headers` (cabeçalhos).
- **Cloudflare Pages**: comando de build `npm run build`, pasta `dist`; o `public/_headers` vale.
- **Vercel**: pronto, `vercel.json`.
- **GitHub Pages**: pronto, com o workflow `.github/workflows/pages.yml`, que roda os testes, faz o
  build e publica a cada push na `main`. Configuração única no GitHub: **Settings → Pages →
  Build and deployment → Source: "GitHub Actions"**. O site fica em
  `https://<usuário>.github.io/<repositório>/` (o workflow ajusta o caminho base com `BASE_PATH`).
  Como o Pages não permite cabeçalhos próprios, o service worker do app os acrescenta pelo
  navegador: na primeira visita a página recarrega sozinha uma vez. Onde service workers estão
  bloqueados (algumas abas anônimas), a IA fica indisponível e o jogo oferece o modo dois jogadores.
- Qualquer outro servidor: configure os dois cabeçalhos acima e sirva a pasta `dist/`.

O ffish.js (regras) não precisa desses cabeçalhos; só o motor de IA.

## PWA (instalar e jogar offline)

- `public/manifest.webmanifest`: nome, cores e ícones (`public/icons/`, gerados por
  `node scripts/make-icons.cjs`).
- `src/pwa/sw.template.js`: o service worker. No `npm run build`, o plugin em `vite.config.ts`
  gera `dist/sw.js` com a lista de todos os arquivos do build (~3,6 MB, incluindo o motor) e uma
  versão calculada do conteúdo. Ele:
  - guarda tudo no aparelho na primeira visita, então o jogo inteiro funciona offline;
  - acrescenta os cabeçalhos COOP/COEP em todas as respostas (necessário no GitHub Pages);
  - páginas: rede primeiro (sempre atualizadas quando online), cache se offline;
    demais arquivos: cache primeiro.
- `src/pwa/register.ts`: registra o service worker (só no build de produção), recarrega a página
  uma vez na primeira visita se faltarem os cabeçalhos, mostra "Nova versão disponível" quando
  um build novo é publicado (a atualização só acontece quando o jogador toca em "Atualizar") e o
  botão "Instalar app" quando o navegador oferece a instalação.
- Como instalar: **Android/Chrome** — botão "Instalar app" ou menu ⋮ → "Instalar app";
  **iPhone/iPad (Safari)** — Compartilhar → "Adicionar à Tela de Início";
  **computador (Chrome/Edge)** — botão "Instalar app" ou o ícone na barra de endereço.
- Em `npm run dev` não há service worker (o servidor de desenvolvimento já envia os cabeçalhos).

## O curso: como editar e de onde vem o conteúdo

As lições são dados em `src/learn/lessons/*.ts`. Cada passo é uma explicação (`info`) ou um
exercício com um objetivo: chegar às estrelas, capturar tudo ou montar uma formação (o adversário
fica parado), seguir uma sequência com respostas do adversário, dar mate, ou tentar um lance
proibido. As posições se escrevem com `setup({ "5i": "K", "5a": "k" }, "G")`.

`tests/lessons.test.ts` confere todas: posições válidas, soluções que resolvem cada exercício,
mates conferidos por busca (o mate em 3 tem um único primeiro lance), lances táticos marcados com
`engineCheck` conferidos pelo Fairy-Stockfish, e todo termo japonês acompanhado do kanji.
Depois de escrever um termo novo, rode `node scripts/make-kanji-font.mjs` para incluir os
caracteres na fonte.

Referências usadas para a estrutura e os conceitos: a série "How to Play Shogi" de HIDETCHI
(regras → táticas → aberturas → castelos), recomendada pelo [Lishogi](https://lishogi.org/resources);
os artigos de tesuji da escola [i-tsu-tsu](https://en.i-tsu-tsu.co.jp/blog/); os verbetes
[Shogi tactics](https://en.wikipedia.org/wiki/Shogi_tactics), [Shogi strategy](https://en.wikipedia.org/wiki/Shogi_strategy)
e [Castle (shogi)](https://en.wikipedia.org/wiki/Castle_(shogi)) da Wikipedia; e os provérbios
(kakugen 格言) listados no [World Shogi Forum do 81Dojo](https://system.81dojo.com/en/topics/28).
Os textos e as posições são nossos.

## Licença e créditos

Este projeto é software livre sob a **GNU General Public License v3.0 ou posterior** (veja
[`LICENSE`](LICENSE)), porque usa bibliotecas GPL-3.0:

- [Fairy-Stockfish](https://github.com/fairy-stockfish/Fairy-Stockfish), de Fabian Fichter e
  colaboradores, baseado no [Stockfish](https://stockfishchess.org/).
- [ffish.js / ffish-es6](https://www.npmjs.com/package/ffish-es6): biblioteca de regras do
  Fairy-Stockfish em WebAssembly (Fabian Fichter, Johannes Czech).
- [fairy-stockfish-nnue.wasm](https://github.com/fairy-stockfish/fairy-stockfish.wasm): motor
  Fairy-Stockfish em WebAssembly.
- [Potta One](https://fonts.google.com/specimen/Potta+One),
  [Archivo](https://fonts.google.com/specimen/Archivo) e
  [IBM Plex Mono](https://fonts.google.com/specimen/IBM+Plex+Mono) (SIL OFL 1.1): fontes incluídas
  em `src/ui/fonts/` (detalhes no README da pasta).

**Aviso GPL:** quem distribuir este programa, inclusive publicando-o na web, deve oferecer o
código-fonte completo sob a mesma licença. O rodapé do jogo já mostra a licença, os créditos e
um link para o código-fonte (`SOURCE_URL` em `src/ui/App.ts`; troque se publicar um fork).
