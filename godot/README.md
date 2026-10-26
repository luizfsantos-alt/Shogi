# Shogi (Godot, Android)

Versão nativa para Android, em construção. As decisões estão em [`DECISIONS.md`](DECISIONS.md).
O PWA na raiz do repositório fica congelado como referência.

## Partida (`app/`)

`app/game.tscn` é a cena principal: partida contra o computador nos 5 níveis do PWA, escolhendo o
lado. O motor (`engine/`, `ShogiEngine`) decide o que é legal (com o filtro de uchifuzume) e joga
pelo computador; a mesa anima; o mentor (`app/mentor.gd`, retrato provisório 師) explica lances
recusados, avisa do xeque e dá dicas. No menu ☰: nova partida, desfazer, dica, desistir e os
ajustes dos efeitos. A partida é salva sozinha em `user://partida.json` e pode ser continuada.

As explicações completas (porte de `explain.ts`, `coach.ts`, `impasse.ts`, `session.ts`) estão
sendo escritas em `game/` no branch do motor; por enquanto `game_screen.gd` tem uma versão curta.

Captura de tela: `godot --path godot --fixed-fps 30 res://app/game.tscn -- shot=/tmp/a.png
demo=reply at=3` (demos: `dialog`, `reply`, `illegal`, `hint`).

## Frente visual (`visual/`)

Teste da mesa: tabuleiro em 3D com a câmera quase de cima, as 40 peças, toque e arrasto,
efeitos e as setas de movimento. As jogadas seguem só o padrão de cada peça (sem xeque nem
outras regras: isso vem com o motor). Os lados se alternam, para testar os dois num aparelho.

- `koma_mesh.gd`: a cunha gerada por código, com leves defeitos (semente diferente por peça).
- `koma.gdshader`: laca perolada (Sente) ou vermelha (Gote), kanji entalhado com tinta preta ou
  ouro no fundo, verniz com brilho, desgaste. O ruído vem de uma textura pequena compartilhada.
- `textures/kanji/`: máscaras do entalhe, geradas por `tools/make_kanji_textures.mjs` com a
  Kaisei Tokumin ExtraBold (`fonts/`, OFL, reduzida aos caracteres das peças).
- `arrows.gd`, `arrow.gdshader`: as setas do botão "Movimentos".
- `koma.gd`: pegar, carregar, soltar com peso, virar na promoção.
- `fx.gd`: poeira e anel no impacto, faíscas na promoção, tremor, pausa no impacto.
- `table.gd`: a cena (`table.tscn`), o toque, as setas e o menu de ajustes (☰).

Captura de tela para desenvolvimento (precisa de um display; no container, `xvfb-run`):

```bash
godot --path godot --fixed-fps 30 res://visual/table.tscn -- shot=/tmp/a.png demo=promote at=0.8
# demo: start, lift, arrows, enemy, impact, promote, capture; count=6 every=0.05 para uma sequência
```

## APK de teste

O workflow **Godot app** (`.github/workflows/godot-app.yml`) compila o motor para Android, roda
os testes, exporta o APK (arm64, ID `io.github.luizfsantosalt.shogi`, paisagem), assina com a
chave de teste de `ci/` e publica uma **pre-release** no GitHub a cada push. A versão vem de
`config/version` no `project.godot` e aparece na tela, ao lado do ☰.
