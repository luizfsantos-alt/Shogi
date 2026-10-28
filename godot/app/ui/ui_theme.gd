class_name UiTheme
extends RefCounted
## The Genpei look of the PWA in pixel art, like the tengu and the rivals, for every screen of the
## app (not the table: its look is its own): charred dark surfaces, red for action and gold for
## value, drawn on a grid of PX screen pixels per art pixel. Boxes are chamfered in steps with a
## dark outline, a light top edge and a dark bottom edge; text is Jersey 10 (titles, buttons,
## labels: heavy and condensed), Pixelify Sans (body text) and DotGothic16 (kanji and symbols),
## without smoothing, in sizes on each font's own grid.

const BG := Color("0e0a09")
const SURFACE := Color("17100d")
const SURFACE_2 := Color("1f1612")
const FRAME := Color("3a2219")
const BORDER := Color("4a2a20")
const IRON := Color("6b5446")
const TEXT := Color("efe4cc")
const MUTED := Color("a8987a")
const ACCENT := Color("ff4b37")
const ACCENT_DEEP := Color("7a0d14")
const BLOOD := Color("d42a1c")
const GOLD := Color("d6a63a")
const OUTLINE := Color("080404")

## Screen pixels per art pixel of the interface (the emblems' and the logo's scale).
const PX := 2
## Art pixels cut off each corner of a box.
const CHAMFER := 2
## Pixelify Sans is drawn on a grid of 12 pixels per em, Jersey 10 on 14, DotGothic16 on 16: font
## sizes are multiples of these, so every font pixel is a whole block of screen pixels.
const TEXT_GRID := 12
const DISPLAY_GRID := 14
const KANJI_GRID := 16

const FONTS := "res://app/ui/fonts/"
const DITHER := preload("res://app/ui/dither.gdshader")

static var _theme: Theme
static var _body: Font
static var _display: Font
static var _kanji: Font
static var _boxes := {}
static var _applied := false


## A bundled font without smoothing, hinting or subpixel positions: hard pixels.
static func _pixel_font(file: String) -> FontFile:
	var f: FontFile = load(FONTS + file)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f


## DotGothic16 reduced to the Japanese characters the app uses and the symbols (★ ← ▷ ≡…)
## the Latin fonts lack (`node scripts/make-kanji-font.mjs --godot` remakes it).
static func _dot() -> FontFile:
	return _pixel_font("dot-kanji.ttf")


## Pixelify Sans, regular: body text. Its only fallback is the pixel kanji font: a fallback's
## line height counts for every line, so the device's own fonts are not listed (Godot still turns
## to them for a character no bundled font has, without counting their height).
static func body() -> Font:
	if _body == null:
		var f := _pixel_font("pixelify-400.ttf")
		f.fallbacks = [_dot()]
		_body = f
	return _body


## Jersey 10, heavy and condensed: titles, buttons, labels.
static func display() -> Font:
	if _display == null:
		var f := _pixel_font("jersey-10.ttf")
		f.fallbacks = [_dot()]
		_display = f
	return _display


## Small labels ("NÍVEL", "TRILHA A"): the display face, in gold capitals (see "Caption").
static func mono() -> Font:
	return display()


## Kanji in pixels (DotGothic16), the Latin around them in Pixelify Sans.
static func kanji_font() -> Font:
	if _kanji == null:
		var v := FontVariation.new()
		v.base_font = _dot()
		v.fallbacks = [body()]
		_kanji = v
	return _kanji


## The nearest size on the body font's grid (at least two screen pixels per font pixel).
static func text_size(size: int) -> int:
	return maxi(TEXT_GRID * 2, roundi(size / float(TEXT_GRID)) * TEXT_GRID)


## The nearest size on the display font's grid.
static func display_size(size: int) -> int:
	return maxi(DISPLAY_GRID * 2, roundi(size / float(DISPLAY_GRID)) * DISPLAY_GRID)


## The nearest size on the kanji font's grid.
static func kanji_size(size: int) -> int:
	return maxi(KANJI_GRID * 2, roundi(size / float(KANJI_GRID)) * KANJI_GRID)


## A pixel box: `bg` inside, a ring of `border` (when `border_width` > 0) in a dark outline, the
## corners cut in steps of `chamfer` art pixels. `margin` is the content's margin in screen pixels
## (more on the sides). Without background or border it is an empty box with those margins.
static func box(bg: Color, border := Color.TRANSPARENT, border_width := 0, margin := 16, chamfer := CHAMFER) -> StyleBox:
	var bordered := border_width > 0 and border.a > 0.0
	var sb: StyleBox
	if bg.a <= 0.0 and not bordered:
		sb = StyleBoxEmpty.new()
	else:
		var key := "%s|%s|%s|%d" % [bg.to_html(), border.to_html(), bordered, chamfer]
		if not _boxes.has(key):
			_boxes[key] = ImageTexture.create_from_image(_box_image(bg, border, bordered, chamfer))
		var t := StyleBoxTexture.new()
		t.texture = _boxes[key]
		t.set_texture_margin_all((chamfer + 3) * PX)
		sb = t
	sb.content_margin_left = margin * 1.4
	sb.content_margin_right = margin * 1.4
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


