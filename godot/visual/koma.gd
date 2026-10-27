class_name Koma
extends Node3D
## One piece on the table: its mesh and material, and the motion of picking it up, carrying it,
## setting it down and promoting. Where it goes and why is decided by Table.

const KANJI := {
	"K": ["king_sente", ""], "R": ["rook", "rook_p"], "B": ["bishop", "bishop_p"],
	"G": ["gold", ""], "S": ["silver", "silver_p"], "N": ["knight", "knight_p"],
	"L": ["lance", "lance_p"], "P": ["pawn", "pawn_p"],
}
## Ink of the unpromoted face, one colour per kind, the same on both teams: every knight has the
## same kanji colour whether it is Sente's (pearl) or Gote's (red lacquer). Mid-dark, saturated
## hues away from red, so they stay dark enough on the lit pearl and stand out by hue on the red.
## The promoted face keeps its own ink (red or gold) and the gold rim: its move changes.
const INK := {
	"K": Color(0.1, 0.09, 0.09),    # sumi black
	"R": Color(0.2, 0.25, 0.42),    # indigo
	"B": Color(0.16, 0.36, 0.37),   # muted teal
	"G": Color(0.5, 0.4, 0.2),      # ochre
	"S": Color(0.32, 0.35, 0.39),   # steel
	"N": Color(0.23, 0.35, 0.24),   # moss green
	"L": Color(0.37, 0.27, 0.43),   # plum
	"P": Color(0.21, 0.21, 0.23),   # slate: the most common piece stays quiet
}
const SHADER := preload("res://visual/koma.gdshader")
const PIXEL_SHADER := preload("res://visual/koma_pixel.gdshader")
const OUTLINE_SHADER := preload("res://visual/koma_outline.gdshader")

## The pixel look (the default): thick pieces, one pixel kanji with movement marks, banded light
## and a dark outline. Set before the table is built, or call `restyle()` on every piece.
static var pixel := true

## One small tiling noise texture shared by every piece (sheen, scratches).
static var noise_texture: NoiseTexture2D


static func shared_noise() -> NoiseTexture2D:
	if noise_texture == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.02
		n.fractal_octaves = 4
		noise_texture = NoiseTexture2D.new()
		noise_texture.width = 256
		noise_texture.height = 256
		noise_texture.seamless = true
		noise_texture.generate_mipmaps = true
		noise_texture.noise = n
	return noise_texture

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
var _seed := 0


func setup(p_kind: String, p_colour: int, seed: int) -> void:
	kind = p_kind
	colour = p_colour
	_seed = seed
	lift_pivot = Node3D.new()
	add_child(lift_pivot)
	flip_pivot = Node3D.new()
	lift_pivot.add_child(flip_pivot)
	mesh_instance = MeshInstance3D.new()
	flip_pivot.add_child(mesh_instance)
	_build_look(float(colour))
	# Gote's pieces point toward Sente.
	rotation.y = PI if colour == 1 else 0.0


## Rebuilds the mesh and the material for the current look (`Koma.pixel`), keeping the state.
func restyle() -> void:
	var team: float = material.get_shader_parameter("team")
	_build_look(team)
	if promoted:
		show_promoted()


func _build_look(team: float) -> void:
	KomaMesh.thickness = 1.6 if pixel else 1.0
	KomaMesh.bevel = 0.17 if pixel else KomaMesh.BEVEL
	KomaMesh.warp = 0.0 if pixel else KomaMesh.WARP
	mesh_instance.mesh = KomaMesh.build(kind, _seed)
	material = ShaderMaterial.new()
	material.shader = PIXEL_SHADER if pixel else SHADER
	var folder := "kanji_px" if pixel else "kanji"
	var faces: Array = KANJI[kind]
	var front: String = faces[0]
	if kind == "K" and colour == 1:
		front = "king_gote"
	material.set_shader_parameter("kanji_front", load("res://visual/textures/%s/%s.png" % [folder, front]))
	if faces[1] != "":
		material.set_shader_parameter("kanji_back", load("res://visual/textures/%s/%s.png" % [folder, faces[1]]))
	material.set_shader_parameter("seed", float(_seed % 997))
	material.set_shader_parameter("noise_tex", shared_noise())
	material.set_shader_parameter("team", team)
	material.set_shader_parameter("ink_kind", INK[kind])
	# Set now so tweens can animate them.
	material.set_shader_parameter("glow", 0.0)
	material.set_shader_parameter("gold_edge", 0.0)
	if pixel:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		material.next_pass = outline
	mesh_instance.material_override = material
	# Lying flat: rest on the back face, which tilts the piece slightly toward its tip.
	# The flip pivot sits at the piece's centre so promotion turns it over in place.
	flip_pivot.position.y = KomaMesh.rest_height(kind)
	mesh_instance.rotation.x = -KomaMesh.rest_tilt(kind)


## Facing for a new owner (after a capture the piece changes sides).
func set_colour(c: int) -> void:
	colour = c
	rotation.y = PI if colour == 1 else 0.0


## Changes the lacquer to the new owner's (pearl or red) over `seconds`.
func fade_to_team(c: int, seconds: float) -> void:
	create_tween().tween_property(material, "shader_parameter/team", float(c), seconds).set_trans(Tween.TRANS_SINE)


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


## Shows the promoted side at once (setting up a position).
func show_promoted() -> void:
	promoted = true
	flip_pivot.rotation.z = PI
	mesh_instance.rotation.x = KomaMesh.rest_tilt(kind)
	material.set_shader_parameter("gold_edge", 1.0)


## Turns a captured piece back to its unpromoted side at once (it goes to the hand).
func reset_promotion() -> void:
	promoted = false
	flip_pivot.rotation.z = 0.0
	mesh_instance.rotation.x = -KomaMesh.rest_tilt(kind)
	material.set_shader_parameter("gold_edge", 0.0)
