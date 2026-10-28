class_name PieceCard
extends PanelContainer
## A piece's card for the lessons: kanji, name, romaji and how it moves, with a small diagram
## (dot = one square, line to the edge = any distance, ring = jump), all in pixels like the rest
## of the interface. `code` is "R", "+P"…

var code := "K"


static func make(piece_code: String) -> PieceCard:
	var c := PieceCard.new()
	c.code = piece_code
	return c


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.SURFACE, 0.94), UiTheme.BORDER, 2, 18))
	var piece := Pieces.make("black", code.replace("+", ""), code.begins_with("+"))
	var info := Pieces.info(piece)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	box.add_child(head)
	var kanji := UiTheme.label(Pieces.kanji(piece))
	kanji.add_theme_font_override("font", UiTheme.kanji_font())
	kanji.add_theme_font_size_override("font_size", UiTheme.kanji_size(64))
	kanji.add_theme_color_override("font_color", UiTheme.GOLD if piece.promoted else UiTheme.TEXT)
	head.add_child(kanji)
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	head.add_child(names)
	names.add_child(UiTheme.label(info.name_pt, "Title", 36))
	names.add_child(UiTheme.label("%s · %s" % [info.romaji, info.kanji_name], "Caption", 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var diagram := _Diagram.new()
	diagram.info = info
	diagram.custom_minimum_size = Vector2(160, 160)
	diagram.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(diagram)
	var move := UiTheme.label(info.move_pt, "Muted", 22)
	move.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	move.custom_minimum_size.x = 220
	move.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(move)


## 5 × 5 squares around the piece, the owner moving up, on the interface's pixel grid: a square
## mark for one step, a stepped line out to the edge for any distance, a hollow square for a jump.
class _Diagram extends Control:
	const PX := UiTheme.PX
	var info: Dictionary

	func _draw() -> void:
		var n := 5
		var cell := floorf(size.x / n / (2 * PX)) * 2 * PX   # whole, even art pixels
		var c := Vector2(2, 2)
		for y in n:
			for x in n:
				draw_rect(Rect2(Vector2(x, y) * cell, Vector2(cell, cell)).grow(-PX), UiTheme.SURFACE_2)
		var centre := (c + Vector2(0.5, 0.5)) * cell
		var red := UiTheme.ACCENT
		# Directions are (dx, forward): forward is up on the diagram.
		for d: Vector2i in info.steps:
			_square((c + Vector2(d.x, -d.y) + Vector2(0.5, 0.5)) * cell, 5, red)
		for d: Vector2i in info.slides:
			var dir := Vector2(d.x, -d.y)
			var length := int(cell * 2.4 / PX)
			for k in length:
				_square(centre + dir * k * PX, 3, red)
			_square(centre + dir * length * PX, 4, red)
		for d: Vector2i in info.jumps:
			var at := (c + Vector2(d.x, -d.y) + Vector2(0.5, 0.5)) * cell
			var r := Rect2(at - Vector2(4, 4) * PX, Vector2(8, 8) * PX)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2 * PX)), red)
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2 * PX), Vector2(r.size.x, 2 * PX)), red)
			draw_rect(Rect2(r.position, Vector2(2 * PX, r.size.y)), red)
			draw_rect(Rect2(r.position + Vector2(r.size.x - 2 * PX, 0), Vector2(2 * PX, r.size.y)), red)
		draw_rect(Rect2(c * cell, Vector2(cell, cell)).grow(-2 * PX), UiTheme.GOLD)

	## A square of `side` art pixels centred on `at`, snapped to the pixel grid.
	func _square(at: Vector2, side: int, colour: Color) -> void:
		var half := Vector2(side, side) * PX * 0.5
		var corner := ((at - half) / PX).round() * PX
		draw_rect(Rect2(corner, Vector2(side, side) * PX), colour)
