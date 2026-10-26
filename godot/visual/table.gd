class_name Table
extends Node3D
## The table: board, komadai, the 40 pieces, touch and drag, the effects and the movement
## arrows. A game controller attaches the rules (see "Rules interface"); without one it runs as
## a sandbox for the visual test (patterns only, sides alternate).
##
## Units are centimetres; the board top is at y = 0, centred on the origin.

const CELL := Vector2(3.33, 3.64)
const BOARD_SIZE := Vector3(33.4, 6.0, 36.4)
const KOMADAI_SIZE := Vector3(11.5, 2.6, 12.0)
const KOMADAI_TOP := -2.6
const START_SFEN := "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1"
const HAND_ORDER := ["R", "B", "G", "S", "N", "L", "P"]
const GOLD := Color(1.0, 0.72, 0.28)
const ARROW_GOLD := Color(1.0, 0.78, 0.25)
const ARROW_RED := Color(0.95, 0.12, 0.06)

signal move_chosen(usi: String)
## A move the rules refuse: from the square (or (-1,-1) and `kind` from the hand) to `to`.
signal illegal_attempt(from: Vector2i, kind: String, to: Vector2i)
signal _promotion_answered
## The "Efeitos reduzidos" switch of the menu changed.
signal reduced_effects_changed(on: bool)

var sandbox := true                  ## no rules attached: the visual test
var legal_moves := PackedStringArray()
var interactive := true              ## false while the computer is thinking

## Tuning (menu).
var lift_height := 2.4
var arrows_on := false            ## the "Movimentos" button (beginner levels)

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
var _enemy_arrows: Koma = null      ## opponent's piece whose arrows are shown
var arrows: MoveArrows
var _time := 0.0
var _last_move: Array = []           ## squares of the last move
var _asking := false                 ## the promotion question is open
var _ui_layer: CanvasLayer
var _flashes := {}                   ## square -> [colour, time left]
var _menu_panel: PanelContainer
var _menu_actions: VBoxContainer
var _moves_button: Button
var _sandbox_reset: Button
var _cam_home: Transform3D
var _marks := {}                     ## square -> colour, lit until changed (lessons, hints)
var _stars := {}                     ## square -> star mesh to walk over (lessons)
static var _star_mesh_cache: ArrayMesh
## "Efeitos reduzidos" for new tables (the app's saved setting).
static var reduced_default := false


func _ready() -> void:
	_build_world()
	fx = TableFx.new()
	fx.reduced = reduced_default
	add_child(fx)
	fx.attach_camera(camera)
	_build_board()
	_build_squares()
	arrows = MoveArrows.new()
	arrows.cell = CELL
	add_child(arrows)
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
	bm.set_shader_parameter("noise_tex", Koma.shared_noise())
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
		sm.set_shader_parameter("noise_tex", Koma.shared_noise())
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
	show_sfen(START_SFEN)


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


