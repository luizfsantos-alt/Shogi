class_name Impasse
extends RefCounted
## Entering-king declaration (jishogi), "27-point rule" as used by the Japan Shogi Association in
## amateur play and by computer shogi (CSA). Port of src/core/impasse.ts.
##
## On their own turn, a player may declare a win when ALL of these hold:
##  1. their king is inside the enemy camp (the promotion zone);
##  2. they have at least 10 other pieces inside the enemy camp;
##  3. pieces in the enemy camp + pieces in hand are worth at least 28 points (Sente) or
##     27 points (Gote); rook and bishop (promoted or not) are worth 5, others 1, the king 0;
##  4. their king is not in check.
##
## Fairy-Stockfish does not implement this rule, so it lives here.

const BLACK_POINTS := 28
const WHITE_POINTS := 27
const MIN_PIECES_IN_ZONE := 10
const BIG_PIECES := ["R", "B"]
const BIG_PIECE_VALUE := 5


static func is_in_enemy_camp(row: int, color: String) -> bool:
	var zone := GameRules.PROMOTION_ZONE_RANKS
	return row < zone if color == "black" else row >= GameRules.RANKS - zone


static func value_of(type: String) -> int:
	return BIG_PIECE_VALUE if type in BIG_PIECES else 1


## {can_declare, king_in_zone, pieces_in_zone, required_pieces, points, required_points, in_check}.
static func evaluate(position: Dictionary, color: String, in_check: bool) -> Dictionary:
	var king_in_zone := false
	var pieces_in_zone := 0
	var points := 0
	for row in GameRules.RANKS:
		if not is_in_enemy_camp(row, color):
			continue
		for piece in position.board[row]:
			if piece == null or piece.color != color:
				continue
			if piece.type == "K":
				king_in_zone = true
				continue
			pieces_in_zone += 1
			points += value_of(piece.type)
	for type in position.hands[color]:
		points += value_of(type) * position.hands[color][type]
	var required_points := BLACK_POINTS if color == "black" else WHITE_POINTS
	return {
		"can_declare": king_in_zone and pieces_in_zone >= MIN_PIECES_IN_ZONE and points >= required_points and not in_check,
		"king_in_zone": king_in_zone,
		"pieces_in_zone": pieces_in_zone,
		"required_pieces": MIN_PIECES_IN_ZONE,
		"points": points,
		"required_points": required_points,
		"in_check": in_check,
	}
