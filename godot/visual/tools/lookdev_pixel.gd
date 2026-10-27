extends SceneTree
## Close-up render of the pixel pieces (Koma.pixel): every face of both teams, promoted ones too,
## under the table's key light. Optional: camera distance (1 = the whole set), a folder of trial
## masks (absolute path, "" for the real ones) and shader overrides (groove_shadow=0.8 ...).
##   xvfb-run -a godot --path godot --resolution 1600x900 -s res://visual/tools/lookdev_pixel.gd -- out.png [distance] [masks] [name=value ...]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://lookdev_pixel.png"
	var dist := float(args[1]) if args.size() > 1 else 1.0
	var masks: String = args[2] if args.size() > 2 else ""
	var params := {}
	for a in args.slice(3):
		params[a.get_slice("=", 0)] = float(a.get_slice("=", 1))
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.3, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.58, 0.55)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	root3d.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -38, 0) # the table's key light
	light.light_energy = 1.6
	light.light_color = Color(1.0, 0.92, 0.8)
	light.shadow_enabled = true
	root3d.add_child(light)
	Koma.pixel = true
	var kinds := ["K", "R", "B", "G", "S", "N", "L", "P"]
	var promotes := ["R", "B", "S", "N", "L", "P"]
	var rows := [kinds.map(func(k): return [k, 0]), kinds.map(func(k): return [k, 1]),
		promotes.map(func(k): return [k, 0, true]), promotes.map(func(k): return [k, 1, true])]
	for r in rows.size():
		for i in rows[r].size():
			var p: Array = rows[r][i]
			var k := Koma.new()
			root3d.add_child(k)
			k.setup(p[0], p[1], 100 + i * 7 + r)
			if masks != "":
				var faces: Array = Koma.KANJI[p[0]]
				var front: String = "king_gote" if p[0] == "K" and p[1] == 1 else faces[0]
				k.material.set_shader_parameter("kanji_front", ImageTexture.create_from_image(Image.load_from_file(masks + "/" + front + ".png")))
				if faces[1] != "":
					k.material.set_shader_parameter("kanji_back", ImageTexture.create_from_image(Image.load_from_file(masks + "/" + faces[1] + ".png")))
			for key in params:
				k.material.set_shader_parameter(key, params[key])
			if p.size() > 2:
				k.show_promoted()
			k.position = Vector3((i - 3.5) * 3.3, 0, r * 4.0 - 6.0)
	var cam := Camera3D.new()
	cam.fov = 30
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0, 30.0, 18.0) * dist, Vector3(0, 0, 0.3))
	for i in 8:
		await process_frame
	get_root().get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
