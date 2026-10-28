class_name GameScreen
extends Node
## A game against the computer on the 3D table. The GameSession (godot/game/) holds the rules,
## the computer and the saved game; the table animates; the mentor explains. Everything else is
## in the menu. What to start comes from App.request (new game, continue, or a guided game of the
## course, where the coach of learn/coach_tips.gd comments on the way).

const BEGINNER_LEVELS := 2           ## "Movimentos" is offered up to this level
const REASONS := {
	"checkmate": "xeque-mate", "no-legal-moves": "sem lances possíveis",
	"repetition": "sennichite (a mesma posição pela 4ª vez)", "perpetual-check": "xeque perpétuo",
	"resignation": "desistência", "impasse": "impasse (jishogi)",
}

var session: GameSession
var table: Table
var mentor: Mentor

var _status: Label
var _status_layer: CanvasLayer
var _rival: Control                  ## the computer's face and name, top right
var _rival_level := 0
var _animating := false              ## the table is showing a move; the next waits for it
var _queue: Array = []               ## computer moves to animate, in order
var _coach_seen := {}                ## coach tips already shown in this guided game
var _game_over_panel: CanvasLayer    ## the end-of-game panel, while it is open


func _ready() -> void:
	UiTheme.apply(get_tree())
	table = Table.new()
	add_child(table)
	mentor = Mentor.new()
	mentor.balloon_width = 560.0
	add_child(mentor)
	session = GameSession.new()
	add_child(session)
	_build_status()
	if not session.engine_available():
		mentor.say("O motor de regras não carregou neste aparelho. Avise o desenvolvedor.", 30.0, "startled")
		return
	session.move_played.connect(_on_move_played)
	session.position_reset.connect(_on_position_reset)
	session.game_over.connect(_on_game_over)
	session.ai_thinking.connect(func(on: bool) -> void: _set_status("O computador está pensando…" if on else ""))
	session.hint_ready.connect(_on_hint)
	session.engine_failed.connect(func(msg: String) -> void: mentor.say("O computador parou de jogar: " + msg, 10.0, "startled"))
	table.move_chosen.connect(_on_player_move)
	table.illegal_attempt.connect(_on_illegal)
	table.reduced_effects_changed.connect(func(on: bool) -> void: App.set_setting("reduced_effects", on))
	table.pixel_look_changed.connect(func(on: bool) -> void: App.set_setting("classic_look", not on))
	table.add_menu_action("Início", App.go_home)
	table.add_menu_action("Nova partida", func() -> void: _confirm_abandon(_show_new_game))
	table.add_menu_action("Reiniciar partida", func() -> void: _confirm_abandon(_restart))
	table.add_menu_action("Desfazer", func() -> void: session.undo())
	table.add_menu_action("Dica", _hint)
	table.add_menu_action("Declarar impasse", _declare_impasse)
	table.add_menu_action("Desistir", func() -> void: session.resign())
	if not _run_cmdline_demo():
		_start_requested(App.request)


## What the start screen or the course asked for.
func _start_requested(req: Dictionary) -> void:
	match req.get("action", ""):
		"new":
			start(int(req.level), req.side)
		"continue":
			if not session.load_game():
				mentor.say("Não consegui abrir a partida salva. Comece uma nova.", 0.0, "startled")
				_show_new_game()
		"guided":
			start_guided(req.lesson)
		_:
			_show_new_game()


# --- Game flow -----------------------------------------------------------------------------

func _colour(c: String) -> int:
	return 0 if c == "black" else 1


## `side` is "black", "white" or "random"; a random side is drawn again on each restart.
func start(level: int, side: String) -> void:
	_close_game_over()
	_queue.clear()
	_coach_seen.clear()
	var human: String = side if side != "random" else ["black", "white"][randi() % 2]
	session.new_game({"mode": "ai", "human_color": human, "level": level, "side": side})
	var beginner := level <= BEGINNER_LEVELS
	mentor.say("Vamos lá! Você joga com as peças %s. %s" % [
		"peroladas e começa" if human == "black" else "%s; o computador começa" % ("pretas" if Koma.pixel else "vermelhas"),
		"Toque numa peça para ver para onde ela pode ir." if beginner else "Boa partida."], 0.0, "explain")


