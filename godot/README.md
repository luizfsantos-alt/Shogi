# Shogi (Godot, Android)

Versão nativa para Android, em construção. As decisões estão em [`DECISIONS.md`](DECISIONS.md).
O PWA na raiz do repositório fica congelado como referência.

## Telas (`app/`)

`app/home.tscn` é a cena principal. O autoload `App` (`app/app.gd`) troca de tela (com um fade) e
guarda os ajustes em `user://ajustes.json`; o botão "voltar" do Android sobe uma tela.

- **Início** (`home.gd`): a mesa 3D ao fundo, o menu à esquerda (Continuar partida, Jogar,
  Aprender a jogar com o progresso, Ajustes) e as boas-vindas do tengu na primeira abertura.
- **Partida** (`game.tscn`, `game_screen.gd`): contra o computador nos 5 níveis do PWA, escolhendo
  o lado (painel `ui/new_game_panel.gd`). A `GameSession` (`game/`) decide o que é legal, joga
  pelo computador e salva a partida (`user://partida.json`); a mesa anima; o mentor explica lances
  recusados (`Explain`), diz como sair do xeque (`Coach`) e dá dicas em palavras. Na **partida
  guiada** do curso, o treinador (`learn/coach_tips.gd`) comenta os momentos importantes e marca as
  casas. No menu ☰: início, nova partida, desfazer, dica, declarar impasse, desistir e os ajustes.
- **Curso** (`course.gd`): duas abas. **Iniciante**: as três trilhas lado a lado; **Avançado**: a trilha D,
  uma coluna por parte (aberturas, táticas, planejamento, mates). Abre na aba da próxima lição.
- **Lição** (`lesson.gd`): a mesa com a posição do passo, estrelas ★ para alcançar, casas em foco,
  dica, recomeçar e o painel da peça (`ui/piece_card.gd`). Ao terminar: estrelas (1 a 3) e a próxima
  lição.

O visual segue o Genpei do PWA (`ui/ui_theme.gd`): fundo queimado, Archivo condensada, rótulos em
IBM Plex Mono, botões chanfrados, vermelho para ação e ouro para valor; os kanji da interface vêm
da Potta One reduzida aos caracteres usados (`node scripts/make-kanji-font.mjs --godot`).

### O mentor (tengu 天狗) e os rivais

`app/mentor.gd` e `app/mentor/mascot.gd`. O tengu é pixel art em seis poses
(`app/mentor/art/tengu_<pose>.png`, todas na mesma tela, para uma trocar a outra no lugar):
calmo, explicando (mão erguida), apontando com o leque (objetivo, dica, treinador), assustado
(xeque), rindo (acerto, vitória) e bravo (lance proibido). Quem fala escolhe a pose:
`say(text, seconds, pose)`, `note(text, title, pose)`, `speak(pages, title, pose)`. Ele respira
devagar (`mentor/breath.gdshader`): o corpo sobe um pixel e volta; o tapete fica parado. Dois
tamanhos:

- **grande** (`speak`): o que precisa ser lido até o fim (boas-vindas, explicações das lições,
  fim da partida guiada). O tengu inteiro (3 pixels de tela por pixel da arte), a tela escurece e
  cada toque no balão mostra a próxima página. Nas lições, o tabuleiro desliza para a direita;
- **pequeno** (`say`, `note`): falas enquanto o jogador mexe as peças, com só a cabeça da pose
  num medalhão.

Os **rivais** (`app/rivals/rivals.gd`), um por nível: Kappa, Ashigaru, Kitsune, Benkei e Kiyomori.
O rosto aparece em Nova partida e no canto da partida, e troca pelo rosto derrotado quando você
vence. Sem a arte (Kitsune, por enquanto), aparece o kanji.

**A arte.** As imagens geradas ficam em `art_source/` (JPEG sobre preto).
`python3 -I godot/art_source/prepare_art.py` acha a grade de pixels de cada uma (3×3 nos
retratos), recorta o fundo, reduz a um pixel por bloco, fecha a paleta e grava os PNG em `app/`
(tengu, rivais, emblemas das trilhas em `app/course_art/`, ícone em `app/icon/`). Tudo é
desenhado com filtro *nearest*.

### O curso (`learn/`)

As 52 lições vêm do PWA: `node scripts/export-lessons.mjs` gera `learn/course.json` a partir de
`src/learn/` (o teste `tests/godotCourse.test.ts` falha se o arquivo ficar desatualizado). Duas
frases que citam botões do PWA são trocadas no carregamento (`Course.APP_WORDING`).

