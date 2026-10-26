// Glowing particles: sparks and motes brighter than white, so the glow (bloom) picks them up.
// The colour comes from the particle (colour ramp); `energy` pushes it into HDR.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float energy = 3.0;
uniform bool billboard = true;  // motes face the camera; sparks are stretched boxes instead
uniform bool soft = true;       // round soft dot

void vertex() {
	if (billboard) {
		mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(vec4(s.x, 0, 0, 0), vec4(0, s.y, 0, 0), vec4(0, 0, s.z, 0), vec4(0, 0, 0, 1));
	}
}

void fragment() {
	float a = 1.0;
	if (soft) {
		vec2 p = UV * 2.0 - 1.0;
		a = clamp(1.0 - dot(p, p), 0.0, 1.0);
		a *= a;
	}
	ALBEDO = COLOR.rgb * energy * a * COLOR.a;
}
