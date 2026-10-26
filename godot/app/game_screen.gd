class_name GameScreen
extends Node
## A game against the computer on the 3D table: the engine decides what is legal and plays the
## computer's moves, the table animates, the mentor explains. Everything else is in the menu.
##
## The rules layer ported from the PWA (godot/game/: explanations, coach, impasse, session) is
## being written on the engine branch; until it lands this keeps a small local version.

const LEVELS := [
	{"name": "Iniciante", "skill": -15, "depth": 1, "movetime": 0},
	{"name": "Fácil", "skill": -5, "depth": 3, "movetime": 0},
	{"name": "Médio", "skill": 10, "depth": 3, "movetime": 0},
	{"name": "Difícil", "skill": 20, "depth": 0, "movetime": 1000},
	{"name": "Mestre", "skill": 20, "depth": 0, "movetime": 4000},
]
const HINT := {"skill": 20, "depth": 14, "movetime": 1500}
const BEGINNER_LEVELS := 2           ## "Movimentos" is offered up to this level
const SAVE_PATH := "user://partida.json"
const NAMES := {
	"K": "o Rei", "R": "a Torre", "B": "o Bispo", "G": "o General de Ouro", "S": "o General de Prata",
	"N": "o Cavalo", "L": "a Lança", "P": "o Peão",
}
const REASONS := {
	"checkmate": "xeque-mate", "no-legal-moves": "sem lances possíveis",
	"repetition": "sennichite (a mesma posição pela 4ª vez)", "perpetual-check": "xeque perpétuo",
	"resign": "desistência",
}

var engine: Object                   ## ShogiEngine (GDExtension)
var table: Table
var mentor: Mentor
var level := 1                       ## 1..5
var player := 0                      ## 0 Sente, 1 Gote
var vs_computer := true

var _thinking := false
var _hint_pending := false
var _discard_result := false         ## a search was stopped: ignore the move it reports
var _over := false
var _status: Label
var _dialog: CanvasLayer


func _ready() -> void:
	_apply_theme()
	table = Table.new()
	add_child(table)
	mentor = Mentor.new()
	add_child(mentor)
	if not ClassDB.class_exists("ShogiEngine"):
		mentor.say("O motor de regras não carregou neste aparelho. Avise o desenvolvedor.", 30.0)
		return
	engine = ClassDB.instantiate("ShogiEngine")
	engine.configure(2, 16)
	engine.best_move.connect(_on_best_move)
	table.move_chosen.connect(_on_player_move)
	table.illegal_attempt.connect(_on_illegal)
	table.add_menu_action("Nova partida", _show_new_game)
	table.add_menu_action("Desfazer", _undo)
	table.add_menu_action("Dica", _hint)
	table.add_menu_action("Desistir", _resign)
	_build_status()
	if not _run_cmdline_demo():
		_show_new_game()


# --- Game flow -----------------------------------------------------------------------------

func start(p_level: int, p_player: int, sfen := "", moves := PackedStringArray()) -> void:
	level = p_level
	player = p_player
	_over = false
	_cancel_search()
	engine.set_position(sfen, moves)
	table.set_view_side(player)
	table.set_moves_button(level <= BEGINNER_LEVELS)
	table.show_sfen(engine.get_sfen())
	if moves.is_empty():
		mentor.say("Vamos lá! Você joga com as peças %s. %s" % [
			"peroladas e começa" if player == 0 else "vermelhas; o computador começa",
			"Toque numa peça para ver para onde ela pode ir." if level <= BEGINNER_LEVELS else "Boa partida."])
	_next_turn()


func _side() -> int:
	return 0 if engine.side_to_move() == "black" else 1


