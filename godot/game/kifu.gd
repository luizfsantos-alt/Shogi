class_name Kifu
extends RefCounted
## Western (Hodges) move notation for the move list, e.g. "P-7f", "Bx2b+", "S6h-5g", "P*5e"
## (port of src/core/kifu.ts). The origin is shown only when another piece of the same kind could
## reach the same square; "=" marks a promotion that was available but declined.


## `position` and `legal_moves` are those before the move.
static func format_western(position: Dictionary, legal_moves: PackedStringArray, move: String) -> String:
	var parsed := GameRules.parse_move(move)
	if parsed.is_empty():
		return move
	var to := GameRules.square_name(parsed.to)
	if parsed.drop != "":
		return "%s*%s" % [parsed.drop, to]
	var piece = GameRules.piece_at(position, parsed.from)
	if piece == null:
		return move
	var letter: String = ("+" if piece.promoted else "") + piece.type
	var from := GameRules.square_name(parsed.from)
	var capture := GameRules.piece_at(position, parsed.to) != null
	var ambiguous := false
	for other in legal_moves:
		var o := GameRules.parse_move(other)
		if o.is_empty() or o.drop != "" or other.begins_with(from) or o.to != parsed.to:
			continue
		var other_piece = GameRules.piece_at(position, o.from)
		if other_piece != null and other_piece.type == piece.type and other_piece.promoted == piece.promoted:
			ambiguous = true
			break
	var promotion := "+" if parsed.promote else ("=" if legal_moves.has(move + "+") else "")
	return "%s%s%s%s%s" % [letter, from if ambiguous else "", "x" if capture else "-", to, promotion]
