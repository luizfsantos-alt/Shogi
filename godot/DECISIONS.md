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
- **Botão "Movimentos"** (só nos níveis iniciais): setas saem da borda de cada peça de quem
  joga, mostrando como ela anda. Seta curta = uma casa; seta longa com ponta dupla = qualquer
  distância; o cavalo aponta para a casa do salto. Tocar numa peça do adversário mostra as
  setas dela em **vermelho**. Vermelho significa sempre perigo (xeque, lance proibido, ameaça).
  A onda de luz automática foi descartada: com todas as peças pulsando, ficava ilegível.

## Efeitos ("gordos", referência Hearthstone)

Pegar (sobe, sombra se afasta, inclina), jogar (peso, pausa no impacto, poeira, leve tremor),
captura (arremesso até o komadai), drop (rastro de luz), promoção (vira no ar, faíscas
douradas), xeque (pulso vermelho, vinheta), mate (câmera lenta, explosão). Valores de tempo e
força fáceis de ajustar; opção "efeitos reduzidos" para celulares fracos.

## Mentor

- As mensagens de aprendizado (lance inválido explicado, ajuda no xeque, treinador) são ditas
  por um **personagem mentor**, que aparece num canto só quando fala.
- Arte do mentor: **gerador de imagens**, feita pelo dono do projeto a partir de um briefing de
  prompt fixo (mesmo personagem, várias expressões, fundo transparente). Até lá, um espaço
  reservado no lugar da imagem.

## Escopo da v1 (primeiro APK jogável)

Partida contra a IA nos 5 níveis (recalibrados no aparelho), regras completas, mentor com as
explicações, setas de movimento (botão), desfazer/dica no menu, salvamento automático.
Depois: curso de 32 lições, handicaps, declaração de impasse pelo jogador, exportar SFEN/USI.

## Pastas

```
godot/
  project.godot         # projeto (paisagem, renderizador Mobile)
  DECISIONS.md          # este arquivo
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
