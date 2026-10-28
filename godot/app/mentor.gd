class_name Mentor
extends CanvasLayer
## The mentor: the tengu (app/mentor/mascot.gd) and a speech balloon. It appears only when it
## speaks, and the text types itself out. It has two sizes:
##
## - **Big** (`speak(pages, title)`): something to read to the end (the welcome, a lesson's
##   explanation, the end of a lesson). The whole tengu, large, over a dimmed screen; each tap
##   shows the next page and after the last one `dialog_finished` is emitted. The pieces wait.
## - **Small** (`say(text)`, `note(text, title)`): words while the player can move the pieces (an
##   exercise's goal, a refused move, a hint, the coach). Only the tengu's head, in a medallion
##   in the corner, so the board stays free. `say` goes away by itself; `note` stays until
##   replaced or hidden.
##
## Every way of talking takes a `pose` for the tengu (Mascot.POSES): "explain", "point",
## "startled", "laugh", "stern", or "" for the calm one.

signal dialog_finished
## A tap on a small balloon that stays (the controller may react).
signal tapped
## The big tengu comes in (true) or goes away (false), so a screen can make room.
signal big_shown(on: bool)

const SHOW_TIME := 0.25
const CHARS_PER_SECOND := 55.0
## Presses closer than this are one tap (see _on_input).
const TAP_REPEAT_MS := 250
const BALLOON := Color(0.97, 0.93, 0.85, 0.97)
const BALLOON_BORDER := Color(0.75, 0.55, 0.2)
const INK := Color(0.15, 0.08, 0.04)
## The big tengu's height: a whole multiple of the art's, so every art pixel is the same size.
const BIG_HEIGHT := 633.0
const BIG_TEXT_SIZE := 36
## Space kept free above the big balloon.
const TOP_GAP := 20.0

## Layout of the small balloon, set before adding the node: bottom left corner of the screen,
## offset upward by `bottom`; the width of the balloon and the size of the head.
var bottom := -140.0
var left := 24.0
var balloon_width := 440.0
var head_size := 150.0
var small_text_size := 36
## Width of the big balloon; how dark the screen gets behind the big tengu.
var big_width := 820.0
var big_dim := 0.62

var _root: Control
var _small: HBoxContainer
var _small_text: Dictionary       ## {panel, title, text, footer} of the small balloon
var _big: Control
var _big_text: Dictionary
var _hide_timer: SceneTreeTimer
var _tween: Tween
var _shown: Control              ## the box on screen (_small or _big), or null
var _label: Label                ## the label typing out
var _pages: Array = []
var _page := -1                  ## page of the big dialogue on screen; -1 for none
var _dialog_title := ""
var _typed := 0.0
var _head: TextureRect
var _last_tap_ms := -1000
var _tengu: Mascot


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_small()
	_build_big()


func _process(delta: float) -> void:
	if _label and _label.visible_characters >= 0 and _label.visible_characters < _label.get_total_character_count():
		_typed += delta * CHARS_PER_SECOND
		_label.visible_characters = int(_typed)
		if _label.visible_characters >= _label.get_total_character_count():
			_finish_typing()


# --- Building ------------------------------------------------------------------------------

