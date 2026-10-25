# Shogi Web

Shogi (xadrez japonês) no navegador, fiel às regras oficiais, com IA em níveis e um modo de
aprendizado. As regras e a IA vêm do [Fairy-Stockfish](https://github.com/fairy-stockfish/Fairy-Stockfish)
compilado para WebAssembly.

> **Estado:** Fase 1 concluída (motor de regras integrado e testado). A interface jogável chega na Fase 2.

## Como rodar

Requer Node.js 22.12 ou mais recente.

```bash
npm install
npm run dev      # servidor de desenvolvimento (http://localhost:5173)
npm test         # testes (Vitest)
npm run build    # build de produção em dist/
npm run preview  # serve o build localmente
```

## Estrutura

```
src/
  core/                 # regras; sem DOM, sem dependência da UI
    types.ts            # tipos compartilhados (Color, Square, Piece, GameResult…)
    GameBackend.ts      # interface que a UI e a IA usam (USI + SFEN)
    FairyBackend.ts     # implementação com ffish.js
    variants.ts         # definição das variantes (por enquanto só "shogi")
    notation.ts         # USI <-> notação interna do Fairy-Stockfish
    position.ts         # SFEN: leitura, escrita e validação de posição
    impasse.ts          # declaração de impasse (jishogi, regra dos 27 pontos)
    ffishLoader.ts      # carrega o WebAssembly do ffish.js
  ui/                   # interface (Fase 2+)
tests/                  # testes de regras, notação e de fumaça
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

## Como adicionar uma variante

O Fairy-Stockfish aceita variantes definidas em texto no formato
[`variants.ini`](https://github.com/fairy-stockfish/Fairy-Stockfish/blob/master/src/variants.ini).

1. Em `src/core/variants.ts`, crie um `VariantDefinition` e registre-o em `VARIANTS`.
2. Se a variante não for nativa do Fairy-Stockfish, coloque a seção do `variants.ini` no campo
   `ini`. Exemplo:

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
3. `FairyBackend.create(ffish, "myshogi")` carrega a configuração e cria o jogo.
   Tamanho do tabuleiro, zona de promoção etc. vêm da definição — nada de "9" fixo no código.
4. Escreva testes em `tests/` para as regras novas.

Use os mesmos campos `ini` no motor de IA (Fase 4) para que ele jogue a mesma variante.

## Publicação: cabeçalhos COOP/COEP

O motor de IA (`fairy-stockfish-nnue.wasm`) usa threads de WebAssembly, que exigem
`SharedArrayBuffer`. Os navegadores só liberam isso em páginas "isoladas", então **o servidor
precisa enviar estes dois cabeçalhos** em todas as respostas:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

`npm run dev` e `npm run preview` já fazem isso (veja `vite.config.ts`). Para publicar:
- **Netlify / Cloudflare Pages:** arquivo `_headers` com as duas linhas acima.
- **Vercel:** `headers` em `vercel.json`.
- **GitHub Pages:** não permite cabeçalhos próprios; seria preciso um service worker
  (ex.: `coi-serviceworker`). Será avaliado na Fase 5.

O ffish.js (regras) **não** precisa desses cabeçalhos; só o motor de IA.

## Licença e créditos

Este projeto é software livre sob a **GNU General Public License v3.0 ou posterior** (veja
[`LICENSE`](LICENSE)), porque usa bibliotecas GPL-3.0:

- [Fairy-Stockfish](https://github.com/fairy-stockfish/Fairy-Stockfish), de Fabian Fichter e
  colaboradores, baseado no [Stockfish](https://stockfishchess.org/).
- [ffish.js / ffish-es6](https://www.npmjs.com/package/ffish-es6) — biblioteca de regras do
  Fairy-Stockfish em WebAssembly (Fabian Fichter, Johannes Czech).
- [fairy-stockfish-nnue.wasm](https://github.com/fairy-stockfish/fairy-stockfish.wasm) — motor
  Fairy-Stockfish em WebAssembly.

Quem distribuir este programa (inclusive publicando-o na web) deve oferecer o código-fonte
sob a mesma licença.
