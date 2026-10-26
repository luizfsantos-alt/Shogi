class_name Attacks
extends RefCounted
## Piece reach computed from the movement table in pieces.gd (port of src/core/attacks.ts).
## Used to explain illegal moves and to show attacked squares; the legal moves themselves
## always come from Fairy-Stockfish.
##
## Squares are Vector2i(col, row): col 0..8 from Sente's left (USI files 9..1), row 0..8 from the
## top (USI ranks a..i), the same indices as position.board[row][col].


## Converts a direction in the owner's frame (dy = forward) to a board offset.
static func board_offset(direction: Vector2i, color: String) -> Vector2i:
	# Sente faces row 0 and has col 8 (file 1) on its right; Gote is mirrored.
	return Vector2i(direction.x, -direction.y) if color == "black" else Vector2i(-direction.x, direction.y)


static func inside(square: Vector2i) -> bool:
	return square.x >= 0 and square.x < GameRules.FILES and square.y >= 0 and square.y < GameRules.RANKS


## Squares a piece on `from` attacks (it could capture there), stopping at the first piece on slides.
static func attacks_from(position: Dictionary, from: Vector2i, piece: Dictionary) -> Array[Vector2i]:
	var movement := Pieces.info(piece)
	var result: Array[Vector2i] = []
	for direction in movement.steps + movement.jumps:
		var to: Vector2i = from + board_offset(direction, piece.color)
		if inside(to):
			result.append(to)
	for direction in movement.slides:
		var offset := board_offset(direction, piece.color)
		var to: Vector2i = from + offset
		while inside(to):
			result.append(to)
			if GameRules.piece_at(position, to) != null:
				break
			to += offset
	return result


## Whether the piece's movement pattern can bring it from `from` to `to`: "reachable", "blocked"
## (it moves that way but another piece is in the path) or "never".
static func reach(position: Dictionary, from: Vector2i, piece: Dictionary, to: Vector2i) -> String:
	var movement := Pieces.info(piece)
	for direction in movement.steps + movement.jumps:
		if from + board_offset(direction, piece.color) == to:
			return "reachable"
	for direction in movement.slides:
		var offset := board_offset(direction, piece.color)
		var square: Vector2i = from + offset
		while inside(square):
			if square == to:
				return "reachable"
			if GameRules.piece_at(position, square) != null:
				# Is the target further along this line?
				var further := square + offset
				while inside(further):
					if further == to:
						return "blocked"
					further += offset
				break
			square += offset
	return "never"


## Squares of the pieces of `color` attacking `target`.
static func attackers_of(position: Dictionary, target: Vector2i, color: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row in GameRules.RANKS:
		for col in GameRules.FILES:
			var piece = position.board[row][col]
			if piece == null or piece.color != color:
				continue
			if attacks_from(position, Vector2i(col, row), piece).has(target):
				result.append(Vector2i(col, row))
	return result


## Every square attacked by `color` -> number of attackers.
static func attack_map(position: Dictionary, color: String) -> Dictionary:
	var map := {}
	for row in GameRules.RANKS:
		for col in GameRules.FILES:
			var piece = position.board[row][col]
			if piece == null or piece.color != color:
				continue
			for target in attacks_from(position, Vector2i(col, row), piece):
				map[target] = map.get(target, 0) + 1
	return map


## Ranks from the far end of the board for `color` (0 = the last rank).
static func distance_to_last_rank(square: Vector2i, color: String) -> int:
	return square.y if color == "black" else GameRules.RANKS - 1 - square.y


static func in_promotion_zone(square: Vector2i, color: String) -> bool:
	return distance_to_last_rank(square, color) < GameRules.PROMOTION_ZONE_RANKS
