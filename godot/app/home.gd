extends Node
## The start screen: the 3D table in the background, the menu on the left (continue the saved
## game, play, learn, settings) and the tengu, who greets the player.

const MENU_WIDTH := 600.0

var table: Table
var mentor: Mentor
var _menu: VBoxContainer


func _ready() -> void:
	UiTheme.apply(get_tree())
	table = Table.new()
	add_child(table)
	table.show_controls(false)
	table.set_legal_moves(PackedStringArray(), 0, false)
	table.set_view_offset(330.0)
	_build_shade()
	_build_menu()
	mentor = Mentor.new()
	mentor.left = MENU_WIDTH + 140.0
	mentor.bottom = -40.0
	mentor.balloon_width = 560.0
	add_child(mentor)
	if not _run_cmdline_demo():
		_greet.call_deferred()


func _process(delta: float) -> void:
	# The table turns very slowly behind the menu.
	table.camera.rotate_y(sin(Time.get_ticks_msec() / 9000.0) * delta * 0.012)


## Darkens the left side, where the menu is.
func _build_shade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.set_color(0, Color(UiTheme.BG, 0.97))
	g.set_offset(0, 0.36)
	g.set_color(1, Color(UiTheme.BG, 0.0))
	g.set_offset(1, 0.66)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	layer.add_child(shade)


func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	root.add_theme_constant_override("margin_left", 110)
	root.add_theme_constant_override("margin_top", 70)
	root.add_theme_constant_override("margin_bottom", 50)
	layer.add_child(root)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = MENU_WIDTH
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	# The mark: 将棋 in red pixel brush (two screen pixels per art pixel), the name in heavy
	# condensed type.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var mark := TextureRect.new()
	mark.texture = load("res://app/logo/shogi.png")
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = mark.texture.get_size() * 2
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(mark)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", -6)
	head.add_child(names)
	var title := Label.new()
	title.text = "SHOGI"
	title.add_theme_font_override("font", UiTheme.display_font(900, 62))
	title.add_theme_font_size_override("font_size", 132)
	title.add_theme_color_override("font_color", UiTheme.TEXT)
	names.add_child(title)
	names.add_child(UiTheme.label("XADREZ JAPONÊS · APRENDA JOGANDO", "Caption", 22))

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 26
	col.add_child(spacer)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 14)
	col.add_child(_menu)
	_fill_menu()

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	var version := UiTheme.label("v" + str(ProjectSettings.get_setting("application/config/version", "?")), "Caption", 20)
	version.modulate.a = 0.6
	col.add_child(version)


func _fill_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()
	var saved := App.saved_game()
	if not saved.is_empty():
		var lv := Levels.get_level(int(saved.settings.get("level", 1)))
		var plies: int = (saved.get("moves", []) as Array).size()
		var b := _menu_button("Continuar partida", "%s · %d lances" % [lv.name, plies], "")
		b.pressed.connect(App.continue_game)
	var play := _menu_button("Jogar", "contra o computador, 5 níveis", "PrimaryButton")
	play.pressed.connect(func() -> void: NewGamePanel.open(self, App.new_game))
	var progress := Course.load_progress()
	var count := Course.completed_count(progress)
	var learn := _menu_button("Aprender a jogar", "%d de %d lições ★" % [count.done, count.total], "")
	learn.pressed.connect(App.open_course)
	var settings := _menu_button("Ajustes", "", "GhostButton")
	settings.pressed.connect(_show_settings)


## A tall button with a title and a small line under it.
func _menu_button(text: String, sub: String, variation: String) -> Button:
	var b := Button.new()
	if variation != "":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(MENU_WIDTH, 112 if sub != "" else 76)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu.add_child(b)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 30
	b.add_child(box)
	var t := Label.new()
	t.text = text.to_upper()
	t.add_theme_font_override("font", UiTheme.display())
	t.add_theme_font_size_override("font_size", 44 if sub != "" else 30)
	t.add_theme_color_override("font_color", Color.WHITE if variation == "PrimaryButton" else (UiTheme.MUTED if variation == "GhostButton" else UiTheme.TEXT))
	box.add_child(t)
	if sub != "":
		var s := UiTheme.label(sub, "Caption", 21)
		if variation == "PrimaryButton":
			s.add_theme_color_override("font_color", Color(1, 0.88, 0.8))
		box.add_child(s)
	return b


func _greet() -> void:
	if not App.settings.welcomed:
		mentor.speak([
			"Olá! Eu sou o Tengu, o mestre da montanha. Na lenda, foi um tengu quem ensinou o jovem Yoshitsune. Agora vou ensinar shogi (将棋) a você.",
			"Se você nunca jogou, comece por Aprender a jogar: eu explico as regras no próprio tabuleiro, uma peça de cada vez.",
			"Quando quiser, desafie o computador em Jogar. Eu fico por perto para explicar os lances e dar dicas.",
		], "TENGU")
		mentor.dialog_finished.connect(func() -> void: App.set_setting("welcomed", true), CONNECT_ONE_SHOT)
		return
	var next := Course.recommended_lesson(Course.load_progress())
	if not next.is_empty() and Course.completed_count(Course.load_progress()).done > 0:
		mentor.say("Bem-vindo de volta! A próxima lição é \"%s\"." % next.title, 6.0, "point")
	else:
		mentor.say("Bem-vindo de volta! Vamos jogar?", 5.0, "laugh")


func _show_settings() -> void:
	var m := UiTheme.modal(self, 5, 760)
	var layer: CanvasLayer = m.layer
	var box: VBoxContainer = m.box
	box.add_child(UiTheme.label("Ajustes", "Title"))
	var reduced := CheckButton.new()
	reduced.text = "Efeitos reduzidos (celulares mais fracos)"
	reduced.button_pressed = App.settings.reduced_effects
	reduced.toggled.connect(func(on: bool) -> void: App.set_setting("reduced_effects", on))
	box.add_child(reduced)
	var welcome := UiTheme.button("Ouvir as boas-vindas do Tengu de novo", "", 28, 76)
	welcome.pressed.connect(func() -> void:
		layer.queue_free()
		App.set_setting("welcomed", false)
		_greet())
	box.add_child(welcome)
	var about := UiTheme.label("Shogi v%s · GPL-3.0\nRegras e computador: Fairy-Stockfish. Fontes: Archivo, IBM Plex Mono, Potta One e Kaisei Tokumin (OFL)." % ProjectSettings.get_setting("application/config/version", "?"), "Muted", 22)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 680
	box.add_child(about)
	var close := UiTheme.button("Fechar", "PrimaryButton", 32, 84)
	close.pressed.connect(layer.queue_free)
	box.add_child(close)


# --- Screenshots for development -----------------------------------------------------------
# godot --path godot --fixed-fps 30 res://app/home.tscn -- shot=/tmp/a.png demo=welcome at=3

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
	await get_tree().process_frame
	match args.get("demo", "welcome"):
		"welcome":
			App.settings.welcomed = false
			_greet()
		"back":
			App.settings.welcomed = true
			_greet()
		"play":
			NewGamePanel.open(self, App.new_game)
		"settings":
			_show_settings()
	for i in int(float(args.get("at", "2.0")) * 30.0):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	print("saved ", args["shot"])
	get_tree().quit()