## A game lesson of the course: Sente against the lesson's level (the weakest by default), with the coach.
func start_guided(lesson_id: String) -> void:
	_close_game_over()
	_queue.clear()
	_coach_seen.clear()
	var level := int(Course.find_lesson(lesson_id).get("lesson", {}).get("level", 1))
	# The coach's first tip (the opening) comes with the first turn.
	session.new_game({"mode": "ai", "human_color": "black", "level": level, "coach": lesson_id})


func _guided() -> String:
	return str(session.settings.get("coach", ""))


## The same game again: the same level and side (a random side is drawn again), or the same
## lesson of the course.
func _restart() -> void:
	if _guided() != "":
		start_guided(_guided())
	else:
		start(int(session.settings.level), str(session.settings.get("side", session.settings.human_color)))


## Restarting or starting a new game in the middle of one asks first.
func _confirm_abandon(then: Callable) -> void:
	if session.rules.result().over or session.rules.history().is_empty():
		then.call()
		return
	var m := UiTheme.modal(self, 7, 900)
	var layer: CanvasLayer = m.layer
	var box: VBoxContainer = m.box
	var question := UiTheme.label("Abandonar a partida atual?", "Title")
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(question)
	var note := UiTheme.label("A partida em andamento será perdida.", "Muted")
	box.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var keep := UiTheme.button("Continuar jogando", "GhostButton", 42, 108)
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keep.pressed.connect(layer.queue_free)
	row.add_child(keep)
	var leave := UiTheme.button("Abandonar", "PrimaryButton", 42, 108)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void:
		layer.queue_free()
		then.call())
	row.add_child(leave)


## Rebuilds the table from the session (new game, undo, continuing a saved game).
func _on_position_reset() -> void:
	_close_game_over()
	_queue.clear()
	_show_rival(int(session.settings.level))
	var human := _colour(session.settings.human_color)
	table.set_view_side(human)
	table.set_moves_button(int(session.settings.level) <= BEGINNER_LEVELS)
	table.show_sfen(session.rules.sfen())
	_refresh_turn()


## Lets the player touch the pieces when it is their turn; warns of check.
func _refresh_turn() -> void:
	if _animating or not _queue.is_empty():
		return
	var side := _colour(session.rules.side_to_move())
	if session.can_human_move():
		table.set_legal_moves(session.rules.legal_moves(), side, true)
		var help := session.check_help_text()
		if help != "":
			mentor.say(help, 0.0, "startled")
		elif _guided() != "":
			_coach_tip()
	else:
		table.set_legal_moves(PackedStringArray(), side, false)


## The coach of the guided game: one tip at a time, each once per game, with its squares lit.
func _coach_tip() -> void:
	var tip := CoachTips.coach_tip(session.rules, session.settings.human_color, _coach_seen)
	if tip.is_empty():
		return
	_coach_seen[tip.id] = true
	var marks := {}
	for sq: Vector2i in tip.squares:
		marks[sq] = Table.GOLD
	table.set_marks(marks)
	mentor.note(tip.text, tip.title.to_upper(), "point")


func _on_player_move(usi: String) -> void:
	table.set_marks({})
	# The table has already animated it; the session answers with the computer's move.
	if not session.play(usi):
		# Should not happen (the table only offers legal moves): resync.
		table.show_sfen(session.rules.sfen())
	session.save_game()
	_refresh_turn()


func _on_move_played(move: String, info: Dictionary) -> void:
	if not info.get("by_computer", false):
		return
	_queue.append(move)
	if not _animating:
		_animate_queue()


func _animate_queue() -> void:
	_animating = true
	while not _queue.is_empty():
		var move: String = _queue.pop_front()
		await table.play_usi(move)
	_animating = false
	session.save_game()
	_refresh_turn()