func _next_turn() -> void:
	_save()
	var r: Dictionary = engine.game_result()
	if r.get("over", false):
		_game_over(r)
		return
	var side := _side()
	if not vs_computer or side == player:
		table.set_legal_moves(_legal_moves(), side, true)
		_set_status("")
		if engine.is_check():
			mentor.say("Xeque! Seu rei está sendo atacado: mova o rei, capture a peça que ataca ou bloqueie o caminho.")
	else:
		table.set_legal_moves(PackedStringArray(), side, false)
		_set_status("O computador está pensando…")
		var lv: Dictionary = LEVELS[level - 1]
		_thinking = true
		engine.start_search(lv.depth, lv.movetime, lv.skill)


## Legal moves without the pawn-drop mate (uchifuzume), which the engine still lists.
func _legal_moves() -> PackedStringArray:
	var out := PackedStringArray()
	for m: String in engine.legal_moves():
		if not _is_pawn_drop_mate(m):
			out.append(m)
	return out


func _is_pawn_drop_mate(m: String) -> bool:
	if not m.begins_with("P*") or not engine.gives_check(m):
		return false
	engine.play(m)
	var mate: bool = engine.legal_move_count() == 0
	engine.undo()
	return mate


func _on_player_move(usi: String) -> void:
	if _over:
		return
	engine.play(usi)
	_next_turn()


func _on_best_move(move: String) -> void:
	if _discard_result:
		_discard_result = false
		return
	if _hint_pending:
		_hint_pending = false
		_show_hint(move)
		return
	_thinking = false
	_set_status("")
	if move == "" or _over:
		return
	await table.play_usi(move)
	engine.play(move)
	_next_turn()


func _cancel_search() -> void:
	if engine.is_searching():
		_discard_result = true
		engine.stop()
	_thinking = false
	_hint_pending = false


func _game_over(r: Dictionary) -> void:
	_over = true
	table.set_legal_moves(PackedStringArray(), _side(), false)
	var winner: String = r.get("winner", "draw")
	var reason: String = REASONS.get(r.get("reason", ""), str(r.get("reason", "")))
	var text := ""
	if winner == "draw":
		text = "Empate: %s." % reason
	elif (winner == "black") == (player == 0):
		text = "Você venceu! (%s)" % reason
	else:
		text = "O computador venceu (%s). Quer tentar de novo?" % reason
	if r.get("reason", "") == "checkmate":
		var loser := 1 if winner == "black" else 0
		await table.checkmate_effect(table.king_square(loser))
	mentor.say(text, 8.0)
	_set_status(text)
	_clear_save()


# --- Menu actions --------------------------------------------------------------------------

func _undo() -> void:
	if _over or engine.history().is_empty():
		return
	_cancel_search()
	# Against the computer, go back to the player's last turn.
	engine.undo()
	while vs_computer and _side() != player and not engine.history().is_empty():
		engine.undo()
	table.show_sfen(engine.get_sfen())
	_next_turn()


func _hint() -> void:
	if _over or _thinking or _side() != player:
		return
	_hint_pending = true
	_set_status("Procurando uma boa jogada…")
	engine.start_search(HINT.depth, HINT.movetime, HINT.skill)


func _show_hint(move: String) -> void:
	_set_status("")
	if move == "":
		return
	var to := Table.usi_square(move.substr(2, 2))
	var text := ""
	if move[1] == "*":
		text = "Que tal colocar %s da sua mão em %s?" % [NAMES[move[0]].substr(2), move.substr(2, 2)]
	else:
		var from := Table.usi_square(move.substr(0, 2))
		var p := table.piece_at(from)
		text = "Que tal mover %s de %s para %s%s?" % [NAMES.get(p.kind, "a peça") if p else "a peça",
			move.substr(0, 2), move.substr(2, 2), " e promover" if move.ends_with("+") else ""]
		table.flash_square(from, Table.GOLD, 3.0)
	table.flash_square(to, Table.GOLD, 3.0)
	mentor.say(text)


func _resign() -> void:
	if _over:
		return
	_cancel_search()
	_game_over({"over": true, "winner": "white" if player == 0 else "black", "reason": "resign"})


# --- Explanations --------------------------------------------------------------------------

