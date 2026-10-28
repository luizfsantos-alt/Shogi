extends Node
## The course map, in two tabs. Iniciante: the three tracks side by side (基本 basics, 手筋 tactics,
## 戦略 strategy). Avançado: the advanced track (上級), one column per part. Each lesson shows its
## stars; the recommended one stands out.

const TRACK_LETTERS := ["A", "B", "C", "D"]
const TABS := ["Iniciante", "Avançado"]
## Pixel emblem of each track (app/course_art/<name>.png).
const EMBLEMS := {"A": "basics", "B": "tactics", "C": "strategy"}

var mentor: Mentor
var _tab_buttons: Array[Button] = []
var _columns: HBoxContainer
var _progress: Dictionary
var _recommended: Dictionary


func _ready() -> void:
	UiTheme.apply(get_tree())
	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	var fill := ColorRect.new()
	fill.color = UiTheme.BG
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(fill)

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		root.add_theme_constant_override("margin_" + side, 56)
	root.add_theme_constant_override("margin_top", 34)
	root.add_theme_constant_override("margin_bottom", 30)
	layer.add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	root.add_child(col)

	var progress := Course.load_progress()
	var recommended := Course.recommended_lesson(progress)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var back := UiTheme.button("← Início", "GhostButton", 30, 72)
	back.pressed.connect(App.go_home)
	head.add_child(back)
	var title := UiTheme.label("Aprender a jogar", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var count := Course.completed_count(progress)
	head.add_child(UiTheme.label("%d / %d LIÇÕES" % [count.done, count.total], "Caption", 24))
	if not recommended.is_empty():
		var go := UiTheme.button("Continuar: " + recommended.title, "PrimaryButton", 30, 76)
		go.pressed.connect(App.open_lesson.bind(recommended.id))
		head.add_child(go)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	col.add_child(tabs)
	for i in TABS.size():
		var tab := UiTheme.button(TABS[i], "GhostButton", 28, 64)
		tab.toggle_mode = true
		tab.custom_minimum_size.x = 260
		tab.pressed.connect(_show_tab.bind(i))
		tabs.add_child(tab)
		_tab_buttons.append(tab)

	_columns = HBoxContainer.new()
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("separation", 22)
	col.add_child(_columns)
	_progress = progress
	_recommended = recommended
	# Open on the tab of the recommended lesson (Avançado once the beginner course is done).
	var start_tab := 0
	if not recommended.is_empty():
		start_tab = 1 if Course.find_lesson(recommended.id).track.get("advanced", false) else 0
	elif count.done > 0:
		start_tab = 1
	_show_tab(start_tab)

	mentor = Mentor.new()
	mentor.bottom = -26.0
	mentor.left = 1180.0
	mentor.balloon_width = 520.0
	add_child(mentor)
	if count.done == 0:
		mentor.say("Siga as trilhas em ordem: os Fundamentos ensinam todas as regras, até a primeira partida.", 7.0, "explain")
	_run_cmdline_demo()


func _show_tab(tab: int) -> void:
	for i in _tab_buttons.size():
		var b := _tab_buttons[i]
		b.set_pressed_no_signal(i == tab)
		b.add_theme_color_override("font_color", UiTheme.TEXT if i == tab else UiTheme.MUTED)
		var line := UiTheme.box(Color(UiTheme.FRAME, 0.9) if i == tab else Color(0, 0, 0, 0), UiTheme.GOLD if i == tab else Color.TRANSPARENT, 2 if i == tab else 0, 10)
		b.add_theme_stylebox_override("normal", line)
		b.add_theme_stylebox_override("pressed", line)
	for c in _columns.get_children():
		c.queue_free()
	var recommended: String = _recommended.get("id", "")
	var tlist := Course.tracks()
	for i in tlist.size():
		var track: Dictionary = tlist[i]
		if bool(track.get("advanced", false)) != (tab == 1):
			continue
		if track.has("parts"):
			# A long track: one column per part, numbered on from the previous parts.
			var n := 0
			for p in track.parts.size():
				var part: Dictionary = track.parts[p]
				var lessons: Array = track.lessons.filter(func(l): return l.get("part", "") == part.id)
				var column := {"title": part.title, "term": part.term, "description": part.description, "lessons": lessons}
				var caption := "TRILHA %s · PARTE %d" % [TRACK_LETTERS[i], p + 1]
				_columns.add_child(_track_column(column, TRACK_LETTERS[i], _progress, recommended, caption, n, 40))
				n += lessons.size()
		else:
			_columns.add_child(_track_column(track, TRACK_LETTERS[i], _progress, recommended))


func _track_column(track: Dictionary, letter: String, progress: Dictionary, recommended: String, caption := "", first := 0, title_size := 46) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.95), UiTheme.BORDER, 2, 18))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var count := Course.completed_count(progress, track)
	if caption == "":
		caption = "TRILHA %s" % letter
	box.add_child(UiTheme.label("%s · %d/%d" % [caption, count.done, count.total], "Caption", 22))
	var name := HBoxContainer.new()
	name.add_theme_constant_override("separation", 16)
	name.custom_minimum_size.y = 98  # the emblem's height, so the three columns line up
	box.add_child(name)
	# The track's pixel emblem, two screen pixels per art pixel (only the ones already drawn).
	var emblem_path := "res://app/course_art/%s.png" % EMBLEMS.get(letter, "")
	if ResourceLoader.exists(emblem_path):
		var emblem := TextureRect.new()
		emblem.texture = load(emblem_path)
		emblem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		emblem.custom_minimum_size = Vector2(96, 98)
		name.add_child(emblem)
	var title := UiTheme.label(track.title, "Title", title_size)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name.add_child(title)
	# "Kihon 基本": the kanji in pixels, gold.
	var term: String = track.get("term", "")
	var kanji := term.substr(term.find(" ") + 1)
	var k := UiTheme.label(kanji)
	k.add_theme_font_override("font", UiTheme.kanji_font())
	k.add_theme_font_size_override("font_size", UiTheme.kanji_size(48))
	k.add_theme_color_override("font_color", UiTheme.GOLD)
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name.add_child(k)
	var desc := UiTheme.label(track.description, "Muted", 24)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var n := first
	for lesson: Dictionary in track.lessons:
		n += 1
		var b := _lesson_button(lesson, n, int(progress.stars.get(lesson.id, 0)), lesson.id == recommended)
		list.add_child(b)
		if lesson.id == recommended:
			_scroll_to.call_deferred(scroll, b)
	return panel


