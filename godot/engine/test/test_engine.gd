extends SceneTree
## Headless tests for the ShogiEngine GDExtension.
##   godot --headless --path godot -s res://engine/test/test_engine.gd
## Cases mirror tests/rules.test.ts of the PWA (same SFENs, same expected moves/results).

const START := "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1"

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print(ShogiEngine.engine_info())
	test_perft()
	test_sfen_and_usi()
	test_promotion()
	test_drops()
	test_checks_and_pins()
	test_endings()
	test_invalid_positions()
	await test_search()
	print("%d checks, %d failures" % [checks, failures])
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


func game(sfen := START, moves := PackedStringArray()) -> ShogiEngine:
	var engine := ShogiEngine.new()
	var ok := engine.set_position(sfen, moves)
	expect(ok, "set_position(%s)" % sfen)
	return engine


## Uchifuzume filter (to be ported to the GDScript backend, like FairyBackend.isPawnDropMate).
func legal(engine: ShogiEngine) -> PackedStringArray:
	var out := PackedStringArray()
	for move in engine.legal_moves():
		if move.begins_with("P*") and engine.gives_check(move):
			engine.play(move)
			var mate := engine.legal_move_count() == 0
			engine.undo()
			if mate:
				continue
		out.append(move)
	return out


func sorted(moves: PackedStringArray) -> Array:
	var a := Array(moves)
	a.sort()
	return a


func starting_with(moves: PackedStringArray, prefix: String) -> Array:
	return sorted(PackedStringArray(Array(moves).filter(func(m): return m.begins_with(prefix))))


func perft(engine: ShogiEngine, depth: int) -> int:
	if depth == 0:
		return 1
	var nodes := 0
	for move in legal(engine):
		engine.play(move)
		nodes += perft(engine, depth - 1)
		engine.undo()
	return nodes


func result(sfen: String, moves := PackedStringArray()) -> Dictionary:
	return game(sfen, moves).game_result()


# ---------------------------------------------------------------- tests

func test_perft() -> void:
	var engine := game()
	expect_eq(engine.get_sfen(), START, "start SFEN")
	expect_eq(engine.side_to_move(), "black", "Sente moves first")
	var expected := [30, 900, 25470]
	for depth in range(1, 4):
		var t := Time.get_ticks_usec()
		expect_eq(perft(engine, depth), expected[depth - 1], "GDScript perft %d" % depth)
		print("  perft %d via GDScript API: %.1f ms" % [depth, (Time.get_ticks_usec() - t) / 1000.0])
	var t4 := Time.get_ticks_usec()
	expect_eq(engine.perft(4), 719731, "native perft 4")
	print("  perft 4 native: %.1f ms" % ((Time.get_ticks_usec() - t4) / 1000.0))
	expect_eq(engine.get_sfen(), START, "perft leaves the position untouched")


func test_sfen_and_usi() -> void:
	var engine := game(START, PackedStringArray(["7g7f", "3c3d", "8h2b+"]))
	expect_eq(engine.get_sfen(), "lnsgkgsnl/1r5+B1/pppppp1pp/6p2/9/2P6/PP1PPPPPP/7R1/LNSGKGSNL w B 4", "SFEN after 8h2b+")
	expect_eq(Array(engine.history()), ["7g7f", "3c3d", "8h2b+"], "history")

	engine = game("4k4/9/9/9/9/9/9/9/4K4 b P 1")
	expect(engine.is_legal("P*5e"), "P*5e is legal")
	expect(engine.play("P*5e"), "play P*5e")
	expect_eq(engine.get_sfen(), "4k4/9/9/9/4P4/9/9/9/4K4 w - 2", "SFEN after a drop")

	engine = game(START, PackedStringArray(["7g7f", "3c3d", "8h2b+", "3a2b", "B*4e"]))
	var sfen := engine.get_sfen()
	var copy := game(sfen)
	expect_eq(copy.get_sfen(), sfen, "SFEN round trip")
	expect_eq(sorted(copy.legal_moves()), sorted(engine.legal_moves()), "same moves after reload")

	engine = game(START, PackedStringArray(["7g7f", "3c3d"]))
	expect_eq(engine.undo(), "3c3d", "undo 1")
	expect_eq(engine.undo(), "7g7f", "undo 2")
	expect_eq(engine.undo(), "", "undo on empty history")
	expect_eq(engine.get_sfen(), START, "back at the start")

	engine = game(START, PackedStringArray(["7g7f"]))
	expect(not engine.play("7f7e"), "not Sente's turn")
	expect(not engine.set_position(START, PackedStringArray(["7g7f", "7f7e"])), "illegal imported line")
	expect_eq(Array(engine.history()), ["7g7f"], "state kept after a rejected line")

	# Hands with counts >= 10 and the usual R B G S N L P order.
	engine = game("RBGGGG3/SSSSK4/9/9/9/9/9/9/8k b 10Pps 1")
	expect_eq(engine.get_sfen(), "RBGGGG3/SSSSK4/9/9/9/9/9/9/8k b 10Psp 1", "hand counts and order")