| Arquivo | Classe | Porte de |
| --- | --- | --- |
| `course.gd` | `Course` | `course.ts` + progresso (`user://curso.json`) |
| `lesson_session.gd` | `LessonSession` | `LessonSession.ts` (passos, objetivos, respostas do adversário, dicas, estrelas) |
| `coach_tips.gd` | `CoachTips` | `coachTips.ts` (o treinador da partida guiada) |

Testes: `godot --headless --path godot -s res://learn/test/test_learn.gd`. São 1286 verificações:
todos os 72 exercícios resolvidos pela `LessonSession`, mates conferidos por busca, os casos de
`lessons.test.ts` e `coachTips.test.ts`, progresso salvo e a cobertura da fonte de kanji.

Capturas de tela (demos em `_demo` de cada tela):

```bash
godot --path godot --fixed-fps 30 res://app/home.tscn -- shot=/tmp/a.png demo=welcome at=3
godot --path godot --fixed-fps 30 res://app/course.tscn -- shot=/tmp/a.png at=1
godot --path godot --fixed-fps 30 res://app/lesson.tscn -- shot=/tmp/a.png lesson=rook step=1 demo=move at=2
godot --path godot --fixed-fps 30 res://app/game.tscn -- shot=/tmp/a.png demo=guided at=3
```

## Frente visual (`visual/`)

Teste da mesa: tabuleiro em 3D com a câmera quase de cima, as 40 peças, toque e arrasto,
efeitos e as setas de movimento. As jogadas seguem só o padrão de cada peça (sem xeque nem
outras regras: isso vem com o motor). Os lados se alternam, para testar os dois num aparelho.

Dois visuais (`DECISIONS.md`, "Visual pixel"). O **pixel**, padrão: peças grossas com luz em
faixas e contorno (`koma_pixel.gdshader`, `koma_outline.gdshader`), um kanji em pixel com as marcas
de movimento (`textures/kanji_px/`, de `tools/make_pixel_kanji.mjs` com a DotGothic16), mesa de
pedra, chão de lajes (`ground.gdshader`), vinheta em degraus e efeitos em pixel. O **clássico**, de
laca e madeira, volta com Ajustes › "Visual pixel" desligado. O uniform global `pixel_look`
(`project.godot`) troca os efeitos de uma vez; `Table.set_pixel_look` troca tudo sem recarregar.

- `koma_mesh.gd`: a cunha gerada por código, com leves defeitos (semente diferente por peça).
- `koma.gdshader`: (clássico) laca perolada (Sente) ou vermelha (Gote), kanji entalhado com a
  tinta no fundo, verniz com brilho, desgaste. O ruído vem de uma textura pequena compartilhada.
- `textures/kanji/`: máscaras do entalhe, geradas por `tools/make_kanji_textures.mjs` com a
  Kaisei Tokumin ExtraBold (`fonts/`, OFL, reduzida aos caracteres das peças).
- `arrows.gd`, `arrow.gdshader`: as setas do botão "Movimentos".
- `koma.gd`: pegar, carregar, soltar com peso, virar na promoção. `Koma.INK` é a cor do kanji
  de cada tipo de peça, a mesma no Sente e no Gote (os dois shaders a recebem em `ink_kind`).
- `fx.gd`: poeira e anel no impacto, faíscas na promoção, tremor, pausa no impacto.
- `table.gd`: a cena (`table.tscn`), o toque, as setas e o menu de ajustes (☰). As coordenadas
  (colunas 9…1 em cima, fileiras a…i à direita) são `Label3D` deitados na moldura do tabuleiro;
  `set_view_side` as recoloca para quem joga de Gote.

Captura de tela para desenvolvimento (precisa de um display; no container, `xvfb-run`):

```bash
godot --path godot --fixed-fps 30 res://visual/table.tscn -- shot=/tmp/a.png demo=promote at=0.8
# demo: start, lift, arrows, enemy, impact, promote, capture; count=6 every=0.05 para uma sequência
# look=classic para o visual de laca e madeira
```

## APK de teste

O workflow **Godot app** (`.github/workflows/godot-app.yml`) compila o motor para Android, roda
os testes, exporta o APK (arm64, ID `io.github.luizfsantosalt.shogi`, paisagem), assina com a
chave de teste de `ci/` e publica uma **pre-release** no GitHub a cada push. A versão vem de
`config/version` no `project.godot` e aparece na tela, ao lado do ☰.
