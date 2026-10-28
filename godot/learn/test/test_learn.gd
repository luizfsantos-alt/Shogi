extends SceneTree
## Headless tests for the course (godot/learn).
##   godot --headless --path godot -s res://learn/test/test_learn.gd
## Cases mirror tests/lessons.test.ts and tests/coachTips.test.ts of the PWA: every exercise of
## the 52 lessons is solved through the LessonSession, the mates are checked by search, and the
## coach tips come out on the same positions.

const START := GameRules.START_SFEN
const CJK := "[\\x{3040}-\\x{30ff}\\x{4e00}-\\x{9fff}]"

var failures := 0
var checks := 0
var rules := GameRules.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := Time.get_ticks_msec()
	test_structure()
	test_progress()
	test_exercises()
	test_lesson_session()
	test_coach_tips()
	test_gote_words()
	test_kanji_font()
	print("%d checks, %d failures (%d ms)" % [checks, failures, Time.get_ticks_msec() - t])
	quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------- helpers

func expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
		print("FAIL: " + label)


func expect_eq(actual: Variant, expected: Variant, label: String) -> void:
	expect(actual == expected, "%s: got %s, expected %s" % [label, actual, expected])


func sq(name: String) -> Vector2i:
	return GameRules.parse_square(name)


func lesson(id: String) -> Dictionary:
	return Course.find_lesson(id).lesson


## A session on `step` of `lesson`, with scripted replies played at once.
func session_at(the_lesson: Dictionary, step: int, scheduler := func(reply: Callable) -> void: reply.call()) -> LessonSession:
	var s := LessonSession.new(rules, the_lesson, scheduler)
	s.go_to(step)
	return s


## Moves of the side to move that force checkmate within `moves` of its own moves, giving
## check every time (port of tests/mate.ts).
func forced_mates(r: GameRules, moves: int) -> Array:
	var out := []
	for move in r.legal_moves():
		r.play(move)
		var ok := false
		if r.is_check():
			var res := r.result()
			if res.over and res.get("reason", "") == "checkmate":
				ok = true
			elif moves > 1:
				ok = true
				for reply in r.legal_moves():
					r.play(reply)
					var found := not forced_mates(r, moves - 1).is_empty()
					r.undo()
					if not found:
						ok = false
						break
		r.undo()
		if ok:
			out.append(move)
	return out


# ---------------------------------------------------------------- course

func test_structure() -> void:
	var cjk := RegEx.create_from_string(CJK)
	expect_eq(Course.tracks().size(), 4, "four tracks")
	expect_eq(Course.all_lessons().size(), 52, "52 lessons")
	# The advanced track (D): shown under Avançado, one column per part, every lesson in a part.
	var advanced: Dictionary = Course.tracks()[3]
	expect(advanced.get("advanced", false), "track D is advanced")
	var parts := {}
	for part: Dictionary in advanced.parts:
		parts[part.id] = true
	for l: Dictionary in advanced.lessons:
		expect(parts.has(l.get("part", "")), "lesson %s in a part" % l.id)
	expect_eq(Course.next_lesson("practice-game").id, advanced.lessons[0].id, "strategy leads to the advanced track")
	var ids := {}
	for track: Dictionary in Course.tracks():
		expect(cjk.search(track.term) != null, "track term with kanji: " + track.id)
	for l: Dictionary in Course.all_lessons():
		expect(not ids.has(l.id), "unique lesson id " + l.id)
		ids[l.id] = true
		if l.has("term"):
			expect(cjk.search(l.term) != null, "lesson term with kanji: " + l.id)
		expect(l.steps.size() > 0, "lesson has steps: " + l.id)
		for s: Dictionary in l.steps:
			if s.has("sfen"):
				expect(rules.load_position(s.sfen), "%s: position of %s" % [l.id, s.title])
			for name in s.get("focus", []):
				expect(sq(name).x >= 0, "%s: focus square %s" % [l.id, name])
			expect(not (s.text as Array).is_empty(), "%s: %s has text" % [l.id, s.title])

	expect_eq(Course.recommended_lesson({"stars": {}}).id, "board", "first recommended lesson")
	expect_eq(Course.recommended_lesson({"stars": {"board": 3}}).id, "king", "then the king")
	expect_eq(Course.next_lesson("first-game").id, Course.tracks()[1].lessons[0].id, "basics lead to tactics")
	expect_eq(Course.find_lesson("mino").track.id, "strategy", "mino is strategy")
	expect(Course.find_lesson("nope").is_empty(), "unknown lesson")
	expect(Course.next_lesson(Course.all_lessons()[-1].id).is_empty(), "nothing after the last lesson")
	expect_eq(Course.completed_count({"stars": {"board": 2, "king": 1}}), {"done": 2, "total": 52}, "completed count")