func test_promotion() -> void:
	var engine := game("k8/4P4/9/9/9/9/9/9/4K4 b - 1")
	expect(engine.is_legal("5b5a+") and not engine.is_legal("5b5a"), "pawn must promote on the last rank")
	engine = game("k8/9/9/4L4/9/9/9/9/4K4 b - 1")
	expect(engine.is_legal("5d5a+") and not engine.is_legal("5d5a"), "lance must promote on the last rank")
	expect(engine.is_legal("5d5b") and engine.is_legal("5d5b+"), "lance may promote before")
	engine = game("k8/9/9/9/4N4/9/9/9/4K4 b - 1")
	expect_eq(starting_with(engine.legal_moves(), "5e"), ["5e4c", "5e4c+", "5e6c", "5e6c+"], "knight on the third rank")
	engine = game("k8/9/9/4N4/9/9/9/9/4K4 b - 1")
	expect_eq(starting_with(engine.legal_moves(), "5d"), ["5d4b+", "5d6b+"], "knight must promote")
	engine = game("k8/4S4/4G4/9/9/9/9/9/4K4 b - 1")
	expect(engine.is_legal("5b4c") and engine.is_legal("5b4c+"), "silver leaving the zone")
	expect(starting_with(engine.legal_moves(), "5c").all(func(m): return not m.ends_with("+")), "gold never promotes")
	engine = game("4k4/9/9/9/9/9/9/4p4/K8 w - 1")
	expect(engine.is_legal("5h5i+") and not engine.is_legal("5h5i"), "Gote pawn must promote")


func test_drops() -> void:
	var engine := game("4k4/9/9/9/9/9/4P4/9/4K4 b P 1")
	var drops := starting_with(engine.legal_moves(), "P*")
	expect(not drops.any(func(m): return m.begins_with("P*5")), "nifu")
	expect(drops.has("P*4e"), "pawn drop on another file")
	expect(game("4k4/9/9/9/9/9/4+P4/9/4K4 b P 1").is_legal("P*5e"), "promoted pawn does not count for nifu")
	engine = game("4k4/9/9/9/9/9/9/9/4K4 b PLN 1")
	for m in ["P*1a", "L*1a", "N*1a", "N*1b"]:
		expect(not engine.is_legal(m), "no drop without moves: " + m)
	for m in ["P*1b", "L*1b", "N*1c"]:
		expect(engine.is_legal(m), "drop allowed: " + m)
	expect_eq(starting_with(game("4k4/9/9/9/9/9/9/9/4K4 b G 1").legal_moves(), "G*").size(), 79, "gold drops")

	const UCHIFUZUME := "7lk/9/7G1/9/9/9/9/9/4K4 b P 1"
	engine = game(UCHIFUZUME)
	expect(engine.is_legal("P*1b"), "Fairy-Stockfish itself generates the uchifuzume drop")
	expect(engine.gives_check("P*1b"), "gives_check(P*1b)")
	expect(not legal(engine).has("P*1b"), "the GDScript filter removes uchifuzume")
	engine = game(UCHIFUZUME.replace(" P ", " G "))
	engine.play("G*1b")
	expect_eq(engine.game_result(), {"over": true, "winner": "black", "reason": "checkmate"}, "gold drop mate")
	expect(legal(game("8k/9/7G1/9/9/9/9/9/4K4 b P 1")).has("P*1b"), "pawn drop check that is not mate")
	engine = game("7lk/9/7GP/9/9/9/9/9/4K4 b - 1")
	engine.play("1c1b")
	expect_eq(engine.game_result(), {"over": true, "winner": "black", "reason": "checkmate"}, "mate by a moved pawn")


func test_checks_and_pins() -> void:
	expect_eq(starting_with(game("k3r4/9/9/9/9/9/9/4S4/4K4 b - 1").legal_moves(), "5h"), ["5h5g"], "pinned silver")
	var engine := game("4k4/9/9/9/9/9/9/9/r3K4 b - 1")
	expect(engine.is_check(), "in check")
	expect_eq(sorted(engine.legal_moves()), ["5i4h", "5i5h", "5i6h"], "check evasions")


