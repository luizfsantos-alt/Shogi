class_name Coach
extends RefCounted
## Short explanations that help a beginner: how to get out of check, what a move does
## (port of src/core/coach.ts). Squares are Vector2i(col, row).


## Ways out of the current check, grouped the way a teacher would explain them:
## {king, attackers, king_moves, captures, blocks}; {} when not in check.
static func check_help(rules: GameRules) -> Dictionary:
	if not rules.is_check():
		return {}
	var position := rules.position()
	var side := rules.side_to_move()
	var king := GameRules.find_king(position, side)
	var attackers := Attacks.attackers_of(position, king, GameRules.opposite(side))
	var help := {"king": king, "attackers": attackers, "king_moves": PackedStringArray(), "captures": PackedStringArray(), "blocks": PackedStringArray()}
	for move in rules.legal_moves():
		var parsed := GameRules.parse_move(move)
		if parsed.from != null and parsed.from == king:
			help.king_moves.append(move)
		elif attackers.has(parsed.to):
			help.captures.append(move)
		else:
			help.blocks.append(move)
	return help


static func describe_check_help(help: Dictionary, rules: GameRules) -> String:
	var position := rules.position()
	var names := PackedStringArray()
	for square in help.attackers:
		names.append(Pieces.with_article(GameRules.piece_at(position, square)))
	var who := " e ".join(names)
	var ways := PackedStringArray()
	if not help.king_moves.is_empty():
		ways.append("mover o rei para uma casa segura")
	if not help.captures.is_empty():
		ways.append("capturar %s" % ("uma das peças que atacam" if help.attackers.size() > 1 else who))
	if not help.blocks.is_empty():
		ways.append("colocar uma peça no caminho (do tabuleiro ou da mão)")
	return "Seu rei está em xeque! Quem ataca: %s. Para sair: %s." % [who, "; ou ".join(ways)]


## Plain-language facts about a legal move, e.g. ["captura a Torre", "dá xeque"].
## Plays the move on the rules and takes it back.
static func describe_move(rules: GameRules, move: String) -> PackedStringArray:
	var facts := PackedStringArray()
	var parsed := GameRules.parse_move(move)
	if parsed.is_empty() or not rules.is_legal(move):
		return facts
	var position := rules.position()
	var side := rules.side_to_move()
	var was_in_check := rules.is_check()

	if parsed.drop != "":
		facts.append("coloca %s da mão no tabuleiro" % Pieces.with_article(Pieces.make(side, parsed.drop)))
	else:
		var moving: Dictionary = GameRules.piece_at(position, parsed.from)
		var captured = GameRules.piece_at(position, parsed.to)
		if captured != null:
			facts.append("captura %s (a peça vai para a sua mão)" % Pieces.with_article(captured))
		if parsed.promote:
			facts.append("promove %s" % Pieces.with_article(moving))
		var threatened := not Attacks.attackers_of(position, parsed.from, GameRules.opposite(side)).is_empty()
		if not was_in_check and captured == null and threatened and moving.type != "P":
			facts.append("tira %s de um ataque" % Pieces.with_article(moving))
	if was_in_check:
		facts.append("tira o seu rei do xeque")

	rules.play(move)
	var result := rules.result()
	if result.over and result.reason == "checkmate":
		facts.append("dá xeque-mate!")
	elif rules.is_check():
		facts.append("dá xeque")
	rules.undo()
	return facts
