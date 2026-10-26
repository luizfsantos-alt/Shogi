// Flat effects lying on the table: the shock ring of an impact and the glow of a square.
// Driven per instance: progress 0..1 (ring) or intensity (square), and colour.
// In the pixel look both snap to texels, have hard edges, and the ring grows in a few frames.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform int mode = 0;        // 0 ring, 1 square glow
uniform vec3 color : source_color = vec3(1.0, 0.8, 0.45);
uniform float progress = 0.0;
uniform float intensity = 1.0;
global uniform float pixel_look;
uniform vec2 quad_cm = vec2(7.0);  // size of the quad, for texels of a fixed size in cm
uniform float texel = 0.21;

// Square glows come from a MultiMesh: custom data = colour (rgb) and intensity (a).
varying vec4 inst;

void vertex() {
	inst = INSTANCE_CUSTOM;
}

float bayer2(vec2 cell) {
	vec2 c = mod(cell, 2.0);
	return (c.x * 2.0 + c.y * 3.0 - c.x * c.y * 4.0 + 0.5) / 4.0;
}

void fragment() {
	bool pixel = pixel_look > 0.5;
	vec2 n = max(floor(quad_cm / texel), vec2(1.0));
	vec2 cell = floor(UV * n);
	vec2 uv = pixel ? (cell + 0.5) / n : UV;
	vec2 p = uv * 2.0 - 1.0;
	float a = 0.0;
	vec3 col = color;
	if (mode == 0 && pixel) {
		// Five frames, a ring two texels thick that thins out, then a dithered last frame.
		float f = floor(progress * 5.0) / 5.0;
		float r = length(p);
		float radius = mix(0.2, 0.95, 1.0 - pow(1.0 - f, 2.0));
		float width = mix(3.0, 1.0, f) / n.x * 2.0;
		float on = step(abs(r - radius), width * 0.5);
		float fade = step(bayer2(cell), (1.0 - f) * 1.4) * intensity;
		a = on * fade;
		col = f < 0.4 ? vec3(1.0, 0.95, 0.8) : color;
	} else if (mode == 0) {
		float r = length(p);
		float radius = mix(0.15, 0.95, 1.0 - pow(1.0 - progress, 3.0));
		float width = mix(0.18, 0.04, progress);
		a = smoothstep(width, 0.0, abs(r - radius)) * (1.0 - progress) * intensity;
	} else if (pixel) {
		// A one-texel rim and a checkered fill, like a selection cursor.
		vec2 e = min(cell, n - 1.0 - cell);
		float rim = step(min(e.x, e.y), 0.5);
		float corner = step(max(e.x, e.y), 3.5) * step(min(e.x, e.y), 1.5);
		float fill = step(0.5, mod(cell.x + cell.y, 2.0)) * 0.3;
		a = max(max(rim, corner), fill) * step(0.02, inst.a) * (0.55 + 0.45 * inst.a);
		col = inst.rgb;
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
