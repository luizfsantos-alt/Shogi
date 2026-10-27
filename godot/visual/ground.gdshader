// The table under the board. Lacquer look: dark varnished wood, flat. Pixel look: a floor of
// near-black flagstones in big texels (twice the board's), mortar between them and a dithered
// mottle, kept so dark that the kaya board stands out as the brightest thing on screen.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

global uniform float pixel_look;
uniform vec3 wood : source_color = vec3(0.16, 0.09, 0.055);
uniform vec3 stone_0 : source_color = vec3(0.028, 0.026, 0.025);
uniform vec3 stone_1 : source_color = vec3(0.036, 0.033, 0.031);
uniform vec3 stone_2 : source_color = vec3(0.045, 0.041, 0.038);
uniform vec3 mortar : source_color = vec3(0.016, 0.014, 0.013);
uniform float texel = 0.42;         // cm
uniform vec2 slab = vec2(15.0, 10.0); // cm, one flagstone, rows offset by half
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (pixel_look < 0.5) {
		ALBEDO = wood;
		ROUGHNESS = 0.55;
		CLEARCOAT = 0.4;
	} else {
		vec2 cell = floor(lpos.xz / texel);
		vec2 p = (cell + 0.5) * texel;
		float row = floor(p.y / slab.y);
		vec2 q = vec2(p.x + mod(row, 2.0) * slab.x * 0.5, p.y);
		vec2 id = floor(q / slab);
		vec2 in_slab = q - id * slab;
		float joint = step(min(in_slab.x, in_slab.y), texel * 1.01);
		float tone = hash(id) * 0.6 + texture(noise_tex, p * 0.03 + id * 0.17).r * 0.7 - 0.15;
		vec2 c2 = mod(cell, 2.0);
		float bayer = (c2.x * 2.0 + c2.y * 3.0 - c2.x * c2.y * 4.0) / 4.0 - 0.375;
		float g = clamp(tone + bayer * 0.25, 0.0, 0.999) * 3.0;
		vec3 col = g < 1.0 ? stone_0 : (g < 2.0 ? stone_1 : stone_2);
		ALBEDO = mix(col, mortar, joint);
		ROUGHNESS = 0.85;
	}
}
