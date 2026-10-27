// The pixel look of a koma (the default, see DECISIONS.md "Visual pixel"): the same lacquer as
// koma.gdshader, but everything on its surface is drawn in whole texels, like a 16-bit sprite.
// The kanji and the movement marks come from a 32×36 mask (textures/kanji_px/) sampled with
// nearest filtering, the sheen is posterized, and the light falls in a few hard bands with one
// sharp highlight, so the thick wedge reads in 3D the way a hand-shaded sprite does.
// Vertex colours from KomaMesh: r = edge wear, g = front face, b = back face.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D kanji_front : hint_default_black, filter_nearest, repeat_disable;
uniform sampler2D kanji_back : hint_default_black, filter_nearest, repeat_disable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float team : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

group_uniforms palette;
uniform vec3 pearl_light : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 pearl_base : source_color = vec3(0.9, 0.86, 0.78);
uniform vec3 pearl_tint : source_color = vec3(0.86, 0.84, 0.95);
uniform vec3 red_light : source_color = vec3(0.72, 0.1, 0.07);
uniform vec3 red_base : source_color = vec3(0.56, 0.05, 0.035);
uniform vec3 ink_kind : source_color = vec3(0.07, 0.04, 0.03);  // front face: Koma.INK, by kind
uniform vec3 ink_promoted : source_color = vec3(0.78, 0.1, 0.04); // promoted Sente: red
uniform vec3 ink_gold : source_color = vec3(1.0, 0.78, 0.3);      // promoted Gote: gold
uniform float texels_per_cm = 9.5;   // the grid of the sheen and the edges, close to the mask's
uniform float carve_depth = 0.9;

group_uniforms shading;
uniform float bands = 3.0;
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.22;
uniform float highlight : hint_range(0.0, 2.0) = 0.9;

group_uniforms glow;
uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.3);
uniform float glow = 0.0;
uniform float gold_edge = 0.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

float tap(vec2 p) {
	return texture(noise_tex, p + vec2(seed * 0.137, seed * 0.071)).r;
}

void fragment() {
	float front = COLOR.g;
	float back = COLOR.b;
	float face = front + back;
	float edge = clamp(COLOR.r, 0.0, 1.0);
	vec3 n = NORMAL;

	// The surface grid: faces snap to the mask's texels, the edges to the same size in cm.
	vec2 mask_size = vec2(textureSize(kanji_front, 0));
	vec2 cell_uv = (floor(UV * mask_size) + 0.5) / mask_size;
	vec3 cell_pos = (floor(lpos * texels_per_cm) + 0.5) / texels_per_cm;

	// Lacquer in three tones per team: a light patch, the body and a cool tint, no gradients.
	float swirl = tap(cell_pos.xz * 0.035 + cell_pos.y * 0.02);
	float tone = floor(clamp(swirl * 1.6 - 0.35, 0.0, 0.999) * 3.0);
	vec3 pearl = tone > 1.5 ? pearl_light : (tone > 0.5 ? pearl_base : mix(pearl_base, pearl_tint, 0.35));
	vec3 red = tone > 1.5 ? red_light : red_base;
	vec3 albedo = mix(pearl, red, step(0.5, team));
	// Worn edges: the wood under the lacquer, in a single darker tone.
	vec3 under = mix(vec3(0.62, 0.5, 0.38), vec3(0.3, 0.05, 0.03), step(0.5, team));
	albedo = mix(albedo, under, step(0.55, edge * 0.7 + tap(cell_pos.xz * 0.5) * 0.3) * 0.6);
	float rough = 0.35;

	if (face > 0.5) {
		bool is_back = back > 0.5;
		vec2 t = 1.0 / mask_size;
		float m, mu, mv;
		if (is_back) {
			m = texture(kanji_back, cell_uv).r;
			mu = texture(kanji_back, cell_uv + vec2(t.x, 0)).r - texture(kanji_back, cell_uv - vec2(t.x, 0)).r;
			mv = texture(kanji_back, cell_uv + vec2(0, t.y)).r - texture(kanji_back, cell_uv - vec2(0, t.y)).r;
		} else {
			m = texture(kanji_front, cell_uv).r;
			mu = texture(kanji_front, cell_uv + vec2(t.x, 0)).r - texture(kanji_front, cell_uv - vec2(t.x, 0)).r;
			mv = texture(kanji_front, cell_uv + vec2(0, t.y)).r - texture(kanji_front, cell_uv - vec2(0, t.y)).r;
		}
		// Carved texels: the wall next to the ink catches the light on one side only.
		n = normalize(n + (TANGENT * mu + BINORMAL * mv) * carve_depth * (1.0 - m));
		float ink = step(0.5, m);
		vec3 ink_col = is_back ? mix(ink_promoted, ink_gold, step(0.5, team)) : ink_kind;
		albedo = mix(albedo, ink_col, ink);
		rough = mix(rough, 0.6, ink);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	NORMAL = n;
	// The gold rim of a promoted piece and the selection glow, in flat steps too.
	float fres = step(0.55, 1.0 - clamp(dot(n, VIEW), 0.0, 1.0));
	EMISSION = glow_color * (glow * (0.3 + 1.4 * fres) + gold_edge * step(0.5, edge) * 0.9);
}

void light() {
	// Hard bands instead of a smooth falloff: lit, half, shade, and a floor so nothing goes black.
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float b = max(floor(ndl * bands + 0.35) / bands, shadow_floor);
	DIFFUSE_LIGHT += LIGHT_COLOR * b / PI;
	// One sharp square-ish highlight per light, like the white pixels on a sprite.
	vec3 h = normalize(VIEW + LIGHT);
	float s = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 80.0) * ATTENUATION;
	SPECULAR_LIGHT += LIGHT_COLOR * step(0.5, s) * highlight * (1.0 - ROUGHNESS) / PI;
}
