class_name LessonSession
extends RefCounted
## One lesson being played (port of src/learn/LessonSession.ts): which step is showing, the
## position, the goal and how the learner is doing. No scene: the lesson screen draws from this
## state and forwards the learner's moves here. The learner always plays Sente.
##
## `feedback` is {} or {kind: "info"|"success"|"error", text}. Squares are Vector2i(col, row).

signal changed

## Exercises where the opponent stands still: after each move the turn comes back to Sente.
const STILL_GOALS := ["reach", "capture", "formation", "free"]

var rules: GameRules
var lesson: Dictionary
var step_index := 0
var feedback := {}
## The current exercise is solved (or the step is not an exercise).
var solved := false
## The lesson is over; `score` holds its stars (1-3), or 0 if exercises were skipped.
var finished := false
var score := 0
## The opponent is about to answer (scripted reply).
var replying := false
var last_move := ""
## Squares highlighted by the last hint.
var hint_squares: Array[Vector2i] = []

## Runs the opponent's scripted reply (a Callable); the default waits a little so the learner
## sees it. The tests pass one that runs it at once.
var schedule: Callable

var _star_squares: Array[Vector2i] = []
var _played: Array[String] = []
var _line_index := 0
var _mistakes := 0
var _hinted := false
## Stars of each solved exercise, by step index.
var _results := {}
## Bumped on every step change, so a late scripted reply cannot land in another step.
var _step_token := 0


func _init(game_rules: GameRules, the_lesson: Dictionary, scheduler := Callable()) -> void:
	rules = game_rules
	lesson = the_lesson
	schedule = scheduler
	_load_step(0)


## Stars for one exercise: 3 when solved cleanly, fewer with extra moves, mistakes or hints.
static func exercise_stars(goal: Dictionary, moves: int, mistakes: int, hinted: bool) -> int:
	var stars: int
	if goal.type in ["reach", "capture", "formation"]:
		var extra: int = moves - (goal.solution as Array).size()
		stars = 3 if extra <= 0 else (2 if extra <= 2 else 1)
	else:
		stars = 3 - mistakes
	if hinted:
		stars -= 1
	return clampi(stars, 1, 3)


## Squares from USI names.
static func squares(names) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if names is Array:
		for name: String in names:
			out.append(GameRules.parse_square(name))
	return out


## Moves a learner may play for one entry of a line: one move, several, or [] for "*" (any).
static func accepted(accept) -> Array:
	if accept is String:
		return [] if accept == "*" else [accept]
	return accept


static func accepts(accept, move: String) -> bool:
	return (accept is String and accept == "*") or accepted(accept).has(move)


func step() -> Dictionary:
	return lesson.steps[step_index]


## The current step when it is an exercise, else {}.
func exercise() -> Dictionary:
	var s := step()
	return s if s.kind == "exercise" else {}


func is_last() -> bool:
	return step_index == lesson.steps.size() - 1


## Squares the current step talks about.
func focus() -> Array[Vector2i]:
	return squares(step().get("focus"))


## Stars left on the board in a "reach" exercise.
func remaining_stars() -> Array[Vector2i]:
	return _star_squares


## True when the learner may move a piece now.
func can_move() -> bool:
	var ex := exercise()
	if ex.is_empty() or replying or rules.side_to_move() != "black" or rules.result().over:
		return false
	return ex.goal.type == "free" or not solved


func legal_moves() -> PackedStringArray:
	return rules.legal_moves() if can_move() else PackedStringArray()


## The step can be left: info steps, free play and solved exercises.
func can_continue() -> bool:
	return exercise().is_empty() or solved


# --- Navigation ----------------------------------------------------------------------------

func next() -> void:
	if not can_continue():
		return
	var ex := exercise()
	if not ex.is_empty() and ex.goal.type != "free":
		_results[step_index] = exercise_stars(ex.goal, _played.size(), _mistakes, _hinted)
	if is_last():
		finished = true
		score = _lesson_score()
		changed.emit()
		return
	_load_step(step_index + 1)
	changed.emit()


