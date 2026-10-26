class_name MoveArrows
extends Node3D
## Arrows that grow out of the edge of pieces and show how each one moves (the "Movimentos"
## button for beginners, and the red arrows of an opponent's piece you tap).
## One step: a short arrow into the next square. Any distance: a long arrow with a double head.
## The knight's jump: an arrow to the square it lands on.

const SHADER := preload("res://visual/arrow.gdshader")
const HEIGHT := 2.2          ## above the board, over the pieces
const START := 0.42          ## arrows start at the edge of the piece, leaving the kanji clear
const STEP_REACH := 0.68     ## a one-square arrow ends just inside the next square
const SLIDE_REACH := 1.55    ## the long arrow for "any distance"
const WIDTH := 1.1           ## cm
const GROW_TIME := 0.22

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
		for d: Vector2i in pat[0]:
			_arrow(p, Vector2(d.x * -flip, d.y * flip), STEP_REACH, 1.0, tint, delay)
		for d: Vector2i in pat[1]:
			_arrow(p, Vector2(d.x * -flip, d.y * flip), SLIDE_REACH, 2.0, tint, delay)
		for d: Vector2i in pat[2]:
			_arrow(p, Vector2(d.x * -flip, d.y * flip), 1.0, 1.0, tint, delay)


func _arrow(p: Koma, dir: Vector2, reach: float, heads: float, tint: Color, delay: float) -> void:
	# In table space a square step is (dx * cell.x, dy * cell.y); diagonals are longer.
	var world := Vector3(dir.x * cell.x, 0.0, dir.y * cell.y)
	var full := world.length()
	var unit := world / full
	var start := unit * full * START / dir.length()
	var length := full * reach - start.length()
	if dir.length() > 1.5:
		# The knight: land on the centre of the target square.
		length = full * 0.92 - start.length()
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var origin := p.position + Vector3(0, HEIGHT, 0) + start
	mi.transform = Transform3D(Basis.looking_at(unit, Vector3.UP) * Basis.from_scale(Vector3(WIDTH, 1.0, length)), origin)
	mi.set_instance_shader_parameter("length_cm", length)
	mi.set_instance_shader_parameter("width_cm", WIDTH)
	mi.set_instance_shader_parameter("heads", heads)
	mi.set_instance_shader_parameter("tint", tint)
	mi.set_instance_shader_parameter("grow", 0.0)
	var t := mi.create_tween()
	t.tween_interval(delay)
	t.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("grow", v), 0.0, 1.0, GROW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