func _on_game_over(result: Dictionary) -> void:
	while _animating:
		await get_tree().process_frame
	var winner: String = result.get("winner", "draw")
	var human: String = session.settings.human_color
	var reason: String = REASONS.get(result.get("reason", ""), str(result.get("reason", "")))
	var text := ""
	if winner == "draw":
		text = "Empate: %s." % reason
	elif winner == human:
		text = "Você venceu! (%s)" % reason
	else:
		text = "O computador venceu (%s)." % reason
	table.set_legal_moves(PackedStringArray(), _colour(session.rules.side_to_move()), false)
	if result.get("reason", "") == "checkmate":
		var loser := 1 if winner == "black" else 0
		await table.checkmate_effect(table.king_square(loser))
	_set_status(text)
	if winner == human and _rival != null:
		Rivals.set_defeated(_rival.get_child(0), _rival_level, true)
	session.save_game()
	var lesson := _guided()
	if lesson == "":
		mentor.say(text, 8.0, "laugh" if winner == human else ("stern" if winner != "draw" else ""))
		# Unless the game was undone or restarted during the checkmate effect.
		if session.rules.result().over:
			_close_game_over()
			var title := "Empate" if winner == "draw" else ("Você venceu!" if winner == human else "O computador venceu")
			_game_over_panel = GameOverPanel.open(self, title, reason,
				{"home": App.go_home, "restart": _restart, "new_game": _show_new_game})
		return
	# The guided game is a lesson: 3 stars for a win, 2 for a draw, 1 for playing it to the end.
	var stars := 3 if winner == human else (2 if winner == "draw" else 1)
	Course.save_result(lesson, stars)
	var following := Course.next_lesson(lesson)
	mentor.speak([text, "Partida guiada concluída. Agora é com você: escolha um nível em Nova partida, ou siga no curso%s." % (
		(": a próxima lição é \"%s\"" % following.title) if not following.is_empty() else "")], "FIM DA PARTIDA",
		"laugh" if winner == human else "explain")
	mentor.dialog_finished.connect(func() -> void:
		if not following.is_empty():
			App.open_lesson(following.id)
		else:
			App.open_course(), CONNECT_ONE_SHOT)


# --- Mentor --------------------------------------------------------------------------------

## A refused move: the mentor says why (the PWA's explanations, ported in game/explain.gd).
func _on_illegal(from: Vector2i, kind: String, to: Vector2i) -> void:
	var move := ""
	if from.x < 0:
		move = GameRules.drop_move(kind, to)
	else:
		move = GameRules.board_move(from, to)
	var text := Explain.explain_text(session.rules, move)
	if text != "":
		mentor.say(text, 0.0, "stern")


func _hint() -> void:
	if not session.can_human_move():
		return
	_set_status("Procurando uma boa jogada…")
	session.request_hint()


func _on_hint(hint: Dictionary) -> void:
	_set_status("")
	if hint.get("from") is Vector2i:
		table.flash_square(hint.from, Table.GOLD, 3.0)
	table.flash_square(hint.to, Table.GOLD, 3.0)
	var facts: PackedStringArray = hint.get("facts", PackedStringArray())
	var why := (" Assim você " + ", ".join(facts) + ".") if not facts.is_empty() else ""
	mentor.say("Que tal %s?%s" % [_move_in_words(hint.move), why], 0.0, "point")


## "mover o General de Ouro de 6i para 6h", "colocar um Peão da mão em 5e": plain words for
## beginners, instead of the notation.
func _move_in_words(move: String) -> String:
	var m := GameRules.parse_move(move)
	if m.drop != "":
		return "colocar um %s da mão em %s" % [Pieces.BASE[m.drop].name_pt, GameRules.square_name(m.to)]
	var piece = session.rules.piece_on(m.from)
	var name := "peça"
	if piece:
		name = (Pieces.PROMOTED if piece.promoted else Pieces.BASE)[piece.type].name_pt
	var article := "a" if name.begins_with("Torre") or name.begins_with("Lança") or name.begins_with("Prata") or name == "peça" else "o"
	return "mover %s %s de %s para %s%s" % [article, name, GameRules.square_name(m.from),
		GameRules.square_name(m.to), " e promover" if move.ends_with("+") else ""]


