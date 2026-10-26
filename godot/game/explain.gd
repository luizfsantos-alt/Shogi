class_name Explain
extends RefCounted
## Explains WHY a move is illegal (port of src/core/explain.ts). Fairy-Stockfish only tells us
## "not in the legal move list", so the rules are re-checked here one by one, in the order a
## player would think about them.
##
## A reason is a Dictionary {code: String, ...}: "legal", "game-over", "no-piece",
## "not-your-piece" (piece), "not-in-hand" (type), "same-square", "own-piece-on-target" (piece),
## "drop-on-occupied", "cannot-move-like-that" (piece), "path-blocked" (piece),
## "dead-piece" (type, drop), "must-promote" (type), "cannot-promote" (piece),
## "promotion-outside-zone", "nifu" (file), "uchifuzume", "king-into-check" (attackers),
## "still-in-check" (attackers), "pinned" (attackers), "unknown". Squares are Vector2i(col, row).


static func explain_move(rules: GameRules, move: String) -> Dictionary:
	if rules.result().over:
		return {"code": "game-over"}
	if rules.is_legal(move):
		return {"code": "legal"}
	var parsed := GameRules.parse_move(move)
	if parsed.is_empty():
		return {"code": "unknown"}
	var position := rules.position()
	var side := rules.side_to_move()
	var problem := _drop_problem(position, parsed, side) if parsed.drop != "" else _board_move_problem(position, parsed, side)
	if not problem.is_empty():
		return problem
	problem = _king_safety_problem(position, parsed, side)
	return problem if not problem.is_empty() else _uchifuzume_problem(position, parsed, side)


## Explanation for a board move from `from` to `to`, trying the non-promoting move first.
static func explain_board_move(rules: GameRules, from: Vector2i, to: Vector2i) -> Dictionary:
	var plain := GameRules.board_move(from, to)
	if rules.is_legal(plain) or rules.is_legal(plain + "+"):
		return {"code": "legal"}
	return explain_move(rules, plain)


## Explanation for a move, as a Portuguese sentence (what the mentor says).
static func explain_text(rules: GameRules, move: String) -> String:
	return describe_illegal(explain_move(rules, move), rules.position())


static func _drop_problem(position: Dictionary, move: Dictionary, side: String) -> Dictionary:
	var type: String = move.drop
	var to: Vector2i = move.to
	if position.hands[side].get(type, 0) == 0:
		return {"code": "not-in-hand", "type": type}
	if GameRules.piece_at(position, to) != null:
		return {"code": "drop-on-occupied"}
	if Attacks.distance_to_last_rank(to, side) < GameRules.IMMOBILE_RANKS.get(type, 0):
		return {"code": "dead-piece", "type": type, "drop": true}
	if type == "P":
		for row in GameRules.RANKS:
			var piece = position.board[row][to.x]
			if piece != null and piece.type == "P" and not piece.promoted and piece.color == side:
				return {"code": "nifu", "file": GameRules.FILES - to.x}
	return {}


static func _board_move_problem(position: Dictionary, move: Dictionary, side: String) -> Dictionary:
	var from: Vector2i = move.from
	var to: Vector2i = move.to
	var piece = GameRules.piece_at(position, from)
	if piece == null:
		return {"code": "no-piece"}
	if piece.color != side:
		return {"code": "not-your-piece", "piece": piece}
	if from == to:
		return {"code": "same-square"}
	var target = GameRules.piece_at(position, to)
	if target != null and target.color == side:
		return {"code": "own-piece-on-target", "piece": target}
	var path := Attacks.reach(position, from, piece, to)
	if path == "never":
		return {"code": "cannot-move-like-that", "piece": piece}
	if path == "blocked":
		return {"code": "path-blocked", "piece": piece}
	if move.promote:
		if piece.promoted or not piece.type in GameRules.PROMOTABLE:
			return {"code": "cannot-promote", "piece": piece}
		if not Attacks.in_promotion_zone(from, side) and not Attacks.in_promotion_zone(to, side):
			return {"code": "promotion-outside-zone"}
	elif not piece.promoted and Attacks.distance_to_last_rank(to, side) < GameRules.IMMOBILE_RANKS.get(piece.type, 0):
		return {"code": "must-promote", "type": piece.type}
	return {}


## Plays a move on a copy of the position (no legality checks).
static func apply_move(position: Dictionary, move: Dictionary, side: String) -> Dictionary:
	var next := position.duplicate(true)
	var to: Vector2i = move.to
	if move.drop != "":
		var hand: Dictionary = next.hands[side]
		hand[move.drop] -= 1
		if hand[move.drop] == 0:
			hand.erase(move.drop)
		next.board[to.y][to.x] = Pieces.make(side, move.drop)
	else:
		var from: Vector2i = move.from
		var moving: Dictionary = next.board[from.y][from.x]
		var captured = next.board[to.y][to.x]
		if captured != null:
			next.hands[side][captured.type] = next.hands[side].get(captured.type, 0) + 1
		next.board[from.y][from.x] = null
		next.board[to.y][to.x] = Pieces.make(moving.color, moving.type, moving.promoted or move.promote)
	next.side = GameRules.opposite(side)
	next.move_number += 1
	return next


