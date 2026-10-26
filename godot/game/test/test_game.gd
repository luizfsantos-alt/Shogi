extends SceneTree
## Headless tests for the GDScript rules layer (godot/game).
##   godot --headless --path godot -s res://game/test/test_game.gd
## Cases mirror tests/rules.test.ts, explain.test.ts, kifu.test.ts, interaction.test.ts and
## session.test.ts of the PWA (same SFENs, same expected moves, codes and messages).

const START := GameRules.START_SFEN

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := Time.get_ticks_msec()
	test_squares_and_moves()
	test_rules()
	test_impasse()
	test_interaction()
	test_kifu()
	test_explain()
	test_explain_random_games()
	test_coach()
	test_levels()
	await test_session()
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


func game(sfen := "", moves := PackedStringArray()) -> GameRules:
	var rules := GameRules.new()
	expect(rules.load_position(sfen, moves), "load_position(%s)" % sfen)
	return rules


func sorted(list) -> Array:
	var a := Array(list)
	a.sort()
	return a


func sq(name: String) -> Vector2i:
	return GameRules.parse_square(name)


func perft(rules: GameRules, depth: int) -> int:
	if depth == 0:
		return 1
	var nodes := 0
	for move in rules.legal_moves():
		rules.play(move)
		nodes += perft(rules, depth - 1)
		rules.undo()
	return nodes


# ---------------------------------------------------------------- tests

func test_squares_and_moves() -> void:
	expect_eq(sq("9a"), Vector2i(0, 0), "9a is the top-left (Sente's view)")
	expect_eq(sq("1i"), Vector2i(8, 8), "1i is the bottom-right")
	expect_eq(sq("7g"), Vector2i(2, 6), "7g")
	expect_eq(GameRules.square_name(Vector2i(2, 6)), "7g", "square_name")
	expect_eq(sq("0a"), Vector2i(-1, -1), "invalid square")
	expect_eq(GameRules.parse_move("8h2b+"), {"from": sq("8h"), "to": sq("2b"), "drop": "", "promote": true}, "parse board move")
	expect_eq(GameRules.parse_move("P*5e"), {"from": null, "to": sq("5e"), "drop": "P", "promote": false}, "parse drop")
	expect(GameRules.parse_move("banana").is_empty(), "parse garbage")
	var position := GameRules.parse_sfen("lnsgkgsnl/1r5+B1/pppppp1pp/6p2/9/2P6/PP1PPPPPP/7R1/LNSGKGSNL w B10p 4")
	expect_eq(GameRules.piece_at(position, sq("2b")), {"color": "black", "type": "B", "promoted": true}, "promoted bishop on 2b")
	expect_eq(GameRules.piece_at(position, sq("5a")), {"color": "white", "type": "K", "promoted": false}, "Gote king on 5a")
	expect_eq(position.hands, {"black": {"B": 1}, "white": {"P": 10}}, "hands")
	expect_eq(position.side, "white", "side")
	expect_eq(position.move_number, 4, "move number")


func test_rules() -> void:
	var rules := game()
	expect_eq(rules.sfen(), START, "start SFEN")
	expect_eq([perft(rules, 1), perft(rules, 2), perft(rules, 3)], [30, 900, 25470], "perft 1-3 through GameRules")

	const UCHIFUZUME := "7lk/9/7G1/9/9/9/9/9/4K4 b P 1"
	rules = game(UCHIFUZUME)
	expect(rules.engine.is_legal("P*1b") and not rules.is_legal("P*1b"), "uchifuzume filtered out")
	expect(not rules.play("P*1b"), "uchifuzume cannot be played")
	expect(game("8k/9/7G1/9/9/9/9/9/4K4 b P 1").is_legal("P*1b"), "pawn drop check that is not mate")

	rules = game(START, PackedStringArray(["7g7f"]))
	expect(not rules.load_position(START, PackedStringArray(["7g7f", "7f7e"])), "illegal imported line")
	expect(rules.last_error != "", "last_error is set")
	expect_eq(Array(rules.history()), ["7g7f"], "state kept after a rejected line")
	expect(not rules.load_position("4r4/9/9/9/9/9/9/9/k3K4 w - 1"), "side that just moved is in check")

	rules = game(START, PackedStringArray(["7g7f", "3c3d", "8h2b+"]))
	expect_eq(rules.hand("black"), {"B": 1}, "hand after capture")
	expect_eq(rules.piece_on(sq("2b")), {"color": "black", "type": "B", "promoted": true}, "piece_on")

	rules = game(START, PackedStringArray(["7g7f"]))
	expect(rules.resign("white"), "resign")
	expect_eq(rules.result(), {"over": true, "winner": "black", "reason": "resignation"}, "resignation result")
	expect(rules.legal_moves().is_empty(), "no moves after resignation")
	expect_eq(rules.undo(), "", "first undo cancels the resignation")
	expect_eq(rules.result(), {"over": false}, "game goes on")
	expect_eq(Array(rules.history()), ["7g7f"], "history kept")

	rules = game()
	var cycle := ["2h3h", "8b7b", "3h2h", "7b8b"]
	for i in 4:
		for m in cycle:
			rules.play(m)
	expect_eq(rules.result(), {"over": true, "winner": "draw", "reason": "repetition"}, "sennichite")
	expect(rules.legal_moves().is_empty(), "no moves after sennichite")


