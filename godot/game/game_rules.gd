class_name GameRules
extends RefCounted
## The rules of one game: ShogiEngine (Fairy-Stockfish) plus what it does not do itself
## (port of src/core/FairyBackend.ts + variants.ts + notation.ts + ui/interaction.ts).
##
## - legal_moves()/is_legal() leave out uchifuzume (checkmate by a dropped pawn);
## - resignation and impasse declaration as game endings;
## - static snapshots of the position (board + hands) parsed from SFEN;
## - squares as Vector2i(col, row) for the UI: col 0..8 from Sente's left (USI files 9..1),
##   row 0..8 from the top (USI ranks a..i), so position.board[row][col].
##
## Moves are USI strings ("7g7f", "P*5e", "8h2b+"), positions SFEN. Colors: "black" = Sente
## (moves first), "white" = Gote. A piece is {color, type, promoted} (see pieces.gd).

const FILES := 9
const RANKS := 9
const START_SFEN := "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1"
const PROMOTION_ZONE_RANKS := 3
const PIECE_TYPES := ["K", "R", "B", "G", "S", "N", "L", "P"]
## Order of the pieces in hand (SFEN order).
const HAND_TYPES := ["R", "B", "G", "S", "N", "L", "P"]
const PROMOTABLE := ["R", "B", "S", "N", "L", "P"]
## Unpromoted pieces with no move on the last N ranks: no drop there, promotion is mandatory.
const IMMOBILE_RANKS := {"P": 1, "L": 1, "N": 2}
## Handicap starts: Gote (the stronger side, "uwate") plays without some pieces and moves first.
const HANDICAPS := [
	{"id": "lance", "label": "Lança (kyō-ochi 香落ち)", "sfen": "lnsgkgsn1/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1"},
	{"id": "bishop", "label": "Bispo (kaku-ochi 角落ち)", "sfen": "lnsgkgsnl/1r7/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1"},
	{"id": "rook", "label": "Torre (hisha-ochi 飛車落ち)", "sfen": "lnsgkgsnl/7b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1"},
	{"id": "two", "label": "Torre e Bispo (nimai-ochi 二枚落ち)", "sfen": "lnsgkgsnl/9/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1"},
]

## The engine holding the game position (also usable directly, e.g. gives_check()).
var engine := ShogiEngine.new()
## Why the last load_position() failed (Portuguese), "" if it did not.
var last_error := ""

var _manual_result := {}
var _legal_cache = null
var _position_cache = null


# ---------------------------------------------------------------- static helpers

static func opposite(color: String) -> String:
	return "white" if color == "black" else "black"


## Starting SFEN for a handicap id; the standard start for "none" or an unknown id.
static func start_sfen_for(handicap: String) -> String:
	for h in HANDICAPS:
		if h.id == handicap:
			return h.sfen
	return START_SFEN


## Vector2i(col, row) -> "7g".
static func square_name(square: Vector2i) -> String:
	return str(FILES - square.x) + char(97 + square.y)


## "7g" -> Vector2i(col, row); Vector2i(-1, -1) if invalid.
static func parse_square(text: String) -> Vector2i:
	if text.length() != 2 or not text[0].is_valid_int():
		return Vector2i(-1, -1)
	var file := int(text[0])
	var rank := text.unicode_at(1) - 96
	if file < 1 or file > FILES or rank < 1 or rank > RANKS:
		return Vector2i(-1, -1)
	return Vector2i(FILES - file, rank - 1)


## "7g7f+" -> {from: Vector2i, to: Vector2i, drop: "", promote: true};
## "P*5e" -> {from: null, to, drop: "P", promote: false}; {} if the text is not a USI move.
static func parse_move(move: String) -> Dictionary:
	if move.length() == 4 and move[1] == "*":
		var to := parse_square(move.substr(2, 2))
		if to.x < 0 or not move[0] in HAND_TYPES:
			return {}
		return {"from": null, "to": to, "drop": move[0], "promote": false}
	if move.length() != 4 and not (move.length() == 5 and move[4] == "+"):
		return {}
	var from := parse_square(move.substr(0, 2))
	var to := parse_square(move.substr(2, 2))
	if from.x < 0 or to.x < 0:
		return {}
	return {"from": from, "to": to, "drop": "", "promote": move.length() == 5}


