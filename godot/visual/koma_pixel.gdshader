// The pixel look of a koma (the default, see DECISIONS.md "Visual pixel"): the same lacquer as
// koma.gdshader, but everything on its surface is drawn in whole texels, like a 16-bit sprite.
// The kanji (red) and the movement marks (green) come from a 48×54 mask (textures/kanji_px/)
// sampled with nearest filtering, the sheen is posterized, and the light falls in a few hard bands with one
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
// Gote's black lacquer (the classic look keeps it red).
uniform vec3 black_light : source_color = vec3(0.075, 0.07, 0.075);
uniform vec3 black_base : source_color = vec3(0.035, 0.033, 0.036);
uniform vec3 ink_kind : source_color = vec3(0.07, 0.04, 0.03);  // front face: Koma.INK, by kind
uniform vec3 ink_promoted : source_color = vec3(0.78, 0.1, 0.04); // promoted Sente: red
uniform vec3 ink_gold : source_color = vec3(1.0, 0.78, 0.3);      // promoted Gote: gold
uniform float texels_per_cm = 9.5;   // the grid of the sheen and the edges
// Where the table's key light comes from (world space, toward the light): the carved kanji is
// shaded for it, so the groove reads the same on both teams and after the promotion flip.
uniform vec3 light_from = vec3(-0.41, 0.74, 0.53);
uniform float groove_shadow : hint_range(0.0, 1.0) = 0.7;  // the shadow of the groove's wall on the light's side
uniform float groove_light : hint_range(0.0, 1.0) = 0.5;   // the far wall, lit, on the lacquer just past the stroke

group_uniforms pearl;
// Mother-of-pearl on the Sente pieces: the colour slides between pink, lavender and mint with
// the angle you see the face from, in flat steps like the rest of the sprite.
uniform vec3 nacre_pink : source_color = vec3(1.0, 0.72, 0.84);
uniform vec3 nacre_lilac : source_color = vec3(0.74, 0.77, 1.0);
uniform vec3 nacre_mint : source_color = vec3(0.72, 0.97, 0.86);
uniform float nacre : hint_range(0.0, 1.0) = 0.6;
// The table light is strong enough to clip white lacquer: pearl is kept lower so its hues show.
uniform float pearl_exposure : hint_range(0.3, 1.0) = 0.7;
// Satin: a broad soft sheen under the sharp highlight, stronger on pearl than on black lacquer.
uniform float satin_pearl : hint_range(0.0, 2.0) = 0.7;
uniform float satin_black : hint_range(0.0, 2.0) = 0.3;

group_uniforms shading;
uniform float bands = 3.0;
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.22;
uniform float highlight : hint_range(0.0, 2.0) = 0.9;

group_uniforms glow;
uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.3);
uniform float glow = 0.0;
uniform float gold_edge = 0.0;

varying vec3 lpos;
varying vec3 v_sheen;  // colour of the satin sheen: cool on black, the nacre hue on pearl
varying float v_ink;   // 1 on the carved kanji: no highlight or sheen there, so its colour stays
varying float v_up;    // the normal's height in the piece's own space: + on the front, - on the back

void vertex() {
	lpos = VERTEX;
	v_up = NORMAL.y;
}

// The carving of a face (front or promoted back) at a texel: r = the kanji, g = a movement mark.
vec2 carving_at(bool is_back, vec2 uv) {
	return is_back ? texture(kanji_back, uv).rg : texture(kanji_front, uv).rg;
}

