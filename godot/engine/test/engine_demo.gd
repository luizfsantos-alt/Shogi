extends Control
## Minimal scene for the engine spike: shows the board (as text), the legal moves and lets the
## AI play. Tap a move to play it; the AI answers. "IA x IA" makes it play both sides.

signal self_test_finished

# Same levels as src/ai/levels.ts of the PWA (to be recalibrated on the device).
const LEVELS := [
	{"name": "1 Iniciante", "skill": -15, "depth": 1, "movetime": 0},
	{"name": "2 Fácil", "skill": -5, "depth": 3, "movetime": 0},
	{"name": "3 Médio", "skill": 10, "depth": 3, "movetime": 0},
	{"name": "4 Difícil", "skill": 20, "depth": 0, "movetime": 1000},
	{"name": "5 Mestre", "skill": 20, "depth": 0, "movetime": 4000},
]

var engine := ShogiEngine.new()
var auto_play := false
var search_started_ms := 0
var self_test_text := "Autoteste em andamento..."

var board_label: Label
var status_label: Label
var moves_list: ItemList
var level_option: OptionButton
var auto_button: Button


func _ready() -> void:
	engine.configure(2, 16)
	engine.best_move.connect(_on_best_move)
	_build_ui()
	_refresh("Toque num lance para jogar.")
	_self_test()


## Measures the engine on this device; results go to the screen and to the log (logcat "godot").
func _self_test() -> void:
	var probe := ShogiEngine.new()
	var lines := []
	var log_line := func(line: String) -> void:
		lines.append(line)
		print("SELFTEST ", line)  # one by one, so the log shows how far it got
	log_line.call(ShogiEngine.engine_info())
	log_line.call("%s %s, %d núcleos" % [OS.get_name(), Engine.get_architecture_name(), OS.get_processor_count()])
	var t := Time.get_ticks_usec()
	var nodes := probe.perft(3)
	log_line.call("perft 3 = %d em %.1f ms" % [nodes, (Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	nodes = probe.perft(4)
	log_line.call("perft 4 = %d em %.1f ms" % [nodes, (Time.get_ticks_usec() - t) / 1000.0])
	for level in [[3, 0, 10], [0, 1000, 20]]:
		t = Time.get_ticks_usec()
		if not probe.start_search(level[0], level[1], level[2]):
			break
		var move: String = await probe.best_move
		log_line.call("busca depth=%d movetime=%d skill=%d -> %s em %.0f ms" % [level[0], level[1], level[2], move, (Time.get_ticks_usec() - t) / 1000.0])
	print("SELFTEST done")
	self_test_text = "\n".join(lines)
	_refresh("Autoteste concluído.")
	self_test_finished.emit()


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	board_label = Label.new()
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["monospace"])
	board_label.add_theme_font_override("font", mono)
	board_label.add_theme_font_size_override("font_size", 40)
	left.add_child(board_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 28)
	left.add_child(status_label)

	var buttons := HBoxContainer.new()
	left.add_child(buttons)
	level_option = OptionButton.new()
	for level in LEVELS:
		level_option.add_item(level.name)
	level_option.selected = 2
	buttons.add_child(level_option)
	_add_button(buttons, "IA joga", _ai_move)
	auto_button = _add_button(buttons, "IA x IA", _toggle_auto)
	_add_button(buttons, "Desfazer", _undo)
	_add_button(buttons, "Reiniciar", _restart)

	moves_list = ItemList.new()
	moves_list.custom_minimum_size = Vector2(520, 0)
	moves_list.max_columns = 4
	moves_list.same_column_width = true
	moves_list.add_theme_font_size_override("font_size", 30)
	moves_list.item_activated.connect(_on_move_chosen)
	moves_list.item_clicked.connect(func(index, _pos, _button): _on_move_chosen(index))
	root.add_child(moves_list)


func _add_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## Legal moves without uchifuzume (Fairy-Stockfish generates it; the rules forbid it).
func _legal_moves() -> PackedStringArray:
	if engine.game_result().over:
		return PackedStringArray()
	var out := PackedStringArray()
	for move in engine.legal_moves():
		if move.begins_with("P*") and engine.gives_check(move):
			engine.play(move)
			var mate := engine.legal_move_count() == 0
			engine.undo()
			if mate:
				continue
		out.append(move)
	return out


func _refresh(message: String) -> void:
	board_label.text = _board_text(engine.get_sfen())
	var moves := _legal_moves()
	moves_list.clear()
	for move in moves:
		moves_list.add_item(move)
	var result := engine.game_result()
	var turn := "Sente (▲)" if engine.side_to_move() == "black" else "Gote (△)"
	var state := "Fim: %s, vencedor %s" % [result.reason, result.winner] if result.over else "Vez de %s%s" % [turn, " — XEQUE" if engine.is_check() else ""]
	status_label.text = "%s\n%d lances legais. %s\n%s\n\n%s" % [state, moves.size(), message, engine.get_sfen(), self_test_text]


func _board_text(sfen: String) -> String:
	var rows := sfen.split(" ")[0].split("/")
	var text := "  9  8  7  6  5  4  3  2  1\n"
	var rank_names := "abcdefghi"
	for r in rows.size():
		var line := ""
		var promoted := false
		for c in rows[r]:
			if c == "+":
				promoted = true
			elif c.is_valid_int():
				for i in int(c):
					line += "  ."
			else:
				line += (" +" if promoted else "  ") + c
				promoted = false
		text += line + "  " + rank_names[r] + "\n"
	return text


func _on_move_chosen(index: int) -> void:
	if engine.is_searching():
		return
	engine.play(moves_list.get_item_text(index))
	_refresh("Você jogou %s." % engine.history()[-1])
	if not engine.game_result().over:
		_ai_move()


func _ai_move() -> void:
	if engine.is_searching() or engine.game_result().over:
		return
	var level: Dictionary = LEVELS[level_option.selected]
	search_started_ms = Time.get_ticks_msec()
	if not engine.start_search(level.depth, level.movetime, level.skill):
		return  # another search (the self-test) is running
	status_label.text = "IA pensando (%s)..." % level.name


func _on_best_move(move: String) -> void:
	var ms := Time.get_ticks_msec() - search_started_ms
	if move != "":
		engine.play(move)
	_refresh("IA jogou %s em %d ms." % [move, ms])
	if auto_play and not engine.game_result().over:
		_ai_move.call_deferred()


func _toggle_auto() -> void:
	auto_play = not auto_play
	auto_button.text = "Parar" if auto_play else "IA x IA"
	if auto_play:
		_ai_move()


func _undo() -> void:
	if engine.is_searching():
		return
	engine.undo()
	_refresh("Lance desfeito.")


func _restart() -> void:
	auto_play = false
	auto_button.text = "IA x IA"
	engine.stop()
	if engine.is_searching():
		await engine.best_move
	engine.set_position("")
	_refresh("Nova partida.")