func test_impasse() -> void:
	var black_camp := func(hand: String) -> String: return "RBGGGG3/SSSSK4/9/9/9/9/9/9/8k b %s 1" % hand
	var rules := game(black_camp.call("10P"))
	var eval := rules.impasse()
	expect(eval.can_declare and eval.points == 28 and eval.required_points == 28 and eval.pieces_in_zone == 10, "Sente declares with 28 points: %s" % eval)
	expect(rules.declare_impasse(), "declare")
	expect_eq(rules.result(), {"over": true, "winner": "black", "reason": "impasse"}, "impasse result")

	rules = game(black_camp.call("9P"))
	expect(not rules.impasse().can_declare and rules.impasse().points == 27, "Sente cannot declare with 27")
	expect(not rules.declare_impasse(), "declare refused")
	eval = game("8K/9/9/9/9/9/9/4kssss/3ggggbr w 9p 1").impasse()
	expect(eval.can_declare and eval.points == 27 and eval.required_points == 27 and eval.pieces_in_zone == 10, "Gote needs 27: %s" % eval)
	eval = game("RBGGGG3/SSS1K4/9/9/9/9/9/9/8k b S10P 1").impasse()
	expect(not eval.can_declare and eval.pieces_in_zone == 9 and eval.points == 28, "needs 10 pieces in the camp")
	expect(game("RBGGGG3/SSSS5/4K4/9/9/9/9/9/8k b 10P 1").impasse().can_declare, "king on the camp's last row")
	eval = game("RBGGGG3/SSSS5/9/4K4/9/9/9/9/8k b 10P 1").impasse()
	expect(not eval.can_declare and not eval.king_in_zone, "king outside the camp")
	eval = game("RBGGGG3/SSSSK4/9/9/9/9/9/9/4r3k b 10P 1").impasse()
	expect(not eval.can_declare and eval.in_check, "not while in check")
	eval = game("+R+BGGGG3/SSSSK4/9/9/9/9/9/9/8k b 10P 1").impasse()
	expect(eval.can_declare and eval.points == 28, "promoted rook/bishop count 5")


func test_interaction() -> void:
	var rules := game()
	expect_eq(sorted(rules.moves_from(sq("7g"))), ["7g7f"], "moves_from 7g")
	expect_eq(rules.targets_for({"kind": "board", "square": sq("2h")}).size(), 6, "rook targets")
	expect_eq(rules.choose_move({"kind": "board", "square": sq("7g")}, sq("7f")), {"kind": "move", "move": "7g7f"}, "choose a move")
	expect_eq(rules.choose_move({"kind": "board", "square": sq("7g")}, sq("7e")), {"kind": "none"}, "nothing there")
	rules = game(START, PackedStringArray(["7g7f", "3c3d"]))
	expect_eq(rules.choose_move({"kind": "board", "square": sq("8h")}, sq("2b")), {"kind": "promotion", "promote": "8h2b+", "stay": "8h2b"}, "optional promotion")
	expect_eq(rules.promotion_status(sq("8h"), sq("2b")), "optional", "promotion_status optional")
	expect_eq(rules.promotion_status(sq("7f"), sq("7e")), "none", "promotion_status none")
	expect_eq(rules.promotion_status(sq("7f"), sq("7d")), "illegal", "promotion_status illegal")
	expect_eq(game("k8/4P4/9/9/9/9/9/9/4K4 b - 1").promotion_status(sq("5b"), sq("5a")), "mandatory", "promotion_status mandatory")
	rules = game("4k4/9/9/9/9/9/9/9/4K4 b G 1")
	expect_eq(rules.targets_for({"kind": "hand", "type": "G"}).size(), 79, "drop targets")
	expect_eq(rules.choose_move({"kind": "hand", "type": "G"}, sq("5e")), {"kind": "move", "move": "G*5e"}, "choose a drop")


