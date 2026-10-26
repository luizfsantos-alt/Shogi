class_name UiTheme
extends RefCounted
## The Genpei look of the PWA, for every screen of the app: charred dark surfaces, condensed heavy
## type (Archivo), mono labels (IBM Plex Mono), chamfered controls, red for action and gold for
## value. Japanese text falls back to the brush kanji font of the PWA (Potta One, reduced to the
## characters the course uses).

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
const CHAMFER := 10

const FONTS := "res://app/ui/fonts/"

static var _theme: Theme
static var _display: Font
static var _mono: Font
static var _kanji: FontFile
static var _applied := false


## Brush kanji (Potta One subset): the 将棋 mark, the Japanese terms.
static func kanji_font() -> FontFile:
	if _kanji == null:
		_kanji = load(FONTS + "koma-kanji.woff2")
	return _kanji


## The device's own fonts, last in every fallback list: symbols (★ ▸ ✕ ←) and anything the
## bundled subsets lack.
static func system_font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["sans-serif", "Noto Sans Symbols 2", "Noto Sans Symbols", "DejaVu Sans"])
	return f


## Archivo, condensed and heavy, for titles and buttons; `weight` 100..900, `width` 62..125.
static func display_font(weight := 800, width := 72) -> Font:
	var base: FontFile = load(FONTS + "archivo-latin.woff2")
	var romaji: FontFile = load(FONTS + "archivo-romaji.woff2")
	var piece_kanji: FontFile = load("res://visual/fonts/kaisei-tokumin-800-koma.woff2")
	base.fallbacks = [romaji, kanji_font(), piece_kanji, system_font()]
	var v := FontVariation.new()
	v.base_font = base
	var ts := TextServerManager.get_primary_interface()
	v.variation_opentype = {ts.name_to_tag("wght"): weight, ts.name_to_tag("wdth"): width}
	return v


## IBM Plex Mono for small labels.
static func mono_font(bold := false) -> Font:
	var weight := "700" if bold else "500"
	var base: FontFile = load(FONTS + "plex-mono-%s-latin.woff2" % weight)
	base.fallbacks = [load(FONTS + "plex-mono-%s-romaji.woff2" % weight), kanji_font(), system_font()]
	return base


static func display() -> Font:
	if _display == null:
		_display = display_font(800, 72)
	return _display


static func mono() -> Font:
	if _mono == null:
		_mono = mono_font(true)
	return _mono


## A chamfered box (straight cut corners, as in the PWA's clip-path).
static func box(bg: Color, border := Color.TRANSPARENT, border_width := 0, margin := 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.corner_detail = 1
	sb.set_corner_radius_all(CHAMFER)
	sb.content_margin_left = margin * 1.4
	sb.content_margin_right = margin * 1.4
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var body := display_font(500, 88)
	t.default_font = body
	t.default_font_size = 30

	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(Color(SURFACE, 0.96), BORDER, 2, 20))
	t.set_stylebox("panel", "Panel", box(Color(SURFACE, 0.96), BORDER, 2, 20))

	# Buttons: dark iron with a thin border; pressed/toggled ones turn red.
	t.set_font("font", "Button", display())
	t.set_font_size("font_size", "Button", 32)
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

	# Small mono labels ("NÍVEL", "TRILHA A").
	t.add_type("Caption")
	t.set_type_variation("Caption", "Label")
	t.set_font("font", "Caption", mono())
	t.set_font_size("font_size", "Caption", 22)
	t.set_color("font_color", "Caption", GOLD)

	t.add_type("Title")
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", display())
	t.set_font_size("font_size", "Title", 56)
	t.set_color("font_color", "Title", TEXT)

	t.add_type("Muted")
	t.set_type_variation("Muted", "Label")
	t.set_font_size("font_size", "Muted", 26)
	t.set_color("font_color", "Muted", MUTED)

	t.set_font("font", "CheckButton", body)
	t.set_font_size("font_size", "CheckButton", 30)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "RichTextLabel", 30)
	t.set_font("normal_font", "RichTextLabel", body)
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
		l.add_theme_font_size_override("font_size", size)
	return l


static func button(text: String, variation := "", size := 0, min_height := 84) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	if size > 0:
		b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, min_height)
	return b


## A dimmed full-screen layer with a centred panel; returns the panel's content box.
static func modal(parent: Node, layer := 5, width := 0.0) -> Dictionary:
	var cl := CanvasLayer.new()
	cl.layer = layer
	parent.add_child(cl)
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