static func _king_safety_problem(position: Dictionary, move: Dictionary, side: String) -> Dictionary:
	var after := apply_move(position, move, side)
	var king := GameRules.find_king(after, side)
	if king.x < 0:
		return {}
	var attackers := Attacks.attackers_of(after, king, GameRules.opposite(side))
	if attackers.is_empty():
		return {}
	var king_before := GameRules.find_king(position, side)
	var was_in_check := not Attacks.attackers_of(position, king_before, GameRules.opposite(side)).is_empty()
	var mover = GameRules.piece_at(position, move.from) if move.from != null else null
	if mover != null and mover.type == "K":
		return {"code": "king-into-check", "attackers": attackers}
	if was_in_check:
		return {"code": "still-in-check", "attackers": attackers}
	return {"code": "pinned", "attackers": attackers}


static func _uchifuzume_problem(position: Dictionary, move: Dictionary, side: String) -> Dictionary:
	if move.drop != "P":
		return {"code": "unknown"}
	var enemy_king := GameRules.find_king(position, GameRules.opposite(side))
	var forward := -1 if side == "black" else 1
	var gives_check: bool = enemy_king == move.to + Vector2i(0, forward)
	# Every other rule passed, so the only remaining reason for a checking pawn drop is uchifuzume.
	return {"code": "uchifuzume"} if gives_check else {"code": "unknown"}


# ---------------------------------------------------------------- messages

static func _squares(list: Array, position: Dictionary) -> String:
	var parts := PackedStringArray()
	for square in list:
		parts.append("%s em %s" % [Pieces.name_pt(GameRules.piece_at(position, square)), GameRules.square_name(square)])
	return ", ".join(parts)


## Clear Portuguese message for a reason; `position` is the position before the move.
static func describe_illegal(reason: Dictionary, position: Dictionary) -> String:
	match reason.code:
		"legal":
			return "A jogada é legal."
		"game-over":
			return "A partida já terminou."
		"no-piece":
			return "Não há peça nessa casa."
		"not-your-piece":
			return "Essa peça (%s) é do adversário." % Pieces.name_pt(reason.piece)
		"not-in-hand":
			return "Você não tem %s na mão." % Pieces.name_pt(Pieces.make("black", reason.type))
		"same-square":
			return "A peça já está nessa casa."
		"own-piece-on-target":
			return "Essa casa já tem uma peça sua (%s). Não dá para capturar a própria peça." % Pieces.name_pt(reason.piece)
		"drop-on-occupied":
			return "Peças da mão só podem ser colocadas em casas vazias."
		"cannot-move-like-that":
			return "%s não anda assim. %s" % [Pieces.name_pt(reason.piece), Pieces.info(reason.piece).move_pt]
		"path-blocked":
			return "Há uma peça no caminho: %s não pode pular peças." % Pieces.name_pt(reason.piece)
		"dead-piece":
			if reason.drop:
				return "Essa peça ficaria sem jogadas: não dá para colocar %s %s." % [
					Pieces.with_article(Pieces.make("black", reason.type)),
					"nas duas últimas fileiras" if reason.type == "N" else "na última fileira"]
			return "Essa peça ficaria sem jogadas."
		"must-promote":
			return "Você precisa promover: %s ficaria sem jogadas nessa casa, então a promoção é obrigatória." % Pieces.name_pt(Pieces.make("black", reason.type))
		"cannot-promote":
			return "Essa peça já está promovida." if reason.piece.promoted else "%s não pode ser promovido." % Pieces.name_pt(reason.piece)
		"promotion-outside-zone":
			return "Só dá para promover quando a peça entra, sai ou se move dentro das %d últimas fileiras (o campo do adversário)." % GameRules.PROMOTION_ZONE_RANKS
		"nifu":
			return "Nifu (二歩): você já tem um peão (não promovido) na coluna %d. Não pode haver dois peões seus na mesma coluna." % reason.file
		"uchifuzume":
			return "Uchifuzume (打ち歩詰め): esse peão colocado da mão daria xeque-mate, e isso é proibido. (Dar mate movendo um peão do tabuleiro é permitido.)"
		"king-into-check":
			# The attackers are still on the board before the move (the king cannot have captured them).
			return "O rei não pode ir para uma casa atacada (%s)." % _squares(reason.attackers, position)
		"still-in-check":
			return "Seu rei está em xeque e essa jogada não resolve o xeque."
		"pinned":
			return "Isso deixaria seu rei em xeque: essa peça está cravada, protegendo o rei de um ataque."
	return "Jogada ilegal."
