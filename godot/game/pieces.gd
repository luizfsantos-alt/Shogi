class_name Pieces
extends RefCounted
## Piece catalogue: names and movement (port of src/core/pieces.ts).
##
## A piece is a Dictionary {color: "black"|"white", type: "P".."K", promoted: bool}.
## Directions are from the owner's point of view: Vector2i(dx, dy), dy = +1 is "forward" (towards
## the enemy), dx = +1 is to the owner's right.

const ORTHOGONAL: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
const DIAGONAL: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
const GOLD_STEPS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]

const BASE := {
	"K": {"label_pt": "Rei", "label_en": "King", "kanji": "王", "name_pt": "Rei", "name_en": "King", "romaji": "Ōshō / Gyokushō", "kanji_name": "王将 / 玉将",
		"move_pt": "Uma casa em qualquer direção. Se ele não tiver como escapar de um ataque, é xeque-mate.",
		"steps": ORTHOGONAL + DIAGONAL, "slides": [], "jumps": []},
	"R": {"label_pt": "Torre", "label_en": "Rook", "kanji": "飛", "name_pt": "Torre", "name_en": "Rook", "romaji": "Hisha", "kanji_name": "飛車",
		"move_pt": "Quantas casas quiser na horizontal ou na vertical, sem pular peças.",
		"steps": [], "slides": ORTHOGONAL, "jumps": []},
	"B": {"label_pt": "Bispo", "label_en": "Bishop", "kanji": "角", "name_pt": "Bispo", "name_en": "Bishop", "romaji": "Kakugyō", "kanji_name": "角行",
		"move_pt": "Quantas casas quiser na diagonal, sem pular peças.",
		"steps": [], "slides": DIAGONAL, "jumps": []},
	"G": {"label_pt": "Ouro", "label_en": "Gold", "kanji": "金", "name_pt": "General de Ouro", "name_en": "Gold general", "romaji": "Kinshō", "kanji_name": "金将",
		"move_pt": "Uma casa para frente, para os lados, para trás ou nas duas diagonais da frente (não vai nas diagonais de trás).",
		"steps": GOLD_STEPS, "slides": [], "jumps": []},
	"S": {"label_pt": "Prata", "label_en": "Silver", "kanji": "銀", "name_pt": "General de Prata", "name_en": "Silver general", "romaji": "Ginshō", "kanji_name": "銀将",
		"move_pt": "Uma casa para frente ou em qualquer diagonal (não vai para os lados nem direto para trás).",
		"steps": [Vector2i(0, 1)] + DIAGONAL, "slides": [], "jumps": []},
	"N": {"label_pt": "Cavalo", "label_en": "Knight", "kanji": "桂", "name_pt": "Cavalo", "name_en": "Knight", "romaji": "Keima", "kanji_name": "桂馬",
		"move_pt": "Salta para uma das duas casas duas à frente e uma para o lado, pulando qualquer peça. Só anda para frente.",
		"steps": [], "slides": [], "jumps": [Vector2i(1, 2), Vector2i(-1, 2)]},
	"L": {"label_pt": "Lança", "label_en": "Lance", "kanji": "香", "name_pt": "Lança", "name_en": "Lance", "romaji": "Kyōsha", "kanji_name": "香車",
		"move_pt": "Quantas casas quiser, só para frente, sem pular peças.",
		"steps": [], "slides": [Vector2i(0, 1)], "jumps": []},
	"P": {"label_pt": "Peão", "label_en": "Pawn", "kanji": "歩", "name_pt": "Peão", "name_en": "Pawn", "romaji": "Fuhyō", "kanji_name": "歩兵",
		"move_pt": "Uma casa para frente. Captura do mesmo jeito que anda (diferente do xadrez).",
		"steps": [Vector2i(0, 1)], "slides": [], "jumps": []},
}

