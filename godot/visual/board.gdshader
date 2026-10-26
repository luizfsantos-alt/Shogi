// The board: a thick block of kaya with the grid in black lacquer and the four star points.
// Lines are drawn from the local position on the top face; the grid size comes from Table.
// The grain comes from one shared noise texture, cheap enough for phones.
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
// Pixel look (proposal): > 0 snaps the wood and the grid to texels of this size (cm) and draws
// the grain in a few flat tones, so the board matches the pixel kanji on the pieces.
uniform float pixel_size = 0.0;
// In the pixel look the board is a slab of stone: four greys, dithered where they meet, a few
// cracks, and the grid cut into it (dark groove, lit lower lip).
uniform vec3 px_stone_0 : source_color = vec3(0.13, 0.135, 0.15);
uniform vec3 px_stone_1 : source_color = vec3(0.19, 0.195, 0.215);
uniform vec3 px_stone_2 : source_color = vec3(0.25, 0.25, 0.27);
uniform vec3 px_stone_3 : source_color = vec3(0.32, 0.31, 0.32);
uniform vec3 px_line : source_color = vec3(0.07, 0.07, 0.09);
uniform vec3 px_lip : source_color = vec3(0.45, 0.43, 0.41);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 lpos;
varying vec3 lnormal;

float tap(vec2 p) {
	return texture(noise_tex, p).r;
}

void vertex() {
	lpos = VERTEX;
	lnormal = NORMAL;
}

void fragment() {
	bool pixel = pixel_size > 0.0;
	vec3 lp = pixel ? (floor(lpos / pixel_size) + 0.5) * pixel_size : lpos;
	// Straight grain running along the files (z), with slow waves.
	// The side faces use y in place of the missing direction.
	vec2 p2 = vec2(lp.x + lp.y * 0.7, lp.z + lp.y * 0.3);
	float warp = tap(p2 * vec2(0.02, 0.006)) * 6.0;
	float lines = 0.5 + 0.5 * sin((p2.x + warp) * 4.2);
	lines = lines * lines * lines * lines;
	float fine = tap(p2 * vec2(0.6, 0.04));
	float patch = tap(p2 * 0.012 + 0.37);
	float grain = clamp(0.8 - 0.3 * lines + 0.3 * (fine - 0.5) + 0.4 * (patch - 0.5), 0.0, 1.0);
	vec3 albedo = mix(wood_dark, wood_light, grain);
	if (pixel) {
		// Stone: broad patches and a fine mottle, 2×2 ordered dither, then one of four greys.
		vec2 sp2 = vec2(lp.x + lp.y * 0.7, lp.z + lp.y * 0.3);
		float patches = tap(sp2 * 0.015 + 0.21);
		float mottle = tap(sp2 * 0.11 + 0.63);
		float stone = clamp(0.5 + (patches - 0.5) * 0.8 + (mottle - 0.5) * 0.6, 0.0, 1.0);
		vec2 cellp = mod(floor(vec2(lpos.x + lpos.y, lpos.z) / pixel_size), 2.0);
		float bayer = (cellp.x * 2.0 + cellp.y * 3.0 - cellp.x * cellp.y * 4.0) / 4.0 - 0.375;
		float g = clamp(stone + bayer * 0.2, 0.0, 0.999) * 4.0;
		albedo = g < 1.0 ? px_stone_0 : (g < 2.0 ? px_stone_1 : (g < 3.0 ? px_stone_2 : px_stone_3));
		// Cracks: the thin valleys of a ridged noise, one texel wide.
		float ridge = abs(tap(sp2 * 0.022 + 0.47) - 0.5);
		albedo = mix(albedo, px_line, step(ridge, 0.008) * 0.85);
	}
	float rough = pixel ? 0.6 : 0.42;
	float coat = pixel ? 0.0 : gloss;

	bool top = draw_grid && lnormal.y > 0.9;
	if (top) {
		// Grid: 10 lines each way, centred on the board.
		vec2 p = lp.xz + cell * 4.5;
		vec2 d = abs(p - round(p / cell) * cell);
		vec2 inside = step(vec2(-0.01), p) * step(p, cell * 9.0 + 0.01);
		// In the pixel look a line is one texel wide, whatever line_width says.
		float half_w = pixel ? pixel_size * 0.5 : line_width * 0.5;
		float on_line = max(step(d.x, half_w) * inside.y, step(d.y, half_w) * inside.x);
		// Star points where lines 3 and 6 cross (square ones in the pixel look).
		vec2 sp = lp.xz;
		vec2 star = vec2(1.5) * cell;
		vec2 sd = abs(abs(sp) - star);
		float st = pixel ? step(max(sd.x, sd.y), pixel_size * 1.1) : step(length(abs(sp) - star), star_radius);
		float ink = max(on_line, st);
		albedo = mix(albedo, pixel ? px_line : line_color, ink * 0.92);
		if (pixel) {
			// The lit lower lip of the cut, one texel toward the player.
			vec2 pl = p - vec2(0.0, pixel_size);
			vec2 dl = abs(pl - round(pl / cell) * cell);
			float lip = step(dl.y, half_w) * inside.x * (1.0 - ink);
			albedo = mix(albedo, px_lip, lip);
		}
		rough = mix(rough, 0.25, ink);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.18;
	SPECULAR = 0.5;
}