## The box's nine-slice picture, already at PX screen pixels per art pixel: a square of
## 2 × (chamfer + 3) + 1 art pixels whose middle row and column stretch.
static func _box_image(bg: Color, border: Color, bordered: bool, chamfer: int) -> Image:
	var n := 2 * (chamfer + 3) + 1
	var fill_from := 2 if bordered else 0   # the outline and the border ring come first
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var depth := _depth(x, y, n, chamfer)
			if depth < 0:
				continue
			var c := bg
			if bordered and depth == 0:
				c = OUTLINE
			elif bordered and depth == 1:
				c = border
			elif _depth(x, y - 1, n, chamfer) < fill_from:
				c = bg.lightened(0.12)
			elif _depth(x, y + 1, n, chamfer) < fill_from:
				c = bg.darkened(0.35)
			img.set_pixel(x, y, c)
	img.resize(n * PX, n * PX, Image.INTERPOLATE_NEAREST)
	return img


## How deep (x, y) lies inside the chamfered square of side `n`: 0 on its edge, < 0 outside.
static func _depth(x: int, y: int, n: int, chamfer: int) -> int:
	if x < 0 or y < 0 or x >= n or y >= n:
		return -1
	var dx := mini(x, n - 1 - x)
	var dy := mini(y, n - 1 - y)
	return mini(mini(dx, dy), dx + dy - chamfer)