func _build_small() -> void:
	_small = HBoxContainer.new()
	_small.add_theme_constant_override("separation", 10)
	_root.add_child(_small)
	_small.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_small.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_small.offset_left = left
	_small.offset_bottom = bottom
	_small.offset_top = bottom
	_small.gui_input.connect(_on_input)

	# The head in a lacquered medallion: an octagon in pixel steps, its rim showing around the head.
	var medallion := PanelContainer.new()
	var sb := UiTheme.box(Color(0.2, 0.07, 0.05), Color(1.0, 0.75, 0.3), 4, 0, int(head_size / UiTheme.PX / 4))
	sb.set_content_margin_all(2 * UiTheme.PX)
	medallion.add_theme_stylebox_override("panel", sb)
	medallion.custom_minimum_size = Vector2(head_size, head_size)
	medallion.size_flags_vertical = Control.SIZE_SHRINK_END
	medallion.mouse_filter = Control.MOUSE_FILTER_PASS
	medallion.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_small.add_child(medallion)
	var head := TextureRect.new()
	head.texture = Mascot.head("")
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_head = head
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.add_child(head)

	_small_text = _balloon(balloon_width, small_text_size, "left", 70.0)
	_small_text.panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_small.add_child(_small_text.panel)
	_small.modulate.a = 0.0
	_small.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_big() -> void:
	_big = Control.new()
	_root.add_child(_big)
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.gui_input.connect(_on_input)
	# The screen dims: this is to be read now, the pieces wait.
	var dim := UiTheme.shade(Color(0.02, 0.012, 0.008), big_dim)
	_big.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The whole tengu at the bottom left, the balloon over his head (the right side of the screen
	# stays free for the board).
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(column)
	column.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = 30
	column.offset_bottom = -4
	column.offset_top = -4
	var tengu_width := BIG_HEIGHT * Mascot.aspect()
	_big_text = _balloon(big_width, BIG_TEXT_SIZE, "bottom", tengu_width * 0.5 - 30.0)
	_big_text.panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(_big_text.panel)
	var tengu := Mascot.new()
	tengu.custom_minimum_size = Vector2(tengu_width, BIG_HEIGHT)
	tengu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(tengu)
	_tengu = tengu
	_big.modulate.a = 0.0
	_big.visible = false


## A paper balloon with a gold edge, in pixels: title (small capitals, red), text, footer
## ("toque para continuar").
func _balloon(width: float, text_size: int, tail_side: String, tail_at: float) -> Dictionary:
	var panel := PanelContainer.new()
	var sb := UiTheme.box(BALLOON, BALLOON_BORDER, 3, 0, 3)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var tail := _Tail.new()
	tail.colour = BALLOON
	tail.border = BALLOON_BORDER
	tail.side = tail_side
	tail.at = tail_at
	panel.add_child(tail)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(inner)
	var title := Label.new()
	title.add_theme_font_override("font", UiTheme.mono())
	title.add_theme_font_size_override("font_size", UiTheme.text_size(int(text_size * 0.66)))
	title.add_theme_color_override("font_color", Color(0.62, 0.12, 0.06))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(title)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(width - 56, 0)
	text.add_theme_font_size_override("font_size", UiTheme.text_size(text_size))
	text.add_theme_color_override("font_color", INK)
	text.add_theme_constant_override("line_spacing", 4)
	inner.add_child(text)
	var footer := Label.new()
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_font_override("font", UiTheme.mono())
	footer.add_theme_font_size_override("font_size", UiTheme.text_size(int(text_size * 0.66)))
	footer.add_theme_color_override("font_color", Color(0.45, 0.32, 0.2))
	inner.add_child(footer)
	return {"panel": panel, "title": title, "text": text, "footer": footer}


# --- Talking -------------------------------------------------------------------------------

## A short remark (small): stays long enough to read it, or until tapped.
func say(text: String, seconds := 0.0, pose := "") -> void:
	note(text, "", pose)
	if seconds <= 0.0:
		seconds = 3.0 + text.length() / 14.0
	var timer := get_tree().create_timer(seconds)
	_hide_timer = timer
	timer.timeout.connect(func() -> void:
		if _hide_timer == timer:
			hide_now())


## Words that stay (small) while the player moves the pieces: an exercise's goal, feedback.
func note(text: String, title := "", pose := "") -> void:
	_hide_timer = null
	_page = -1
	_head.texture = Mascot.head(pose)
	_show(_small, _small_text, title, text)
	_small_text.footer.visible = false


## Something to read to the end (big), page by page; `dialog_finished` after the last tap.
func speak(pages: Array, title := "", pose := "explain") -> void:
	_hide_timer = null
	_tengu.set_pose(pose)
	_pages = _fit_pages(pages)
	_page = 0
	_dialog_title = title
	_show_page()


## Pages too long for the big balloon over the tengu are cut between sentences into more pages
## (the text keeps its size).
func _fit_pages(pages: Array) -> Array:
	var label: Label = _big_text.text
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var width := label.custom_minimum_size.x
	var line := font.get_height(size) + label.get_theme_constant("line_spacing")
	# The balloon grows upward from the tengu: what is left of the screen, less its frame,
	# title and footer.
	var room := _root.size.y - BIG_HEIGHT - 26.0 - TOP_GAP - 32.0 - 2.0 * (line + 8.0)
	var max_lines := maxi(2, int(room / line))
	var lines_of := func(text: String) -> int:
		return roundi(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y / font.get_height(size))
	var out := []
	for page in pages:
		var text := str(page)
		if lines_of.call(text) <= max_lines:
			out.append(text)
			continue
		var chunk := ""
		for sentence in _sentences(text):
			var joined := sentence if chunk == "" else chunk + " " + sentence
			if chunk != "" and lines_of.call(joined) > max_lines:
				out.append(chunk)
				chunk = sentence
			else:
				chunk = joined
		if chunk != "":
			out.append(chunk)
	return out


## The sentences of a paragraph, each with its final mark.
static func _sentences(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var start := 0
	for i in text.length():
		if text[i] in ".!?…" and i + 1 < text.length() and text[i + 1] == " ":
			out.append(text.substr(start, i + 1 - start))
			start = i + 2
	out.append(text.substr(start))
	return out


## True while a big dialogue is on screen.
func in_dialog() -> bool:
	return _page >= 0


func is_showing() -> bool:
	return _shown != null


func _show_page() -> void:
	_show(_big, _big_text, _dialog_title, str(_pages[_page]))
	var last := _page == _pages.size() - 1
	var count := "%d/%d   " % [_page + 1, _pages.size()] if _pages.size() > 1 else ""
	_big_text.footer.text = count + ("toque para continuar →" if not last else "toque para seguir →")
	_big_text.footer.visible = true


func _show(box: Control, labels: Dictionary, title: String, text: String) -> void:
	var other := _big if box == _small else _small
	# The other balloon goes away at once: on screen, or still fading out after hide_now (whose
	# fade the tween below replaces, so it would otherwise stay on screen, frozen).
	if _shown == other or other.modulate.a > 0.0:
		other.modulate.a = 0.0
		other.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if other == _big:
			_big.visible = false
			if _shown == other:
				big_shown.emit(false)
	if box == _big and _shown != _big:
		big_shown.emit(true)
	labels.title.text = title
	labels.title.visible = title != ""
	labels.text.text = text
	_label = labels.text
	_typed = 0.0
	_label.visible_characters = 0
	if _tween:
		_tween.kill()
	box.visible = true
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	if _shown != box:
		_tween = create_tween().set_parallel()
		_tween.tween_property(box, "modulate:a", 1.0, SHOW_TIME)
		if box == _small:
			# Rises a little into place, measured from its anchor at the bottom of the screen.
			_small.offset_top = bottom + 30.0
			_small.offset_bottom = bottom + 30.0
			_tween.tween_property(_small, "offset_top", bottom, SHOW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(_small, "offset_bottom", bottom, SHOW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		box.modulate.a = 1.0
	_shown = box


func _finish_typing() -> void:
	if _label:
		_label.visible_characters = -1


func _on_input(e: InputEvent) -> void:
	var pressed: bool = (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	# On a phone one tap arrives twice: as the touch and as the mouse click Godot makes from it.
	# Taken as two taps, it finished the typing and turned the page (or closed the dialogue and
	# then acted on what came next) in one go. A second press this soon is the same tap.
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < TAP_REPEAT_MS:
		return
	_last_tap_ms = now
	advance()


## What a tap does: finish typing, show the next page, end the dialogue or close the remark.
func advance() -> void:
	if _label and _label.visible_characters >= 0:
		_finish_typing()
		return
	if _page < 0:
		if _hide_timer != null:
			hide_now()
		tapped.emit()
		return
	if _page < _pages.size() - 1:
		_page += 1
		_show_page()
		return
	hide_now()
	dialog_finished.emit()


func hide_now() -> void:
	_hide_timer = null
	_page = -1
	_finish_typing()
	var box := _shown
	_shown = null
	if box == null:
		return
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(box, "modulate:a", 0.0, SHOW_TIME)
	if box == _big:
		big_shown.emit(false)
		_tween.tween_callback(func() -> void: _big.visible = _shown == _big)


## The balloon's tail: a small triangle on its left or bottom edge, pointing at the tengu, drawn
## in art pixels with the balloon's dark outline and gold rim on its two outer sides; where it
## meets the balloon it covers the balloon's rim, so the two read as one shape.
class _Tail extends Control:
	var colour: Color
	var border: Color
	var side := "left"
	var at := 70.0                   ## distance along that edge

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## The container places this control inside its margins: draw from the balloon's corner.
	func _draw() -> void:
		var px := float(UiTheme.PX)
		var parent_size: Vector2 = get_parent().size
		var o := -position
		var bottom := side == "bottom"
		var rim := 4 * px                # the balloon's outline and rim, covered by the tail
		var tri: PackedVector2Array
		if bottom:
			var h := parent_size.y
			tri = PackedVector2Array([o + Vector2(at - 16, h - rim), o + Vector2(at + 4, h + 26), o + Vector2(at + 18, h - rim)])
		else:
			var y := minf(parent_size.y - 30.0, at)
			tri = PackedVector2Array([o + Vector2(rim, y - 18), o + Vector2(-24, y + 6), o + Vector2(rim, y + 12)])
		var lo := Vector2(INF, INF)
		var hi := -lo
		for p in tri:
			lo = lo.min(p)
			hi = hi.max(p)
		lo = (lo / px).floor() - Vector2.ONE
		var cells := Vector2i(((hi / px).ceil() - lo)) + Vector2i(2, 2)
		# 0 outside, 1 inside the tail, 2 inside the balloon (no edge drawn against it).
		var kind := {}
		for cy in cells.y:
			for cx in cells.x:
				var centre := (lo + Vector2(cx, cy) + Vector2(0.5, 0.5)) * px
				var k := 0
				if Geometry2D.point_is_inside_triangle(centre, tri[0], tri[1], tri[2]):
					k = 1
				elif (bottom and centre.y < o.y + parent_size.y) or (not bottom and centre.x > o.x):
					k = 2
				kind[Vector2i(cx, cy)] = k
		var steps: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
		var edge := {}
		for cell: Vector2i in kind:
			if kind[cell] == 1 and steps.any(func(d: Vector2i) -> bool: return kind.get(cell + d, 0) == 0):
				edge[cell] = true
		for cell: Vector2i in kind:
			if kind[cell] != 1:
				continue
			var c := colour
			if edge.has(cell):
				c = UiTheme.OUTLINE
			elif steps.any(func(d: Vector2i) -> bool: return edge.has(cell + d)):
				c = border
			draw_rect(Rect2((lo + Vector2(cell)) * px, Vector2(px, px)), c)

	func _process(_delta: float) -> void:
		queue_redraw()
