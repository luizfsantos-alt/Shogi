class_name GameSession
extends Node
## One game being played (port of src/ui/session.ts): the rules plus turn handling, the computer's
## moves, undo, hint, resignation, impasse, the move list and saving. No UI here: the table scene
## renders from this state, calls these methods and listens to the signals.
##
## Works outside the scene tree too (timers come from the main loop), but adding it to the tree
## keeps it alive while the computer thinks.

## Something changed (any state below): redraw what depends on it.
signal changed
## A move was played (by a person or the computer). info = {color, notation, from (Vector2i or
## null), to, drop ("" or type), promote, piece (the piece that moved, before promotion),
## captured (piece or null), check, by_computer}.
signal move_played(move: String, info: Dictionary)
## The board was replaced without a move being played (new game, restore, undo): rebuild it.
signal position_reset
## The game ended: result = {over: true, winner, reason} (see GameRules.result()).
signal game_over(result: Dictionary)
signal ai_thinking(thinking: bool)
## A hint arrived: {move, notation, facts: PackedStringArray, from, to, drop}.
signal hint_ready(hint: Dictionary)
signal engine_failed(message: String)

const DEFAULT_SETTINGS := {"mode": "ai", "human_color": "black", "level": Levels.DEFAULT_LEVEL, "handicap": "none"}
const SAVE_PATH := "user://partida.json"

var rules := GameRules.new()
## {mode: "ai"|"local", human_color: "black"|"white", level: 1..5, handicap: "none"|id}.
var settings := DEFAULT_SETTINGS.duplicate()
## Readable notation of each move in history order ("P-7f", "Bx2b+"…).
var notations := PackedStringArray()
var thinking := false
var hint := {}
var hint_pending := false
var engine_error := ""
## Minimum time the computer appears to think, so instant replies are easy to follow.
var min_think_ms := 600

var _searcher := ShogiEngine.new()
var _ai_turn := 0
var _hint_id := 0


func _init() -> void:
	_searcher.configure(2, 16)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_searcher.stop()


func engine_available() -> bool:
	return engine_error == ""


# ---------------------------------------------------------------- game setup

## Starts a game. With a handicap against the computer, the computer is the stronger side (Gote,
## without the removed pieces, moving first) and the person plays Sente.
func new_game(new_settings: Dictionary, sfen := "") -> bool:
	_cancel_ai()
	var merged := DEFAULT_SETTINGS.duplicate()
	merged.merge(new_settings, true)
	var handicapped: bool = sfen == "" and merged.handicap != "none"
	if handicapped and merged.mode == "ai":
		merged.human_color = "black"
	if not rules.load_position(sfen if sfen != "" else GameRules.start_sfen_for(merged.handicap)):
		return false
	settings = merged
	notations = PackedStringArray()
	position_reset.emit()
	_after_change()
	return true


## Restores a game saved with to_saved(); returns false (current game intact) if it is invalid.
func restore(saved: Dictionary) -> bool:
	_cancel_ai()
	var previous := to_saved()
	if not rules.load_position(saved.get("initial_sfen", ""), PackedStringArray(saved.get("moves", []))):
		return false
	var merged := DEFAULT_SETTINGS.duplicate()
	merged.merge(saved.get("settings", {}), true)
	merged.level = int(merged.level)
	settings = merged
	_rebuild_notations()
	var ok := true
	if saved.get("impasse_declared", false):
		ok = rules.declare_impasse()
	elif saved.get("resigned", "") != "":
		ok = rules.resign(saved.resigned)
	if not ok:
		restore(previous)
		return false
	position_reset.emit()
	_after_change()
	return true


## Everything needed to restore the game (JSON-friendly).
func to_saved() -> Dictionary:
	var result := rules.result()
	var resigned := ""
	if result.over and result.reason == "resignation" and result.winner != "draw":
		resigned = GameRules.opposite(result.winner)
	return {
		"variant": "shogi",
		"initial_sfen": rules.initial_sfen(),
		"moves": Array(rules.history()),
		"settings": settings.duplicate(),
		"resigned": resigned,
		"impasse_declared": result.over and result.reason == "impasse",
		"saved_at": Time.get_datetime_string_from_system(true),
	}


func save_game(path := SAVE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_saved(), "\t"))
	return true


