extends Node
## A lesson of the course on the 3D table. The LessonSession (learn/) holds the steps, the goal
## and the stars; the tengu teaches: the explanations to read (info steps) in the big dialogue,
## with the board sliding aside, and the exercise's goal and feedback in the small balloon while
## the learner moves the pieces. The lesson's controls are on the right.

const HINT := Color(0.35, 0.65, 1.0)
## How far the board slides right while the big tengu talks (pixels of a 1080-high screen).
const BIG_OFFSET := 420.0
const HUD_WIDTH := 560.0

var table: Table
var mentor: Mentor
var rules := GameRules.new()
var session: LessonSession
var lesson: Dictionary
var track: Dictionary

var _shown_step := -1
var _reply_pending := false
var _animating := false
var _last_feedback := {}
var _illegal_text := ""              ## the rule just shown by trying a forbidden move
var _offset_tween: Tween
var _hud := {}


func _ready() -> void:
	UiTheme.apply(get_tree())
	var args := _cmdline_args()
	var found := Course.find_lesson(args.get("lesson", App.request.get("lesson", "")))
	if found.is_empty():
		found = Course.find_lesson("board")
	lesson = found.lesson
	track = found.track

	table = Table.new()
	add_child(table)
	table.reduced_effects_changed.connect(func(on: bool) -> void: App.set_setting("reduced_effects", on))
	table.pixel_look_changed.connect(func(on: bool) -> void: App.set_setting("classic_look", not on))
	table.add_menu_action("Mapa do curso", App.open_course)
	table.add_menu_action("Início", App.go_home)
	table.add_menu_action("Recomeçar a lição", func() -> void: _restart(0))
	table.move_chosen.connect(_on_move)
	table.illegal_attempt.connect(_on_illegal)
	table.set_moves_button(true)

	mentor = Mentor.new()
	# The balloon stops at the board's frame; the text is big enough to read on a phone.
	mentor.left = 16.0
	mentor.head_size = 128.0
	mentor.balloon_width = 540.0
	mentor.big_dim = 0.45
	mentor.big_width = 1040.0
	add_child(mentor)
	mentor.dialog_finished.connect(_continue)
	mentor.tapped.connect(_on_balloon_tapped)
	mentor.big_shown.connect(_make_room)

	_build_hud()
	session = LessonSession.new(rules, lesson)
	session.changed.connect(_on_changed)
	if args.has("step"):
		session.go_to(int(args.step))
	_show_step()
	if args.has("shot"):
		_demo(args)


# --- Steps ---------------------------------------------------------------------------------

func _show_step() -> void:
	_shown_step = session.step_index
	# The first cue of a guided line is already in the goal's balloon.
	_last_feedback = session.feedback.duplicate()
	_reply_pending = false
	var step := session.step()
	table.set_view_side(0)
	table.show_sfen(rules.sfen())
	_update_hud()
	_sync_table()
	if step.kind == "info":
		mentor.speak(step.text.map(Course.gote_words), step.title.to_upper())
	else:
		_show_goal()


## The exercise's explanation and goal, in the small balloon (the pieces can move meanwhile).
## In a guided line the tengu then says one move at a time: after the first, only that move.
func _show_goal() -> void:
	var step := session.step()
	var cue := session.cue()
	var at := session.line_move()
	if cue != "" and at.x > 0:
		mentor.note(Course.gote_words(cue), "LANCE %d DE %d" % [at.x + 1, at.y], "point")
		return
	var text := "\n\n".join(step.text)
	if cue != "":
		text += "\n\n" + cue
	mentor.note(Course.gote_words(text), step.title.to_upper(), "point")


func _on_changed() -> void:
	if session.finished:
		_finish()
		return
	if session.step_index != _shown_step:
		_show_step()
		return
	if _reply_pending and not session.replying:
		# The opponent's scripted answer: the table shows it before the learner moves again.
		_reply_pending = false
		_animating = true
		table.set_legal_moves(PackedStringArray(), 1, false)
		await table.play_usi(session.last_move)
		_animating = false
	_sync_table()
	_update_hud()
	_show_feedback()


