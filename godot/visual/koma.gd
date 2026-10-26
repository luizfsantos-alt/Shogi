class_name Koma
extends Node3D
## One piece on the table: its mesh and material, and the motion of picking it up, carrying it,
## setting it down and promoting. Where it goes and why is decided by Table.

const KANJI := {
	"K": ["king_sente", ""], "R": ["rook", "rook_p"], "B": ["bishop", "bishop_p"],
	"G": ["gold", ""], "S": ["silver", "silver_p"], "N": ["knight", "knight_p"],
	"L": ["lance", "lance_p"], "P": ["pawn", "pawn_p"],
}
const SHADER := preload("res://visual/koma.gdshader")

var kind := "P"
var colour := 0          ## 0 Sente (near side), 1 Gote
var promoted := false
var square := Vector2i(-1, -1) ## on the board, or (-1, -1) when in hand

var mesh_instance: MeshInstance3D
var material: ShaderMaterial
## The visible piece sits inside two pivots so carrying, tilting and flipping combine freely.
var lift_pivot: Node3D   ## height above the resting place and tilt while carried
var flip_pivot: Node3D   ## the promotion flip

var _glow_tween: Tween


func setup(p_kind: String, p_colour: int, seed: int) -> void:
	kind = p_kind
	colour = p_colour
	lift_pivot = Node3D.new()
	add_child(lift_pivot)
	flip_pivot = Node3D.new()
	lift_pivot.add_child(flip_pivot)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = KomaMesh.build(kind, seed)
	material = ShaderMaterial.new()
	material.shader = SHADER
	var faces: Array = KANJI[kind]
	var front: String = faces[0]
	if kind == "K" and colour == 1:
		front = "king_gote"
	material.set_shader_parameter("kanji_front", load("res://visual/textures/kanji/%s.png" % front))
	if faces[1] != "":
		material.set_shader_parameter("kanji_back", load("res://visual/textures/kanji/%s.png" % faces[1]))
	material.set_shader_parameter("seed", float(seed % 997))
	# Set now so tweens can animate them.
	material.set_shader_parameter("glow", 0.0)
	material.set_shader_parameter("gold_edge", 0.0)
	mesh_instance.material_override = material
	flip_pivot.add_child(mesh_instance)
	# Lying flat: rest on the back face, which tilts the piece slightly toward its tip.
	# The flip pivot sits at the piece's centre so promotion turns it over in place.
	flip_pivot.position.y = KomaMesh.rest_height(kind)
	mesh_instance.rotation.x = -KomaMesh.rest_tilt(kind)
	# Gote's pieces point toward Sente.
	rotation.y = PI if colour == 1 else 0.0


## Facing for a new owner (after a capture the piece changes sides).
func set_colour(c: int) -> void:
	colour = c
	rotation.y = PI if colour == 1 else 0.0


func set_glow(amount: float, colour_tint: Color = Color(1.0, 0.75, 0.3), seconds: float = 0.15) -> void:
	if _glow_tween:
		_glow_tween.kill()
	material.set_shader_parameter("glow_color", colour_tint)
	_glow_tween = create_tween()
	_glow_tween.tween_property(material, "shader_parameter/glow", amount, seconds)


## Picks the piece up: it rises, leans a little and glows.
func lift(height: float, seconds: float = 0.16) -> Tween:
	var t := create_tween().set_parallel()
	t.tween_property(lift_pivot, "position:y", height, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lift_pivot, "scale", Vector3.ONE * 1.08, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_glow(0.35)
	return t


## While carried: lean toward the movement, like something with weight (velocity in cm/s).
func carry_lean(velocity: Vector3, delta: float) -> void:
	var target := Vector3(clampf(velocity.z * 0.012, -0.5, 0.5), 0.0, clampf(-velocity.x * 0.012, -0.5, 0.5))
	# The lean is in table space; the piece itself may be turned around (Gote).
	target = target.rotated(Vector3.UP, -rotation.y)
	var k := 1.0 - exp(-delta * 14.0)
	lift_pivot.rotation.x = lerpf(lift_pivot.rotation.x, target.x, k)
	lift_pivot.rotation.z = lerpf(lift_pivot.rotation.z, target.z, k)


## Sets the piece down from wherever it is carried: falls with weight, squashes on impact and
## settles. Calls `on_impact` at the moment it touches the board.
func slam(seconds: float, on_impact: Callable) -> Tween:
	set_glow(0.0, Color(1.0, 0.75, 0.3), 0.25)
	var t := create_tween()
	t.set_parallel()
	t.tween_property(lift_pivot, "position:y", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(lift_pivot, "rotation", Vector3.ZERO, seconds)
	t.tween_property(lift_pivot, "scale", Vector3.ONE, seconds)
	t.chain().tween_callback(on_impact)
	# Squash and stretch on impact.
	t.chain().tween_property(lift_pivot, "scale", Vector3(1.06, 0.82, 1.06), 0.05)
	t.chain().tween_property(lift_pivot, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return t


## Promotion: the piece jumps, turns over in the air and lands on its promoted side.
## `on_apex` fires at the top of the flip (sparks), `on_impact` when it lands.
func promote_flip(height: float, seconds: float, on_apex: Callable, on_impact: Callable) -> Tween:
	promoted = not promoted
	var up := seconds * 0.45
	var down := seconds * 0.55
	var t := create_tween()
	t.tween_property(lift_pivot, "position:y", height, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(flip_pivot, "rotation:z", flip_pivot.rotation.z + PI * 0.5, up).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(on_apex)
	t.tween_callback(func() -> void: material.set_shader_parameter("gold_edge", 1.0 if promoted else 0.0))
	t.tween_property(lift_pivot, "position:y", 0.0, down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(flip_pivot, "rotation:z", flip_pivot.rotation.z + PI, down).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Turned over, the wedge must lean the other way to keep its tip down.
	var tilt := KomaMesh.rest_tilt(kind) * (1.0 if promoted else -1.0)
	t.parallel().tween_property(mesh_instance, "rotation:x", tilt, down)
	t.tween_callback(on_impact)
	t.tween_property(lift_pivot, "scale", Vector3(1.08, 0.8, 1.08), 0.05)
	t.tween_property(lift_pivot, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return t


## Turns a captured piece back to its unpromoted side at once (it goes to the hand).
func reset_promotion() -> void:
	promoted = false
	flip_pivot.rotation.z = 0.0
	mesh_instance.rotation.x = -KomaMesh.rest_tilt(kind)
	material.set_shader_parameter("gold_edge", 0.0)