## Going back forgets the result of the step we return to, so it counts again when redone.
func previous() -> void:
	if step_index > 0:
		go_to(step_index - 1)


## Jumps to a step; results of the steps from there on are forgotten.
func go_to(index: int) -> void:
	if index < 0 or index >= lesson.steps.size():
		return
	for s in _results.keys():
		if s >= index:
			_results.erase(s)
	finished = false
	_load_step(index)
	changed.emit()


func restart_step() -> void:
	_load_step(step_index)
	changed.emit()


## Average stars of the exercises, or 0 when some exercise was skipped.
func _lesson_score() -> int:
	var exercises := []
	for i in lesson.steps.size():
		var s: Dictionary = lesson.steps[i]
		if s.kind == "exercise" and s.goal.type != "free":
			exercises.append(i)
	if exercises.is_empty():
		return 3
	var total := 0
	for i in exercises:
		if not _results.has(i):
			return 0
		total += _results[i]
	return roundi(float(total) / exercises.size())


func _load_step(index: int) -> void:
	_step_token += 1
	step_index = index
	var s := step()
	feedback = {}
	solved = s.kind == "info" or (s.kind == "exercise" and s.goal.type == "free")
	replying = false
	last_move = ""
	_played.clear()
	_line_index = 0
	_mistakes = 0
	_hinted = false
	hint_squares = []
	_star_squares = squares(s.goal.stars) if s.kind == "exercise" and s.goal.type == "reach" else ([] as Array[Vector2i])
	var sfen := sfen_for(index)
	if sfen != "":
		rules.load_position(sfen)
	elif index == 0:
		rules.load_position()


## The position of a step: its own, or (info steps without one) the previous step's.
func sfen_for(index: int) -> String:
	for i in range(index, -1, -1):
		var sfen: String = lesson.steps[i].get("sfen", "")
		if sfen != "":
			return sfen
	return ""


# --- Moves ---------------------------------------------------------------------------------

## The learner plays a legal move.
func play(move: String) -> void:
	var ex := exercise()
	if ex.is_empty() or not can_move() or not rules.is_legal(move):
		return
	hint_squares = []
	var goal: Dictionary = ex.goal
	if goal.type in STILL_GOALS:
		_play_still(ex, move)
	elif goal.type == "line":
		_play_line(ex, goal, move)
	elif goal.type == "mate":
		_play_mate(ex, move)
	elif goal.type == "illegal":
		feedback = {"kind": "info", "text": "Esse lance é permitido. Tente o lance proibido que o texto descreve."}
	changed.emit()


## The learner tried an illegal move (`reason` from Explain). In an "illegal" exercise trying the
## forbidden kind of move is the goal; returns true when that solved it.
func attempt_illegal(reason: Dictionary) -> bool:
	var ex := exercise()
	if ex.is_empty() or ex.goal.type != "illegal" or solved or reason.get("code", "") != ex.goal.code:
		return false
	_solve(ex)
	changed.emit()
	return true


func _play_still(ex: Dictionary, move: String) -> void:
	var goal: Dictionary = ex.goal
	rules.play(move)
	if rules.is_check():
		rules.undo()
		feedback = {"kind": "error", "text": "Aqui o rei adversário fica de fora: escolha um lance que não dê xeque."}
		return
	# The opponent "passes": the same position with Sente to move again.
	var parts := rules.sfen().split(" ")
	parts[1] = "b"
	rules.load_position(" ".join(parts))
	last_move = move
	_played.append(move)
	feedback = {}
	var to: Vector2i = GameRules.parse_move(move).to
	match goal.type:
		"reach":
			_star_squares.erase(to)
			if _star_squares.is_empty():
				_solve(ex)
		"capture":
			if not _enemy_pieces_left():
				_solve(ex)
		"formation":
			if _formation_done(goal.pieces):
				_solve(ex)


