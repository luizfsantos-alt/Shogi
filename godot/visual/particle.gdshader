// Glowing particles: sparks and motes brighter than white, so the glow (bloom) picks them up.
// The colour comes from the particle (colour ramp); `energy` pushes it into HDR.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float energy = 3.0;
uniform bool billboard = true;  // motes face the camera; sparks are stretched boxes instead
uniform bool soft = true;       // round soft dot
global uniform float pixel_look;

void vertex() {
	if (billboard) {
		mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
		MODELVIEW_MATRIX = VIEW_MATRIX * face * mat4(vec4(s.x, 0, 0, 0), vec4(0, s.y, 0, 0), vec4(0, 0, s.z, 0), vec4(0, 0, 0, 1));
	}
}

void fragment() {
	float a = 1.0;
	if (pixel_look > 0.5) {
		// A 3×3 plus: bright centre, dimmer arms, nothing in the corners.
		vec2 c = floor(UV * 3.0);
		vec2 d = abs(c - 1.0);
		a = (d.x + d.y < 0.5) ? 1.0 : (d.x + d.y < 1.5 ? 0.55 : 0.0);
		// Three golds, picked by how far along its colour ramp the particle is.
		float lum = dot(COLOR.rgb, vec3(0.3, 0.55, 0.15));
		vec3 col = lum > 0.8 ? vec3(1.0, 0.93, 0.62) : (lum > 0.55 ? vec3(1.0, 0.66, 0.18) : vec3(0.82, 0.32, 0.06));
		ALBEDO = col * min(energy, 1.6) * a * step(0.3, COLOR.a);
	} else {
		if (soft) {
			vec2 p = UV * 2.0 - 1.0;
			a = clamp(1.0 - dot(p, p), 0.0, 1.0);
			a *= a;
		}
		ALBEDO = COLOR.rgb * energy * a * COLOR.a;
	}
}