func test_kifu() -> void:
	var notate := func(sfen: String, moves: Array, move: String) -> String:
		var rules := game(sfen, PackedStringArray(moves))
		return Kifu.format_western(rules.position(), rules.legal_moves(), move)
	expect_eq(notate.call("", [], "7g7f"), "P-7f", "simple move")
	expect_eq(notate.call("", ["7g7f", "3c3d"], "8h2b+"), "Bx2b+", "capture with promotion")
	expect_eq(notate.call("", ["7g7f", "3c3d"], "8h2b"), "Bx2b=", "declined promotion")
	expect_eq(notate.call("4k4/9/9/9/9/9/9/9/4K4 b P 1", [], "P*5e"), "P*5e", "drop")
	expect_eq(notate.call("", [], "6i5h"), "G6i-5h", "ambiguous origin")
	expect_eq(notate.call("", [], "6i7h"), "G-7h", "unambiguous")
	expect_eq(notate.call("8k/9/9/9/9/9/9/4+R4/K8 b - 1", [], "5h5g"), "+R-5g", "promoted piece")


func test_explain() -> void:
	var cases := [
		["nifu", "4k4/9/9/9/9/9/4P4/9/4K4 b P 1", "P*5e"],
		["uchifuzume", "7lk/9/7G1/9/9/9/9/9/4K4 b P 1", "P*1b"],
		["dead-piece", "4k4/9/9/9/9/9/9/9/4K4 b PN 1", "P*1a"],
		["dead-piece", "4k4/9/9/9/9/9/9/9/4K4 b PN 1", "N*1b"],
		["drop-on-occupied", "4k4/9/9/9/9/9/9/9/4K4 b P 1", "P*5a"],
		["not-in-hand", "4k4/9/9/9/9/9/9/9/4K4 b P 1", "G*5e"],
		["must-promote", "k8/4P4/9/9/9/9/9/9/4K4 b - 1", "5b5a"],
		["must-promote", "k8/9/9/4N4/9/9/9/9/4K4 b - 1", "5d4b"],
		["cannot-promote", "k8/4G4/9/9/9/9/9/9/4K4 b - 1", "5b5a+"],
		["promotion-outside-zone", "", "7g7f+"],
		["pinned", "k3r4/9/9/9/9/9/9/4S4/4K4 b - 1", "5h4g"],
		["still-in-check", "4k4/9/9/9/9/9/9/8G/r3K4 b - 1", "1h1g"],
		["king-into-check", "4k4/9/9/9/9/9/9/8G/r3K4 b - 1", "5i4i"],
		["cannot-move-like-that", "", "7g7e"],
		["path-blocked", "", "8h6f"],
		["path-blocked", "", "2h2b"],
		["own-piece-on-target", "", "9i9g"],
		["not-your-piece", "", "3c3d"],
		["legal", "", "7g7f"],
	]
	for c in cases:
		expect_eq(Explain.explain_move(game(c[1]), c[2]).code, c[0], "explain %s %s" % [c[1], c[2]])

	var rules := game("k8/4P4/9/9/9/9/9/9/4K4 b - 1")
	expect_eq(Explain.explain_board_move(rules, sq("5b"), sq("5a")).code, "legal", "board tap ignores the promotion suffix")
	expect_eq(Explain.explain_board_move(rules, sq("5b"), sq("4a")).code, "cannot-move-like-that", "board tap")

	rules = game("4k4/9/9/9/9/9/4P4/9/4K4 b P 1")
	expect(Explain.explain_text(rules, "P*5e").begins_with("Nifu (二歩): você já tem um peão"), "nifu message")
	rules = game("7lk/9/7G1/9/9/9/9/9/4K4 b P 1")
	expect(Explain.explain_text(rules, "P*1b").begins_with("Uchifuzume"), "uchifuzume message")
	rules = game("4k4/9/9/9/9/9/9/8G/r3K4 b - 1")
	expect_eq(Explain.explain_text(rules, "5i4i"), "O rei não pode ir para uma casa atacada (Torre em 9i).", "king-into-check message")
	expect_eq(Explain.explain_text(game("4k4/9/9/9/9/9/9/9/4K4 b PN 1"), "N*1b"),
		"Essa peça ficaria sem jogadas: não dá para colocar o Cavalo nas duas últimas fileiras.", "dead-piece message")