## Restores the game saved at `path`; false if there is none or it is invalid.
func load_game(path := SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data is Dictionary and restore(data)


# ---------------------------------------------------------------- turns

func is_computer(color: String) -> bool:
	return settings.mode == "ai" and color != settings.human_color


## True when a person may move now.
func can_human_move() -> bool:
	return not rules.result().over and not is_computer(rules.side_to_move())


## Plays a person's move; false if it is not their turn or the move is illegal
## (Explain.explain_text(rules, move) says why).
func play(move: String) -> bool:
	if not can_human_move() or not rules.is_legal(move):
		return false
	_push_with_notation(move, false)
	_after_change()
	return true


## Against the computer, takes back the computer's reply and the player's move, so that it is
## the player's turn again. A resignation or impasse declaration is undone first, on its own.
func undo() -> void:
	_cancel_ai()
	var result := rules.result()
	if result.over and result.reason in ["resignation", "impasse"]:
		rules.undo()
	else:
		_undo_one()
	while is_computer(rules.side_to_move()) and _undo_one():
		pass
	position_reset.emit()
	_after_change()


func can_undo() -> bool:
	return rules.history().size() > 0 or rules.result().over


## The player resigns (in a local game, the side to move resigns).
func resign() -> void:
	_cancel_ai()
	var color: String = settings.human_color if settings.mode == "ai" else rules.side_to_move()
	if rules.resign(color):
		game_over.emit(rules.result())
	_after_change()


## Declares an entering-king win for the side to move (see rules.impasse()).
func declare_impasse() -> bool:
	if not rules.declare_impasse():
		return false
	game_over.emit(rules.result())
	_after_change()
	return true


func last_move() -> String:
	return rules.last_move()


## Mentor text when the side to move is in check ("" otherwise).
func check_help_text() -> String:
	var help := Coach.check_help(rules)
	return "" if help.is_empty() else Coach.describe_check_help(help, rules)


# ---------------------------------------------------------------- hint

## Asks the engine for a good move for the player; hint_ready (and changed) fire when it arrives.
func request_hint() -> void:
	if not engine_available() or not can_human_move() or hint_pending:
		return
	_hint_id += 1
	var id := _hint_id
	hint_pending = true
	hint = {}
	changed.emit()
	var move := await _search(Levels.HINT_LEVEL)
	if id != _hint_id:
		return
	hint_pending = false
	if move != "" and rules.is_legal(move):
		var parsed := GameRules.parse_move(move)
		hint = {
			"move": move,
			"notation": Kifu.format_western(rules.position(), rules.legal_moves(), move),
			"facts": Coach.describe_move(rules, move),
			"from": parsed.from,
			"to": parsed.to,
			"drop": parsed.drop,
		}
		hint_ready.emit(hint)
	changed.emit()


# ---------------------------------------------------------------- internals

func _undo_one() -> bool:
	if rules.history().is_empty():
		return false
	rules.undo()
	if notations.size() > 0:
		notations.resize(notations.size() - 1)
	return true


func _push_with_notation(move: String, by_computer: bool) -> void:
	var position := rules.position()
	var side := rules.side_to_move()
	var parsed := GameRules.parse_move(move)
	var notation := Kifu.format_western(position, rules.legal_moves(), move)
	var piece = Pieces.make(side, parsed.drop) if parsed.drop != "" else GameRules.piece_at(position, parsed.from)
	var captured = null if parsed.drop != "" else GameRules.piece_at(position, parsed.to)
	rules.play(move)
	notations.append(notation)
	move_played.emit(move, {
		"color": side,
		"notation": notation,
		"from": parsed.from,
		"to": parsed.to,
		"drop": parsed.drop,
		"promote": parsed.promote,
		"piece": piece,
		"captured": captured,
		"check": rules.is_check(),
		"by_computer": by_computer,
	})
	var result := rules.result()
	if result.over:
		game_over.emit(result)


func _rebuild_notations() -> void:
	var moves := rules.history()
	rules.load_position(rules.initial_sfen())
	notations = PackedStringArray()
	for move in moves:
		notations.append(Kifu.format_western(rules.position(), rules.legal_moves(), move))
		rules.play(move)


func _after_change() -> void:
	_cancel_hint()
	changed.emit()
	_maybe_computer_turn()


func _cancel_hint() -> void:
	hint = {}
	if not hint_pending:
		return
	hint_pending = false
	_hint_id += 1
	_searcher.stop()


func _cancel_ai() -> void:
	_ai_turn += 1
	if thinking:
		_searcher.stop()
		thinking = false
		ai_thinking.emit(false)


func _maybe_computer_turn() -> void:
	if thinking or rules.result().over or not is_computer(rules.side_to_move()) or not engine_available():
		return
	if rules.impasse().can_declare:
		rules.declare_impasse()
		game_over.emit(rules.result())
		changed.emit()
		return
	_computer_move()


func _computer_move() -> void:
	_ai_turn += 1
	var turn := _ai_turn
	thinking = true
	ai_thinking.emit(true)
	changed.emit()
	var started := Time.get_ticks_msec()
	var move := await _search(Levels.get_level(settings.level))
	var wait := min_think_ms - (Time.get_ticks_msec() - started)
	if wait > 0:
		await (Engine.get_main_loop() as SceneTree).create_timer(wait / 1000.0).timeout
	if turn != _ai_turn:
		return
	thinking = false
	ai_thinking.emit(false)
	if move != "" and rules.is_legal(move):
		_push_with_notation(move, true)
	else:
		engine_error = "O motor sugeriu uma jogada inválida (%s)." % move if move != "" else "O motor não respondeu."
		engine_failed.emit(engine_error)
	_after_change()


## Searches the current game with `level`; "" if the engine could not search.
func _search(level: Dictionary) -> String:
	# Wait for a cancelled search of this engine to deliver its (ignored) answer.
	while _searcher.is_searching():
		_searcher.stop()
		await _searcher.best_move
	if not _searcher.set_position(rules.initial_sfen(), rules.history()):
		return ""
	# Another ShogiEngine (only one search runs at a time in the whole app) may still be busy.
	var tries := 0
	while not _searcher.start_search(level.depth, level.movetime_ms, level.skill):
		tries += 1
		if tries > 600:
			return ""
		await (Engine.get_main_loop() as SceneTree).process_frame
	return await _searcher.best_move
