class_name Mentor
extends CanvasLayer
## The mentor: a portrait in the corner that appears only when it speaks, with a speech balloon.
## The portrait is a placeholder (the 師 emblem) until the generated art arrives; set
## `portrait_texture` to use an image instead.

const SHOW_TIME := 0.25
const BOTTOM := -140.0  ## above the "Movimentos" button

var portrait_texture: Texture2D

var _root: Control
var _balloon: PanelContainer
var _text: Label
var _hide_timer: SceneTreeTimer
var _tween: Tween


func _ready() -> void:
	layer = 3
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Bottom left, above the "Movimentos" button; grows upward with longer text.
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_root.add_child(box)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = 24
	box.offset_bottom = BOTTOM
	box.offset_top = BOTTOM

	var portrait := _portrait()
	portrait.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_child(portrait)

	_balloon = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.93, 0.85, 0.96)
	sb.border_color = Color(0.75, 0.55, 0.2)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_balloon.add_theme_stylebox_override("panel", sb)
	_balloon.size_flags_vertical = Control.SIZE_SHRINK_END
	_balloon.custom_minimum_size = Vector2(360, 0)
	box.add_child(_balloon)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(320, 0)
	_text.add_theme_font_size_override("font_size", 26)
	_text.add_theme_color_override("font_color", Color(0.15, 0.08, 0.04))
	_balloon.add_child(_text)
	# Tapping the balloon closes it.
	_balloon.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			hide_now())

	box.modulate.a = 0.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_meta("box", box)


func _portrait() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(150, 150)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.5, 0.04, 0.03)
	sb.border_color = Color(1.0, 0.75, 0.3)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(75)
	frame.add_theme_stylebox_override("panel", sb)
	if portrait_texture:
		var tr := TextureRect.new()
		tr.texture = portrait_texture
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.add_child(tr)
	else:
		var l := Label.new()
		l.text = "師"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 84)
		l.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
		frame.add_child(l)
	return frame


## Says something; stays long enough to read it, or until tapped.
func say(text: String, seconds := 0.0) -> void:
	var box: Control = _root.get_meta("box")
	_text.text = text
	if seconds <= 0.0:
		seconds = 2.5 + text.length() / 14.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	# Rises a little into place, measured from its anchor at the bottom of the screen.
	if box.modulate.a < 0.5:
		box.offset_top = BOTTOM + 30.0
		box.offset_bottom = BOTTOM + 30.0
	_tween.tween_property(box, "modulate:a", 1.0, SHOW_TIME)
	_tween.tween_property(box, "offset_top", BOTTOM, SHOW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(box, "offset_bottom", BOTTOM, SHOW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_balloon.mouse_filter = Control.MOUSE_FILTER_STOP
	var timer := get_tree().create_timer(seconds)
	_hide_timer = timer
	timer.timeout.connect(func() -> void:
		if _hide_timer == timer:
			hide_now())


func hide_now() -> void:
	var box: Control = _root.get_meta("box")
	_hide_timer = null
	_balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(box, "modulate:a", 0.0, SHOW_TIME)
