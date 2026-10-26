# Shogi (Godot, Android)

Versão nativa para Android, em construção. As decisões estão em [`DECISIONS.md`](DECISIONS.md).
O PWA na raiz do repositório fica congelado como referência.

## Frente visual (`visual/`)

Teste da mesa: tabuleiro em 3D com a câmera quase de cima, as 40 peças, toque e arrasto,
efeitos e a onda de movimento. As jogadas seguem só o padrão de cada peça (sem xeque nem
outras regras: isso vem com o motor). Os lados se alternam, para testar os dois num aparelho.

- `koma_mesh.gd`: a cunha gerada por código, com leves defeitos (semente diferente por peça).
- `koma.gdshader`: madeira, kanji entalhado com tinta no fundo, verniz com brilho, desgaste.
- `textures/kanji/`: máscaras do entalhe, geradas por `tools/make_kanji_textures.mjs` a partir
  da fonte de pincel do PWA.
- `koma.gd`: pegar, carregar, soltar com peso, virar na promoção.
- `fx.gd`: poeira e anel no impacto, faíscas na promoção, tremor, pausa no impacto.
- `table.gd`: a cena (`table.tscn`), o toque, a onda e o menu de ajustes (☰).

Captura de tela para desenvolvimento (precisa de um display; no container, `xvfb-run`):

```bash
godot --path godot --fixed-fps 30 res://visual/table.tscn -- shot=/tmp/a.png demo=promote at=0.8
# demo: start, lift, enemy, impact, promote, capture; count=6 every=0.05 para uma sequência
```

## APK de teste

`export_presets.cfg` tem o preset "Android" (arm64, ID `io.github.luizfsantosalt.shogi`,
paisagem). Com o Android SDK configurado no editor: `godot --headless --path godot
--export-debug Android ../build/shogi.apk`.