func test_endings() -> void:
	var engine := game("4k4/4G4/4P4/9/9/9/9/9/4K4 w - 1")
	expect(engine.is_check() and engine.legal_moves().is_empty(), "Gote mated")
	expect_eq(engine.game_result(), {"over": true, "winner": "black", "reason": "checkmate"}, "checkmate of Gote")
	expect_eq(result("4k4/9/9/9/9/9/4p4/4g4/4K4 b - 1"),
		{"over": true, "winner": "white", "reason": "checkmate"}, "checkmate of Sente")
	expect_eq(result("4k4/9/9/9/9/9/1g7/2g6/K8 b - 1"), {"over": true, "winner": "white", "reason": "no-legal-moves"}, "no legal moves")
	expect_eq(result(START), {"over": false}, "start position is not over")

	engine = game()
	var cycle := ["2h3h", "8b7b", "3h2h", "7b8b"]
	for i in 2:
		for m in cycle:
			engine.play(m)
	expect_eq(engine.game_result(), {"over": false}, "3rd repetition is not sennichite")
	for m in cycle:
		engine.play(m)
	expect_eq(engine.game_result(), {"over": true, "winner": "draw", "reason": "repetition"}, "sennichite")

	engine = game("8k/9/9/9/9/9/9/9/K6R1 b - 1")
	cycle = ["2i1i", "1a2a", "1i2i", "2a1a"]
	for i in 2:
		for m in cycle:
			engine.play(m)
	for m in ["2i1i", "1a2a", "1i2i"]:
		engine.play(m)
	expect_eq(engine.game_result(), {"over": false}, "perpetual check not yet")
	engine.play("2a1a")
	expect_eq(engine.game_result(), {"over": true, "winner": "white", "reason": "perpetual-check"}, "perpetual check loses")

	engine = game("7sk/9/9/9/9/9/9/9/K6R1 b - 1")
	cycle = ["2i1i", "2a1b", "1i2i", "1b2a"]
	for i in 3:
		for m in cycle:
			engine.play(m)
	expect_eq(engine.game_result(), {"over": true, "winner": "draw", "reason": "repetition"}, "repetition with some checks")


func test_invalid_positions() -> void:
	var engine := ShogiEngine.new()
	expect(not engine.set_position("4r4/9/9/9/9/9/9/9/k3K4 w - 1"), "side that just moved is in check")
	expect(not engine.set_position("garbage"), "garbage SFEN")
	expect(not engine.set_position("9/9/9/9/9/9/9/9/9 b - 1"), "no kings")
	expect(not engine.set_position("4k4/9/9/9/9/9/9/9/4K5 b - 1"), "rank with 10 files")
	expect_eq(engine.get_sfen(), START, "rejected positions leave the start position")


func test_search() -> void:
	var engine := game(START, PackedStringArray(["7g7f", "3c3d"]))
	expect(engine.configure(2, 16), "configure 2 threads, 16 MB")
	var legal_now := engine.legal_moves()

	for level in [[1, 0, -15, "Iniciante (depth 1, skill -15)"], [3, 0, 10, "Médio (depth 3, skill 10)"],
			[0, 1000, 20, "Difícil (1 s, skill 20)"]]:
		var t := Time.get_ticks_msec()
		expect(engine.start_search(level[0], level[1], level[2]), "start_search " + level[3])
		expect(not engine.start_search(1, 0, 20), "a second search is refused while one runs")
		var move: String = await engine.best_move
		var ms := Time.get_ticks_msec() - t
		print("  %s -> %s in %d ms" % [level[3], move, ms])
		expect(legal_now.has(move), "AI move is legal: " + move)
		if level[1] > 0:
			expect(ms < level[1] + 500, "movetime respected (%d ms)" % ms)

	# stop() ends a long search early with the best move so far.
	var t := Time.get_ticks_msec()
	engine.start_search(0, 30000, 20)
	await create_timer(0.3).timeout
	engine.stop()
	var move: String = await engine.best_move
	var ms := Time.get_ticks_msec() - t
	print("  stop() after 300 ms -> %s in %d ms" % [move, ms])
	expect(legal_now.has(move) and ms < 2000, "stop() returns a legal move quickly")

	# Mated side: no move.
	var mated := game("4k4/4G4/4P4/9/9/9/9/9/4K4 w - 1")
	mated.start_search(1, 0, 20)
	expect_eq(await mated.best_move, "", "no move when mated")
	# The search must not touch the game position.
	expect_eq(engine.get_sfen(), game(START, PackedStringArray(["7g7f", "3c3d"])).get_sfen(), "search leaves the game alone")