func _relayout_hand(colour: int, instant := false) -> void:
	var counts := {}
	for p: Koma in hands[colour]:
		var i: int = counts.get(p.kind, 0)
		counts[p.kind] = i + 1
		var to := _hand_slot(colour, p.kind, i)
		if instant:
			p.position = to
		elif p.position.distance_to(to) > 0.01:
			p.create_tween().tween_property(p, "position", to, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# --- Rules interface -----------------------------------------------------------------------
# With `sandbox` on (the visual test) moves follow the pieces' patterns and the sides alternate.
# A game controller turns it off and drives the table: it passes the legal moves (USI) with
# set_legal_moves(), hears move_chosen / illegal_attempt, and animates the opponent's moves
# with play_usi().

## Squares in USI: "7g" is file 7, rank g -> Vector2i(col 2, row 6).
static func usi_square(s: String) -> Vector2i:
	return Vector2i(9 - int(s[0]), s.unicode_at(1) - 97)


static func square_usi(sq: Vector2i) -> String:
	return str(9 - sq.x) + char(97 + sq.y)


func set_legal_moves(moves: PackedStringArray, side: int, can_touch: bool) -> void:
	sandbox = false
	legal_moves = moves
	side_to_move = side
	interactive = can_touch
	_refresh_arrows()


## Where a piece starts from in USI: "7g" on the board, "P*" from the hand.
func _origin(p: Koma) -> String:
	return square_usi(p.square) if p.square.x >= 0 else p.kind + "*"


func _targets_for(p: Koma) -> Array:
	if sandbox:
		if p.square.x >= 0:
			return KomaMoves.reach(p.kind, p.promoted, p.colour, p.square, occupant).map(func(r: Array) -> Vector2i: return r[0])
		return KomaMoves.drops(p.kind, p.colour, occupant)
	var origin := _origin(p)
	var out := []
	for m in legal_moves:
		if m.begins_with(origin):
			var to := usi_square(m.substr(2, 2))
			if not to in out:
				out.append(to)
	return out


## Rebuilds the pieces from a SFEN (no animation): new game, undo, loading a saved game.
func show_sfen(sfen: String) -> void:
	_selected = null
	_targets = []
	_enemy_arrows = null
	for p in pieces:
		p.queue_free()
	pieces.clear()
	hands = [[], []]
	_last_move = []
	var parts := sfen.split(" ")
	var row := 0
	var col := 0
	var promoted := false
	var n := 0
	for ch in parts[0]:
		if ch == "/":
			row += 1
			col = 0
		elif ch == "+":
			promoted = true
		elif ch.is_valid_int():
			col += int(ch)
		else:
			var k := _new_piece(ch.to_upper(), 0 if ch == ch.to_upper() else 1, n)
			k.square = Vector2i(col, row)
			k.position = square_pos(k.square)
			if promoted:
				k.show_promoted()
			promoted = false
			col += 1
			n += 1
	side_to_move = 0 if parts.size() < 2 or parts[1] == "b" else 1
	if parts.size() > 2 and parts[2] != "-":
		var count := 0
		for ch in parts[2]:
			if ch.is_valid_int():
				count = count * 10 + int(ch)
				continue
			var colour := 0 if ch == ch.to_upper() else 1
			for i in maxi(count, 1):
				var k := _new_piece(ch.to_upper(), colour, n)
				n += 1
				k.square = Vector2i(-1, -1)
				hands[colour].append(k)
			count = 0
		for c in 2:
			_relayout_hand(c, true)
	_refresh_arrows()


func _new_piece(kind: String, colour: int, n: int) -> Koma:
	var k := Koma.new()
	add_child(k)
	k.setup(kind, colour, 7919 * (n + 1))
	pieces.append(k)
	return k


## Animates a move decided elsewhere (the computer, or a replay): "7g7f", "8h2b+", "P*5e".
func play_usi(usi: String) -> void:
	var p: Koma = null
	if usi[1] == "*":
		for h: Koma in hands[side_to_move]:
			if h.kind == usi[0]:
				p = h
				break
	else:
		p = piece_at(usi_square(usi.substr(0, 2)))
	if p == null:
		push_error("play_usi: no piece for " + usi)
		return
	_busy = true
	arrows.clear()
	await p.lift(lift_height).finished
	await _perform(p, usi_square(usi.substr(2, 2)), false, usi.ends_with("+"))


# --- Input ---------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _busy or _asking:
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
		# A second tap: on a target moves there, on another own piece switches, on the piece
		# itself starts a drag; anywhere else on the board is an attempt to be explained.
		var sq := _square_under(screen)
		if sq in _targets and (hit == null or hit.colour != side_to_move or hit == _selected):
			_move_selected(sq, false)
			return
		if hit == _selected:
			_dragging = false
			return
		if sq.x >= 0 and (hit == null or hit.colour != side_to_move):
			_refuse(sq)
			return
		_deselect()
	if hit == null:
		if _enemy_arrows != null:
			_enemy_arrows = null
			_refresh_arrows()
		return
	if hit.colour != side_to_move or not interactive:
		# The opponent's piece shows how it moves, in red. Tap again to hide.
		_enemy_arrows = null if _enemy_arrows == hit or hit.square.x < 0 else hit
		_refresh_arrows()
		return
	_select(hit)


func _on_release(screen: Vector2) -> void:
	if _selected == null or not _dragging:
		return
	_dragging = false
	var sq := _square_under(screen)
	if sq in _targets:
		_move_selected(sq, true)
	elif sq.x >= 0 and sq != _selected.square:
		_refuse(sq)
	else:
		_return_selected()


## A move the rules don't allow: the square flashes red, the piece goes back, and the game
## controller is told so the mentor can explain why.
func _refuse(sq: Vector2i) -> void:
	var p := _selected
	flash_square(sq, ARROW_RED)
	fx.shake(0.15)
	_return_selected()
	illegal_attempt.emit(p.square, p.kind, sq)


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
	_enemy_arrows = null
	arrows.clear()
	_dragging = false
	_carry_prev = p.position
	_targets = _targets_for(p)
	p.lift(lift_height)


func _deselect() -> void:
	if _selected:
		_selected.slam(0.12, func() -> void: pass)
	_selected = null
	_targets = []
	_refresh_arrows()


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
	for sq: Vector2i in _stars:
		var star: MeshInstance3D = _stars[sq]
		star.rotation.y += delta * 1.2
		star.position.y = 0.9 + sin(_time * 2.4 + sq.x) * 0.25
	_update_squares()


func _return_selected() -> void:
	var p := _selected
	if p.square.x < 0:
		_relayout_hand(p.colour)
	else:
		p.create_tween().tween_property(p, "position", square_pos(p.square), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_deselect()


## The player's move: decide the promotion (asking if it is optional), then animate and report.
func _move_selected(to: Vector2i, dragged: bool) -> void:
	var p := _selected
	var origin := _origin(p)
	_selected = null
	_targets = []
	_enemy_arrows = null
	_busy = true
	var promote := false
	if sandbox:
		promote = p.square.x >= 0 and not p.promoted and KomaMoves.can_promote(p.kind, p.colour, p.square, to)
	elif p.square.x >= 0:
		var plain := origin + square_usi(to) in legal_moves
		var plus := origin + square_usi(to) + "+" in legal_moves
		if plain and plus:
			# Hover over the square while the player chooses.
			var t := p.create_tween()
			t.tween_property(p, "position", square_pos(to), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			promote = await _ask_promotion(to, p)
		else:
			promote = plus
	var usi := origin + square_usi(to) + ("+" if promote else "")
	await _perform(p, to, dragged, promote)
	if sandbox:
		side_to_move = 1 - side_to_move
		_busy = false
		_refresh_arrows()
	else:
		_busy = false
		move_chosen.emit(usi)


## Moves a lifted piece to `to`: travel, then a slam or the promotion flip, capturing on landing.
func _perform(p: Koma, to: Vector2i, dragged: bool, promote: bool) -> void:
	var from := p.square
	var from_hand := from.x < 0
	var victim := piece_at(to)
	var dest := square_pos(to)
	var trail: CPUParticles3D = null
	if from_hand:
		hands[p.colour].erase(p)
		trail = fx.trail(p)
	# Travel to the square while lifted (a short arc when tapped, a snap when dragged).
	if p.position.distance_to(dest) > 0.05:
		var travel := 0.1 if dragged else clampf(p.position.distance_to(dest) / 60.0, 0.16, 0.32)
		var t := p.create_tween()
		t.tween_property(p, "position", dest, travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await t.finished
	p.square = to
	if from_hand:
		_relayout_hand(p.colour)
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
	if not sandbox:
		_busy = false


## Two buttons over the square: promote (成) or not (不成). Returns the choice.
func _ask_promotion(sq: Vector2i, p: Koma) -> bool:
	_asking = true
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	var yes := Button.new()
	yes.text = "成  Promover"
	var no := Button.new()
	no.text = "不成  Não promover"
	for b in [yes, no]:
		b.add_theme_font_size_override("font_size", 34)
		b.custom_minimum_size = Vector2(0, 92)
		box.add_child(b)
	_ui_layer.add_child(box)
	await get_tree().process_frame
	var at := camera.unproject_position(square_pos(sq) + Vector3(0, lift_height, 0))
	var vp := get_viewport().get_visible_rect().size
	box.position = Vector2(clampf(at.x - box.size.x * 0.5, 16, vp.x - box.size.x - 16), clampf(at.y - box.size.y - 70, 16, vp.y - box.size.y - 16))
	p.set_glow(0.6)
	var answer := [false]
	var done := func(v: bool) -> void:
		answer[0] = v
		_promotion_answered.emit()
	yes.pressed.connect(done.bind(true))
	no.pressed.connect(done.bind(false))
	await _promotion_answered
	box.queue_free()
	_asking = false
	return answer[0]


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
	victim.fade_to_team(new_owner, 0.5)  # red turns to pearl (or back) in the air
	t.tween_property(spin, "rotation:x", spin.rotation.x + TAU, 0.55)
	t.chain().tween_callback(func() -> void:
		spin.rotation = Vector3.ZERO
		victim.reset_promotion()
		victim.set_colour(new_owner)
		fx.impact(end, 0.25)
		_relayout_hand(new_owner))


# --- Squares and arrows ------------------------------------------------------------------

func _update_squares() -> void:
	var mm := _squares.multimesh
	var lit := {}
	if _selected != null:
		var v := 0.75 + 0.15 * sin(_time * 6.0)
		for sq: Vector2i in _targets:
			lit[sq] = v
	else:
		for sq: Vector2i in _last_move:
			lit[sq] = 0.18
	var tint := {}
	for sq: Vector2i in _marks:
		if not lit.has(sq) or lit[sq] < 0.5:
			lit[sq] = 0.42 + 0.1 * sin(_time * 3.0)
			tint[sq] = _marks[sq]
	for sq: Vector2i in _flashes.keys():
		var f: Array = _flashes[sq]
		f[1] -= get_process_delta_time()
		if f[1] <= 0.0:
			_flashes.erase(sq)
			continue
		lit[sq] = minf(1.0, f[1] * 2.5)
		tint[sq] = f[0]
	for row in 9:
		for col in 9:
			var sq := Vector2i(col, row)
			var v: float = lit.get(sq, 0.0)
			var c: Color = tint.get(sq, GOLD)
			mm.set_instance_custom_data(row * 9 + col, Color(c.r, c.g, c.b, v))


func flash_square(sq: Vector2i, colour: Color, seconds := 0.6) -> void:
	_flashes[sq] = [colour, seconds]


## Squares lit steadily until changed: square -> colour (what a lesson talks about, a hint).
func set_marks(marks: Dictionary) -> void:
	_marks = marks


## Gold stars floating over squares (a lesson's "walk over every ★"). A star that is no longer in
## the list bursts and goes away.
func set_stars(squares: Array) -> void:
	for sq: Vector2i in _stars.keys():
		if not sq in squares:
			var star: MeshInstance3D = _stars[sq]
			_stars.erase(sq)
			if not fx.reduced:
				fx.promotion_burst(star.position + Vector3(0, 1, 0))
			var t := star.create_tween()
			t.tween_property(star, "scale", Vector3.ONE * 1.8, 0.25).set_trans(Tween.TRANS_BACK)
			t.tween_property(star, "scale", Vector3.ZERO, 0.15)
			t.tween_callback(star.queue_free)
	for sq: Vector2i in squares:
		if _stars.has(sq):
			continue
		var star := MeshInstance3D.new()
		star.mesh = _star_mesh()
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(star)
		star.position = square_pos(sq) + Vector3(0, 0.9, 0)
		_stars[sq] = star


static func _star_mesh() -> ArrayMesh:
	if _star_mesh_cache:
		return _star_mesh_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		var r := 1.25 if i % 2 == 0 else 0.52
		pts.append(Vector3(cos(a) * r, 0, sin(a) * r))
	# A low pyramid on both faces, so it catches the light as it turns.
	for face in [1.0, -1.0]:
		var apex := Vector3(0, 0.28 * face, 0)
		st.set_normal(Vector3(0, face, 0))
		for i in 10:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % 10]
			if face > 0:
				st.add_vertex(apex)
				st.add_vertex(b)
				st.add_vertex(a)
			else:
				st.add_vertex(apex)
				st.add_vertex(a)
				st.add_vertex(b)
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.78, 0.25)
	m.metallic = 0.8
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color(1.0, 0.65, 0.15)
	m.emission_energy_multiplier = 1.6
	mesh.surface_set_material(0, m)
	_star_mesh_cache = mesh
	return mesh


## Shifts the picture sideways by `pixels` (of a 1080-high screen), leaving room for the mentor:
## positive moves the board to the right.
func set_view_offset(pixels: float) -> void:
	var units_per_pixel := 2.0 * 70.0 * tan(deg_to_rad(camera.fov / 2.0)) / 1080.0
	camera.h_offset = -pixels * units_per_pixel


## Shows or hides the menu, the "Movimentos" button and the version (the start screen hides them).
func show_controls(on: bool) -> void:
	_ui_layer.visible = on


## Arrows of the mover's pieces (button on) and of a tapped opponent's piece.
func _refresh_arrows() -> void:
	arrows.clear()
	if _selected != null or _busy:
		return
	if _enemy_arrows != null:
		arrows.show_for([_enemy_arrows], ARROW_RED)
	elif arrows_on:
		var own := pieces.filter(func(p: Koma) -> bool: return p.colour == side_to_move and p.square.x >= 0)
		arrows.show_for(own, ARROW_GOLD)


# --- Menu ----------------------------------------------------------------------------------

func _build_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_ui_layer = layer
	var button := Button.new()
	button.text = "☰"
	button.add_theme_font_size_override("font_size", 40)
	button.position = Vector2(24, 20)
	button.custom_minimum_size = Vector2(84, 84)
	button.modulate = Color(1, 1, 1, 0.75)
	layer.add_child(button)

	# "Movimentos": arrows out of every piece of the side to move (beginner levels only).
	var moves := Button.new()
	moves.text = "⇡ Movimentos"
	moves.toggle_mode = true
	moves.add_theme_font_size_override("font_size", 34)
	moves.custom_minimum_size = Vector2(300, 96)
	moves.anchor_top = 1.0
	moves.anchor_bottom = 1.0
	moves.offset_left = 24
	moves.offset_top = -120
	moves.offset_bottom = -24
	moves.offset_right = 324
	moves.modulate = Color(1, 1, 1, 0.85)
	moves.toggled.connect(func(on: bool) -> void:
		arrows_on = on
		_enemy_arrows = null
		_refresh_arrows())
	layer.add_child(moves)

	# Build version, so a test on the phone shows which APK is running.
	var version := Label.new()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "?"))
	version.add_theme_font_size_override("font_size", 22)
	version.modulate = Color(1, 1, 1, 0.5)
	version.position = Vector2(120, 46)
	layer.add_child(version)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 116)
	panel.visible = false
	layer.add_child(panel)
	button.pressed.connect(func() -> void: panel.visible = not panel.visible)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)
	# Game actions (added by the controller) on top, the tuning under "Ajustes".
	_menu_actions = VBoxContainer.new()
	_menu_actions.add_theme_constant_override("separation", 10)
	outer.add_child(_menu_actions)
	var settings_toggle := Button.new()
	settings_toggle.text = "Ajustes ▾"
	settings_toggle.flat = true
	settings_toggle.add_theme_font_size_override("font_size", 28)
	outer.add_child(settings_toggle)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.visible = false
	outer.add_child(box)
	settings_toggle.pressed.connect(func() -> void: box.visible = not box.visible)
	_menu_panel = panel
	_moves_button = moves

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

	add_toggle.call("Efeitos reduzidos", fx.reduced, func(v: bool) -> void:
		fx.reduced = v
		reduced_default = v
		reduced_effects_changed.emit(v))
	add_slider.call("Tremor no impacto", fx.impact_shake, 0.0, 1.0, func(v: float) -> void: fx.impact_shake = v)
	add_slider.call("Pausa no impacto (s)", fx.hitstop, 0.0, 0.15, func(v: float) -> void: fx.hitstop = v)
	add_slider.call("Poeira", fx.impact_dust, 0.0, 2.0, func(v: float) -> void: fx.impact_dust = v)
	add_slider.call("Altura ao pegar", lift_height, 0.8, 5.0, func(v: float) -> void: lift_height = v)
	var reset := Button.new()
	_sandbox_reset = reset
	reset.text = "Recomeçar posição"
	reset.add_theme_font_size_override("font_size", 30)
	reset.pressed.connect(func() -> void:
		_selected = null
		_targets = []
		_enemy_arrows = null
		_setup_position()
		_refresh_arrows())
	box.add_child(reset)


