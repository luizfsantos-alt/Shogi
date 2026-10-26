class_name KomaMoves
## How each piece moves, for the movement wave and the visual test. Not the rules: legality
## (check, pins, nifu, uchifuzume…) comes from the engine later. Here a move is any square the
## piece's pattern reaches, stopping at the first piece in the way.
##
## Squares are Vector2i(col, row): col 0..8 from left to right as Sente sees the board (files
## 9..1), row 0..8 from the far side (rank a) to the near side (rank i). Sente moves up (row - 1).

const ORTHO := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
const DIAG := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## Directions with +y = forward for the piece's owner.
const GOLD := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
const SILVER := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

const PROMOTABLE := ["R", "B", "S", "N", "L", "P"]


## [steps, slides, jumps] for a piece: arrays of forward-relative directions.
static func pattern(kind: String, promoted: bool) -> Array:
	if promoted:
		match kind:
			"R": return [DIAG, ORTHO, []]
			"B": return [ORTHO, DIAG, []]
			_: return [GOLD, [], []]
	match kind:
		"K": return [ORTHO + DIAG, [], []]
		"R": return [[], ORTHO, []]
		"B": return [[], DIAG, []]
		"G": return [GOLD, [], []]
		"S": return [SILVER, [], []]
		"N": return [[], [], [Vector2i(1, 2), Vector2i(-1, 2)]]
		"L": return [[], [Vector2i(0, 1)], []]
		"P": return [[Vector2i(0, 1)], [], []]
	return [[], [], []]


## Squares the piece reaches, each with its distance in squares: [[Vector2i, int], ...].
## `occupant` is a Callable(Vector2i) -> int: -1 empty, else the owner's colour (0 Sente, 1 Gote).
static func reach(kind: String, promoted: bool, colour: int, from: Vector2i, occupant: Callable) -> Array:
	var out := []
	var p := pattern(kind, promoted)
	var flip := -1 if colour == 0 else 1 # forward is row - 1 for Sente
	for d: Vector2i in p[0] + p[2]:
		var to := from + Vector2i(d.x * -flip, d.y * flip)
		if _on_board(to) and occupant.call(to) != colour:
			out.append([to, maxi(absi(d.x), absi(d.y))])
	for d: Vector2i in p[1]:
		var step := Vector2i(d.x * -flip, d.y * flip)
		var to := from + step
		var dist := 1
		while _on_board(to):
			var occ: int = occupant.call(to)
			if occ == colour:
				break
			out.append([to, dist])
			if occ != -1:
				break
			to += step
			dist += 1
	return out


## Squares where a piece from hand may be dropped (empty, and not where it could never move).
static func drops(kind: String, colour: int, occupant: Callable) -> Array:
	var out := []
	for row in 9:
		var depth := row if colour == 0 else 8 - row # rows left in front of the piece
		if (kind == "P" or kind == "L") and depth < 1:
			continue
		if kind == "N" and depth < 2:
			continue
		for col in 9:
			var sq := Vector2i(col, row)
			if occupant.call(sq) == -1:
				out.append(sq)
	return out


static func in_zone(sq: Vector2i, colour: int) -> bool:
	return sq.y <= 2 if colour == 0 else sq.y >= 6


static func can_promote(kind: String, colour: int, from: Vector2i, to: Vector2i) -> bool:
	return kind in PROMOTABLE and (in_zone(from, colour) or in_zone(to, colour))


static func must_promote(kind: String, colour: int, to: Vector2i) -> bool:
	var depth := to.y if colour == 0 else 8 - to.y
	return ((kind == "P" or kind == "L") and depth < 1) or (kind == "N" and depth < 2)


static func _on_board(sq: Vector2i) -> bool:
	return sq.x >= 0 and sq.x < 9 and sq.y >= 0 and sq.y < 9