func test_progress() -> void:
	var path := "user://test_curso.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	expect_eq(Course.load_progress(path), {"stars": {}}, "no progress yet")
	Course.save_result("king", 2, path)
	Course.save_result("king", 1, path)
	Course.save_result("rook", 0, path)
	expect_eq(Course.load_progress(path).stars, {"king": 2}, "keeps the best result, skips 0")
	Course.save_result("king", 3, path)
	expect_eq(int(Course.load_progress(path).stars.king), 3, "improves")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_exercises() -> void:
	var count := 0
	for l: Dictionary in Course.all_lessons():
		for index in l.steps.size():
			var step: Dictionary = l.steps[index]
			if step.kind != "exercise":
				continue
			count += 1
			var name := "%s #%d %s" % [l.id, index + 1, step.title]
			var goal: Dictionary = step.goal
			var s := session_at(l, index)
			expect_eq(s.solved, goal.type == "free", name + ": not solved at first")
			match goal.type:
				"reach", "capture", "formation":
					for i in goal.solution.size():
						var move: String = goal.solution[i]
						expect(not s.solved, "%s: not solved before %s" % [name, move])
						expect(rules.is_legal(move), "%s: %s legal" % [name, move])
						s.play(move)
						expect(s.feedback.get("kind", "") != "error", "%s: %s → %s" % [name, move, s.feedback.get("text", "")])
				"line":
					for i in goal.line.size():
						if i % 2 == 1:
							continue   # the opponent's replies are played by the session
						var accept = goal.line[i]
						if accept is String and accept == "*":
							s.play(rules.legal_moves()[0])
							continue
						var moves: Array = LessonSession.accepted(accept) if i == 0 else LessonSession.accepted(accept).slice(0, 1)
						for move: String in moves:
							expect(rules.is_legal(move), "%s: %s legal at ply %d" % [name, move, i])
						# Moves as good as the one asked are praised and not played.
						for strong: String in goal.get("strong", {}).get(str(i), {}):
							var before := rules.sfen()
							expect(rules.is_legal(strong), "%s: strong %s legal at ply %d" % [name, strong, i])
							s.play(strong)
							expect(s.feedback.get("text", "").begins_with("Escolha forte!"), "%s: %s praised" % [name, strong])
							expect_eq(rules.sfen(), before, "%s: strong %s not played" % [name, strong])
						s.play(LessonSession.accepted(accept)[0])
				"mate":
					s.play(goal.solution)
				"illegal":
					expect(not rules.is_legal(goal.solution), name + ": solution is illegal")
					var reason := Explain.explain_move(rules, goal.solution)
					expect_eq(reason.code, goal.code, name + ": explained as")
					expect(s.attempt_illegal(reason), name + ": attempt solves")
			expect(s.solved, "%s: solved (%s)" % [name, s.feedback.get("text", "")])
			expect_eq(s.feedback.get("kind", "success"), "success", name + ": success feedback")

			# Wrong-move notes are for legal first moves.
			rules.load_position(step.sfen)
			for move: String in step.get("wrong", {}):
				expect(rules.is_legal(move), "%s: wrong move %s is legal" % [name, move])
			if goal.type == "mate":
				expect(forced_mates(rules, 1).has(goal.solution), name + ": real mate in one")
			if goal.type == "line" and goal.get("mate", false):
				var n := ceili(goal.line.size() / 2.0)
				expect(forced_mates(rules, n - 1).is_empty(), name + ": no shorter mate")
				var keys := forced_mates(rules, n)
				keys.sort()
				var expected := LessonSession.accepted(goal.line[0]).duplicate()
				expected.sort()
				expect_eq(keys, expected, name + ": key moves")
	print("  %d exercises" % count)