static func board_move(from: Vector2i, to: Vector2i, promote := false) -> String:
	return square_name(from) + square_name(to) + ("+" if promote else "")


static func drop_move(type: String, to: Vector2i) -> String:
	return type + "*" + square_name(to)


## SFEN -> {board: rows of 9 cells (piece Dictionary or null), side: "black"|"white",
##          hands: {black: {type: count}, white: {...}}, move_number: int}.
## Assumes a valid SFEN (as produced by the engine); see ShogiEngine.set_position for checks.
static func parse_sfen(sfen: String) -> Dictionary:
	var parts := sfen.strip_edges().split(" ", false)
	var board := []
	for text in parts[0].split("/"):
		var row := []
		var promoted := false
		for c in text:
			if c == "+":
				promoted = true
			elif c.is_valid_int():
				for i in int(c):
					row.append(null)
			else:
				var type := c.to_upper()
				row.append(Pieces.make("black" if c == type else "white", type, promoted))
				promoted = false
		board.append(row)
	var hands := {"black": {}, "white": {}}
	var count := 0
	var hand_text: String = parts[2] if parts.size() > 2 else "-"
	if hand_text != "-":
		for c in hand_text:
			if c.is_valid_int():
				count = count * 10 + int(c)
				continue
			var type := c.to_upper()
			var color := "black" if c == type else "white"
			hands[color][type] = hands[color].get(type, 0) + max(count, 1)
			count = 0
	return {
		"board": board,
		"side": "black" if parts[1] == "b" else "white",
		"hands": hands,
		"move_number": int(parts[3]) if parts.size() > 3 else 1,
	}


static func piece_at(position: Dictionary, square: Vector2i):
	if square.x < 0 or square.x >= FILES or square.y < 0 or square.y >= RANKS:
		return null
	return position.board[square.y][square.x]


static func find_king(position: Dictionary, color: String) -> Vector2i:
	for row in RANKS:
		for col in FILES:
			var piece = position.board[row][col]
			if piece != null and piece.type == "K" and piece.color == color:
				return Vector2i(col, row)
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- loading

## Loads a position (default: the standard start) and replays USI moves on it. On failure the
## previous game stays and last_error says why.
func load_position(sfen := "", moves := PackedStringArray()) -> bool:
	var previous := {"sfen": engine.get_start_sfen(), "moves": engine.history(), "manual": _manual_result}
	last_error = ""
	if not engine.set_position(sfen if sfen != "" else START_SFEN, PackedStringArray()):
		last_error = "Posição inválida (SFEN mal formado, sem os dois reis ou com o lado que acabou de jogar em xeque)."
		return false
	_manual_result = {}
	_invalidate()
	for move in moves:
		if not play(move):
			last_error = "Jogada ilegal na lista: %s." % move
			engine.set_position(previous.sfen, previous.moves)
			_manual_result = previous.manual
			_invalidate()
			return false
	return true


# ---------------------------------------------------------------- moves

func side_to_move() -> String:
	return engine.side_to_move()


## Legal moves for the side to move (without uchifuzume); empty once the game is over.
func legal_moves() -> PackedStringArray:
	if _legal_cache == null:
		_legal_cache = PackedStringArray()
		if not result().over:
			for move in engine.legal_moves():
				if not _is_pawn_drop_mate(move):
					_legal_cache.append(move)
	return _legal_cache


func is_legal(move: String) -> bool:
	return legal_moves().has(move)


## Plays a legal move; returns false (and changes nothing) if it is not legal.
func play(move: String) -> bool:
	if not is_legal(move):
		return false
	engine.play(move)
	_invalidate()
	return true


## Takes back the last move and returns it ("" if there is none). If the game ended by
## resignation or declaration, only that ending is cancelled (and "" is returned).
func undo() -> String:
	if not _manual_result.is_empty():
		_manual_result = {}
		_invalidate()
		return ""
	var move := engine.undo()
	_invalidate()
	return move


func history() -> PackedStringArray:
	return engine.history()


func last_move() -> String:
	var moves := history()
	return moves[moves.size() - 1] if moves.size() > 0 else ""


