extends SceneTree
## Close-up render of a few pieces, to tune the look without the whole table.
##   xvfb-run -a godot --path godot --resolution 1280x720 -s res://visual/tools/lookdev.gd -- out.png

func _initialize() -> void:
	var out := "user://lookdev.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var root3d := Node3D.new()
	get_root().add_child(root3d)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.06, 0.05)
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.45, 0.35)
	sky_mat.sky_horizon_color = Color(0.9, 0.75, 0.55)
	sky_mat.ground_bottom_color = Color(0.1, 0.07, 0.05)
	sky_mat.ground_horizon_color = Color(0.4, 0.3, 0.2)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.6
	light.light_color = Color(1.0, 0.92, 0.8)
	light.shadow_enabled = true
	root3d.add_child(light)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.25, 0.15)
	ground.material_override = gm
	root3d.add_child(ground)

	var shader := load("res://visual/koma.gdshader")
	var kinds := [["K", "king_sente", "king_sente"], ["R", "rook", "rook_p"], ["P", "pawn", "pawn_p"], ["S", "silver", "silver_p"]]
	var x := -5.25
	for i in kinds.size():
		var k: Array = kinds[i]
		var mi := MeshInstance3D.new()
		mi.mesh = KomaMesh.build(k[0], 1000 + i * 7)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("kanji_front", load("res://visual/textures/kanji/%s.png" % k[1]))
		mat.set_shader_parameter("kanji_back", load("res://visual/textures/kanji/%s.png" % k[2]))
		mat.set_shader_parameter("seed", float(i * 13 + 5))
		mi.material_override = mat
		mi.position = Vector3(x, KomaMesh.rest_height(k[0]), 0)
		mi.rotation.x = -KomaMesh.rest_tilt(k[0])
		if i == 3:
			mi.rotation.z = PI # show the promoted (back) side
		root3d.add_child(mi)
		x += 3.5

	var cam := Camera3D.new()
	cam.fov = 30
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0, 11.0, 9.0), Vector3(0, 0, 0.3))

	for i in 8:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png(out)
	print("saved ", out)
	quit()