func test_lesson_session() -> void:
	# A wrong move is not played and is explained.
	var s := session_at(lesson("values"), 1)
	var before := rules.sfen()
	s.play("5f5c")
	expect_eq(rules.sfen(), before, "wrong move not played")
	expect_eq(s.feedback.get("kind"), "error", "wrong move feedback")
	expect("Prata" in s.feedback.get("text", ""), "wrong move note")
	s.play("5f1f")
	expect(s.solved, "values solved")

	# The opponent stands still and the turn comes back to Sente.
	s = session_at(lesson("rook"), 1)
	s.play("8h8d")
	expect_eq(rules.side_to_move(), "black", "turn back to Sente")
	expect_eq(s.remaining_stars().size(), 2, "two stars left")
	expect_eq(s.last_move, "8h8d", "last move")

	# A still exercise cannot check the enemy king.
	s = session_at(lesson("rook"), 1)
	s.play("8h5h")
	expect_eq(s.feedback.get("kind"), "error", "no check in still exercises")
	expect_eq(rules.piece_on(sq("8h")).type, "R", "rook stays")

	# Hint: the next move of the solution, at the cost of a star.
	var bishop := lesson("bishop")
	s = session_at(bishop, 1)
	s.hint()
	expect_eq(s.hint_squares, [sq("8h"), sq("4d")] as Array[Vector2i], "hint squares")
	s.play("8h4d")
	s.play("4d2f")
	expect(s.solved, "bishop 1 solved")
	s.next()
	s.go_to(2)
	s.play("2h4f")
	s.play("4f6d")
	s.next()
	expect(s.finished, "bishop finished")
	expect_eq(s.score, 3, "(2 + 3) / 2 rounded")

	# A guided line: the mentor says one move at a time and points its squares, at no cost.
	var mino := lesson("mino")
	var mino_step := 1
	var guide: Array = mino.steps[mino_step].goal.guide
	s = session_at(mino, mino_step)
	expect(s.points(), "mino points its moves")
	expect_eq(s.feedback.get("text"), guide[0], "first cue on load")
	expect_eq(s.cue_squares(), [sq("5i"), sq("4h")] as Array[Vector2i], "first move pointed")
	expect_eq(s.line_move(), Vector2i(0, 5), "move 1 of 5")
	s.play("5i4h")
	expect_eq(s.feedback.get("text"), guide[1], "next cue after the reply")
	expect_eq(s.cue_squares(), [sq("4h"), sq("3h")] as Array[Vector2i], "second move pointed")
	expect_eq(s.line_move(), Vector2i(1, 5), "move 2 of 5")
	for move in ["4h3h", "3h2h", "3i3h", "6i5h"]:
		s.play(move)
	expect(s.solved, "mino solved")
	expect_eq(s.cue(), "", "no cue once solved")
	s.next()
	expect_eq(s._results.get(mino_step), 3, "pointed moves cost no star")

	# A puzzle with a guide says the next stage without pointing it.
	s = session_at(lesson("fork"), 1)
	expect(not s.points(), "fork does not point")
	expect_eq(s.cue(), "", "no cue before the first move")
	s.play("N*6e")
	expect_eq(s.feedback.get("text"), lesson("fork").steps[1].goal.guide[1], "fork's second cue")
	expect_eq(s.cue_squares(), [] as Array[Vector2i], "fork points nothing")

	# A skipped exercise scores 0.
	var king := lesson("king")
	s = session_at(king, king.steps.size() - 1)
	s.attempt_illegal(Explain.explain_move(rules, "5h5g"))
	s.next()
	expect(s.finished, "king finished")
	expect_eq(s.score, 0, "skipped exercises score 0")

	# Stars by extra moves, mistakes and hints.
	var reach := {"type": "reach", "stars": [], "solution": ["a", "b"]}
	expect_eq(LessonSession.exercise_stars(reach, 2, 0, false), 3, "clean")
	expect_eq(LessonSession.exercise_stars(reach, 4, 0, false), 2, "2 extra")
	expect_eq(LessonSession.exercise_stars(reach, 5, 0, false), 1, "3 extra")
	expect_eq(LessonSession.exercise_stars(reach, 2, 0, true), 2, "hinted")
	expect_eq(LessonSession.exercise_stars({"type": "mate", "solution": "G*5b"}, 1, 1, false), 2, "one mistake")
	expect_eq(LessonSession.exercise_stars({"type": "mate", "solution": "G*5b"}, 1, 5, true), 1, "at least one")

	# Scripted replies come later.
	var pending := []
	s = session_at(lesson("fork"), 1, func(reply: Callable) -> void: pending.append(reply))
	s.play("N*6e")
	expect(s.replying, "replying")
	expect(not s.can_move(), "cannot move while replying")
	pending.pop_front().call()
	expect_eq(s.last_move, "7c7f", "scripted reply")
	expect(s.can_move(), "can move again")
	s.play("6e5c+")
	expect(s.solved, "fork solved")

	# A late reply after leaving the step is dropped.
	pending.clear()
	s = session_at(lesson("fork"), 1, func(reply: Callable) -> void: pending.append(reply))
	s.play("N*6e")
	s.restart_step()
	pending.pop_front().call()
	expect_eq(rules.history(), PackedStringArray(), "late reply dropped")

	# Info steps without a board keep the previous step's position.
	var board := lesson("board")
	s = session_at(board, 1)
	expect_eq(rules.sfen(), board.steps[0].sfen, "info step keeps the previous board")


