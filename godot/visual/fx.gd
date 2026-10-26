class_name TableFx
extends Node3D
## The "fat" effects: dust and shock ring when a piece lands, gold sparks on promotion,
## camera shake and hit-stop. Every strength is a field here so it can be tuned while playing.

const FX_SHADER := preload("res://visual/fx.gdshader")
const PARTICLE_SHADER := preload("res://visual/particle.gdshader")

## Tuning, all scaled by `strength` passed to each effect (0..1).
var impact_dust := 1.0
var impact_shake := 0.35      ## cm of camera offset at full strength
var hitstop := 0.06           ## seconds the world freezes on a heavy impact
var reduced := false          ## "efeitos reduzidos": fewer particles, no shake

var _shake := 0.0
var _shake_time := 0.0
var camera: Camera3D
var _cam_base: Transform3D


func attach_camera(cam: Camera3D) -> void:
	camera = cam
	_cam_base = cam.transform


func _process(delta: float) -> void:
	if camera == null:
		return
	# Shake runs in real time, so it keeps going during hit-stop.
	var real := delta / maxf(Engine.time_scale, 0.001)
	_shake = maxf(0.0, _shake - real * 2.8)
	_shake_time += real
	var s := _shake * _shake
	var off := Vector3(sin(_shake_time * 61.0), sin(_shake_time * 47.0 + 1.3), 0.0) * s
	if Koma.pixel:
		# The pixel look shakes in whole steps, like a sprite jumping a pixel at a time.
		off = (off / 0.12).round() * 0.12
	camera.transform = _cam_base.translated_local(off)


func shake(amount: float) -> void:
	if reduced:
		return
	_shake = clampf(maxf(_shake, amount), 0.0, 1.0)


## A piece landing at `pos` (table space). strength 0..1.
func impact(pos: Vector3, strength: float) -> void:
	_ring(pos, 7.0 * (0.6 + 0.4 * strength), Color(1.0, 0.86, 0.6), 0.35, 0.8 * strength)
	_dust(pos, strength)
	shake(impact_shake * strength / 0.35 * 0.6)
	if strength > 0.5 and hitstop > 0.0 and not reduced:
		_hitstop(hitstop * strength)


## Promotion burst: sparks, a flash of light and a gold ring.
func promotion_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 50 if reduced else 140
	p.lifetime = 1.0
	p.direction = Vector3.UP
	p.spread = 95.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 52.0
	p.gravity = Vector3(0, -70.0, 0)
	p.damping_min = 10.0
	p.damping_max = 24.0
	p.particle_flag_align_y = not Koma.pixel # streaks point along their flight
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color_ramp = _ramp([Color(1.0, 0.88, 0.5), Color(1.0, 0.6, 0.12), Color(0.9, 0.25, 0.02, 0.0)])
	# In the pixel look the sparks are little pixel crosses instead of streaks.
	p.mesh = _mote_mesh(4.0) if Koma.pixel else _streak_mesh()
	p.restart() # created in code: a restart makes the one-shot burst actually fire
	_free_later(p, 1.5)

	# Slower glowing motes that hang in the air after the burst.
	var m := CPUParticles3D.new()
	add_child(m)
	m.position = pos
	m.one_shot = true
	m.explosiveness = 0.8
	m.amount = 14 if reduced else 40
	m.lifetime = 1.3
	m.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 1.5
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 12.0
	m.gravity = Vector3(0, -4.0, 0)
	m.damping_min = 4.0
	m.damping_max = 8.0
	m.scale_amount_min = 0.5
	m.scale_amount_max = 1.4
	m.scale_amount_curve = curve
	m.color_ramp = _ramp([Color(1.0, 0.78, 0.35), Color(1.0, 0.55, 0.12, 0.6), Color(1.0, 0.4, 0.05, 0.0)])
	m.mesh = _mote_mesh(2.5)
	m.restart() # created in code: a restart makes the one-shot burst actually fire
	_free_later(m, 1.8)

	var light := OmniLight3D.new()
	add_child(light)
	light.position = pos + Vector3(0, 3, 0)
	light.light_color = Color(1.0, 0.8, 0.4)
	light.omni_range = 18.0
	light.light_energy = 0.0
	var t := light.create_tween()
	t.tween_property(light, "light_energy", 6.0, 0.05)
	t.tween_property(light, "light_energy", 0.0, 0.45)
	t.tween_callback(light.queue_free)

	_ring(pos, 11.0, Color(1.0, 0.75, 0.3), 0.5, 1.0)
	shake(0.5)


## Gold motes trailing behind a piece flying in from the hand. Returns the emitter so the
## caller can stop it on landing.
func trail(target: Node3D) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	target.add_child(p)
	p.amount = 12 if reduced else 36
	p.lifetime = 0.45
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.8
	p.color_ramp = _ramp([Color(1.0, 0.9, 0.6), Color(1.0, 0.7, 0.25, 0.0)])
	p.mesh = _mote_mesh(2.0)
	p.restart() # created in code: a restart makes the one-shot burst actually fire
	return p


func _ring(pos: Vector3, size: float, colour: Color, seconds: float, intensity: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = FX_SHADER
	m.set_shader_parameter("mode", 0)
	m.set_shader_parameter("color", colour)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("progress", 0.0)
	m.set_shader_parameter("quad_cm", Vector2(size, size))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = pos + Vector3(0, 0.05, 0)
	var t := mi.create_tween()
	t.tween_property(m, "shader_parameter/progress", 1.0, seconds)
	t.tween_callback(mi.queue_free)


func _dust(pos: Vector3, strength: float) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.position = pos + Vector3(0, 0.15, 0)
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int((12 if reduced else 34) * impact_dust)
	if p.amount < 1:
		p.queue_free()
		return
	p.lifetime = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 1.5
	p.emission_ring_inner_radius = 1.2
	p.emission_ring_height = 0.05
	p.direction = Vector3(1, 0.25, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = 4.0 + 6.0 * strength
	p.initial_velocity_max = 9.0 + 12.0 * strength
	p.damping_min = 14.0
	p.damping_max = 22.0
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	if Koma.pixel:
		# Stone dust: light grey chips.
		p.color_ramp = _ramp([Color(0.78, 0.76, 0.74, 0.55), Color(0.6, 0.58, 0.57, 0.3), Color(0.5, 0.48, 0.47, 0.0)])
	else:
		p.color_ramp = _ramp([Color(1.0, 0.9, 0.72, 0.55), Color(0.93, 0.8, 0.6, 0.28), Color(0.9, 0.75, 0.55, 0.0)])
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://visual/dust.gdshader")
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = mat
	p.mesh = q
	p.restart() # created in code: a restart makes the one-shot burst actually fire
	_free_later(p, 1.0)


## A thin stretched box: reads as a spark streak from any angle.
func _streak_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.75, 0.07)
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE_SHADER
	mat.set_shader_parameter("billboard", false)
	mat.set_shader_parameter("soft", false)
	mat.set_shader_parameter("energy", 4.0)
	box.material = mat
	return box


## A soft glowing dot facing the camera.
func _mote_mesh(energy: float) -> Mesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE_SHADER
	mat.set_shader_parameter("energy", energy)
	q.material = mat
	return q


func _ramp(colours: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colours.size():
		g.add_point(float(i) / (colours.size() - 1), colours[i])
	return g


func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.03
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _free_later(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds, true, false, true).timeout.connect(node.queue_free)
