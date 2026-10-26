class_name GameScreen
extends Node
## A game against the computer on the 3D table. The GameSession (godot/game/) holds the rules,
## the computer and the saved game; the table animates; the mentor explains. Everything else is
## in the menu.

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
var _dialog: CanvasLayer
var _animating := false              ## the table is showing a move; the next waits for it
var _queue: Array = []               ## computer moves to animate, in order


func _ready() -> void:
	_apply_theme()
	table = Table.new()
	add_child(table)
	mentor = Mentor.new()
	add_child(mentor)
	session = GameSession.new()
	add_child(session)
	_build_status()
	if not session.engine_available():
		mentor.say("O motor de regras não carregou neste aparelho. Avise o desenvolvedor.", 30.0)
		return
	session.move_played.connect(_on_move_played)
	session.position_reset.connect(_on_position_reset)
	session.game_over.connect(_on_game_over)
	session.ai_thinking.connect(func(on: bool) -> void: _set_status("O computador está pensando…" if on else ""))
	session.hint_ready.connect(_on_hint)
	session.engine_failed.connect(func(msg: String) -> void: mentor.say("O computador parou de jogar: " + msg, 10.0))
	table.move_chosen.connect(_on_player_move)
	table.illegal_attempt.connect(_on_illegal)
	table.add_menu_action("Nova partida", _show_new_game)
	table.add_menu_action("Desfazer", func() -> void: session.undo())
	table.add_menu_action("Dica", _hint)
	table.add_menu_action("Declarar impasse", _declare_impasse)
	table.add_menu_action("Desistir", func() -> void: session.resign())
	if not _run_cmdline_demo():
		_show_new_game()


# --- Game flow -----------------------------------------------------------------------------

func _colour(c: String) -> int:
	return 0 if c == "black" else 1


func start(level: int, human: String) -> void:
	_queue.clear()
	session.new_game({"mode": "ai", "human_color": human, "level": level})
	var beginner := level <= BEGINNER_LEVELS
	mentor.say("Vamos lá! Você joga com as peças %s. %s" % [
		"peroladas e começa" if human == "black" else "vermelhas; o computador começa",
		"Toque numa peça para ver para onde ela pode ir." if beginner else "Boa partida."])


## Rebuilds the table from the session (new game, undo, continuing a saved game).
func _on_position_reset() -> void:
	_queue.clear()
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
			mentor.say(help)
	else:
		table.set_legal_moves(PackedStringArray(), side, false)


func _on_player_move(usi: String) -> void:
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
		text = "O computador venceu (%s). Quer tentar de novo? Menu ☰ → Nova partida." % reason
	table.set_legal_moves(PackedStringArray(), _colour(session.rules.side_to_move()), false)
	if result.get("reason", "") == "checkmate":
		var loser := 1 if winner == "black" else 0
		await table.checkmate_effect(table.king_square(loser))
	mentor.say(text, 8.0)
	_set_status(text)
	session.save_game()


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
		mentor.say(text)


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
	mentor.say("Que tal %s?%s" % [_move_in_words(hint.move), why])


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
	mentor.say("Ainda não dá para declarar impasse: " + "; ".join(missing) + ".")


# --- New game ------------------------------------------------------------------------------

func _show_new_game() -> void:
	if _dialog:
		_dialog.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_dialog = layer
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var title := Label.new()
	title.text = "将棋  Nova partida"
	title.add_theme_font_size_override("font_size", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var close := func() -> void:
		layer.queue_free()
		_dialog = null

	var saved := _saved_game()
	if not saved.is_empty():
		var lv := Levels.get_level(int(saved.settings.get("level", 1)))
		var cont := _big_button("Continuar partida (%s)" % lv.name)
		cont.pressed.connect(func() -> void:
			close.call()
			if not session.load_game():
				mentor.say("Não consegui abrir a partida salva. Comece uma nova."))
		box.add_child(cont)

	box.add_child(_label("Nível do computador"))
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 10)
	box.add_child(levels)
	var chosen := {"level": int(session.settings.get("level", 1)), "side": 0}
	var level_group := ButtonGroup.new()
	for lv: Dictionary in Levels.LEVELS:
		var b := _big_button("%d. %s" % [lv.id, lv.name])
		b.toggle_mode = true
		b.button_group = level_group
		b.button_pressed = lv.id == chosen.level
		b.pressed.connect(func() -> void: chosen.level = lv.id)
		levels.add_child(b)

	box.add_child(_label("Seu lado"))
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 10)
	box.add_child(sides)
	var side_group := ButtonGroup.new()
	var side_names := ["先手 Sente (pérola, começa)", "後手 Gote (vermelho)", "Aleatório"]
	for i in 3:
		var b := _big_button(side_names[i])
		b.toggle_mode = true
		b.button_group = side_group
		b.button_pressed = i == 0
		b.pressed.connect(func() -> void: chosen.side = i)
		sides.add_child(b)

	var go := _big_button("Começar")
	go.add_theme_font_size_override("font_size", 40)
	go.pressed.connect(func() -> void:
		close.call()
		var side: int = chosen.side if chosen.side < 2 else randi() % 2
		start(chosen.level, "black" if side == 0 else "white"))
	box.add_child(go)


## The saved game, if there is one still being played.
func _saved_game() -> Dictionary:
	if not FileAccess.file_exists(GameSession.SAVE_PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(GameSession.SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or (data.get("moves", []) as Array).is_empty():
		return {}
	if data.get("resigned", "") != "" or data.get("impasse_declared", "") != "":
		return {}
	if typeof(data.get("settings")) != TYPE_DICTIONARY:
		return {}
	return data


func _big_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 30)
	b.custom_minimum_size = Vector2(0, 84)
	return b


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.modulate = Color(1, 1, 1, 0.7)
	return l


# --- Status line and theme -----------------------------------------------------------------

func _build_status() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.offset_top = 18
	_status.add_theme_font_size_override("font_size", 30)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 8)
	layer.add_child(_status)


func _set_status(text: String) -> void:
	_status.text = text


## Default font with the brush kanji as fallback, so 成, 師, 将棋… show in the interface.
func _apply_theme() -> void:
	var kanji: FontFile = load("res://visual/fonts/kaisei-tokumin-800-koma.woff2")
	var base: Font = ThemeDB.fallback_font.duplicate()
	base.fallbacks = [kanji]
	var theme := Theme.new()
	theme.default_font = base
	get_tree().root.theme = theme


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
	for i in int(float(args.get("at", "2.0")) * 30.0):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	print("saved ", args["shot"])
	get_tree().quit()
