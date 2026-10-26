class_name CoachTips
extends RefCounted
## The coach of the guided game (port of src/learn/coachTips.ts): short tips at the moments a
## beginner needs them (the first move, a chance to promote, a fork on the board…). Each tip
## shows once per game. A tip is {id, title, text, squares: Array[Vector2i]}.

## Rough piece values for a beginner (the table taught in the "values" lesson).
const VALUE := {"P": 1, "L": 3, "N": 4, "S": 5, "G": 6, "B": 8, "R": 10, "K": 100}
const PROMOTED_VALUE := {"P": 6, "L": 6, "N": 6, "S": 6, "B": 10, "R": 12}


static func piece_value(piece: Dictionary) -> int:
	return (PROMOTED_VALUE if piece.get("promoted", false) else VALUE).get(piece.type, 1)


## The tip to show now, for the player `human` whose turn it is; {} when nothing new is worth saying.
static func coach_tip(rules: GameRules, human: String, seen: Dictionary) -> Dictionary:
	if rules.result().over or rules.side_to_move() != human:
		return {}
	for finder in [_check_tip, _fork_tip, _hanging_tip, _opening_tip, _hand_tip, _promotion_tip, _sitting_king_tip]:
		var tip: Dictionary = finder.call(rules, human)
		if not tip.is_empty() and not seen.has(tip.id):
			return tip
	return {}


static func _tip(id: String, title: String, text: String, squares: Array[Vector2i] = []) -> Dictionary:
	return {"id": id, "title": title, "text": text, "squares": squares}


static func _check_tip(rules: GameRules, _human: String) -> Dictionary:
	if not rules.is_check():
		return {}
	return _tip("check", "Xeque! (王手, ōte)", "Seu Rei está atacado. Lembre as três saídas: fugir com o Rei, capturar a peça que ataca ou colocar uma peça no caminho (合駒, aigoma). As peças que atacam estão marcadas.")


static func _opening_tip(rules: GameRules, human: String) -> Dictionary:
	if rules.history().size() > 1:
		return {}
	if human == "black":
		return _tip("opening", "Primeiro lance", "Comece abrindo a diagonal do Bispo (Peão 7g→7f) ou avançando o Peão da Torre (2g→2f). Depois tire o Rei do centro e monte um castelo (囲い, kakoi).",
			[GameRules.parse_square("7g"), GameRules.parse_square("2g")])
	return _tip("opening", "Primeiro lance", "Você é Gote: abra a diagonal do Bispo (Peão 3c→3d) ou avance o Peão da Torre (8c→8d). Depois tire o Rei do centro e monte um castelo (囲い, kakoi).",
		[GameRules.parse_square("3c"), GameRules.parse_square("8c")])


static func _hand_tip(rules: GameRules, human: String) -> Dictionary:
	var hand := rules.hand(human)
	for type: String in GameRules.HAND_TYPES:
		if int(hand.get(type, 0)) > 0:
			var piece := Pieces.with_article(Pieces.make(human, type))
			return _tip("hand", "Uma peça na mão (持ち駒, mochigoma)", "Você tem %s na mão. Em vez de mover, você pode colocá-la (打つ, utsu) em qualquer casa vazia: toque nela e depois na casa. Guarde-a para um ataque duplo ou para defender." % piece)
	return {}


## A promotion on a square the opponent does not attack (promoting into a recapture is no tip).
static func _promotion_tip(rules: GameRules, human: String) -> Dictionary:
	var position := rules.position()
	for move in rules.legal_moves():
		if not move.ends_with("+"):
			continue
		var parsed := GameRules.parse_move(move)
		var after := Explain.apply_move(position, parsed, human)
		if not Attacks.attackers_of(after, parsed.to, GameRules.opposite(human)).is_empty():
			continue
		var piece: Dictionary = rules.piece_on(parsed.from)
		var promoted := Pieces.make(piece.color, piece.type, true)
		return _tip("promotion", "Chance de promover (成る, naru)", "%s em %s pode entrar no campo inimigo e promover. Promover quase sempre vale a pena: %s" % [
			_capitalize(Pieces.with_article(piece)), GameRules.square_name(parsed.from), Pieces.info(promoted).move_pt.to_lower()],
			[parsed.from, parsed.to])
	return {}


static func _sitting_king_tip(rules: GameRules, human: String) -> Dictionary:
	if rules.history().size() < 16:
		return {}
	var king := GameRules.find_king(rules.position(), human)
	var home := GameRules.parse_square("5i" if human == "black" else "5a")
	if king != home:
		return {}
	return _tip("sitting-king", "Rei parado (居玉, igyoku)", "O seu Rei ainda está na casa inicial, no meio da luta. O provérbio diz igyoku wa sakeyo (居玉は避けよ): leve-o para o lado oposto ao da Torre e cerque-o com Ouros e Pratas.", [king])


## A piece of the player that the opponent attacks and nobody defends.
static func _hanging_tip(rules: GameRules, human: String) -> Dictionary:
	var position := rules.position()
	for row in GameRules.RANKS:
		for col in GameRules.FILES:
			var piece = position.board[row][col]
			if piece == null or piece.color != human or piece.type == "K" or piece_value(piece) < 3:
				continue
			var square := Vector2i(col, row)
			if Attacks.attackers_of(position, square, GameRules.opposite(human)).is_empty():
				continue
			if not Attacks.attackers_of(position, square, human).is_empty():
				continue
			return _tip("hanging", "Peça sem defesa", "%s em %s está sob ataque e sem defesa. Tire a peça de lá ou proteja-a: lembre que a peça capturada vira arma do adversário." % [
				_capitalize(Pieces.with_article(piece)), GameRules.square_name(square)], [square])
	return {}


## A move that attacks two valuable enemy pieces (or the king and a piece) from a safe square.
static func _fork_tip(rules: GameRules, human: String) -> Dictionary:
	var position := rules.position()
	var enemy := GameRules.opposite(human)
	for move in rules.legal_moves():
		var parsed := GameRules.parse_move(move)
		if parsed.drop == "":
			var mover = GameRules.piece_at(position, parsed.from)
			if mover != null and mover.type == "K":
				continue
		var after := Explain.apply_move(position, parsed, human)
		var piece: Dictionary = GameRules.piece_at(after, parsed.to)
		if not Attacks.attackers_of(after, parsed.to, enemy).is_empty():
			continue
		var targets: Array[Vector2i] = []
		for square in Attacks.attacks_from(after, parsed.to, piece):
			var target = GameRules.piece_at(after, square)
			if target != null and target.color == enemy and piece_value(target) >= 5:
				targets.append(square)
		if targets.size() < 2:
			continue
		var names := PackedStringArray()
		for square in targets:
			names.append(Pieces.with_article(GameRules.piece_at(after, square)))
		return _tip("fork", "Ataque duplo! (両取り, ryōtori)", "Há um lance que ataca %s ao mesmo tempo, de uma casa onde ninguém pode capturar a sua peça. Procure-o: as casas marcadas mostram as peças atacadas." % " e ".join(names), targets)
	return {}


static func _capitalize(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)