## A game action in the menu (new game, undo, hint…). Closes the menu when pressed.
func add_menu_action(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 32)
	b.custom_minimum_size = Vector2(460, 80)
	b.pressed.connect(func() -> void:
		_menu_panel.visible = false
		action.call())
	_menu_actions.add_child(b)
	_sandbox_reset.visible = false
	return b


## The "Movimentos" button exists only in the beginner levels.
func set_moves_button(available: bool) -> void:
	_moves_button.visible = available
	if not available and arrows_on:
		_moves_button.button_pressed = false


## Puts the player's side at the bottom of the screen (0 Sente, 1 Gote).
func set_view_side(colour: int) -> void:
	if _cam_home == Transform3D():
		_cam_home = camera.transform
	var t := _cam_home if colour == 0 else Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * _cam_home
	camera.transform = t
	fx.attach_camera(camera)


## Checkmate: the world slows down, the king's square bursts in red and the table shakes.
func checkmate_effect(king_sq: Vector2i) -> void:
	var pos := square_pos(king_sq)
	Engine.time_scale = 0.35
	fx.promotion_burst(pos + Vector3(0, 2, 0))
	flash_square(king_sq, ARROW_RED, 2.5)
	fx.shake(1.0)
	await get_tree().create_timer(0.9, true, false, true).timeout
	Engine.time_scale = 1.0


## Square of a colour's king, or (-1, -1).
func king_square(colour: int) -> Vector2i:
	for p in pieces:
		if p.kind == "K" and p.colour == colour:
			return p.square
	return Vector2i(-1, -1)


# --- Screenshots for development -----------------------------------------------------------
# godot --path godot res://visual/table.tscn -- shot=/tmp/a.png demo=lift at=1.2

func _run_cmdline_demo() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	# Only when the table runs on its own (the sandbox scene), not inside the game screen.
	if not args.has("shot") or get_tree().current_scene != self:
		return
	var demo: String = args.get("demo", "start")
	var at := float(args.get("at", "1.0"))
	await get_tree().process_frame
	match demo:
		"lift":
			_select(piece_at(Vector2i(7, 7)))   # Sente's rook
		"enemy":
			_enemy_arrows = piece_at(Vector2i(7, 1)) # Gote's bishop
			_refresh_arrows()
		"arrows":
			arrows_on = true
			_refresh_arrows()
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