float mask_at(bool is_back, vec2 uv) {
	vec2 m = carving_at(is_back, uv);
	return max(m.r, m.g);
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
	vec3 black = tone > 1.5 ? black_light : black_base;
	vec3 albedo = mix(pearl, black, step(0.5, team));
	// Worn edges: the wood under the lacquer, in a single darker tone.
	vec3 under = mix(vec3(0.62, 0.5, 0.38), vec3(0.2, 0.12, 0.07), step(0.5, team));
	albedo = mix(albedo, under, step(0.55, edge * 0.7 + tap(cell_pos.xz * 0.5) * 0.3) * 0.6);
	float rough = 0.35;
	v_ink = 0.0;
	// Nacre: hue from the viewing angle and the swirl, snapped to three steps.
	float pearl_side = 1.0 - step(0.5, team);
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float hue = fract(facing * 1.5 + swirl * 2.2 + (cell_pos.x + cell_pos.z) * 0.06);
	float step3 = floor(hue * 3.0);
	vec3 nacre_col = step3 < 0.5 ? nacre_pink : (step3 < 1.5 ? nacre_lilac : nacre_mint);
	albedo *= mix(vec3(1.0), nacre_col, nacre * pearl_side) * mix(1.0, pearl_exposure, pearl_side);
	// The sheen carries the nacre hue, pushed further from white so it shows on the lit face; on
	// black lacquer it is a cool neutral, so the black does not turn brown under the warm light.
	vec3 nacre_sheen = mix(vec3(1.0), clamp((nacre_col - 0.86) * 3.0 + 0.86, 0.0, 1.0), nacre);
	v_sheen = mix(vec3(0.78, 0.82, 0.9), nacre_sheen, pearl_side);

	// The movement marks sit on the edge of the face and run onto the top of the rounded edge,
	// which shares the face's texture coordinates; the side wall below it stays bare.
	bool on_bevel = face < 0.5 && abs(v_up) > 0.25;
	if (face > 0.5 || on_bevel) {
		bool is_back = face > 0.5 ? back > 0.5 : v_up < 0.0;
		vec2 t = 1.0 / mask_size;
		// One texel toward the light, on the face: the light seen in the face's own axes, snapped.
		// On the face from its tangents; on the rounded edge, whose tangents follow the curve, from
		// the piece's own axes (u runs along +x, v along +z; the edge is never mirrored).
		vec3 lv = (VIEW_MATRIX * vec4(light_from, 0.0)).xyz;
		vec2 toward = vec2(dot(lv, TANGENT), -dot(lv, BINORMAL));
		if (on_bevel) {
			vec3 lm = inverse(mat3(MODEL_MATRIX)) * light_from;
			toward = lm.xz;
		}
		toward = sign(toward) * step(0.38, abs(toward) / max(length(toward), 1e-4));
		vec2 to_light = toward * t;
		vec2 carved = step(vec2(0.5), carving_at(is_back, cell_uv));
		float ink = max(carved.r, carved.g);
		vec3 ink_col = is_back ? mix(ink_promoted, ink_gold, step(0.5, team)) : ink_kind;
		// The ink lies at the bottom of a groove, shaded texel by texel like a sunken sprite border:
		// the wall on the light's side throws its shadow on the first texel of the stroke, and the
		// far wall, facing the light, shows as a light texel on the lacquer just past the stroke.
		// The rest of the stroke keeps its flat ink, so even the narrow strokes read as one colour.
		// The movement marks are too small for the shadow: it would bite into their round shapes,
		// so they stay solid ink and show their depth by the lit far wall only.
		float shaded = carved.r * (1.0 - step(0.5, mask_at(is_back, cell_uv + to_light)));
		float lit = (1.0 - ink) * step(0.5, mask_at(is_back, cell_uv + to_light));
		ink_col = mix(ink_col, ink_col * 0.45, shaded * groove_shadow);
		albedo = mix(mix(albedo, albedo * 1.25 + vec3(0.05), lit * groove_light), ink_col, ink);
		rough = mix(rough, 0.9, ink);
		v_ink = ink;
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	NORMAL = n;
	// The gold rim of a promoted piece and the selection glow, in flat steps too.
	float fres = step(0.55, 1.0 - clamp(dot(n, VIEW), 0.0, 1.0));
	// The gold rim leaves the carved marks on the edge in their own ink.
	EMISSION = glow_color * (glow * (0.3 + 1.4 * fres) + gold_edge * step(0.5, edge) * (1.0 - v_ink) * 0.9);
}

void light() {
	// Hard bands instead of a smooth falloff: lit, half, shade, and a floor so nothing goes black.
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float b = max(floor(ndl * bands + 0.35) / bands, shadow_floor);
	DIFFUSE_LIGHT += LIGHT_COLOR * b / PI;
	// One sharp square-ish highlight per light, like the white pixels on a sprite.
	vec3 h = normalize(VIEW + LIGHT);
	float s = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 80.0) * ATTENUATION;
	// The ink at the bottom of the groove catches neither: the gloss would wash its colour out.
	SPECULAR_LIGHT += LIGHT_COLOR * step(0.5, s) * highlight * (1.0 - ROUGHNESS) * (1.0 - v_ink) / PI;
	// Satin: a wide sheen in two flat steps, so the lacquer glows over the whole lit side.
	float sheen = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 6.0) * ATTENUATION;
	float satin = mix(satin_pearl, satin_black, step(0.5, team));
	SPECULAR_LIGHT += LIGHT_COLOR * v_sheen * (step(0.4, sheen) * 0.16 + step(0.7, sheen) * 0.2) * satin * (1.0 - v_ink) / PI;
}