const PROMOTED := {
	"R": {"label_pt": "Dragão", "label_en": "Dragon", "kanji": "龍", "name_pt": "Torre promovida (Dragão)", "name_en": "Dragon king", "romaji": "Ryūō", "kanji_name": "龍王",
		"move_pt": "Como a torre (linhas retas, qualquer distância) e também uma casa nas diagonais.",
		"steps": DIAGONAL, "slides": ORTHOGONAL, "jumps": []},
	"B": {"label_pt": "Cav-dragão", "label_en": "Horse", "kanji": "馬", "name_pt": "Bispo promovido (Cavalo-dragão)", "name_en": "Dragon horse", "romaji": "Ryūma", "kanji_name": "龍馬",
		"move_pt": "Como o bispo (diagonais, qualquer distância) e também uma casa na horizontal ou vertical.",
		"steps": ORTHOGONAL, "slides": DIAGONAL, "jumps": []},
	"S": {"label_pt": "Prata+", "label_en": "+Silver", "kanji": "全", "name_pt": "Prata promovida", "name_en": "Promoted silver", "romaji": "Narigin", "kanji_name": "成銀",
		"move_pt": "Passa a andar como o Ouro.", "steps": GOLD_STEPS, "slides": [], "jumps": []},
	"N": {"label_pt": "Cavalo+", "label_en": "+Knight", "kanji": "圭", "name_pt": "Cavalo promovido", "name_en": "Promoted knight", "romaji": "Narikei", "kanji_name": "成桂",
		"move_pt": "Passa a andar como o Ouro.", "steps": GOLD_STEPS, "slides": [], "jumps": []},
	"L": {"label_pt": "Lança+", "label_en": "+Lance", "kanji": "杏", "name_pt": "Lança promovida", "name_en": "Promoted lance", "romaji": "Narikyō", "kanji_name": "成香",
		"move_pt": "Passa a andar como o Ouro.", "steps": GOLD_STEPS, "slides": [], "jumps": []},
	"P": {"label_pt": "Tokin", "label_en": "Tokin", "kanji": "と", "name_pt": "Peão promovido (Tokin と金)", "name_en": "Tokin", "romaji": "Tokin", "kanji_name": "と金",
		"move_pt": "Passa a andar como o Ouro.", "steps": GOLD_STEPS, "slides": [], "jumps": []},
}

## Relative size of a traditional piece: the king is the largest, the pawn the smallest.
const PIECE_SCALE := {"K": 1.0, "R": 0.97, "B": 0.97, "G": 0.93, "S": 0.93, "N": 0.9, "L": 0.88, "P": 0.85}


static func make(color: String, type: String, promoted := false) -> Dictionary:
	return {"color": color, "type": type, "promoted": promoted}


## Name, kanji, movement… of a piece ({type, promoted} is enough).
static func info(piece: Dictionary) -> Dictionary:
	return PROMOTED[piece.type] if piece.get("promoted", false) else BASE[piece.type]


## Kanji for a piece; by convention Sente's king is 玉 and Gote's is 王.
static func kanji(piece: Dictionary) -> String:
	if piece.type == "K":
		return "玉" if piece.color == "black" else "王"
	return info(piece).kanji


## What is written on a traditional piece (飛車, 角行…; single cursive kanji on promoted minors).
static func face(piece: Dictionary) -> String:
	if piece.type == "K":
		return "玉将" if piece.color == "black" else "王将"
	if piece.get("promoted", false) and piece.type != "R" and piece.type != "B":
		return info(piece).kanji
	return info(piece).kanji_name


## "o Bispo", "a Torre", "a Lança promovida".
static func with_article(piece: Dictionary) -> String:
	var promoted: bool = piece.get("promoted", false)
	var feminine: bool = piece.type == "R" or piece.type == "L" or (promoted and piece.type == "S")
	return ("a " if feminine else "o ") + info(piece).name_pt


static func name_pt(piece: Dictionary) -> String:
	return info(piece).name_pt
