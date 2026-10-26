// Dust puffs: soft round billboards, blended (not added) so they read on light wood.
// In the pixel look a puff is a blocky disc on a 6×6 grid that breaks up into a dither as it fades.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float pixel_look;

void vertex() {
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(vec4(s.x, 0, 0, 0), vec4(0, s.y, 0, 0), vec4(0, 0, s.z, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	if (pixel_look > 0.5) {
		vec2 cell = floor(UV * 6.0);
		vec2 p = (cell + 0.5) / 3.0 - 1.0;
		float inside = step(dot(p, p), 0.8);
		vec2 c = mod(cell, 2.0);
		float t = (c.x * 2.0 + c.y * 3.0 - c.x * c.y * 4.0 + 0.5) / 4.0;
		float keep = step(t, COLOR.a * 2.2);
		// The upper-left texels are lit, the rest in the puff's shade.
		float lit = step(p.x + p.y, -0.3);
		ALBEDO = COLOR.rgb * (lit > 0.5 ? 1.15 : 0.85);
		ALPHA = inside * keep;
	} else {
		vec2 p = UV * 2.0 - 1.0;
		float a = clamp(1.0 - dot(p, p), 0.0, 1.0);
		ALBEDO = COLOR.rgb;
		ALPHA = a * a * COLOR.a;
	}
}