func tip_for(sfen: String, seen: Array = [], moves := PackedStringArray()) -> Dictionary:
	rules.load_position(sfen, moves)
	var set := {}
	for id in seen:
		set[id] = true
	return CoachTips.coach_tip(rules, rules.side_to_move(), set)


func test_coach_tips() -> void:
	expect_eq(tip_for(START).get("id"), "opening", "opening tip")
	expect(tip_for(START, ["opening"]).is_empty(), "then quiet")
	expect_eq(tip_for("4k4/9/4r4/9/9/9/9/9/4K4 b - 1", ["opening"]).get("id"), "check", "check first")
	var fork := tip_for("4k4/9/2r1g4/9/9/9/7P1/6SK1/6G2 b N 1", ["opening"])
	expect_eq(fork.get("id"), "fork", "fork tip")
	expect(fork.get("squares", []).has(sq("7c")) and fork.get("squares", []).has(sq("5c")), "fork squares")
	var hanging := tip_for("4k4/9/7r1/9/7B1/9/9/9/4K4 b - 1", ["opening"])
	expect_eq(hanging.get("id"), "hanging", "hanging tip")
	expect("2e" in hanging.get("text", ""), "hanging square named")
	expect_eq(tip_for("4k4/9/9/9/9/9/9/9/4K4 b P 1", ["opening"]).get("id"), "hand", "hand tip")
	expect_eq(tip_for("4k4/9/9/8P/9/9/9/9/4K4 b - 1", ["opening"]).get("id"), "promotion", "promotion tip")
	expect(tip_for(START, ["opening"], PackedStringArray(["7g7f", "3a4b"])).get("id") != "promotion", "no promotion into a recapture")
	var moves := PackedStringArray(["9g9f", "9c9d", "1g1f", "1c1d", "9f9e", "9d9e", "1f1e", "1d1e", "8g8f", "8c8d", "2g2f", "2c2d", "3g3f", "3c3d", "7g7f", "7c7d"])
	expect_eq(tip_for(START, ["opening", "hand", "hanging", "fork", "promotion"], moves).get("id"), "sitting-king", "sitting king")
	expect_eq(CoachTips.piece_value({"type": "R", "promoted": false}), 10, "rook value")
	expect_eq(CoachTips.piece_value({"type": "P", "promoted": true}), 6, "tokin value")


## Every Japanese character of the course and of the app's scripts is in the bundled pixel kanji
## font (app/ui/fonts/dot-kanji.ttf; `node scripts/make-kanji-font.mjs --godot` remakes it), and
## every other character beyond ASCII in it or in the pixel Latin font (Pixelify Sans).
func test_gote_words() -> void:
	var pixel := Koma.pixel
	Koma.pixel = true
	expect_eq(Course.gote_words("O Rei vermelho e as peças vermelhas; Vermelha é a Torre."), "O Rei preto e as peças pretas; Preta é a Torre.", "Gote's pieces are black in the pixel look")
	expect_eq(Course.gote_words("mostra as dela em vermelho"), "mostra as dela em vermelho", "danger stays red")
	Koma.pixel = false
	expect_eq(Course.gote_words("o Rei vermelho"), "o Rei vermelho", "red lacquer in the classic look")
	Koma.pixel = pixel


func test_kanji_font() -> void:
	var font: FontFile = load("res://app/ui/fonts/dot-kanji.ttf")
	var latin: FontFile = load("res://app/ui/fonts/pixelify-400.ttf")
	var japanese := RegEx.create_from_string("[\\x{3040}-\\x{30ff}\\x{3400}-\\x{9fff}\\x{3005}]")
	var texts := [FileAccess.get_file_as_string(Course.DATA_PATH)]
	for dir in ["res://app", "res://app/ui", "res://learn", "res://game"]:
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				texts.append(FileAccess.get_file_as_string(dir + "/" + file))
	var missing := {}
	var other := {}
	for text: String in texts:
		for m in japanese.search_all(text):
			var ch := m.get_string()
			if not font.has_char(ch.unicode_at(0)):
				missing[ch] = true
		for i in text.length():
			var code := text.unicode_at(i)
			if code > 126 and not japanese.search(text[i]) and not font.has_char(code) and not latin.has_char(code):
				other[text[i]] = true
	expect_eq("".join(other.keys()), "", "symbols missing from the pixel fonts")
	expect_eq("".join(missing.keys()), "", "kanji missing from the font")
