class_name PieceCard
extends PanelContainer
## A piece's card for the lessons: kanji, name, romaji and how it moves, with a small diagram
## (dot = one square, line to the edge = any distance, ring = jump). `code` is "R", "+P"…

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
	var kanji := UiTheme.label(Pieces.kanji(piece), "", 72)
	kanji.add_theme_font_override("font", load("res://visual/fonts/kaisei-tokumin-800-koma.woff2"))
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
	diagram.custom_minimum_size = Vector2(150, 150)
	diagram.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(diagram)
	var move := UiTheme.label(info.move_pt, "Muted", 22)
	move.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	move.custom_minimum_size.x = 220
	move.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(move)


## 5 × 5 squares around the piece, the owner moving up.
class _Diagram extends Control:
	var info: Dictionary

	func _draw() -> void:
		var n := 5
		var cell := size.x / n
		var c := Vector2(2, 2)
		for y in n:
			for x in n:
				draw_rect(Rect2(Vector2(x, y) * cell, Vector2(cell, cell)).grow(-1.5), Color(UiTheme.SURFACE_2, 1.0))
		var centre := (c + Vector2(0.5, 0.5)) * cell
		var red := UiTheme.ACCENT
		# Directions are (dx, forward): forward is up on the diagram.
		for d: Vector2i in info.steps:
			draw_circle((c + Vector2(d.x, -d.y) + Vector2(0.5, 0.5)) * cell, cell * 0.2, red)
		for d: Vector2i in info.slides:
			var end := centre + Vector2(d.x, -d.y) * cell * 2.45
			draw_line(centre, end, red, cell * 0.16, true)
			draw_circle(end, cell * 0.1, red)
		for d: Vector2i in info.jumps:
			draw_arc((c + Vector2(d.x, -d.y) + Vector2(0.5, 0.5)) * cell, cell * 0.24, 0, TAU, 20, red, 4.0, true)
		draw_rect(Rect2(c * cell, Vector2(cell, cell)).grow(-4), UiTheme.GOLD)