func _show_feedback() -> void:
	var fb := session.feedback
	if fb.is_empty() or fb == _last_feedback:
		return
	_last_feedback = fb.duplicate()
	match fb.kind:
		"error":
			mentor.note(Course.gote_words(fb.text), "AINDA NÃO", "stern")
		"success":
			var text: String = Course.gote_words(fb.text)
			if _illegal_text != "":
				text = _illegal_text + "\n\n" + text
			mentor.note(text + "\n\nToque aqui para seguir.", "MUITO BEM!", "laugh")
			table.fx.promotion_burst(table.square_pos(Vector2i(4, 4)) + Vector3(0, 3, 0))
		_:
			if fb.text == session.cue():
				_show_goal()
			else:
				mentor.note(Course.gote_words(fb.text), session.step().title.to_upper(), "explain")
	_illegal_text = ""


## Pieces, lit squares, stars and who may move, from the session.
func _sync_table() -> void:
	var marks := {}
	var pointed := session.cue_squares()
	# While the tengu points a move, only its squares are lit.
	for sq in session.focus() if pointed.is_empty() else []:
		marks[sq] = Table.GOLD
	for sq in session.hint_squares + pointed:
		marks[sq] = HINT
	var ex := session.exercise()
	if not ex.is_empty() and ex.goal.type == "formation" and not session.solved:
		for name: String in ex.goal.pieces:
			marks[GameRules.parse_square(name)] = Table.GOLD
	table.set_marks(marks)
	table.set_stars(session.remaining_stars())
	if not _animating:
		table.set_legal_moves(session.legal_moves(), 0, session.can_move())


func _on_move(usi: String) -> void:
	session.play(usi)
	_reply_pending = session.replying
	if session.last_move != usi:
		# Not played (a wrong move, or a check in an exercise where the opponent stands still):
		# the piece goes back.
		table.show_sfen(rules.sfen())
		_sync_table()


## A move the rules forbid: the tengu says why; in an "illegal" exercise that is the goal.
func _on_illegal(from: Vector2i, kind: String, to: Vector2i) -> void:
	var reason := Explain.explain_move(rules, GameRules.drop_move(kind, to)) if from.x < 0 else Explain.explain_board_move(rules, from, to)
	var text := Explain.describe_illegal(reason, rules.position())
	_illegal_text = text
	if session.attempt_illegal(reason):
		return
	_illegal_text = ""
	if text != "":
		mentor.note(text, "LANCE PROIBIDO", "stern")


func _on_balloon_tapped() -> void:
	if session.exercise().is_empty():
		return
	if session.solved:
		_continue()
	else:
		_show_goal()


func _continue() -> void:
	if not session.can_continue():
		return
	if session.is_last() and lesson.get("game", false):
		App.guided_game(lesson.id)
		return
	session.next()


func _restart(step: int) -> void:
	if step == session.step_index:
		session.restart_step()
	else:
		session.go_to(step)
	_show_step()


## While the big tengu talks, the board slides right so he and the board are both in view.
func _make_room(on: bool) -> void:
	if _offset_tween:
		_offset_tween.kill()
	var from := -table.camera.h_offset / (2.0 * 70.0 * tan(deg_to_rad(table.camera.fov / 2.0)) / 1080.0)
	_offset_tween = create_tween().set_parallel()
	_offset_tween.tween_method(table.set_view_offset, from, BIG_OFFSET if on else 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# The lesson's controls step aside too: the tap on the balloon is the way on.
	_offset_tween.tween_property(_hud.root, "modulate:a", 0.0 if on else 1.0, 0.25)


# --- End of the lesson ---------------------------------------------------------------------

func _finish() -> void:
	var stars := session.score
	Course.save_result(lesson.id, stars)
	table.set_legal_moves(PackedStringArray(), 0, false)
	mentor.hide_now()
	var following := Course.next_lesson(lesson.id)
	var m := UiTheme.modal(self, 7, 960)
	var layer: CanvasLayer = m.layer
	var box: VBoxContainer = m.box
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for l in [UiTheme.label("LIÇÃO CONCLUÍDA", "Caption", 42), UiTheme.label(lesson.title, "Title")]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	var s := UiTheme.label("★".repeat(stars) + "☆".repeat(3 - stars) if stars > 0 else "")
	s.add_theme_font_override("font", UiTheme.kanji_font())
	s.add_theme_font_size_override("font_size", UiTheme.kanji_size(112))
	s.add_theme_color_override("font_color", UiTheme.GOLD)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	var note := UiTheme.label("Três estrelas: sem lances a mais, sem erros e sem dica." if stars > 0 and stars < 3 else (
		"Perfeito!" if stars == 3 else "Você pulou exercícios: faça todos para ganhar estrelas."), "Muted", 36)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var again := UiTheme.button("Repetir", "", 42, 100)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void:
		layer.queue_free()
		_restart(0))
	buttons.add_child(again)
	var course := UiTheme.button("Mapa do curso", "", 42, 100)
	course.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	course.pressed.connect(App.open_course)
	buttons.add_child(course)
	if not following.is_empty():
		var go := UiTheme.button("Próxima: " + following.title, "PrimaryButton", 42, 108)
		go.pressed.connect(App.open_lesson.bind(following.id))
		box.add_child(go)