## A picture from rows of characters, one per art pixel ("." clear, others from `colours`),
## at `scale` screen pixels per art pixel (PX by default): the switch, the slider's grabber.
static func sprite(rows: PackedStringArray, colours: Dictionary, scale := PX) -> ImageTexture:
	var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y][x]
			if colours.has(ch):
				img.set_pixel(x, y, colours[ch])
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## The switch of a CheckButton, 20 × 10 art pixels drawn a size up (3 screen pixels each, so it
## reads beside the text): off (dark track, iron knob on the left) or
## on (red track, gold knob on the right).
static func _switch(on: bool, dim := false) -> ImageTexture:
	var knob_from := 12 if on else 2
	var rows := PackedStringArray()
	for y in 10:
		var line := ""
		for x in 20:
			var edge := mini(x, 19 - x) + mini(y, 9 - y)   # the rounded-off corners
			if edge < 2:
				line += "."
			elif edge == 2 or x == 0 or x == 19 or y == 0 or y == 9:
				line += "o"
			elif y >= 2 and y < 8 and x >= knob_from and x < knob_from + 6:
				line += "h" if y == 2 else ("s" if y == 7 else "k")
			else:
				line += "T"
		rows.append(line)
	var track := ACCENT_DEEP if on else SURFACE_2
	var knob := GOLD if on else IRON
	var alpha := 0.5 if dim else 1.0
	return sprite(rows, {
		"o": Color(OUTLINE, alpha), "T": Color(track, alpha), "k": Color(knob, alpha),
		"h": Color(knob.lightened(0.3), alpha), "s": Color(knob.darkened(0.35), alpha),
	}, PX + 1)


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = 48

	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(Color(SURFACE, 0.96), BORDER, 2, 20))
	t.set_stylebox("panel", "Panel", box(Color(SURFACE, 0.96), BORDER, 2, 20))

	# Buttons: dark iron with a thin border; pressed/toggled ones turn red.
	t.set_font("font", "Button", display())
	t.set_font_size("font_size", "Button", 56)
	t.set_stylebox("normal", "Button", box(SURFACE_2, BORDER, 2, 14))
	t.set_stylebox("hover", "Button", box(FRAME, IRON, 2, 14))
	t.set_stylebox("pressed", "Button", box(ACCENT_DEEP, ACCENT, 2, 14))
	t.set_stylebox("hover_pressed", "Button", box(ACCENT_DEEP, ACCENT, 2, 14))
	t.set_stylebox("disabled", "Button", box(Color(SURFACE_2, 0.5), Color(BORDER, 0.5), 2, 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(state, "Button", TEXT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.5))

	# The primary action: red lacquer.
	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(BLOOD, ACCENT, 2, 16))
	t.set_stylebox("hover", "PrimaryButton", box(ACCENT, ACCENT, 2, 16))
	t.set_stylebox("pressed", "PrimaryButton", box(ACCENT_DEEP, ACCENT, 2, 16))
	t.set_color("font_color", "PrimaryButton", Color.WHITE)
	t.set_color("font_hover_color", "PrimaryButton", Color.WHITE)

	# A flat link-like button for secondary actions (Voltar).
	t.add_type("GhostButton")
	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 10))
	t.set_stylebox("hover", "GhostButton", box(Color(FRAME, 0.6), Color.TRANSPARENT, 0, 10))
	t.set_stylebox("pressed", "GhostButton", box(Color(FRAME, 0.9), Color.TRANSPARENT, 0, 10))
	t.set_color("font_color", "GhostButton", MUTED)

	# Small labels in gold capitals ("NÍVEL", "TRILHA A").
	t.add_type("Caption")
	t.set_type_variation("Caption", "Label")
	t.set_font("font", "Caption", mono())
	t.set_font_size("font_size", "Caption", 42)
	t.set_color("font_color", "Caption", GOLD)

	t.add_type("Title")
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", display())
	t.set_font_size("font_size", "Title", 70)
	t.set_color("font_color", "Title", TEXT)

	t.add_type("Muted")
	t.set_type_variation("Muted", "Label")
	t.set_font_size("font_size", "Muted", 36)
	t.set_color("font_color", "Muted", MUTED)

	# The switch and the slider, in pixels too.
	t.set_font("font", "CheckButton", body())
	t.set_font_size("font_size", "CheckButton", 48)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "CheckButton", TEXT)
	t.set_icon("checked", "CheckButton", _switch(true))
	t.set_icon("unchecked", "CheckButton", _switch(false))
	t.set_icon("checked_mirrored", "CheckButton", _switch(true))
	t.set_icon("unchecked_mirrored", "CheckButton", _switch(false))
	t.set_icon("checked_disabled", "CheckButton", _switch(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch(false, true))
	t.set_icon("checked_disabled_mirrored", "CheckButton", _switch(true, true))
	t.set_icon("unchecked_disabled_mirrored", "CheckButton", _switch(false, true))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckButton", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 6))
	var track := box(SURFACE_2, BORDER, 2, 0, 1)
	track.content_margin_top = 5 * PX
	track.content_margin_bottom = 5 * PX
	t.set_stylebox("slider", "HSlider", track)
	var filled := box(ACCENT_DEEP, ACCENT, 2, 0, 1)
	filled.content_margin_top = 5 * PX
	filled.content_margin_bottom = 5 * PX
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var grabber := PackedStringArray(["oooooooo", "ohhhhhho", "okkkkkko", "okkkkkko", "okkkkkko", "okkkkkko", "okkkkkko", "okkkkkko", "osssssso", "oooooooo"])
	t.set_icon("grabber", "HSlider", sprite(grabber, {"o": OUTLINE, "h": GOLD.lightened(0.3), "k": GOLD, "s": GOLD.darkened(0.35)}))
	t.set_icon("grabber_highlight", "HSlider", sprite(grabber, {"o": OUTLINE, "h": Color.WHITE, "k": GOLD.lightened(0.2), "s": GOLD.darkened(0.2)}))

	t.set_font_size("font_size", "RichTextLabel", 48)
	t.set_font("normal_font", "RichTextLabel", body())
	t.set_font("bold_font", "RichTextLabel", display())
	_theme = t
	return t


## Applies the theme to every control of the app. The screens are plain Nodes with their UI on
## CanvasLayers, so a theme set on the window would not reach them: it goes into the default
## theme instead (once).
static func apply(_tree: SceneTree) -> void:
	if _applied:
		return
	_applied = true
	ThemeDB.get_default_theme().merge_with(theme())
	ThemeDB.fallback_font = theme().default_font
	ThemeDB.fallback_font_size = theme().default_font_size


static func label(text: String, variation := "", size := 0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		var display_face := variation in ["Caption", "Title"]
		l.add_theme_font_size_override("font_size", display_size(size) if display_face else text_size(size))
	return l


static func button(text: String, variation := "", size := 0, min_height := 100) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	if size > 0:
		b.add_theme_font_size_override("font_size", display_size(size))
	b.custom_minimum_size = Vector2(0, min_height)
	return b


## A dimmed full-screen layer with a centred panel; returns the panel's content box.
static func modal(parent: Node, layer := 5, width := 0.0) -> Dictionary:
	var cl := CanvasLayer.new()
	cl.layer = layer
	parent.add_child(cl)
	# A smooth dim, not a dithered one: it lies over the table, whose look stays its own.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.012, 0.008, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(Color(SURFACE, 0.98), GOLD, 2, 30))
	if width > 0:
		panel.custom_minimum_size.x = width
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	return {"layer": cl, "panel": panel, "box": content}


## A full-screen shade in the pixel look: `colour` over a share `amount` of the art pixels
## (ordered dither, app/ui/dither.gdshader), optionally fading out from left to right between the
## shares `ramp.x` and `ramp.y` of the width. Tween "material:shader_parameter/amount" to fade it.
## Only for what does not lie over the table (the screen transition): over the table the dither
## would change how the table looks.
static func shade(colour: Color, amount: float, ramp := Vector2.ZERO) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = DITHER
	m.set_shader_parameter("color", colour)
	m.set_shader_parameter("amount", amount)
	m.set_shader_parameter("ramp", ramp)
	m.set_shader_parameter("cell", float(PX))
	r.material = m
	return r
