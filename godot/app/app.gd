extends Node
## The app (autoload "App"): moves between the screens and keeps the settings.
##
## Screens: start (home.tscn), game (game.tscn), course map (course.tscn) and lesson
## (lesson.tscn). What the next screen should do is left in `request`:
##   game:   {action: "new", level, human_color} | {action: "continue"} | {action: "guided", lesson}
##   lesson: {lesson: id}

const HOME := "res://app/home.tscn"
const GAME := "res://app/game.tscn"
const COURSE := "res://app/course.tscn"
const LESSON := "res://app/lesson.tscn"
const SETTINGS_PATH := "user://ajustes.json"

var request := {}
## {reduced_effects: bool, welcomed: bool}
var settings := {"reduced_effects": false, "welcomed": false}

var _fade: ColorRect


func _ready() -> void:
	_load_settings()
	Table.reduced_default = settings.reduced_effects
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = UiTheme.BG
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	UiTheme.apply(get_tree())
	# Android "back": up one screen.
	get_tree().root.go_back_requested.connect(_back)


func go_home() -> void:
	_go(HOME, {})


func new_game(level: int, human_color: String) -> void:
	_go(GAME, {"action": "new", "level": level, "human_color": human_color})


func continue_game() -> void:
	_go(GAME, {"action": "continue"})


## The course's game lessons: a game against the weakest level, with the coach.
func guided_game(lesson_id: String) -> void:
	_go(GAME, {"action": "guided", "lesson": lesson_id})


func open_course() -> void:
	_go(COURSE, {})


func open_lesson(id: String) -> void:
	_go(LESSON, {"lesson": id})


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	if key == "reduced_effects":
		Table.reduced_default = value
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


## The game in progress saved on the device, or {} (none, or already over).
func saved_game() -> Dictionary:
	if not FileAccess.file_exists(GameSession.SAVE_PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(GameSession.SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or (data.get("moves", []) as Array).is_empty():
		return {}
	if data.get("resigned", "") != "" or data.get("impasse_declared", "") != "":
		return {}
	if typeof(data.get("settings")) != TYPE_DICTIONARY:
		return {}
	return data


func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		for key in settings:
			if data.has(key) and typeof(data[key]) == typeof(settings[key]):
				settings[key] = data[key]


## Fades out, changes the screen, fades in.
func _go(scene: String, req: Dictionary) -> void:
	request = req
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.18)
	await t.finished
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	t = create_tween()
	t.tween_property(_fade, "modulate:a", 0.0, 0.25)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _back() -> void:
	var current := get_tree().current_scene
	if current == null:
		return
	match current.scene_file_path:
		HOME:
			get_tree().quit()
		LESSON:
			open_course()
		_:
			go_home()

