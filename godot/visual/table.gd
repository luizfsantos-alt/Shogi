class_name Table
extends Node3D
## Visual test of the table: board, komadai, the 40 pieces, touch and drag, the effects and the
## movement wave. Moves follow the pieces' patterns only (no check or other rules yet: the
## engine branch brings those). Sides alternate, so both can be tried on one phone.
##
## Units are centimetres; the board top is at y = 0, centred on the origin.

const CELL := Vector2(3.33, 3.64)
const BOARD_SIZE := Vector3(33.4, 6.0, 36.4)
const KOMADAI_SIZE := Vector3(11.5, 2.6, 12.0)
const KOMADAI_TOP := -2.6
const START := [
	"lnsgkgsnl",
	".r.....b.",
	"ppppppppp",
	".........",
	".........",
	".........",
	"PPPPPPPPP",
	".B.....R.",
	"LNSGKGSNL",
]
const HAND_ORDER := ["R", "B", "G", "S", "N", "L", "P"]
const WAVE_CYCLE := 2.5       ## seconds between waves
const WAVE_SWEEP := 0.8       ## the cascade crosses the board in this time
const WAVE_STEP := 0.06       ## delay per square along a slide
const WAVE_PULSE := 0.45      ## how long a square stays lit
const GOLD := Color(1.0, 0.72, 0.28)
const RED := Color(1.0, 0.16, 0.08)

## Tuning (menu).
var lift_height := 2.4
var wave_on := true
var wave_strength := 0.55

var pieces: Array[Koma] = []
var hands := [[], []]                ## pieces in hand per colour
var side_to_move := 0
var camera: Camera3D
var fx: TableFx

var _squares: MultiMeshInstance3D
var _komadai_pos := [Vector3.ZERO, Vector3.ZERO]
var _selected: Koma = null
var _targets: Array = []             ## Vector2i
var _dragging := false
var _press_screen := Vector2.ZERO
var _carry_prev := Vector3.ZERO
var _busy := false
var _enemy_wave: Koma = null
var _enemy_wave_t0 := 0.0
var _time := 0.0
var _last_move: Array = []           ## squares of the last move


func _ready() -> void:
	_build_world()
	fx = TableFx.new()
	add_child(fx)
	fx.attach_camera(camera)
	_build_board()
	_build_squares()
	_setup_position()
	_build_menu()
	_run_cmdline_demo()


# --- World ---------------------------------------------------------------------------------

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.032, 0.026)
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.42, 0.34)
	sky_mat.sky_horizon_color = Color(0.95, 0.78, 0.55)
	sky_mat.ground_bottom_color = Color(0.08, 0.06, 0.05)
	sky_mat.ground_horizon_color = Color(0.35, 0.26, 0.18)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.22
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Warm key light from the upper left, low enough to throw visible shadows, and a dim cool fill.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -38, 0)
	key.light_color = Color(1.0, 0.88, 0.72)
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 140.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 140, 0)
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 0.25
	add_child(fill)

	# The table under everything: dark wood.
	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 300)
	table.mesh = plane
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.16, 0.09, 0.055)
	tm.roughness = 0.55
	tm.clearcoat_enabled = true
	tm.clearcoat = 0.4
	table.material_override = tm
	table.position.y = -BOARD_SIZE.y
	add_child(table)

	# Camera: almost straight down, tilted ~18°, narrow lens so the far ranks stay large.
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	var target := Vector3(0, -1.0, 1.2)
	var dist := 70.0
	var tilt := deg_to_rad(18.0)
	camera.look_at_from_position(target + Vector3(0, cos(tilt), sin(tilt)) * dist, target)
	camera.near = 5.0
	camera.far = 400.0

	# Vignette over the picture, so the eye stays on the board.
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var vig := TextureRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_offset(0, 0.55)
	g.set_color(1, Color(0, 0, 0, 0.7))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	vig.texture = gt
	# Drawn on top of the 3D view.
	var top := CanvasLayer.new()
	top.layer = 1
	add_child(top)
	top.add_child(vig)


