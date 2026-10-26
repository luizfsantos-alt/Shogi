# Motor: Fairy-Stockfish como GDExtension

Classe `ShogiEngine` (GDScript) com as regras e a IA do
[Fairy-Stockfish](https://github.com/fairy-stockfish/Fairy-Stockfish) (variante `shogi`), compilado
em C++ nativo com [godot-cpp](https://github.com/godotengine/godot-cpp). Licença GPL-3.0.

```
engine/
  src/                  # shogi_engine.{h,cpp} (a classe), register_types.cpp, fairy.h
  test/                 # test_engine.gd (testes headless), engine_demo.tscn (cena mínima)
  export/               # export_presets.cfg do APK de teste (o CI copia para godot/)
  fetch_deps.sh         # baixa Fairy-Stockfish (commit fixo) e godot-cpp 4.5 em thirdparty/
  gen_bindings.py       # gera os bindings do godot-cpp
  Makefile, build.sh    # compila para ../bin/
bin/
  shogi_engine.gdextension
  libshogi_engine.<plataforma>.template_release.<arch>.so   # não versionados (build/CI)
```

## API

Tudo em **USI** (`7g7f`, `P*5e`, `8h2b+`) e **SFEN**, como no PWA.

| Método | O quê |
| --- | --- |
| `set_position(sfen, moves = [])` → `bool` | `""` = posição inicial. Rejeita SFEN inválido, lance ilegal e posição em que o lado que acabou de jogar está em xeque (como `FairyBackend.load`); se rejeitar, a posição anterior fica. |
| `get_sfen()`, `get_start_sfen()`, `history()`, `side_to_move()` | `side_to_move()` devolve `"black"` (Sente) ou `"white"` (Gote). |
| `legal_moves()` → `PackedStringArray` | Lances do Fairy-Stockfish **incluindo uchifuzume** (ver abaixo). |
| `legal_move_count()`, `is_legal(move)` | |
| `play(move)` → `bool`, `undo()` → lance desfeito ou `""` | |
| `is_check()`, `gives_check(move)` | |
| `game_result()` → `Dictionary` | `{over: false}` ou `{over: true, winner: "black"/"white"/"draw", reason: "checkmate"/"no-legal-moves"/"repetition"/"perpetual-check"}`, lido como `FairyBackend.result()` (`result(true)`). |
| `perft(depth)` → `int` | Perft nativo (benchmark). |
| `start_search(depth, movetime_ms, skill)` → `bool` | Busca assíncrona nas threads do motor; emite **`best_move(move)`** na thread principal (`""` se não há lance). `depth`/`movetime_ms` = 0 → sem esse limite (ambos 0 → profundidade 10, como o PWA). `skill` de −20 a 20. |
| `stop()`, `is_searching()` | `stop()` encerra a busca já, e `best_move` chega com o melhor lance até ali. |
| `configure(threads, hash_mb)` | Threads limitadas a 1–4 (padrão 2), hash padrão 16 MB. |
| `ShogiEngine.engine_info()` | Versão do Fairy-Stockfish. |

**Uchifuzume**: o Fairy-Stockfish gera o drop de peão que dá mate e só o pontua como derrota. O
filtro fica no GDScript, como em `FairyBackend.isPawnDropMate`; ver `legal()` em
`test/test_engine.gd`: para cada `P*` com `gives_check`, `play` → `legal_move_count() == 0` → `undo`.
A IA nunca escolhe esse lance (para ela é derrota).

O Fairy-Stockfish guarda o estado da busca em variáveis globais: **uma busca por vez** no app inteiro
(`start_search` devolve `false` se outra estiver rodando). As posições de cada `ShogiEngine` são
independentes e podem ser usadas durante a busca.

## Build

```bash
godot/engine/build.sh linux     # .so para os testes headless no Linux
godot/engine/build.sh android   # arm64-v8a + x86_64; usa $ANDROID_NDK_ROOT ou baixa o NDK r28c
godot/engine/build.sh all
```

Precisa de `git`, `python3`, `make`, `g++`; o primeiro build leva ~5 min em 4 núcleos (o godot-cpp
é a maior parte). As bibliotecas Android saem com segmentos alinhados a **16 KB**
(`-z max-page-size=16384`) e `libc++` estática. O NDK, as dependências e os `.so` não são
versionados; o workflow **Godot engine** (`.github/workflows/godot-engine.yml`) compila tudo, roda
os testes, exporta um APK de debug com a cena de demonstração, roda esse APK num emulador x86_64 e
publica o APK e os `.so` como artefatos.

Notas:
- Shogi é 9×9, então o Fairy-Stockfish **precisa** de `LARGEBOARDS` (bitboards de 128 bits); não dá
  para desligar. NNUE fica desligado (o PWA também joga com a avaliação clássica).
- O godot-cpp usado é o `godot-4.5-stable` (`compatibility_minimum = "4.5"`), testado com o Godot
  4.7.2.
- Na **primeira** importação do projeto pelo editor (`--import`), o Godot 4.7.2 pode cair ao sair
  (SIGSEGV dentro do editor, depois de a importação terminar) quando acaba de descobrir a extensão.
  A segunda execução sai limpa; o runtime e os testes não são afetados.

## Testes

```bash
godot --headless --path godot --import
godot --headless --path godot -s res://engine/test/test_engine.gd
```

Cobrem perft 1–3 pela API (30, 900, 25 470) e perft 4 nativo (719 731), SFEN/USI, promoção, drops
(nifu, peças sem movimento, uchifuzume com o filtro), cravada e xeque, fins de partida (mate, sem
lances, sennichite, xeque perpétuo) com os mesmos casos de `tests/rules.test.ts`, e a IA (lance legal
dentro do tempo, `stop()`, busca recusada enquanto outra roda, nenhum lance quando está em mate).

A cena `test/engine_demo.tscn` mostra o tabuleiro em texto e os lances legais (toque para jogar, a IA
responde nos 5 níveis do PWA; "IA x IA"). Ao abrir, roda um autoteste (perft e duas buscas) e
imprime as linhas `SELFTEST` no log (logcat, tag `godot`), para medir no aparelho.
`test/screenshot_demo.gd` gera uma captura da cena (com `xvfb-run`).

## Medidas (Linux x86_64, 4 núcleos, 2 threads, hash 16 MB)

| | |
| --- | --- |
| `.so` Linux x86_64 (strip) | 2,7 MB |
| perft 3 pela API GDScript (com filtro de uchifuzume) | ~150 ms |
| perft 3 / perft 4 nativo | 3 ms / 110–130 ms |
| busca depth 1 skill −15 / depth 3 skill 10 | 7 ms / 7–25 ms |
| busca movetime 1000 ms | 1009 ms |
| `stop()` após 300 ms | volta em 301 ms |

## Medidas no Android (CI, emulador x86_64 API 35, 2 núcleos)

| | |
| --- | --- |
| `.so` arm64-v8a / x86_64 (strip, `libc++` estática) | 1,79 MB / 1,82 MB; segmentos LOAD alinhados a 0x4000, `zipalign -P 16` OK |
| APK de debug (template do Godot, arm64 + x86_64) | 60,6 MB |
| perft 3 / perft 4 nativo | 2,5 ms / 109 ms |
| busca depth 3 skill 10 | 58 ms |
| busca movetime 1000 ms | 1025 ms |

O emulador não tem GPU: com o renderizador Mobile o Vulkan do SwiftShader não apresenta os quadros,
então o CI roda no emulador um segundo APK com o renderizador Compatibility. O APK principal continua
com o Mobile (decisão do projeto) e precisa de um aparelho real.
