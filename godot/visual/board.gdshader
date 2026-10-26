// The board: a thick block of kaya with the grid in black lacquer and the four star points.
// Lines are drawn from the local position on the top face; the grid size comes from Table.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 wood_light : source_color = vec3(0.80, 0.52, 0.24);
uniform vec3 wood_dark : source_color = vec3(0.56, 0.32, 0.12);
uniform vec3 line_color : source_color = vec3(0.04, 0.03, 0.02);
uniform vec2 cell = vec2(3.33, 3.64);   // cm, a real board's squares are a bit taller than wide
uniform float line_width = 0.07;
uniform float star_radius = 0.16;
uniform float gloss : hint_range(0.0, 1.0) = 0.55;
uniform bool draw_grid = true;  // off for the komadai, same wood

varying vec3 lpos;
varying vec3 lnormal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
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
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	lpos = VERTEX;
	lnormal = NORMAL;
}

void fragment() {
	// Straight grain running along the files (z), with slow waves.
	float warp = fbm(lpos * vec3(0.12, 0.3, 0.03)) * 3.0;
	float lines = 0.5 + 0.5 * sin((lpos.x + warp) * 4.2);
	lines = pow(lines, 4.0);
	float fine = fbm(lpos * vec3(6.0, 6.0, 0.4));
	float patch = fbm(lpos * 0.08 + 3.0);
	vec3 albedo = mix(wood_dark, wood_light, clamp(0.8 - 0.3 * lines + 0.3 * (fine - 0.5) + 0.4 * (patch - 0.5), 0.0, 1.0));
	float rough = 0.42;
	float coat = gloss;

	bool top = draw_grid && lnormal.y > 0.9;
	if (top) {
		// Grid: 10 lines each way, centred on the board.
		vec2 p = lpos.xz + cell * 4.5;
		vec2 d = abs(p - round(p / cell) * cell);
		vec2 inside = step(vec2(-0.01), p) * step(p, cell * 9.0 + 0.01);
		float on_line = max(step(d.x, line_width * 0.5) * inside.y, step(d.y, line_width * 0.5) * inside.x);
		// Star points where lines 3 and 6 cross.
		vec2 sp = lpos.xz;
		vec2 star = vec2(1.5) * cell;
		float st = step(length(abs(sp) - star), star_radius);
		float ink = max(on_line, st);
		albedo = mix(albedo, line_color, ink * 0.92);
		rough = mix(rough, 0.25, ink);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.18;
	SPECULAR = 0.5;
}