## Why a move was refused. A short local version; the full port of explain.ts replaces it.
func _on_illegal(from: Vector2i, kind: String, to: Vector2i) -> void:
	var name: String = NAMES.get(kind, "essa peça")
	var dest := Table.square_usi(to)
	if from.x < 0:
		var occupied := table.piece_at(to) != null
		if occupied:
			mentor.say("Só dá para colocar uma peça da mão numa casa vazia.")
		elif kind == "P" and _has_unpromoted_pawn_on_file(to.x):
			mentor.say("Nifu (二歩): você já tem um peão nessa coluna. Não pode haver dois peões seus, sem promover, na mesma coluna.")
		elif kind == "P" and _is_pawn_drop_mate("P*" + dest):
			mentor.say("Uchifuzume (打ち歩詰め): é proibido dar xeque-mate colocando um peão da mão.")
		elif kind in ["P", "L", "N"] and _no_future_move(kind, to):
			mentor.say("%s não poderia mais se mexer ali, então não pode ser colocad%s nessa casa." % [name.capitalize(), "a" if kind == "L" else "o"])
		else:
			mentor.say("Esse lance deixaria seu rei em xeque.")
		return
	var p := table.piece_at(from)
	var reach := []
	if p:
		reach = KomaMoves.reach(p.kind, p.promoted, p.colour, from, table.occupant).map(func(r: Array) -> Vector2i: return r[0])
	if to in reach:
		if engine.is_check():
			mentor.say("Seu rei está em xeque: esse lance não resolve. Mova o rei, capture a peça que ataca ou bloqueie.")
		else:
			mentor.say("Esse lance deixaria seu rei em xeque: %s está protegendo o rei de um ataque." % name)
	else:
		mentor.say("%s não anda assim. Toque nela e veja as casas acesas, ou use o botão Movimentos." % name.capitalize())


func _has_unpromoted_pawn_on_file(col: int) -> bool:
	for p in table.pieces:
		if p.kind == "P" and not p.promoted and p.colour == player and p.square.x == col:
			return true
	return false


func _no_future_move(kind: String, to: Vector2i) -> bool:
	return KomaMoves.must_promote(kind, player, to)


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

	var saved := _load_save()
	if not saved.is_empty():
		var cont := _big_button("Continuar partida (%s)" % LEVELS[int(saved.level) - 1].name)
		cont.pressed.connect(func() -> void:
			layer.queue_free()
			_dialog = null
			start(int(saved.level), int(saved.player), saved.sfen, PackedStringArray(saved.moves)))
		box.add_child(cont)

	box.add_child(_label("Nível do computador"))
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 10)
	box.add_child(levels)
	var chosen := {"level": level, "side": 0}
	var level_group := ButtonGroup.new()
	for i in LEVELS.size():
		var b := _big_button("%d. %s" % [i + 1, LEVELS[i].name])
		b.toggle_mode = true
		b.button_group = level_group
		b.button_pressed = i + 1 == level
		b.pressed.connect(func() -> void: chosen.level = i + 1)
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
		layer.queue_free()
		_dialog = null
		var side: int = chosen.side if chosen.side < 2 else randi() % 2
		start(chosen.level, side))
	box.add_child(go)


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


# --- Status line, theme and saving ---------------------------------------------------------

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


func _save() -> void:
	if not vs_computer:
		return
	var data := {"level": level, "player": player, "sfen": engine.get_start_sfen(), "moves": Array(engine.history())}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func _load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or not data.has("moves") or (data.moves as Array).is_empty():
		return {}
	return data


func _clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


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
			start(1, 0)
			await table.play_usi("7g7f")
			_on_player_move("7g7f")
		"illegal":
			# A pawn trying to move two squares: the square flashes, the mentor explains.
			start(1, 0)
			table.flash_square(Vector2i(2, 4), Table.ARROW_RED, 2.0)
			_on_illegal(Vector2i(2, 6), "P", Vector2i(2, 4))
		"hint":
			start(3, 0)
			_hint()
	for i in int(float(args.get("at", "2.0")) * 30.0):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	print("saved ", args["shot"])
	get_tree().quit()
