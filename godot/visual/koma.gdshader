// Material of a koma: boxwood with a varnished gloss, the kanji carved into the face with
// lacquer at the bottom of the groove, worn edges and fine scratches.
// Vertex colours from KomaMesh: r = edge wear, g = front face, b = back face.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D kanji_front : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D kanji_back : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;

group_uniforms wood;
uniform vec3 wood_light : source_color = vec3(0.93, 0.77, 0.50);
uniform vec3 wood_dark : source_color = vec3(0.72, 0.52, 0.28);
uniform vec3 wear_color : source_color = vec3(0.97, 0.84, 0.60);
uniform float grain_scale = 22.0;
uniform float seed = 0.0;

group_uniforms finish;
uniform float roughness_wood : hint_range(0.0, 1.0) = 0.38;
uniform float gloss : hint_range(0.0, 1.0) = 0.9;          // clear varnish over the wood
uniform float gloss_roughness : hint_range(0.0, 1.0) = 0.06;
uniform float scratches : hint_range(0.0, 1.0) = 0.5;
uniform float wear : hint_range(0.0, 1.0) = 0.6;

group_uniforms engraving;
uniform vec3 ink_front : source_color = vec3(0.035, 0.025, 0.02);
uniform vec3 ink_back : source_color = vec3(0.98, 0.72, 0.26);  // gold leaf on promoted side
uniform float ink_back_metallic : hint_range(0.0, 1.0) = 1.0;
uniform float carve_depth = 6.0;
uniform float groove_shadow : hint_range(0.0, 1.0) = 0.55;

group_uniforms glow;
uniform vec3 glow_color : source_color = vec3(1.0, 0.75, 0.3);
uniform float glow = 0.0;        // selection / promotion
uniform float gold_edge = 0.0;   // gold rim of promoted pieces
uniform float rim = 0.25;

varying vec3 lpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3) + seed * 0.0137);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
	               mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
	               mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Straight grain along the piece (masame), gently wavy.
float grain(vec3 p) {
	float warp = fbm(p * vec3(0.6, 0.6, 0.18) + seed) * 0.9;
	float lines = sin((p.x + warp) * grain_scale + seed * 3.1);
	lines = lines * 0.5 + 0.5;
	lines = pow(lines, 3.0);                       // thin dark late-wood lines
	float fine = fbm(p * vec3(18.0, 18.0, 1.2));
	float patch = fbm(p * 0.7 + seed * 5.0);       // slow colour changes across the piece
	return clamp(0.78 - 0.32 * lines + 0.25 * (fine - 0.5) + 0.35 * (patch - 0.5), 0.0, 1.0);
}

// Thin scratches: stretched noise lines at a few angles.
float scratch(vec2 p) {
	float s = 0.0;
	for (int i = 0; i < 3; i++) {
		float a = seed * 1.7 + float(i) * 2.1;
		vec2 d = vec2(cos(a), sin(a));
		vec2 q = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
		float line = vnoise(vec3(q.x * 0.6, q.y * 38.0, float(i) + seed));
		float len = vnoise(vec3(q.x * 1.3, q.y * 2.0, float(i) * 7.0 + seed));
		s = max(s, smoothstep(0.93, 0.99, line) * smoothstep(0.55, 0.8, len));
	}
	return s;
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float front = COLOR.g;
	float back = COLOR.b;
	float edge = clamp(COLOR.r, 0.0, 1.0);

	// Wood.
	float g = grain(lpos);
	vec3 albedo = mix(wood_dark, wood_light, g);
	albedo *= 0.94 + 0.12 * fbm(lpos * 1.7 + seed);
	albedo = mix(albedo, wear_color, edge * wear * 0.7);
	float rough = roughness_wood + edge * wear * 0.25;
	float coat = gloss * (1.0 - edge * wear * 0.6);
	float coat_rough = gloss_roughness;
	float metal = 0.0;

	// Scratches and tiny dents on the faces catch the light of the varnish.
	float sc = scratch(lpos.xz) * scratches * (front + back);
	coat_rough = mix(coat_rough, 0.55, sc);
	albedo = mix(albedo, wear_color, sc * 0.35);
	vec3 n = NORMAL;
	float dent = fbm(lpos * 6.0 + seed * 2.0);
	vec3 dent_grad = vec3(dFdx(dent), dFdy(dent), 0.0);
	n = normalize(n + (TANGENT * dent_grad.x + BINORMAL * dent_grad.y) * 0.6 * (front + back));

	// Engraving: the mask is the depth of the cut (1 = bottom of the groove).
	if (front + back > 0.5) {
		bool is_back = back > 0.5;
		vec2 texel = 1.0 / vec2(textureSize(kanji_front, 0));
		float m = is_back ? texture(kanji_back, UV).r : texture(kanji_front, UV).r;
		float mu = is_back ? texture(kanji_back, UV + vec2(texel.x, 0)).r - texture(kanji_back, UV - vec2(texel.x, 0)).r
		                   : texture(kanji_front, UV + vec2(texel.x, 0)).r - texture(kanji_front, UV - vec2(texel.x, 0)).r;
		float mv = is_back ? texture(kanji_back, UV + vec2(0, texel.y)).r - texture(kanji_back, UV - vec2(0, texel.y)).r
		                   : texture(kanji_front, UV + vec2(0, texel.y)).r - texture(kanji_front, UV - vec2(0, texel.y)).r;
		// A carved surface sits lower where the mask is high: its normal leans toward the rise.
		n = normalize(n + (TANGENT * mu + BINORMAL * mv) * carve_depth);
		float wall = clamp(length(vec2(mu, mv)) * 4.0, 0.0, 1.0);
		float ink = smoothstep(0.45, 0.85, m);
		vec3 ink_col = is_back ? ink_back : ink_front;
		albedo = mix(albedo, albedo * (1.0 - groove_shadow), wall);
		albedo = mix(albedo, ink_col, ink);
		rough = mix(rough, is_back ? 0.3 : 0.2, ink);
		metal = mix(metal, is_back ? ink_back_metallic : 0.0, ink);
		coat = mix(coat, is_back ? 0.2 : gloss, ink);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.55;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = coat_rough;
	NORMAL = n;
	RIM = rim;
	RIM_TINT = 0.6;

	float fres = pow(1.0 - clamp(dot(n, VIEW), 0.0, 1.0), 2.5);
	EMISSION = glow_color * (glow * (0.25 + 1.6 * fres) + gold_edge * edge * 0.9);
}
