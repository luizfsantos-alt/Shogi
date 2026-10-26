class_name Rivals
extends RefCounted
## The computer's faces: one rival per level, from the Genpei legends the tengu's pupil lived in.
## Pixel art busts (art/<id>.png and art/<id>_defeated.png, made by art_source/prepare_art.py);
## the screens show the head (`HEADS`, art pixels) at a whole multiple of its size.

const ROSTER := {
	1: {"id": "kappa", "name": "Kappa", "kanji": "河童"},
	2: {"id": "ashigaru", "name": "Ashigaru", "kanji": "足軽"},
	3: {"id": "kitsune", "name": "Kitsune", "kanji": "狐"},
	4: {"id": "benkei", "name": "Benkei", "kanji": "弁慶"},
	5: {"id": "kiyomori", "name": "Kiyomori", "kanji": "清盛"},
}
const HEAD_SIZE := 140
## Top left corner of the head in each bust.
const HEADS := {
	"kappa": Vector2(19, 30), "ashigaru": Vector2(46, 0), "kitsune": Vector2(22, 48),
	"benkei": Vector2(82, 0), "kiyomori": Vector2(60, 8),
}


static func of_level(level: int) -> Dictionary:
	return ROSTER.get(level, ROSTER[1])


## The rival's head, calm or defeated; null when its art is missing (the screens then show its
## kanji instead).
static func head(level: int, defeated := false) -> AtlasTexture:
	var id: String = of_level(level).id
	var path := "res://app/rivals/art/%s%s.png" % [id, "_defeated" if defeated else ""]
	if not ResourceLoader.exists(path):
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(HEADS[id], Vector2(HEAD_SIZE, HEAD_SIZE))
	return atlas


## A square portrait of `px` screen pixels: the head with nearest filtering on a dark lacquer
## plate with a gold rim, or the kanji when there is no art.
static func portrait(level: int, px: float, defeated := false) -> PanelContainer:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.05)
	sb.border_color = UiTheme.GOLD
	sb.set_border_width_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(px, px)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var tex := head(level, defeated)
	if tex != null:
		var pic := TextureRect.new()
		pic.name = "Face"
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
	else:
		var k := Label.new()
		k.text = of_level(level).kanji
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		k.add_theme_font_override("font", UiTheme.display())
		k.add_theme_font_size_override("font_size", int(px * 0.42))
		k.add_theme_color_override("font_color", UiTheme.GOLD)
		frame.add_child(k)
	return frame


## Shows the defeated face in a portrait made by `portrait` (no change without art).
static func set_defeated(frame: PanelContainer, level: int, defeated: bool) -> void:
	var pic := frame.get_node_or_null("Face") as TextureRect
	var tex := head(level, defeated)
	if pic != null and tex != null:
		pic.texture = tex
