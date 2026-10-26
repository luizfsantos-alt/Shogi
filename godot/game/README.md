# Regras e partida em GDScript (`godot/game/`)

Porte fiel da camada de regras do PWA (`src/core/`, `src/ai/levels.ts`, `src/ui/session.ts`) sobre o
`ShogiEngine` (Fairy-Stockfish, `godot/engine/`). Sem cena e sem UI: a mesa 3D desenha a partir
daqui e chama estes métodos.

| Arquivo | Classe | Porte de |
| --- | --- | --- |
| `game_rules.gd` | `GameRules` | `FairyBackend.ts`, `variants.ts`, `notation.ts`, `ui/interaction.ts` |
| `explain.gd` | `Explain` | `explain.ts` (por que um lance é ilegal) |
| `coach.gd` | `Coach` | `coach.ts` (como sair do xeque, explicação da dica) |
| `impasse.gd` | `Impasse` | `impasse.ts` (regra dos 27 pontos) |
| `levels.gd` | `Levels` | `ai/levels.ts` (5 níveis; **recalibrar no aparelho**) |
| `kifu.gd` | `Kifu` | `kifu.ts` (notação da lista de lances: `P-7f`, `Bx2b+`) |
| `pieces.gd` | `Pieces` | `pieces.ts` (nomes, kanji, movimento) |
| `attacks.gd` | `Attacks` | `attacks.ts` (alcance e casas atacadas) |
| `session.gd` | `GameSession` | `ui/session.ts` (a partida) |

## Convenções

- **Lances** em USI (`7g7f`, `P*5e`, `8h2b+`); **posições** em SFEN.
- **Cores**: `"black"` = Sente (joga primeiro, embaixo), `"white"` = Gote.
- **Casa** = `Vector2i(col, row)`: `col` 0..8 da esquerda de Sente (filas USI 9..1), `row` 0..8 de
  cima (fileiras a..i). `Vector2i(0, 0)` = 9a, `Vector2i(8, 8)` = 1i, `Vector2i(2, 6)` = 7g.
  `GameRules.square_name(v)` / `GameRules.parse_square("7g")` convertem (inválida = `Vector2i(-1, -1)`).
- **Peça** = `{color, type, promoted}`, `type` em `K R B G S N L P`.
- **Posição** (`rules.position()`): `{board: board[row][col] (peça ou null), side, hands: {black:
  {tipo: n}, white: {...}}, move_number}`.
- **Resultado**: `{over: false}` ou `{over: true, winner: "black"/"white"/"draw", reason}` com
  `reason` em `checkmate`, `no-legal-moves`, `repetition` (sennichite), `perpetual-check`, `impasse`,
  `resignation`.

## `GameSession` (extends Node)

```gdscript
var session := GameSession.new()
add_child(session)
session.move_played.connect(_on_move_played)
session.new_game({"mode": "ai", "human_color": "black", "level": 1})
# toque do jogador: session.rules.choose_move(selection, casa) -> session.play(move)
```

**Sinais**

| Sinal | Quando |
| --- | --- |
| `changed()` | qualquer mudança de estado (redesenhar o que depende dele) |
| `move_played(move, info)` | um lance foi jogado (pessoa ou IA). `info = {color, notation, from (Vector2i ou null), to, drop ("" ou tipo), promote, piece (a peça antes de promover), captured (peça ou null), check, by_computer}` |
| `position_reset()` | o tabuleiro foi trocado sem lance (nova partida, `restore`, `undo`): reconstruir |
| `game_over(result)` | fim de partida (mate, sem lances, sennichite, xeque perpétuo, desistência, impasse) |
| `ai_thinking(thinking)` | a IA começou/parou de pensar |
| `hint_ready(hint)` | dica pronta: `{move, notation, facts, from, to, drop}` |
| `engine_failed(message)` | o motor falhou (a IA para de jogar) |

**Estado**: `rules: GameRules`, `settings = {mode: "ai"|"local", human_color, level: 1..5, handicap:
"none"|"lance"|"bishop"|"rook"|"two"}`, `notations: PackedStringArray`, `thinking`, `hint` (`{}` se
não há), `hint_pending`, `engine_error`, `min_think_ms` (padrão 600: tempo mínimo que a IA "pensa").

**Métodos**