func _enemy_pieces_left() -> bool:
	for row: Array in rules.position().board:
		for p in row:
			if p != null and p.color == "white" and p.type != "K":
				return true
	return false


func _formation_done(pieces: Dictionary) -> bool:
	for name: String in pieces:
		var code: String = pieces[name]
		var p = rules.piece_on(GameRules.parse_square(name))
		if p == null or p.color != "black" or p.type != code.replace("+", "") or p.promoted != code.begins_with("+"):
			return false
	return true


func _play_line(ex: Dictionary, goal: Dictionary, move: String) -> void:
	if goal.get("mate", false) and _mates(move):
		rules.play(move)
		last_move = move
		_played.append(move)
		_solve(ex)
		return
	if not accepts(goal.line[_line_index], move):
		_miss(ex, move)
		return
	rules.play(move)
	last_move = move
	_played.append(move)
	_line_index += 1
	if _line_index >= goal.line.size():
		_solve(ex)
		return
	feedback = {"kind": "info", "text": "Boa! Veja a resposta do adversário…"}
	replying = true
	var token := _step_token
	var reply := func() -> void:
		if token != _step_token:
			return
		var answer: String = accepted(goal.line[_line_index])[0]
		replying = false
		rules.play(answer)
		last_move = answer
		_line_index += 1
		feedback = {"kind": "info", "text": "Sua vez."}
		if _line_index >= goal.line.size():
			_solve(ex)
		changed.emit()
	if schedule.is_valid():
		schedule.call(reply)
	else:
		Engine.get_main_loop().create_timer(0.65).timeout.connect(reply)


func _play_mate(ex: Dictionary, move: String) -> void:
	if not _mates(move):
		_miss(ex, move)
		return
	rules.play(move)
	last_move = move
	_played.append(move)
	_solve(ex)


func _mates(move: String) -> bool:
	if not rules.play(move):
		return false
	var result := rules.result()
	rules.undo()
	return result.over and result.get("reason", "") == "checkmate" and result.get("winner", "") == "black"


func _miss(ex: Dictionary, move: String) -> void:
	_mistakes += 1
	var text: String = ex.get("wrong", {}).get(move, "")
	if text == "":
		rules.play(move)
		var check := rules.is_check()
		rules.undo()
		if ex.goal.type == "mate":
			text = "É xeque, mas o rei ainda tem saída. Procure outro lance." if check else "Esse lance não dá xeque-mate. Procure outro."
		else:
			text = "Não é esse o lance. Pense no que o texto explicou e tente de novo."
	feedback = {"kind": "error", "text": text}


func _solve(ex: Dictionary) -> void:
	solved = true
	replying = false
	feedback = {"kind": "success", "text": ex.success}


# --- Help ----------------------------------------------------------------------------------

## Shows where the next move of the solution goes (when the learner is still on its path).
func hint() -> void:
	var ex := exercise()
	if ex.is_empty() or solved:
		return
	_hinted = true
	var move := _next_solution_move(ex.goal)
	var parsed := GameRules.parse_move(move) if move != "" else {}
	hint_squares = []
	var where := ""
	if not parsed.is_empty():
		if parsed.from is Vector2i:
			hint_squares.append(parsed.from)
		hint_squares.append(parsed.to)
		where = " A casa destacada é onde a peça da mão deve entrar." if parsed.drop != "" else " Veja as casas destacadas: de onde sai e para onde vai."
	feedback = {"kind": "info", "text": ex.hint + where}
	changed.emit()


func _next_solution_move(goal: Dictionary) -> String:
	match goal.type:
		"reach", "capture", "formation":
			for i in _played.size():
				if i >= goal.solution.size() or goal.solution[i] != _played[i]:
					return ""
			return goal.solution[_played.size()] if _played.size() < goal.solution.size() else ""
		"line":
			var options := accepted(goal.line[_line_index])
			return options[0] if not options.is_empty() else ""
		"mate", "illegal":
			return goal.solution
	return ""
