# Shogi em Godot: decisões

Decisões tomadas antes de começar o projeto Godot (out/2026). O PWA na raiz do repositório
fica **congelado como referência**: sem features novas, continua publicado e serve de
especificação (lições e vetores de teste exportados em JSON).

## Plataforma e stack

- **Só Android**, só **paisagem**.
- Godot 4.5+, GDScript para o jogo, renderizador Mobile.
- Fairy-Stockfish como **GDExtension** (C++, Android NDK r28+, arm64 + x86_64 para o emulador,
  bibliotecas alinhadas a 16 KB). A IA roda numa thread separada, limitada a 2–4 threads.
- O que é nosso (uchifuzume, impasse, explicações, treinador) é portado para GDScript e testado
  com gdUnit4 contra os vetores exportados do PWA.
- Licença GPL-3.0; arte de pacotes pagos, se houver, fica fora do repositório público.
- ID do pacote: `io.github.luizfsantosalt.shogi`. Nome provisório: "Shogi".

## Mesa (tela de jogo)

- **Cena 3D**, câmera **quase de cima** (~15–20° de inclinação).
- Tabuleiro no centro, **komadai nas laterais**, como objetos 3D na mesma cena.
- **Nenhuma interface fixa na mesa**: desfazer, dica, lista de lances, regras etc. ficam todos
  no menu.

## Peças

Do Hearthstone vêm só a **sensação 3D** e os **efeitos gordos**; o resto da estética é nossa.

- Cunha 3D gerada por código, com **leves defeitos** (cantos gastos, faces não perfeitamente
  planas, lascas e arranhões finos; semente diferente por peça, nenhuma igual à outra).
- **Cores (decisão antiga do PWA, retomada):** quem joga primeiro (Sente) em **laca perolada
  com escrita preta**; quem joga depois (Gote) em **laca vermelha com escrita em ouro**. A face
  promovida tem escrita em ouro nos dois lados, e a borda da peça promovida fica dourada. Uma
  peça capturada troca de cor no ar, a caminho do komadai.
- Superfície com **gloss**: verniz com reflexo visível.
- Kanji **entalhado** (sulco com a tinta no fundo), na fonte **Kaisei Tokumin ExtraBold**
  (OFL): pesada e legível, com os traços abertos. A Potta One do PWA ficou ilegível na peça.
- **Botão "Movimentos"** (só nos níveis iniciais): setas bem curtas saem da borda de cada peça
  de quem joga. Ponta simples = uma casa; ponta dupla = qualquer distância (bispo, torre,
  lança); o cavalo mostra um L, como no xadrez (duas casas à frente, uma para o lado). Tocar numa peça do adversário mostra as
  setas dela em **vermelho**. Vermelho significa sempre perigo (xeque, lance proibido, ameaça).
  A onda de luz automática foi descartada: com todas as peças pulsando, ficava ilegível.

### Visual pixel (padrão desde out/2026)

A mesa continua 3D e quase de cima; o pixel entra como **textura**, na mesma família do tengu.
É o visual padrão. Ajustes › "Visual pixel" desligado volta à laca e à madeira (ou `look=classic`
na linha de comando).

- Peças **60% mais grossas**, com bordas mais redondas, luz em **faixas** (sem degradê), um
  brilho duro e **contorno escuro** como num sprite: o 3D fica acentuado.
- **Um kanji só**, em pixel (DotGothic16, OFL), com as **marcas de movimento** gravadas em volta:
  um ponto = uma casa, dois pontos em linha = qualquer distância, cruzinha = o salto do cavalo.
  Máscaras de 32×36 em `visual/textures/kanji_px/` (`tools/make_pixel_kanji.mjs`).
- Gote com kanji **creme** (ouro sobre vermelho some); promovida com kanji vermelho no Sente e
  ouro no Gote, mais a borda dourada.
- Tabuleiro e komadai em **pedra** pixelada (quatro cinzas com dither, rachaduras, a grade
  entalhada com o lábio iluminado).
