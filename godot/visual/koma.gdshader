// Material of a koma: glossy lacquer. Sente (moves first) is pearl, Gote red lacquer; the ink
// of the front face has one colour per kind (Koma.INK), the same on both teams. `team` goes
// from 0 (pearl) to 1 (red), so a captured piece can change colour on its way to the other side.
// The promoted face carries gold ink on both teams.
// The kanji is carved into the face, with the ink at the bottom of the groove.
// Vertex colours from KomaMesh: r = edge wear, g = front face, b = back face.
// All the noise comes from one small shared texture: cheap on phones.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D kanji_front : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D kanji_back : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

uniform float team : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

group_uniforms pearl;
uniform vec3 pearl_base : source_color = vec3(0.93, 0.91, 0.87);
uniform vec3 pearl_tint_a : source_color = vec3(1.0, 0.86, 0.9);   // pink sheen
uniform vec3 pearl_tint_b : source_color = vec3(0.8, 0.92, 1.0);   // blue-green sheen
uniform float pearl_iridescence : hint_range(0.0, 1.0) = 0.55;

group_uniforms lacquer;
uniform vec3 red_base : source_color = vec3(0.56, 0.035, 0.025);
uniform vec3 red_deep : source_color = vec3(0.3, 0.01, 0.01);

group_uniforms ink;
uniform vec3 ink_kind : source_color = vec3(0.02, 0.018, 0.016);  // front face: Koma.INK, by kind
uniform vec3 ink_gold : source_color = vec3(1.0, 0.74, 0.3);
uniform float carve_depth = 6.0;
uniform float groove_shadow : hint_range(0.0, 1.0) = 0.45;

group_uniforms finish;
uniform float gloss : hint_range(0.0, 1.0) = 1.0;
uniform float gloss_roughness : hint_range(0.0, 1.0) = 0.05;
uniform float scratches : hint_range(0.0, 1.0) = 0.5;
uniform float wear : hint_range(0.0, 1.0) = 0.5;

group_uniforms glow;
uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.3);
uniform float glow = 0.0;        // selection
uniform float gold_edge = 0.0;   // gold rim of promoted pieces

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

	// Lacquer colour: pearl with a sheen that shifts with the viewing angle, or deep red.
	float cos_v = clamp(dot(n, VIEW), 0.0, 1.0);
	float swirl = tap(lpos.xz * 0.09 + lpos.y * 0.05);
	vec3 sheen = mix(pearl_tint_a, pearl_tint_b, clamp(swirl * 1.6 - 0.3 + (1.0 - cos_v), 0.0, 1.0));
	vec3 pearl = mix(pearl_base, pearl_base * sheen, pearl_iridescence * (0.4 + 0.6 * (1.0 - cos_v)));
	vec3 red = mix(red_base, red_deep, clamp(swirl * 0.8 + (1.0 - cos_v) * 0.5, 0.0, 1.0));
	vec3 albedo = mix(pearl, red, team);

	// Worn edges show a little of the layer under the lacquer.
	vec3 under = mix(vec3(0.75, 0.68, 0.58), vec3(0.32, 0.08, 0.04), team);
	albedo = mix(albedo, under, edge * wear * 0.35);
	float rough = mix(0.22, 0.28, team) + edge * wear * 0.2;
	float coat = gloss * (1.0 - edge * wear * 0.4);
	float coat_rough = gloss_roughness;

	// Fine scratches on the faces: thin bright lines in the noise.
	float sc = smoothstep(0.86, 0.95, tap(lpos.xz * vec2(0.06, 0.9))) * scratches * face;
	coat_rough = mix(coat_rough, 0.45, sc);
	albedo = mix(albedo, albedo * 1.12 + 0.03, sc * 0.5);

	float metal = 0.0;
	if (face > 0.5) {
		bool is_back = back > 0.5;
		vec2 texel = 1.0 / vec2(textureSize(kanji_front, 0));
		float m, mu, mv;
		if (is_back) {
			m = texture(kanji_back, UV).r;
			mu = texture(kanji_back, UV + vec2(texel.x, 0)).r - texture(kanji_back, UV - vec2(texel.x, 0)).r;
			mv = texture(kanji_back, UV + vec2(0, texel.y)).r - texture(kanji_back, UV - vec2(0, texel.y)).r;
		} else {
			m = texture(kanji_front, UV).r;
			mu = texture(kanji_front, UV + vec2(texel.x, 0)).r - texture(kanji_front, UV - vec2(texel.x, 0)).r;
			mv = texture(kanji_front, UV + vec2(0, texel.y)).r - texture(kanji_front, UV - vec2(0, texel.y)).r;
		}
		// A carved surface sits lower where the mask is high: its normal leans toward the rise.
		n = normalize(n + (TANGENT * mu + BINORMAL * mv) * carve_depth);
		float wall = clamp(length(vec2(mu, mv)) * 4.0, 0.0, 1.0);
		float ink = smoothstep(0.45, 0.85, m);
		// The front face carries its kind's colour on both teams; every promoted face is gold.
		float gold = is_back ? 1.0 : 0.0;
		vec3 ink_col = is_back ? ink_gold : ink_kind;
		albedo = mix(albedo, albedo * (1.0 - groove_shadow), wall);
		albedo = mix(albedo, ink_col, ink);
		rough = mix(rough, mix(0.18, 0.3, gold), ink);
		metal = mix(metal, gold, ink);
		coat = mix(coat, mix(gloss, 0.25, gold), ink);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.6;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = coat_rough;
	NORMAL = n;

	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.5);
	EMISSION = glow_color * (glow * (0.25 + 1.6 * fres) + gold_edge * edge * 0.9);
}
