class_name Mascot
extends TextureRect
## The mentor: the tengu (天狗), the long-nosed mountain master of Japanese legend who taught the
## young Minamoto no Yoshitsune. The art is art/tengu.png (made from source/tengu.jpg by
## tools/cut_background.py). It breathes: a very slow, subtle swell of the body only
## (breath.gdshader): the mat stays put, the robe rises and widens a little, the head rides on top.

const ART := preload("res://app/mentor/art/tengu.png")
const BREATH_SECONDS := 4.5

var _time := 0.0


func _ready() -> void:
	texture = ART
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://app/mentor/breath.gdshader")
	material = m


## Width over height of the art, to size the portrait.
static func aspect() -> float:
	return float(ART.get_width()) / ART.get_height()


func _process(delta: float) -> void:
	_time += delta
	# Eased in and out: 0 = breathed out, 1 = breathed in.
	var breath := 0.5 - 0.5 * cos(_time * TAU / BREATH_SECONDS)
	(material as ShaderMaterial).set_shader_parameter("breath", breath)