- Fundo: **lajes de pedra escura** em texels maiores, e a vinheta em degraus com dither.
- Efeitos em pixel: poeira de pedra em blocos que se desfaz em dither, anel de impacto em
  5 quadros, faíscas como cruzinhas em três tons de ouro, casas marcadas com borda de um texel
  e preenchimento quadriculado, setas pixeladas, tremor em passos inteiros, sem bloom.
  Um uniform global (`pixel_look`, em `project.godot`) liga tudo de uma vez.

### Personagens (out/2026)

- O tengu ganha **expressões**: seis poses que reagem ao jogo (explica, aponta, se assusta no
  xeque, ri, fica bravo no lance proibido). A respiração continua.
- **Rivais**, um por nível, do mundo da lenda de Yoshitsune: Kappa, Ashigaru, Kitsune, Benkei
  (o duelo da ponte Gojō) e Kiyomori. Rosto calmo e rosto derrotado.
- **O jogador não tem rosto.**
- Emblemas das trilhas do curso e o ícone do app, na mesma pixel art.

## Efeitos ("gordos", referência Hearthstone)

Pegar (sobe, sombra se afasta, inclina), jogar (peso, pausa no impacto, poeira, leve tremor),
captura (arremesso até o komadai), drop (rastro de luz), promoção (vira no ar, faíscas
douradas), xeque (pulso vermelho, vinheta), mate (câmera lenta, explosão). Valores de tempo e
força fáceis de ajustar; opção "efeitos reduzidos" para celulares fracos.

## Mentor

- As mensagens de aprendizado (lance inválido explicado, ajuda no xeque, treinador) são ditas
  por um **personagem mentor**, que aparece num canto só quando fala.
- O mentor é um **tengu (天狗)**, o mestre da montanha que, na lenda, ensinou Minamoto no
  Yoshitsune. Arte em pixel art do dono do projeto (gerador de imagens), com uma
  **respiração sutil só no corpo**; desde out/2026, seis poses (ver "Personagens").
- **Dois tamanhos**: o tengu **inteiro e grande** nos diálogos que precisam ser lidos até o fim
  (avança tocando no balão); só a **cabeça**, num medalhão, nas falas enquanto o jogador pode
  mexer as peças.

## Escopo da v1 (primeiro APK jogável)

Partida contra a IA nos 5 níveis (recalibrados no aparelho), regras completas, mentor com as
explicações, setas de movimento (botão), desfazer/dica no menu, salvamento automático.
Depois: handicaps, exportar SFEN/USI.

**v0.3** (out/2026): tela inicial e interface no visual Genpei do PWA, o mentor tengu e o curso
completo (as 32 lições exportadas do PWA, com a partida guiada e o treinador).

**v0.4** (out/2026): visual pixel como padrão (peças grossas com um kanji em pixel e as marcas de
movimento, mesa de pedra, efeitos em pixel), o tengu com seis poses, os cinco rivais, os emblemas
das trilhas e o ícone do app.

## Pastas

```
godot/
  project.godot         # projeto (paisagem, renderizador Mobile)
  DECISIONS.md          # este arquivo
  app/                  # telas: início, partida, curso, lição; mentor (tengu); tema
  game/                 # regras e partida em GDScript (porte do PWA)
  learn/                # o curso: lições exportadas do PWA, sessão da lição, treinador
  visual/               # frente visual: peça, tabuleiro, shaders, efeitos
  engine/               # frente do motor: fonte do GDExtension (C++), build com NDK
  bin/                  # bibliotecas compiladas (.so) e o .gdextension
```

## Como trabalhamos

- **Duas frentes em paralelo**, cada uma no seu branch:
  1. **Visual**: uma peça + pedaço do tabuleiro em paisagem, onda dourada (depois trocada pelas setas) e três efeitos
     (pegar, jogar com impacto, promover).
  2. **Motor**: Fairy-Stockfish como GDExtension para Android; cena simples com lances legais
     e uma jogada da IA.
- **APKs de teste**: arquivo direto no chat para testes rápidos e **pre-release no GitHub**
  para as versões marcantes (depois gerada pelo GitHub Actions).
