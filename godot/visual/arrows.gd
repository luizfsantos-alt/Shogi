class_name MoveArrows
extends Node3D
## Short arrows at the edge of pieces that show how each one moves (the "Movimentos" button for
## beginners, and the red arrows of an opponent's piece you tap).
## Single head: one square that way. Double head: any distance that way (like the bishop).
## The knight gets an L, as in chess: a stem two squares forward, then one to each side.

const SHADER := preload("res://visual/arrow.gdshader")
const HEIGHT := 2.2          ## above the board, over the pieces
const START_CM := 1.5        ## arrows start at the edge of the piece, leaving the kanji clear
const STEP_CM := 1.15        ## length of a one-square arrow
const SLIDE_CM := 1.5        ## length of an any-distance arrow (room for two heads)
const WIDTH := 1.0           ## cm
const GROW_TIME := 0.2

var cell := Vector2(3.33, 3.64)
var _material: ShaderMaterial
var _quad: QuadMesh


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = 10
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)
	_quad.orientation = PlaneMesh.FACE_Y
	_quad.center_offset = Vector3(0, 0, -0.5) # the quad runs from its origin toward -Z


func clear() -> void:
	for c in get_children():
		c.queue_free()


## Shows the arrows of `pieces` (on the board) in `tint`, each piece a little after the last.
func show_for(pieces: Array, tint: Color) -> void:
	clear()
	var order := pieces.duplicate()
	order.sort_custom(func(a: Koma, b: Koma) -> bool: return a.square.x * 10 + a.square.y < b.square.x * 10 + b.square.y)
	for i in order.size():
		var p: Koma = order[i]
		var delay := 0.25 * i / maxf(order.size(), 1.0)
		var pat := KomaMoves.pattern(p.kind, p.promoted)
		var flip := -1 if p.colour == 0 else 1
		var centre := p.position + Vector3(0, HEIGHT, 0)
		for d: Vector2i in pat[0]:
			var u := _dir(Vector2(d.x * -flip, d.y * flip))
			_arrow(centre + u * START_CM, u, STEP_CM, 1.0, tint, delay)
		for d: Vector2i in pat[1]:
			var u := _dir(Vector2(d.x * -flip, d.y * flip))
			_arrow(centre + u * START_CM, u, SLIDE_CM, 2.0, tint, delay)
		if not pat[2].is_empty():
			_knight(centre, flip, tint, delay)


## Direction on the table for a step of (cols, rows); squares are a little taller than wide.
func _dir(step: Vector2) -> Vector3:
	return Vector3(step.x * cell.x, 0.0, step.y * cell.y).normalized()


## The L: a stem two squares forward, then a short arrow to each side.
func _knight(centre: Vector3, flip: int, tint: Color, delay: float) -> void:
	var fwd := Vector3(0, 0, flip)
	var stem := cell.y * 2.0 - START_CM
	_arrow(centre + fwd * START_CM, fwd, stem + WIDTH * 0.3, 0.0, tint, delay)
	var corner := centre + fwd * cell.y * 2.0
	for side in [-1.0, 1.0]:
		_arrow(corner, Vector3(side, 0, 0), cell.x * 0.75, 1.0, tint, delay + GROW_TIME * 0.8)


## heads: 0 = plain segment, 1 = arrow, 2 = double arrow.
func _arrow(origin: Vector3, unit: Vector3, length: float, heads: float, tint: Color, delay: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.transform = Transform3D(Basis.looking_at(unit, Vector3.UP) * Basis.from_scale(Vector3(WIDTH, 1.0, length)), origin)
	mi.set_instance_shader_parameter("length_cm", length)
	mi.set_instance_shader_parameter("width_cm", WIDTH)
	mi.set_instance_shader_parameter("heads", heads)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("grow", 0.0)
	var t := mi.create_tween()
	t.tween_interval(delay)
	t.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("grow", v), 0.0, 1.0, GROW_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