## Uchifuzume: Fairy-Stockfish generates the move and only scores it as a loss afterwards, but
## the rules forbid it. A dropped pawn only checks from the square in front of the enemy king.
func _is_pawn_drop_mate(move: String) -> bool:
	if not move.begins_with("P*") or not engine.gives_check(move):
		return false
	engine.play(move)
	var mate := engine.legal_move_count() == 0
	engine.undo()
	return mate


# ---------------------------------------------------------------- game state

func is_check() -> bool:
	return engine.is_check()


## {over: false} or {over: true, winner: "black"|"white"|"draw", reason: "checkmate"|
## "no-legal-moves"|"repetition"|"perpetual-check"|"impasse"|"resignation"}.
func result() -> Dictionary:
	if not _manual_result.is_empty():
		return _manual_result
	return engine.game_result()


func resign(color: String) -> bool:
	if result().over:
		return false
	_manual_result = {"over": true, "winner": opposite(color), "reason": "resignation"}
	_invalidate()
	return true


## Entering-king (27-point) evaluation for the side to move; see impasse.gd.
func impasse() -> Dictionary:
	return Impasse.evaluate(position(), side_to_move(), is_check())


## Declares an entering-king win for the side to move; false if the conditions are not met.
func declare_impasse() -> bool:
	if result().over or not impasse().can_declare:
		return false
	_manual_result = {"over": true, "winner": side_to_move(), "reason": "impasse"}
	_invalidate()
	return true


# ---------------------------------------------------------------- position

func sfen() -> String:
	return engine.get_sfen()


func initial_sfen() -> String:
	return engine.get_start_sfen()


## Snapshot of the current position (see parse_sfen). Do not modify it: it is cached.
func position() -> Dictionary:
	if _position_cache == null:
		_position_cache = parse_sfen(sfen())
	return _position_cache


func piece_on(square: Vector2i):
	return piece_at(position(), square)


## Pieces in hand of `color`: {type: count}, e.g. {"P": 2, "B": 1}.
func hand(color: String) -> Dictionary:
	return position().hands[color].duplicate()


# ---------------------------------------------------------------- interaction helpers

## Legal moves of the piece on `from`.
func moves_from(from: Vector2i) -> PackedStringArray:
	var prefix := square_name(from)
	var out := PackedStringArray()
	for move in legal_moves():
		if move.begins_with(prefix) and move[1] != "*":
			out.append(move)
	return out


## Legal drops of a piece type from the hand.
func drops_of(type: String) -> PackedStringArray:
	var out := PackedStringArray()
	for move in legal_moves():
		if move.begins_with(type + "*"):
			out.append(move)
	return out


## Squares a selection can go to. selection = {kind: "board", square: Vector2i} or
## {kind: "hand", type: "P"}.
func targets_for(selection: Dictionary) -> Array[Vector2i]:
	var moves := moves_from(selection.square) if selection.kind == "board" else drops_of(selection.type)
	var targets: Array[Vector2i] = []
	for move in moves:
		var to: Vector2i = parse_move(move).to
		if not targets.has(to):
			targets.append(to)
	return targets


## Resolves a tap on `to` with the current selection: {kind: "none"}, {kind: "move", move} or,
## when promotion is optional, {kind: "promotion", promote: "…+", stay: "…"} (ask the player).
func choose_move(selection: Dictionary, to: Vector2i) -> Dictionary:
	var moves := moves_from(selection.square) if selection.kind == "board" else drops_of(selection.type)
	var candidates := []
	for move in moves:
		if parse_move(move).to == to:
			candidates.append(move)
	if candidates.is_empty():
		return {"kind": "none"}
	if candidates.size() == 1:
		return {"kind": "move", "move": candidates[0]}
	var promote: String = candidates[0] if candidates[0].ends_with("+") else candidates[1]
	var stay: String = candidates[1] if candidates[0].ends_with("+") else candidates[0]
	return {"kind": "promotion", "promote": promote, "stay": stay}


## Promotion for a board move from -> to: "optional", "mandatory", "none" (cannot promote) or
## "illegal" (no legal move between those squares).
func promotion_status(from: Vector2i, to: Vector2i) -> String:
	var plain := board_move(from, to)
	var with_plain := is_legal(plain)
	var with_promotion := is_legal(plain + "+")
	if with_plain and with_promotion:
		return "optional"
	if with_promotion:
		return "mandatory"
	return "none" if with_plain else "illegal"


func _invalidate() -> void:
	_legal_cache = null
	_position_cache = null
