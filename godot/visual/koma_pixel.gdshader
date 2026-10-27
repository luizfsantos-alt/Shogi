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
uniform vec3 pearl_light : source_color = vec3(0.86, 0.84, 0.8);
uniform vec3 pearl_base : source_color = vec3(0.78, 0.75, 0.7);
uniform vec3 pearl_tint : source_color = vec3(0.86, 0.84, 0.95);
uniform vec3 red_light : source_color = vec3(0.72, 0.1, 0.07);
uniform vec3 red_base : source_color = vec3(0.56, 0.05, 0.035);
uniform vec3 ink_kind : source_color = vec3(0.07, 0.04, 0.03);  // front face: Koma.INK, by kind
uniform vec3 ink_promoted : source_color = vec3(0.78, 0.1, 0.04); // promoted Sente: red
uniform vec3 ink_gold : source_color = vec3(1.0, 0.78, 0.3);      // promoted Gote: gold
uniform float texels_per_cm = 9.5;   // the grid of the sheen and the edges, close to the mask's
uniform float carve_depth = 0.9;
uniform float ink_bevel : hint_range(0.0, 1.0) = 0.6;   // raised ink: lit top-left rim, dark lower-right rim
uniform float ink_shadow : hint_range(0.0, 1.0) = 0.35;  // the shadow the raised ink casts on the lacquer

group_uniforms pearl;
// Mother-of-pearl on the Sente pieces: the colour slides between pink, lavender and mint with
// the angle you see the face from, in flat steps like the rest of the sprite.
uniform vec3 nacre_pink : source_color = vec3(1.0, 0.72, 0.84);
uniform vec3 nacre_lilac : source_color = vec3(0.74, 0.77, 1.0);
uniform vec3 nacre_mint : source_color = vec3(0.72, 0.97, 0.86);
uniform float nacre : hint_range(0.0, 1.0) = 0.6;
// The table light is strong enough to clip white lacquer: pearl is kept lower so its hues show.
uniform float pearl_exposure : hint_range(0.3, 1.0) = 0.7;
// Satin: a broad soft sheen under the sharp highlight, stronger on pearl than on red lacquer.
uniform float satin_pearl : hint_range(0.0, 2.0) = 0.7;
uniform float satin_red : hint_range(0.0, 2.0) = 0.22;

group_uniforms shading;
uniform float bands = 3.0;
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.22;
uniform float highlight : hint_range(0.0, 2.0) = 0.9;

group_uniforms glow;
uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.3);
uniform float glow = 0.0;
uniform float gold_edge = 0.0;

varying vec3 lpos;
varying vec3 v_sheen;  // colour of the satin sheen: warm on red, the nacre hue on pearl

void vertex() {
	lpos = VERTEX;
}

// The kanji mask of a face (front or promoted back) at a texel.
float mask_at(bool is_back, vec2 uv) {
	return is_back ? texture(kanji_back, uv).r : texture(kanji_front, uv).r;
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
	// Nacre: hue from the viewing angle and the swirl, snapped to three steps.
	float pearl_side = 1.0 - step(0.5, team);
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float hue = fract(facing * 1.5 + swirl * 2.2 + (cell_pos.x + cell_pos.z) * 0.06);
	float step3 = floor(hue * 3.0);
	vec3 nacre_col = step3 < 0.5 ? nacre_pink : (step3 < 1.5 ? nacre_lilac : nacre_mint);
	albedo *= mix(vec3(1.0), nacre_col, nacre * pearl_side) * mix(1.0, pearl_exposure, pearl_side);
	// The sheen carries the nacre hue, pushed further from white so it shows on the lit face.
	vec3 nacre_sheen = mix(vec3(1.0), clamp((nacre_col - 0.86) * 3.0 + 0.86, 0.0, 1.0), nacre);
	v_sheen = mix(vec3(1.0, 0.55, 0.45), nacre_sheen, pearl_side);

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
		// Raised texels: the edge of a stroke leans away from it and catches the light on one side.
		n = normalize(n - (TANGENT * mu + BINORMAL * mv) * carve_depth * m);
		float ink = step(0.5, m);
		vec3 ink_col = is_back ? mix(ink_promoted, ink_gold, step(0.5, team)) : ink_kind;
		// The ink stands out like a lacquered relief, shaded texel by texel as on a sprite: the
		// texels on its upper-left rim catch the light, those on the lower-right rim fall in shade,
		// and the lacquer just below and to the right of a stroke gets a one-texel drop shadow.
		float above = step(0.5, mask_at(is_back, cell_uv - t));
		float below = step(0.5, mask_at(is_back, cell_uv + t));
		float lit_rim = ink * (1.0 - above);
		float dark_rim = ink * (1.0 - below) * (1.0 - lit_rim);
		ink_col = mix(ink_col, ink_col * 1.35 + vec3(0.05), lit_rim * ink_bevel);
		ink_col = mix(ink_col, ink_col * 0.55, dark_rim * ink_bevel);
		albedo = mix(mix(albedo, albedo * vec3(0.45, 0.42, 0.4), above * ink_shadow), ink_col, ink);
		rough = mix(rough, 0.28, ink);
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
	// Satin: a wide sheen in two flat steps, so the lacquer glows over the whole lit side.
	float sheen = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 6.0) * ATTENUATION;
	float satin = mix(satin_pearl, satin_red, step(0.5, team));
	SPECULAR_LIGHT += LIGHT_COLOR * v_sheen * (step(0.4, sheen) * 0.16 + step(0.7, sheen) * 0.2) * satin / PI;
}