func _lesson_button(lesson: Dictionary, n: int, stars: int, recommended: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if recommended:
		b.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.ACCENT_DEEP, UiTheme.ACCENT, 3, 12))
	elif stars > 0:
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(UiTheme.SURFACE_2, 0.7), Color(UiTheme.GOLD, 0.35), 2, 12))
	b.pressed.connect(App.open_lesson.bind(lesson.id))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -16
	row.add_theme_constant_override("separation", 14)
	b.add_child(row)
	var num := UiTheme.label("%02d" % n, "Caption", 24)
	num.custom_minimum_size.x = 40
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(num)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var t := Label.new()
	t.text = ("▷ " if lesson.get("game", false) else "") + lesson.title
	t.add_theme_font_override("font", UiTheme.display())
	t.add_theme_font_size_override("font_size", UiTheme.display_size(42))
	# The whole title, on as many lines as it takes: the button grows to hold it.
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_constant_override("line_spacing", -10)
	text.add_child(t)
	var s := UiTheme.label(lesson.summary, "Muted", 21)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.clip_text = true
	text.add_child(s)
	var st := UiTheme.label(_stars_text(stars) if stars > 0 else ("PRÓXIMA" if recommended else ""), "Caption")
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if stars > 0:
		# The stars come from the pixel kanji font: a size on its grid.
		st.add_theme_font_override("font", UiTheme.kanji_font())
		st.add_theme_font_size_override("font_size", UiTheme.kanji_size(32))
	if recommended and stars == 0:
		st.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(st)
	# The row is laid over the button, not inside a container: the button follows its height.
	var fit := func() -> void:
		b.custom_minimum_size.y = maxf(96, text.get_combined_minimum_size().y + 16)
	text.minimum_size_changed.connect(fit)
	return b


static func _stars_text(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(3 - stars)


func _scroll_to(scroll: ScrollContainer, control: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(control):  # gone if the tab changed
		scroll.ensure_control_visible(control)


# godot --path godot --fixed-fps 30 res://app/course.tscn -- shot=/tmp/a.png at=1 [tab=1]
func _run_cmdline_demo() -> void:
	var shot := ""
	var at := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			shot = a.substr(5)
		elif a.begins_with("at="):
			at = float(a.substr(3))
		elif a.begins_with("tab="):
			_show_tab(int(a.substr(4)))
	if shot == "":
		return
	for i in int(at * 30.0):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(shot)
	print("saved ", shot)
	get_tree().quit()
