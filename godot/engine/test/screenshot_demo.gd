extends SceneTree
## Renders the demo scene after a few AI moves and saves a PNG (needs a display, e.g. xvfb-run).
##   godot --path godot --rendering-method gl_compatibility -s res://engine/test/screenshot_demo.gd -- out.png

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var demo: Control = load("res://engine/test/engine_demo.tscn").instantiate()
	root.add_child(demo)
	await demo.self_test_finished
	for i in 6:
		demo._ai_move()
		await demo.engine.best_move
		await process_frame
	await create_timer(0.3).timeout
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://demo.png"
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
	quit()
