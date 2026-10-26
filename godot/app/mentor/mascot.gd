class_name Mascot
extends TextureRect
## The mentor: the tengu (天狗), the long-nosed mountain master of Japanese legend who taught the
## young Minamoto no Yoshitsune. Pixel art in six poses (art/tengu_<pose>.png, made from the
## generated pictures in art_source/ by prepare_art.py), all on the same canvas so one replaces
## another in place. Drawn with nearest filtering: every art pixel stays a square.
## It breathes: a very slow swell of the body only (breath.gdshader), which in pixel art means
## the robe and the head rise by one art pixel and settle back; the mat stays put.

## Pose -> art. "neutral" sits with the hands together; the others react to the game.
const POSES := {
	"neutral": preload("res://app/mentor/art/tengu_neutral.png"),
	"explain": preload("res://app/mentor/art/tengu_explain.png"),   ## a hand raised, explaining
	"point": preload("res://app/mentor/art/tengu_point.png"),       ## pointing with the fan: look here
	"startled": preload("res://app/mentor/art/tengu_startled.png"), ## check, danger
	"laugh": preload("res://app/mentor/art/tengu_laugh.png"),       ## well done
	"stern": preload("res://app/mentor/art/tengu_stern.png"),       ## a forbidden move
}
## The head in each pose (art pixels), for the medallion of the small balloon.
const HEADS := {
	"neutral": Rect2(95, 4, 76, 70), "explain": Rect2(95, 4, 76, 70), "point": Rect2(95, 4, 76, 70),
	"startled": Rect2(70, 0, 76, 70), "laugh": Rect2(95, 4, 76, 70), "stern": Rect2(95, 4, 76, 70),
}
const ART: Texture2D = POSES["neutral"]
const BREATH_SECONDS := 4.5

var _time := 0.0


func _ready() -> void:
	texture = ART
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://app/mentor/breath.gdshader")
	material = m


## Shows one of the POSES ("" or an unknown name: neutral).
func set_pose(pose: String) -> void:
	texture = POSES.get(pose, ART)


## The medallion's picture for a pose: the head cut from that pose's art.
static func head(pose: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = POSES.get(pose, ART)
	atlas.region = HEADS.get(pose, HEADS["neutral"])
	return atlas


## Width over height of the art, to size the portrait.
static func aspect() -> float:
	return float(ART.get_width()) / ART.get_height()


func _process(delta: float) -> void:
	_time += delta
	# Eased in and out: 0 = breathed out, 1 = breathed in.
	var breath := 0.5 - 0.5 * cos(_time * TAU / BREATH_SECONDS)
	(material as ShaderMaterial).set_shader_parameter("breath", breath)
