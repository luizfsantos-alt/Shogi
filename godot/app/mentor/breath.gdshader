// The tengu's breath: only the body moves. Below `base` (the mat) nothing changes; between
// `neck` and `base` the robe stretches upward by `rise` and widens slightly at the chest; above
// the neck the head is carried up by the same amount, so nothing tears. Values in UV (0..1 of
// the picture; y down).
shader_type canvas_item;

uniform float breath = 0.0;   // 0 out .. 1 in
uniform float rise = 0.006;
uniform float widen = 0.006;
uniform float neck = 0.36;
uniform float base = 0.86;

void fragment() {
	float a = rise * breath;
	float y = UV.y;
	float src;
	if (y >= base) {
		src = y;
	} else if (y < neck - a) {
		src = y + a;
	} else {
		float l = base - neck;
		src = base - (base - y) * l / (l + a);
	}
	// The chest widens most, the shoulders and the lap less.
	float w = smoothstep(neck - 0.05, neck + 0.18, y) * (1.0 - smoothstep(base - 0.15, base, y));
	float sx = 1.0 + widen * breath * w;
	vec2 uv = vec2(0.5 + (UV.x - 0.5) / sx, src);
	COLOR = texture(TEXTURE, uv);
}