# --- Controls on the right -----------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.offset_left = -HUD_WIDTH - 30.0
	col.offset_right = -30.0
	col.offset_top = 28.0
	col.custom_minimum_size.x = HUD_WIDTH
	layer.add_child(col)
	_hud.root = col

	var index: int = track.lessons.find(lesson) + 1
	var letter := String.chr(65 + Course.tracks().find(track))  # A, B, C, D
	col.add_child(UiTheme.label("TRILHA %s · LIÇÃO %d/%d" % [letter, index, track.lessons.size()], "Caption", 42))
	var title := UiTheme.label(lesson.title, "Title", 56)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	if lesson.has("term"):
		var term := UiTheme.label(lesson.term, "Muted", 36)
		term.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(term)
	_hud.step = UiTheme.label("", "Caption", 42)
	col.add_child(_hud.step)
	_hud.card = VBoxContainer.new()
	col.add_child(_hud.card)

	_hud.next = UiTheme.button("Continuar →", "PrimaryButton", 42, 100)
	_hud.next.pressed.connect(func() -> void:
		if mentor.in_dialog():
			mentor.hide_now()
		_continue())
	col.add_child(_hud.next)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_hud.hint = UiTheme.button("Dica", "", 42, 88)
	_hud.hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud.hint.pressed.connect(func() -> void: session.hint())
	row.add_child(_hud.hint)
	_hud.restart = UiTheme.button("Recomeçar", "", 42, 88)
	_hud.restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud.restart.pressed.connect(func() -> void: _restart(session.step_index))
	row.add_child(_hud.restart)
	_hud.back = UiTheme.button("←", "", 42, 88)
	_hud.back.custom_minimum_size.x = 88
	_hud.back.pressed.connect(func() -> void: _restart(session.step_index - 1))
	row.add_child(_hud.back)


func _update_hud() -> void:
	var step := session.step()
	var n: int = lesson.steps.size()
	var dots := ""
	for i in n:
		dots += "■" if i < session.step_index else ("◆" if i == session.step_index else "□")
	_hud.step.text = "PASSO %d DE %d  %s" % [session.step_index + 1, n, dots]
	# The piece the step talks about.
	for c in _hud.card.get_children():
		c.queue_free()
	if step.has("piece"):
		_hud.card.add_child(PieceCard.make(step.piece))
	var ex := session.exercise()
	_hud.next.visible = session.can_continue()
	_hud.next.text = ("Começar a partida →" if lesson.get("game", false) else "Concluir lição →") if session.is_last() else "Continuar →"
	# A line that points its moves needs no hint.
	_hud.hint.disabled = ex.is_empty() or session.solved or session.points()
	_hud.restart.disabled = ex.is_empty()
	_hud.back.disabled = session.step_index == 0


# --- Screenshots for development -----------------------------------------------------------
# godot --path godot --fixed-fps 30 res://app/lesson.tscn -- shot=/tmp/a.png lesson=rook step=1 demo=hint at=2

func _cmdline_args() -> Dictionary:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	return args


func _demo(args: Dictionary) -> void:
	await get_tree().process_frame
	match args.get("demo", ""):
		"goal":
			mentor.advance()
		"hint":
			session.hint()
		"move":
			# Plays the first move of the solution through the table.
			var ex := session.exercise()
			var move: String = ex.goal.solution[0] if ex.goal.has("solution") and ex.goal.solution is Array else LessonSession.accepted(ex.goal.line[0])[0]
			await table.play_usi(move)
			_on_move(move)
		"wrong":
			var ex := session.exercise()
			var move: String = ex.wrong.keys()[0]
			await table.play_usi(move)
			_on_move(move)
		"finish":
			session.score = 2
			_finish()
	for i in int(float(args.get("at", "2.0")) * 30.0):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	print("saved ", args["shot"])
	get_tree().quit()