## Every illegal move gets a specific explanation, in positions from random games.
func test_explain_random_games() -> void:
	var seed := 12345
	var random := func() -> float:
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648.0
	var rules := GameRules.new()
	var unexplained := []
	var explained := 0
	for game_index in 6:
		rules.load_position()
		for ply in 80:
			if rules.result().over:
				break
			if ply % 8 == 7:
				var position := rules.position()
				var side := rules.side_to_move()
				for row in 9:
					for col in 9:
						var piece = position.board[row][col]
						if piece == null or piece.color != side:
							continue
						for to_row in 9:
							for to_col in 9:
								explained += 1
								if Explain.explain_board_move(rules, Vector2i(col, row), Vector2i(to_col, to_row)).code == "unknown":
									unexplained.append("%s %d,%d->%d,%d" % [rules.sfen(), col, row, to_col, to_row])
				for type in position.hands[side]:
					for row in 9:
						for col in 9:
							var move := GameRules.drop_move(type, Vector2i(col, row))
							if rules.is_legal(move):
								continue
							explained += 1
							if Explain.explain_move(rules, move).code == "unknown":
								unexplained.append("%s %s" % [rules.sfen(), move])
			var legal := rules.legal_moves()
			# Prefer captures so that hands fill up and drops get exercised.
			var captures := []
			for m in legal:
				if m[1] != "*" and rules.piece_on(GameRules.parse_move(m).to) != null:
					captures.append(m)
			var pool: Array = captures if captures.size() > 0 and random.call() < 0.7 else Array(legal)
			rules.play(pool[int(random.call() * pool.size())])
	print("  %d random moves explained" % explained)
	expect_eq(unexplained.slice(0, 10), [], "every illegal move is explained")


func test_coach() -> void:
	# Sente king 5i checked by the rook on 9i; the gold on 6h can block on 6i, a bishop can be dropped.
	var rules := game("4k4/9/9/9/9/9/9/3G5/r3K4 b B 1")
	var help := Coach.check_help(rules)
	expect_eq(help.attackers, [sq("9i")], "attackers")
	expect(help.king_moves.size() > 0, "king moves")
	expect(help.blocks.has("6h6i") and help.blocks.has("B*7i"), "blocks")
	expect(Coach.describe_check_help(help, rules).begins_with("Seu rei está em xeque! Quem ataca: a Torre. Para sair: mover o rei"), "check help text")
	expect(Coach.check_help(game()).is_empty(), "no help when not in check")

	rules = game(START, PackedStringArray(["7g7f", "3c3d"]))
	expect_eq(Array(Coach.describe_move(rules, "8h2b+")), ["captura o Bispo (a peça vai para a sua mão)", "promove o Bispo"], "describe capture")
	expect_eq(Array(rules.history()), ["7g7f", "3c3d"], "rules restored")
	rules = game("4k4/9/4P4/9/9/9/9/9/4K4 b G 1")
	expect_eq(Array(Coach.describe_move(rules, "G*5b")), ["coloca o General de Ouro da mão no tabuleiro", "dá xeque-mate!"], "describe mate")


func test_levels() -> void:
	expect_eq(Levels.LEVELS.size(), 5, "5 levels")
	expect_eq(Levels.get_level(4).movetime_ms, 1000, "Difícil thinks 1 s")
	expect_eq(Levels.get_level(99).id, 1, "unknown level -> Iniciante")


# ---------------------------------------------------------------- session

func settled(s: GameSession) -> void:
	while s.thinking:
		await process_frame


func new_session() -> GameSession:
	var s := GameSession.new()
	s.min_think_ms = 0
	root.add_child(s)
	return s