func _build_board() -> void:
	var shader := preload("res://visual/board.gdshader")
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BOARD_SIZE
	board.mesh = box
	var bm := ShaderMaterial.new()
	bm.shader = shader
	bm.set_shader_parameter("cell", CELL)
	board.material_override = bm
	board.position.y = -BOARD_SIZE.y * 0.5
	add_child(board)

	for c in 2:
		var stand := MeshInstance3D.new()
		var sbox := BoxMesh.new()
		sbox.size = KOMADAI_SIZE
		stand.mesh = sbox
		var sm := ShaderMaterial.new()
		sm.shader = shader
		sm.set_shader_parameter("draw_grid", false)
		stand.material_override = sm
		# Sente's stand is on its right, near side; Gote's mirrors it.
		var side := 1.0 if c == 0 else -1.0
		var x := side * (BOARD_SIZE.x * 0.5 + 2.2 + KOMADAI_SIZE.x * 0.5)
		var z := side * (BOARD_SIZE.z * 0.5 - KOMADAI_SIZE.z * 0.5)
		stand.position = Vector3(x, KOMADAI_TOP - KOMADAI_SIZE.y * 0.5, z)
		add_child(stand)
		_komadai_pos[c] = Vector3(x, KOMADAI_TOP, z)


func _build_squares() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = CELL * 0.96
	q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	mm.instance_count = 81
	for row in 9:
		for col in 9:
			mm.set_instance_transform(row * 9 + col, Transform3D(Basis(), square_pos(Vector2i(col, row)) + Vector3(0, 0.03, 0)))
			mm.set_instance_custom_data(row * 9 + col, Color(0, 0, 0, 0))
	_squares = MultiMeshInstance3D.new()
	_squares.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://visual/fx.gdshader")
	m.set_shader_parameter("mode", 1)
	_squares.material_override = m
	_squares.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_squares)


# --- Position ------------------------------------------------------------------------------

func _setup_position() -> void:
	for p in pieces:
		p.queue_free()
	pieces.clear()
	hands = [[], []]
	side_to_move = 0
	_last_move = []
	var n := 0
	for row in 9:
		var line: String = START[row]
		for col in 9:
			var ch := line[col]
			if ch == ".":
				continue
			var colour := 0 if ch == ch.to_upper() else 1
			var k := Koma.new()
			add_child(k)
			k.setup(ch.to_upper(), colour, 7919 * (n + 1))
			k.square = Vector2i(col, row)
			k.position = square_pos(k.square)
			pieces.append(k)
			n += 1


func square_pos(sq: Vector2i) -> Vector3:
	return Vector3((sq.x - 4) * CELL.x, 0.0, (sq.y - 4) * CELL.y)


func piece_at(sq: Vector2i) -> Koma:
	for p in pieces:
		if p.square == sq:
			return p
	return null


func occupant(sq: Vector2i) -> int:
	var p := piece_at(sq)
	return -1 if p == null else p.colour


func _hand_slot(colour: int, kind: String, index: int) -> Vector3:
	var slot := HAND_ORDER.find(kind)
	var col := slot % 3
	var row := slot / 3
	var local := Vector3((col - 1) * 3.9 + index * 0.55, 0.0, (row - 1) * 3.9 + index * 0.08)
	if colour == 1:
		local = -local
	return _komadai_pos[colour] + local + Vector3(0, index * 0.02, 0)


