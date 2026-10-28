class_name NewGamePanel
extends RefCounted
## "Nova partida": the computer's level and the player's side, as a modal panel. Used by the
## start screen and by the game's menu. `on_start` receives (level: int, side: String), the side
## being "black", "white" or "random" (drawn by the game, again on each restart).

## Gote's lacquer is black in the pixel look and red in the classic one.
static func side_labels() -> Array:
	return ["先手 Sente\npérola, começa", "後手 Gote\n%s" % ("preto" if Koma.pixel else "vermelho"), "Aleatório"]


static func open(parent: Node, on_start: Callable, level := 1) -> void:
	var m := UiTheme.modal(parent, 5, 1180)
	var layer: CanvasLayer = m.layer
	var box: VBoxContainer = m.box
	var close := func() -> void: layer.queue_free()

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.label("Nova partida", "Title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UiTheme.button("✕", "GhostButton", 36, 72)
	x.custom_minimum_size.x = 72
	x.pressed.connect(close)
	head.add_child(x)

	var chosen := {"level": level, "side": 0}
	box.add_child(UiTheme.label("NÍVEL DO COMPUTADOR", "Caption"))
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 10)
	box.add_child(levels)
	var about := UiTheme.label("", "Muted")
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(1100, 70)
	var level_group := ButtonGroup.new()
	for lv: Dictionary in Levels.LEVELS:
		# Each level is its rival: the face, then the level's number and name.
		var b := UiTheme.button("", "", 28, 250)
		var card := VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_theme_constant_override("separation", 8)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(card)
		var face := Rivals.portrait(lv.id, 140)
		face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(face)
		var caption := UiTheme.label("%d · %s" % [lv.id, Rivals.of_level(lv.id).name], "", 26)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_override("font", UiTheme.display())
		card.add_child(caption)
		var level_name := UiTheme.label(lv.name.to_upper(), "Caption", 18)
		level_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(level_name)
		b.toggle_mode = true
		b.button_group = level_group
		b.button_pressed = lv.id == chosen.level
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			chosen.level = lv.id
			about.text = lv.get("description", ""))
		levels.add_child(b)
	about.text = Levels.get_level(chosen.level).get("description", "")
	box.add_child(about)

	box.add_child(UiTheme.label("SEU LADO", "Caption"))
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 10)
	box.add_child(sides)
	var side_group := ButtonGroup.new()
	for i in 3:
		var b := UiTheme.button(side_labels()[i], "", 28, 112)
		b.toggle_mode = true
		b.button_group = side_group
		b.button_pressed = i == 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: chosen.side = i)
		sides.add_child(b)

	var go := UiTheme.button("Começar", "PrimaryButton", 40, 100)
	go.pressed.connect(func() -> void:
		close.call()
		on_start.call(chosen.level, ["black", "white", "random"][chosen.side]))
	box.add_child(go)