| Método | O quê |
| --- | --- |
| `new_game(settings, sfen = "") -> bool` | Com handicap contra a IA, a IA é Gote sem as peças e joga primeiro (a pessoa fica com Sente). |
| `play(move) -> bool` | Lance da pessoa; `false` se não é a vez dela ou o lance é ilegal (`Explain.explain_text(session.rules, move)` diz por quê). Contra a IA, ela responde sozinha. |
| `can_human_move()`, `is_computer(color)` | |
| `undo()`, `can_undo()` | Contra a IA desfaz o par (resposta da IA + lance da pessoa); desistência/impasse é desfeito primeiro, sozinho. Cancela a IA se estiver pensando. |
| `resign()` | A pessoa desiste (a dois: o lado da vez). |
| `declare_impasse() -> bool` | Ver `rules.impasse()`. A IA declara sozinha quando pode. |
| `request_hint()` | Pede a dica (assíncrono → `hint_ready`). Some no próximo lance. |
| `check_help_text() -> String` | Texto do mentor quando o lado da vez está em xeque (`""` se não está). |
| `last_move()` | Último lance (`""` se não há). |
| `to_saved() -> Dictionary`, `restore(saved) -> bool` | `{variant, initial_sfen, moves, settings, resigned, impasse_declared, saved_at}` (JSON). `restore` recusa registro inválido e mantém a partida atual. |
| `save_game(path = "user://partida.json")`, `load_game(path) -> bool` | Salvamento automático. |

A IA usa um `ShogiEngine` próprio (2 threads, 16 MB). O Fairy-Stockfish só faz uma busca por vez no
app inteiro; a sessão espera se outra estiver rodando.

## `GameRules`

`load_position(sfen = "", moves = []) -> bool` (`last_error` diz por que falhou; a partida anterior
fica), `side_to_move()`, `legal_moves()` (**sem uchifuzume**; vazio com a partida encerrada),
`is_legal(move)`, `play(move) -> bool`, `undo() -> String`, `history()`, `last_move()`, `is_check()`,
`result()`, `resign(color)`, `impasse()`, `declare_impasse()`, `sfen()`, `initial_sfen()`,
`position()`, `piece_on(casa)`, `hand(color)`.

Para a interação: `moves_from(casa)`, `drops_of(tipo)`, `targets_for(selection)`,
`choose_move(selection, casa)` → `{kind: "none"}` / `{kind: "move", move}` /
`{kind: "promotion", promote, stay}` (perguntar ao jogador), e `promotion_status(from, to)` →
`"optional"`, `"mandatory"`, `"none"` ou `"illegal"`. `selection` = `{kind: "board", square}` ou
`{kind: "hand", type}`.

Estáticos: `parse_square`, `square_name`, `parse_move`, `board_move`, `drop_move`, `parse_sfen`,
`piece_at`, `find_king`, `opposite`, `start_sfen_for(handicap)`; constantes `START_SFEN`,
`HANDICAPS`, `PROMOTION_ZONE_RANKS`, `IMMOBILE_RANKS`, `HAND_TYPES`.

## Mentor e explicações

- `Explain.explain_move(rules, move)` → `{code, ...}` (os mesmos códigos do PWA: `nifu`,
  `uchifuzume`, `pinned`, `king-into-check`, `still-in-check`, `must-promote`, `dead-piece`…);
  `Explain.explain_board_move(rules, from, to)` para um toque no tabuleiro;
  `Explain.describe_illegal(reason, position)` / `Explain.explain_text(rules, move)` → frase em
  português, idêntica à do PWA.
- `Coach.check_help(rules)` → `{king, attackers, king_moves, captures, blocks}`;
  `Coach.describe_check_help(help, rules)`; `Coach.describe_move(rules, move)` → fatos da dica
  (`"captura o Bispo (a peça vai para a sua mão)"`, `"dá xeque"`…).
- `Attacks.attack_map(position, color)` (casas atacadas, para a onda de ameaça),
  `Attacks.attacks_from(position, casa, peça)` (alcance real de uma peça, para a onda de movimento).
- `Pieces.info(peça)`: nome em português/inglês, romaji, kanji, como anda e os vetores de movimento.

## Testes

```bash
godot --headless --path godot --import
godot --headless --path godot -s res://game/test/test_game.gd
```

353 verificações, ~6 s: casas e lances, perft pela `GameRules` (com o filtro de uchifuzume),
desistência, sennichite, impasse (os casos de `rules.test.ts`), interação, notação (`kifu.test.ts`),
todos os casos de `explain.test.ts` com as mensagens, o teste de "todo lance ilegal tem
explicação" em 6 partidas aleatórias (84 mil lances), ajuda no xeque e fatos da dica
(`explain.test.ts`), e a `GameSession` contra a IA de verdade (`session.test.ts`: resposta da IA, IA
abrindo como Sente, desfazer o par, desfazer cancelando a busca, desistência salva em arquivo e
restaurada, dois jogadores, dica, handicap, impasse declarado pela IA) mais uma partida IA × IA até
o fim. Os testes usam scripts headless como os do motor (não gdUnit4).

## Fora deste porte (por enquanto)

- O curso e o treinador da partida guiada estão em `godot/learn/` (ver o README do Godot).
- Validação completa de SFEN importado (`findSetupProblem`: nifu na posição, peças sem movimento,
  contagem de peças): o motor só confere formato, reis e o lado que acabou de jogar em xeque.
  Importar SFEN/USI é pós-v1.
