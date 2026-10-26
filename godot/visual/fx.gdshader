// Flat effects lying on the table: the shock ring of an impact and the glow of a square.
// Driven per instance: progress 0..1 (ring) or intensity (square), and colour.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform int mode = 0;        // 0 ring, 1 square glow
uniform vec3 color : source_color = vec3(1.0, 0.8, 0.45);
uniform float progress = 0.0;
uniform float intensity = 1.0;

// Square glows come from a MultiMesh: custom data = colour (rgb) and intensity (a).
varying vec4 inst;

void vertex() {
	inst = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = 0.0;
	vec3 col = color;
	if (mode == 0) {
		float r = length(p);
		float radius = mix(0.15, 0.95, 1.0 - pow(1.0 - progress, 3.0));
		float width = mix(0.18, 0.04, progress);
		a = smoothstep(width, 0.0, abs(r - radius)) * (1.0 - progress) * intensity;
	} else {
		// Soft rounded square: a bright rim and a faint fill.
		vec2 q = abs(p) - vec2(0.78);
		float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.12;
		float rim_light = smoothstep(0.16, 0.0, abs(d + 0.04));
		float fill = smoothstep(0.1, -0.5, d) * 0.35;
		a = (rim_light + fill) * inst.a;
		col = inst.rgb;
	}
	ALBEDO = col * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