func _declare_impasse() -> void:
	if session.declare_impasse():
		return
	var i: Dictionary = session.rules.impasse()
	var missing := PackedStringArray()
	if not i.king_in_zone:
		missing.append("seu rei precisa estar no campo inimigo")
	if i.pieces_in_zone < i.required_pieces:
		missing.append("faltam %d peças no campo inimigo" % (i.required_pieces - i.pieces_in_zone))
	if i.points < i.required_points:
		missing.append("você tem %d pontos de %d" % [i.points, i.required_points])
	if i.in_check:
		missing.append("não pode estar em xeque")
	mentor.say("Ainda não dá para declarar impasse: " + "; ".join(missing) + ".", 0.0, "stern")


# --- New game ------------------------------------------------------------------------------

func _show_new_game() -> void:
	NewGamePanel.open(self, start, int(session.settings.get("level", 1)))


func _close_game_over() -> void:
	if is_instance_valid(_game_over_panel):
		_game_over_panel.queue_free()
	_game_over_panel = null


# --- Status line ----------------------------------------------------------------------------

func _build_status() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_status_layer = layer
	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.offset_top = 18
	_status.add_theme_font_override("font", UiTheme.mono())
	_status.add_theme_font_size_override("font_size", UiTheme.display_size(42))
	_status.add_theme_color_override("font_color", UiTheme.GOLD)
	_status.add_theme_color_override("font_outline_color", UiTheme.OUTLINE)
	_status.add_theme_constant_override("outline_size", 2 * UiTheme.PX)
	layer.add_child(_status)


func _set_status(text: String) -> void:
	_status.text = text


## The computer's rival in the top right corner: its face (two screen pixels per art pixel) and
## name; rebuilt when the level changes.
func _show_rival(level: int) -> void:
	if _rival != null and _rival_level == level:
		Rivals.set_defeated(_rival.get_child(0), level, false)
		return
	if _rival != null:
		_rival.queue_free()
	_rival_level = level
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := Rivals.portrait(level, 280)
	face.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(face)
	var rival := Rivals.of_level(level)
	var name_label := UiTheme.label("%s %s" % [rival.name, rival.kanji], "", 56)
	name_label.add_theme_font_override("font", UiTheme.display())
	name_label.add_theme_font_size_override("font_size", UiTheme.display_size(56))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(name_label)
	var level_label := UiTheme.label("NÍVEL %d · %s" % [level, Levels.get_level(level).name.to_upper()], "Caption", 42)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(level_label)
	_status_layer.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 40)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_rival = box


# --- Screenshots for development -----------------------------------------------------------
# godot --path godot --fixed-fps 30 res://app/game.tscn -- shot=/tmp/a.png demo=reply at=3

func _run_cmdline_demo() -> bool:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if not args.has("shot"):
		return false
	_demo(args)
	return true


func _demo(args: Dictionary) -> void:
	var demo: String = args.get("demo", "reply")
	await get_tree().process_frame
	match demo:
		"dialog":
			_show_new_game()
		"reply":
			# The player opens with 7g7f; the computer answers on the table.
			start(1, "black")
			await table.play_usi("7g7f")
			_on_player_move("7g7f")
		"illegal":
			# A pawn trying to move two squares: the square flashes, the mentor explains.
			start(1, "black")
			table.flash_square(Vector2i(2, 4), Table.ARROW_RED, 2.0)
			_on_illegal(Vector2i(2, 6), "P", Vector2i(2, 4))
		"hint":
			start(3, "black")
			_hint()
		"gote":
			# Playing Gote: the table turns around and the computer opens.
			start(1, "white")
		"guided":
			# The course's first game: the coach suggests the first move.
			start_guided("first-game")
		"gameover":
			# The player resigns: the end-of-game panel.
			start(1, "black")
			session.resign()
		"confirm":
			# Restarting in the middle of a game asks first.
			start(1, "black")
			await table.play_usi("7g7f")
			_on_player_move("7g7f")
			_confirm_abandon(_restart)
	for i in int(float(args.get("at", "2.0")) * 30.0):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	print("saved ", args["shot"])
	get_tree().quit()