func _relayout_hand(colour: int) -> void:
	var counts := {}
	for p: Koma in hands[colour]:
		var i: int = counts.get(p.kind, 0)
		counts[p.kind] = i + 1
		var to := _hand_slot(colour, p.kind, i)
		if p.position.distance_to(to) > 0.01:
			p.create_tween().tween_property(p, "position", to, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Input ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion and _selected != null and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if not _dragging and event.position.distance_to(_press_screen) > 12.0:
			_dragging = true
		if _dragging:
			_carry_to(event.position)


func _on_press(screen: Vector2) -> void:
	_press_screen = screen
	var hit := _piece_under(screen)
	if _selected != null:
		# A second tap: on a target moves there, on another own piece switches, else drops it.
		var sq := _square_under(screen)
		if sq in _targets and (hit == null or hit.colour != side_to_move or hit == _selected):
			_move_selected(sq, false)
			return
		if hit == _selected:
			_dragging = false
			return
		_deselect()
	if hit == null:
		_enemy_wave = null
		return
	if hit.colour != side_to_move:
		# The opponent's piece shows where it can go, in red.
		_enemy_wave = null if _enemy_wave == hit else hit
		_enemy_wave_t0 = _time
		return
	_select(hit)


func _on_release(screen: Vector2) -> void:
	if _selected == null or not _dragging:
		return
	_dragging = false
	var sq := _square_under(screen)
	if sq in _targets:
		_move_selected(sq, true)
	else:
		_return_selected()


func _piece_under(screen: Vector2) -> Koma:
	var best: Koma = null
	var best_d := 1e9
	var scale := get_viewport().get_visible_rect().size.y / 1080.0
	for p in pieces:
		var d := camera.unproject_position(p.global_position).distance_to(screen)
		if d < best_d:
			best_d = d
			best = p
	return best if best_d < 52.0 * scale else null


func _square_under(screen: Vector2) -> Vector2i:
	var hit := _ray_plane(screen, 0.0)
	var col := roundi(hit.x / CELL.x + 4.0)
	var row := roundi(hit.z / CELL.y + 4.0)
	if col < 0 or col > 8 or row < 0 or row > 8:
		return Vector2i(-1, -1)
	return Vector2i(col, row)


func _ray_plane(screen: Vector2, y: float) -> Vector3:
	var o := camera.project_ray_origin(screen)
	var d := camera.project_ray_normal(screen)
	if absf(d.y) < 1e-4:
		return Vector3.ZERO
	return o + d * ((y - o.y) / d.y)


# --- Moving --------------------------------------------------------------------------------

func _select(p: Koma) -> void:
	_selected = p
	_enemy_wave = null
	_dragging = false
	_carry_prev = p.position
	if p.square.x >= 0:
		_targets = KomaMoves.reach(p.kind, p.promoted, p.colour, p.square, occupant).map(func(r: Array) -> Vector2i: return r[0])
	else:
		_targets = KomaMoves.drops(p.kind, p.colour, occupant)
	p.lift(lift_height)


func _deselect() -> void:
	if _selected:
		_selected.slam(0.12, func() -> void: pass)
	_selected = null
	_targets = []


func _carry_to(screen: Vector2) -> void:
	var p := _selected
	# Follow the finger at the carried height, so the piece stays under it on screen.
	var at := _ray_plane(screen, lift_height)
	at.y = 0.0
	p.position = p.position.lerp(at, 0.6)


func _process(delta: float) -> void:
	_time += delta
	if _selected != null:
		var v := (_selected.position - _carry_prev) / maxf(delta, 1e-3)
		_carry_prev = _selected.position
		_selected.carry_lean(v if _dragging else Vector3.ZERO, delta)
	_update_squares()


func _return_selected() -> void:
	var p := _selected
	var home := square_pos(p.square) if p.square.x >= 0 else p.position
	if p.square.x < 0:
		_relayout_hand(p.colour)
	else:
		p.create_tween().tween_property(p, "position", home, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_deselect()


func _move_selected(to: Vector2i, dragged: bool) -> void:
	var p := _selected
	var from := p.square
	var from_hand := from.x < 0
	_selected = null
	_targets = []
	_enemy_wave = null
	_busy = true
	var victim := piece_at(to)
	var dest := square_pos(to)

	var trail: CPUParticles3D = null
	if from_hand:
		hands[p.colour].erase(p)
		trail = fx.trail(p)
	# Travel to the square while lifted (a short arc when tapped, a snap when dragged).
	var travel := 0.1 if dragged else clampf(p.position.distance_to(dest) / 60.0, 0.16, 0.32)
	var t := p.create_tween()
	t.tween_property(p, "position", dest, travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	p.square = to
	if from_hand:
		_relayout_hand(p.colour)

	var promote := not from_hand and not p.promoted and KomaMoves.can_promote(p.kind, p.colour, from, to)
	var landed := func() -> void:
		var strength := 1.0 if victim != null else 0.7
		fx.impact(dest, strength)
		if victim != null:
			_capture(victim, p.colour)
		if trail:
			trail.emitting = false
			get_tree().create_timer(0.6).timeout.connect(trail.queue_free)
	if promote:
		await p.promote_flip(lift_height + 4.0, 0.62, func() -> void: fx.promotion_burst(dest + Vector3(0, lift_height + 4.0, 0)), landed).finished
	else:
		await p.slam(0.13, landed).finished
	_last_move = [from, to] if not from_hand else [to]
	side_to_move = 1 - side_to_move
	_busy = false


## The captured piece is knocked off the board, spins through the air to the capturer's stand
## and becomes theirs.
func _capture(victim: Koma, new_owner: int) -> void:
	victim.square = Vector2i(-1, -1)
	var start := victim.position
	var index := 0
	for h: Koma in hands[new_owner]:
		if h.kind == victim.kind:
			index += 1
	hands[new_owner].append(victim)
	var end := _hand_slot(new_owner, victim.kind, index)
	var peak := (start + end) * 0.5 + Vector3(0, 14.0, 0)
	var t := victim.create_tween()
	var spin := victim.lift_pivot
	t.set_parallel()
	t.tween_method(func(k: float) -> void:
		victim.position = start.lerp(peak, k).lerp(peak.lerp(end, k), k), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	t.tween_property(spin, "rotation:y", spin.rotation.y + TAU * 2.0, 0.55)
	t.tween_property(spin, "rotation:x", spin.rotation.x + TAU, 0.55)
	t.chain().tween_callback(func() -> void:
		spin.rotation = Vector3.ZERO
		victim.reset_promotion()
		victim.set_colour(new_owner)
		fx.impact(end, 0.25)
		_relayout_hand(new_owner))


# --- Squares: targets, last move and the movement wave -------------------------------------

func _update_squares() -> void:
	var light := PackedFloat32Array()
	light.resize(81)
	var tint := []
	tint.resize(81)
	tint.fill(GOLD)
	if _selected != null:
		for sq: Vector2i in _targets:
			light[sq.y * 9 + sq.x] = 0.75 + 0.15 * sin(_time * 6.0)
	else:
		for sq: Vector2i in _last_move:
			light[sq.y * 9 + sq.x] = 0.18
		if wave_on and not _busy:
			_wave(light)
	if _enemy_wave != null and _enemy_wave.square.x >= 0:
		var t := fmod(_time - _enemy_wave_t0, WAVE_CYCLE * 0.6)
		for r: Array in KomaMoves.reach(_enemy_wave.kind, _enemy_wave.promoted, _enemy_wave.colour, _enemy_wave.square, occupant):
			var sq: Vector2i = r[0]
			var v := _pulse(t - (r[1] - 1) * WAVE_STEP) * 0.95
			var i := sq.y * 9 + sq.x
			if v > light[i]:
				light[i] = v
				tint[i] = RED
	var mm := _squares.multimesh
	for i in 81:
		var c: Color = tint[i]
		mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, light[i]))


## Gold wave: every few seconds each of the mover's pieces sends a short pulse of light along
## the squares it can reach, one piece after another across the board.
func _wave(light: PackedFloat32Array) -> void:
	var own: Array[Koma] = []
	for p in pieces:
		if p.colour == side_to_move and p.square.x >= 0:
			own.append(p)
	own.sort_custom(func(a: Koma, b: Koma) -> bool: return a.square.x * 10 + a.square.y < b.square.x * 10 + b.square.y)
	var t := fmod(_time, WAVE_CYCLE)
	for i in own.size():
		var p := own[i]
		var start := WAVE_SWEEP * i / maxf(own.size(), 1.0)
		var self_glow := _pulse(t - start + 0.08)
		p.material.set_shader_parameter("glow", self_glow * 0.18 * wave_strength / 0.55)
		for r: Array in KomaMoves.reach(p.kind, p.promoted, p.colour, p.square, occupant):
			var sq: Vector2i = r[0]
			var v := _pulse(t - start - (r[1] - 1) * WAVE_STEP) * wave_strength
			var idx := sq.y * 9 + sq.x
			light[idx] = maxf(light[idx], v)


func _pulse(x: float) -> float:
	if x < 0.0 or x > WAVE_PULSE:
		return 0.0
	return sin(PI * x / WAVE_PULSE)


# --- Menu ----------------------------------------------------------------------------------

func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var button := Button.new()
	button.text = "☰"
	button.add_theme_font_size_override("font_size", 40)
	button.position = Vector2(24, 20)
	button.custom_minimum_size = Vector2(84, 84)
	button.modulate = Color(1, 1, 1, 0.75)
	layer.add_child(button)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 116)
	panel.visible = false
	layer.add_child(panel)
	button.pressed.connect(func() -> void: panel.visible = not panel.visible)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var add_toggle := func(label: String, value: bool, on_change: Callable) -> void:
		var c := CheckButton.new()
		c.text = label
		c.button_pressed = value
		c.add_theme_font_size_override("font_size", 30)
		c.toggled.connect(on_change)
		box.add_child(c)
	var add_slider := func(label: String, value: float, lo: float, hi: float, on_change: Callable) -> void:
		var l := Label.new()
		l.text = label
		l.add_theme_font_size_override("font_size", 26)
		box.add_child(l)
		var s := HSlider.new()
		s.min_value = lo
		s.max_value = hi
		s.step = (hi - lo) / 100.0
		s.value = value
		s.custom_minimum_size = Vector2(460, 44)
		s.value_changed.connect(on_change)
		box.add_child(s)

	add_toggle.call("Ajuda de movimento (onda)", wave_on, func(v: bool) -> void: wave_on = v; _clear_piece_glow())
	add_toggle.call("Efeitos reduzidos", fx.reduced, func(v: bool) -> void: fx.reduced = v)
	add_slider.call("Brilho da onda", wave_strength, 0.1, 1.0, func(v: float) -> void: wave_strength = v)
	add_slider.call("Tremor no impacto", fx.impact_shake, 0.0, 1.0, func(v: float) -> void: fx.impact_shake = v)
	add_slider.call("Pausa no impacto (s)", fx.hitstop, 0.0, 0.15, func(v: float) -> void: fx.hitstop = v)
	add_slider.call("Poeira", fx.impact_dust, 0.0, 2.0, func(v: float) -> void: fx.impact_dust = v)
	add_slider.call("Altura ao pegar", lift_height, 0.8, 5.0, func(v: float) -> void: lift_height = v)
	var reset := Button.new()
	reset.text = "Recomeçar posição"
	reset.add_theme_font_size_override("font_size", 30)
	reset.pressed.connect(func() -> void:
		_selected = null
		_targets = []
		_enemy_wave = null
		_setup_position())
	box.add_child(reset)


func _clear_piece_glow() -> void:
	for p in pieces:
		p.material.set_shader_parameter("glow", 0.0)


# --- Screenshots for development -----------------------------------------------------------
# godot --path godot res://visual/table.tscn -- shot=/tmp/a.png demo=lift at=1.2

func _run_cmdline_demo() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if not args.has("shot"):
		return
	var demo: String = args.get("demo", "start")
	var at := float(args.get("at", "1.0"))
	await get_tree().process_frame
	match demo:
		"lift":
			_select(piece_at(Vector2i(7, 7)))   # Sente's rook
		"enemy":
			_enemy_wave = piece_at(Vector2i(7, 1)) # Gote's bishop
			_enemy_wave_t0 = _time
		"impact":
			_select(piece_at(Vector2i(2, 6)))
			await get_tree().create_timer(0.3).timeout
			_move_selected(Vector2i(2, 5), false)
		"promote":
			# Clear a path and send Sente's bishop into the promotion zone.
			_move_instant(piece_at(Vector2i(2, 6)), Vector2i(2, 5))
			_select(piece_at(Vector2i(1, 7)))
			await get_tree().create_timer(0.3).timeout
			_move_selected(Vector2i(6, 2), false)
		"capture":
			_move_instant(piece_at(Vector2i(2, 6)), Vector2i(2, 5))
			_select(piece_at(Vector2i(1, 7)))
			await get_tree().create_timer(0.3).timeout
			_move_selected(Vector2i(7, 1), false)
	# Software rendering is slow: wait in game time, counted in frames at a fixed step.
	# Several shots: shot=/tmp/f%d.png count=6 every=0.05
	var count := int(args.get("count", "1"))
	var every := float(args.get("every", "0.1"))
	for i in int(at * 30.0):
		await get_tree().process_frame
	for n in count:
		var path: String = args["shot"] % n if "%d" in args["shot"] else args["shot"]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path, " after ", Engine.get_frames_drawn(), " frames")
		for i in maxi(1, int(every * 30.0)):
			await get_tree().process_frame
	get_tree().quit()


func _move_instant(p: Koma, to: Vector2i) -> void:
	p.square = to
	p.position = square_pos(to)
