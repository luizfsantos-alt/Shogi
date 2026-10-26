// Movement arrows drawn over the pieces: gold for your pieces, red for an opponent's piece.
// One quad per arrow; its length and width (cm) come per instance so the head keeps its shape.
// `heads`: 0 a plain segment (the knight's stem), 1 an arrow, 2 a double head (any distance).
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float length_cm = 3.0;
instance uniform float width_cm = 1.2;
instance uniform float grow = 1.0;
instance uniform float heads = 1.0;
instance uniform vec4 tint : source_color = vec4(1.0, 0.75, 0.25, 1.0);

uniform vec3 outline_color : source_color = vec3(0.12, 0.05, 0.02);
uniform float shaft = 0.16;     // half width of the shaft, cm
uniform float head_len = 0.6;   // cm
uniform float outline = 0.09;   // cm

// Rough signed distance to a triangular head whose tip is at `tip`.
float head(vec2 p, float tip, float half_w) {
	float a = tip - p.y;                    // distance back from the tip
	float side = abs(p.x) - half_w * clamp(a / head_len, 0.0, 1.0);
	return max(max(-a, a - head_len), side * 0.8);
}

void fragment() {
	// The quad's UV.y runs from the tip (0) back to the start (1).
	float len = length_cm * grow;
	vec2 p = vec2((UV.x - 0.5) * width_cm, (1.0 - UV.y) * length_cm);
	float half_w = width_cm * 0.5 - outline;
	float shaft_end = heads > 0.5 ? len - head_len * 0.6 : len;
	float d = max(max(abs(p.x) - shaft, -p.y), p.y - shaft_end);
	if (heads > 0.5) {
		d = min(d, head(p, len, half_w));
	}
	if (heads > 1.5) {
		d = min(d, head(p, len - head_len * 0.75, half_w));
	}
	float fill = 1.0 - smoothstep(-0.02, 0.02, d);
	float edge = 1.0 - smoothstep(outline - 0.02, outline + 0.02, d);
	vec3 col = mix(outline_color, tint.rgb, fill);
	ALBEDO = col;
	ALPHA = edge * tint.a;
}
