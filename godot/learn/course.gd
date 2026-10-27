class_name Course
extends RefCounted
## The course "Aprender a jogar" (port of src/learn/course.ts). The lessons are data exported from
## the PWA (course.json, by scripts/export-lessons.mjs); the learner's stars are saved in
## user://curso.json.
##
## A track is {id, title, term, description, lessons}; a lesson is {id, title, term, summary,
## steps, game?}; a step is {kind: "info"|"exercise", title, text: [paragraphs], sfen?, focus?,
## piece?, goal?, hint?, success?, wrong?}. Squares are USI names ("5e"), moves USI ("7g7f").

const DATA_PATH := "res://learn/course.json"
const PROGRESS_PATH := "user://curso.json"

## Paragraphs of the PWA that talk about its own buttons, as the app says them.
const APP_WORDING := {
	"Cada peça tem seu nome em kanji. Toque numa peça para ver o nome e o movimento no painel, ou segure o dedo sobre ela para ver o nome rapidamente. O botão Leitura troca o kanji por marcas que mostram como a peça anda.":
		"Cada peça tem seu nome em kanji. Toque numa peça sua para ver para onde ela pode ir; o botão Movimentos mostra as setas de todas as suas peças, e uma peça do adversário, tocada, mostra as dela em vermelho.",
	"Torre e Bispo valem 5 pontos, as outras peças (menos o Rei) 1. Os detalhes estão no botão Regras. Você vai ver isso pouco no começo.":
		"Torre e Bispo valem 5 pontos, as outras peças (menos o Rei) 1. Você vai ver isso pouco no começo.",
}

static var _tracks: Array = []
static var _red_words: RegEx


static func tracks() -> Array:
	if _tracks.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(data) == TYPE_DICTIONARY:
			_tracks = data.get("tracks", [])
		for track: Dictionary in _tracks:
			for lesson: Dictionary in track.lessons:
				for step: Dictionary in lesson.steps:
					var text: Array = step.text
					for i in text.size():
						text[i] = APP_WORDING.get(text[i], text[i])
	return _tracks


static func all_lessons() -> Array:
	var out := []
	for track: Dictionary in tracks():
		out.append_array(track.lessons)
	return out


## {lesson, track} or {} when there is no such lesson.
static func find_lesson(id: String) -> Dictionary:
	for track: Dictionary in tracks():
		for lesson: Dictionary in track.lessons:
			if lesson.id == id:
				return {"lesson": lesson, "track": track}
	return {}


## The lesson after `id` in the course order, or {} at the end.
static func next_lesson(id: String) -> Dictionary:
	var lessons := all_lessons()
	for i in lessons.size() - 1:
		if lessons[i].id == id:
			return lessons[i + 1]
	return {}


## The first lesson not done yet, following the recommended order ({} when all are done).
static func recommended_lesson(progress: Dictionary) -> Dictionary:
	for lesson: Dictionary in all_lessons():
		if not progress.stars.has(lesson.id):
			return lesson
	return {}


## {done, total} for one track, or for the whole course when `track` is empty.
static func completed_count(progress: Dictionary, track := {}) -> Dictionary:
	var lessons: Array = track.lessons if not track.is_empty() else all_lessons()
	var done := 0
	for lesson: Dictionary in lessons:
		if progress.stars.has(lesson.id):
			done += 1
	return {"done": done, "total": lessons.size()}


# --- Progress ------------------------------------------------------------------------------

## {stars: {lesson id: 1..3}}; a lesson is done when it has stars.
static func load_progress(path := PROGRESS_PATH) -> Dictionary:
	var progress := {"stars": {}}
	if not FileAccess.file_exists(path):
		return progress
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) == TYPE_DICTIONARY and typeof(data.get("stars")) == TYPE_DICTIONARY:
		for id in data.stars:
			var n := int(data.stars[id])
			if n >= 1 and n <= 3:
				progress.stars[id] = n
	return progress


## Keeps the best result of a lesson. 0 stars (exercises skipped) records nothing.
static func save_result(lesson_id: String, stars: int, path := PROGRESS_PATH) -> Dictionary:
	var progress := load_progress(path)
	if stars >= 1:
		progress.stars[lesson_id] = maxi(int(progress.stars.get(lesson_id, 0)), mini(stars, 3))
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(progress))
	return progress


## The PWA's texts call Gote's pieces red ("o Rei vermelho"), its lacquer there; in the pixel look
## they are black. Red as the colour of danger ("as setas em vermelho") stays red.
static func gote_words(text: String) -> String:
	if not Koma.pixel:
		return text
	if _red_words == null:
		_red_words = RegEx.create_from_string("(?<!em )([Vv])ermelh(os|as|o|a)\\b")
	var out := ""
	var at := 0
	for m in _red_words.search_all(text):
		out += text.substr(at, m.get_start() - at) + ("P" if m.get_string(1) == "V" else "p") + "ret" + m.get_string(2)
		at = m.get_end()
	return out + text.substr(at)