func test_session() -> void:
	var events := []
	var s := new_session()
	s.move_played.connect(func(move, info): events.append([move, info.notation, info.by_computer]))

	# The computer answers the player's move.
	s.new_game({"mode": "ai", "human_color": "black", "level": 1})
	expect(s.play("7g7f"), "play")
	expect(s.thinking and not s.can_human_move(), "computer thinking")
	await settled(s)
	expect_eq(s.rules.history().size(), 2, "computer replied")
	expect_eq(s.notations[0], "P-7f", "notation")
	expect(s.can_human_move(), "player's turn again")
	expect_eq(events.size(), 2, "move_played twice")
	expect(events.size() == 2 and not events[0][2] and events[1][2], "by_computer flags")
	expect(not s.play("5a4b"), "illegal or not my piece")

	# Undo takes back the computer's reply and the player's move.
	s.play("2g2f")
	await settled(s)
	s.undo()
	expect_eq(s.rules.history().size(), 2, "undo pair")
	expect_eq(s.notations.size(), 2, "notations follow undo")
	expect(s.can_human_move(), "player's turn after undo")

	# The computer opens when the player is Gote.
	s.new_game({"mode": "ai", "human_color": "white", "level": 1})
	await settled(s)
	expect_eq(s.rules.history().size(), 1, "computer opened")
	expect_eq(s.rules.side_to_move(), "white", "player's turn as Gote")

	# Undo while the computer is thinking cancels the search.
	s.new_game({"mode": "ai", "human_color": "black", "level": 5})
	s.play("7g7f")
	s.undo()
	await settled(s)
	await create_timer(0.2).timeout
	expect_eq(Array(s.rules.history()), [], "search cancelled by undo")
	expect(not s.thinking, "not thinking")

	# Resignation is saved and restored, and can be undone.
	s.new_game({"mode": "ai", "human_color": "black", "level": 1})
	s.play("7g7f")
	await settled(s)
	var over := []
	s.game_over.connect(func(result): over.append(result))
	s.resign()
	expect_eq(over, [{"over": true, "winner": "white", "reason": "resignation"}], "game_over on resignation")
	var saved := s.to_saved()
	expect_eq(saved.resigned, "black", "saved resignation")
	expect(s.save_game("user://test_partida.json"), "save_game")
	var other := new_session()
	expect(other.load_game("user://test_partida.json"), "load_game")
	expect_eq(other.rules.result(), {"over": true, "winner": "white", "reason": "resignation"}, "restored result")
	expect_eq(other.notations, s.notations, "restored notations")
	other.undo()
	expect_eq(other.rules.result(), {"over": false}, "resignation undone")
	expect_eq(other.rules.history().size(), 2, "moves kept")
	expect(not other.restore({"initial_sfen": START, "moves": ["7g7f", "7f7e"]}), "invalid record refused")
	expect_eq(other.rules.history().size(), 2, "game intact after a refused record")
	other.queue_free()

	# Two players on one device.
	s.new_game({"mode": "local", "human_color": "black", "level": 1})
	s.play("7g7f")
	s.play("3c3d")
	expect(not s.thinking, "no computer in local games")
	s.undo()
	expect_eq(Array(s.rules.history()), ["7g7f"], "local undo is one move")
	s.resign()
	expect_eq(s.rules.result(), {"over": true, "winner": "black", "reason": "resignation"}, "side to move resigns")

	# Hint: a legal move with an explanation, forgotten after a move.
	s.restore({"initial_sfen": "4k4/9/4P4/9/9/9/9/9/4K4 b G 1", "moves": [], "settings": {"mode": "local", "human_color": "black", "level": 1}})
	s.request_hint()
	expect(s.hint_pending, "hint pending")
	while s.hint_pending:
		await process_frame
	expect_eq(s.hint.get("move"), "G*5b", "hint move")
	expect(s.hint.get("facts", PackedStringArray()).has("dá xeque-mate!"), "hint facts")
	expect_eq(s.hint.get("notation"), "G*5b", "hint notation")
	s.play("5i4h")
	expect(s.hint.is_empty(), "hint forgotten")

	# Check help for the mentor.
	s.restore({"initial_sfen": "4k4/9/9/9/9/9/9/3G5/r3K4 b B 1", "moves": [], "settings": {"mode": "local"}})
	expect(s.check_help_text().begins_with("Seu rei está em xeque!"), "check help text")

	# Handicap: the computer plays Gote without the rook and moves first.
	s.new_game({"mode": "ai", "human_color": "white", "level": 1, "handicap": "rook"})
	expect_eq(s.settings.human_color, "black", "person plays Sente with a handicap")
	expect_eq(s.rules.initial_sfen(), "lnsgkgsnl/7b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL w - 1", "handicap start")
	await settled(s)
	expect_eq(s.rules.history().size(), 1, "computer moved first")
	expect(s.can_human_move(), "then the person")

	# The computer declares impasse when it can.
	s.restore({"initial_sfen": "8K/9/9/9/9/9/9/4kssss/3ggggbr w 9p 1", "moves": [], "settings": {"mode": "ai", "human_color": "black", "level": 1}})
	expect_eq(s.rules.result(), {"over": true, "winner": "white", "reason": "impasse"}, "computer declared impasse")

	# A full game between the computer and itself ends with a result (levels 1 vs 1, max 400 plies).
	s.new_game({"mode": "local"})
	var plies := 0
	while not s.rules.result().over and plies < 400:
		var move := await s._search(Levels.get_level(1))
		expect(s.rules.is_legal(move), "self-play move %s is legal" % move)
		s.rules.play(move)
		plies += 1
	print("  self-play: %d plies, result %s" % [plies, s.rules.result()])
	s.queue_free()
