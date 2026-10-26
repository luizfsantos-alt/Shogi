class_name Levels
extends RefCounted
## AI difficulty levels (port of src/ai/levels.ts): the only place to tune the computer's strength.
##
## TODO: recalibrate on the device. These values were calibrated on the PWA (Fairy-Stockfish
## compiled to WebAssembly, 1 thread); the native engine on a phone is faster, so the time-limited
## levels (4 and 5) play stronger than in the browser and the depth-limited ones barely change.
##
## Engine controls: "Skill Level" (-20..20; below 20 the engine looks at several candidate moves
## and deliberately picks a weaker one, so its mistakes stay plausible) and the search limits
## depth / movetime_ms (whichever is reached first; 0 = no limit).
##
## PWA calibration: move quality on 24-40 sample positions, judged by a depth-10 search: with
## 500 ms per move, Skill 0..20 barely differ (average loss 60-70 cp); negative skills jump to
## ~230 cp with ~20% serious mistakes. Depth limits matter much more: full strength at depth 1-6
## loses ~100-130 cp per move, at 1 s ~55 cp. Matches between neighbouring levels: Iniciante 1 x 11
## Fácil; Fácil 0 x 12 Médio; Médio 0 x 12 Difícil; Difícil 0 x 6 Mestre.

const LEVELS := [
	{"id": 1, "name": "Iniciante", "description": "Erra com frequência, inclusive deixando peças sem defesa.", "skill": -15, "depth": 1, "movetime_ms": 0},
	{"id": 2, "name": "Fácil", "description": "Vê ameaças simples, mas ainda erra bastante.", "skill": -5, "depth": 3, "movetime_ms": 0},
	{"id": 3, "name": "Médio", "description": "Joga a sério, com visão tática curta.", "skill": 10, "depth": 3, "movetime_ms": 0},
	{"id": 4, "name": "Difícil", "description": "Forte: pensa cerca de 1 s por jogada.", "skill": 20, "depth": 0, "movetime_ms": 1000},
	{"id": 5, "name": "Mestre", "description": "Força máxima: pensa cerca de 4 s por jogada.", "skill": 20, "depth": 0, "movetime_ms": 4000},
]

## Default for new players: the weakest level.
const DEFAULT_LEVEL := 1

## Strength used for the hint: full strength, short search.
const HINT_LEVEL := {"id": 0, "name": "Dica", "description": "", "skill": 20, "depth": 14, "movetime_ms": 1500}


static func get_level(id: int) -> Dictionary:
	for level in LEVELS:
		if level.id == id:
			return level
	return LEVELS[DEFAULT_LEVEL - 1]
