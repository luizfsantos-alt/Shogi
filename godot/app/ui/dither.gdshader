// The interface's fades and shades in the pixel look: instead of being half transparent, the
// colour covers a share of the cells (of `cell` screen pixels, the interface's art pixel) in an
// ordered 4×4 Bayer pattern, as the pixel vignette does.
shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;
// A horizontal ramp, in shares of the width: full cover up to ramp.x, none from ramp.y on
// (no ramp while ramp.y <= ramp.x).
uniform vec2 ramp = vec2(0.0);
uniform float cell = 2.0;

void fragment() {
	// COLOR.a carries the node's modulate: a fading parent dissolves the shade with it.
	float a = amount * color.a * COLOR.a;
	if (ramp.y > ramp.x) {
		a *= 1.0 - clamp((UV.x - ramp.x) / (ramp.y - ramp.x), 0.0, 1.0);
	}
	vec2 c = floor(FRAGCOORD.xy / cell);
	int x = int(mod(c.x, 4.0));
	int y = int(mod(c.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	float t = (float(m[y * 4 + x]) + 0.5) / 16.0;
	COLOR = vec4(color.rgb, a > t ? 1.0 : 0.0);
}
