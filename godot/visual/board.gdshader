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
// In the pixel look the board is kaya in pixels: the same grain in four warm tones, dithered
// where they meet, and the grid drawn in flat dark lines (no lit lip: it read as raised bars).
uniform vec3 px_wood_0 : source_color = vec3(0.27, 0.14, 0.06);
uniform vec3 px_wood_1 : source_color = vec3(0.32, 0.175, 0.075);
uniform vec3 px_wood_2 : source_color = vec3(0.37, 0.21, 0.095);
uniform vec3 px_wood_3 : source_color = vec3(0.42, 0.25, 0.115);
uniform vec3 px_line : source_color = vec3(0.05, 0.03, 0.018);
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
		// Kaya: the grain snapped to one of four tones through a 2×2 ordered dither.
		vec2 cellp = mod(floor(vec2(lpos.x + lpos.y, lpos.z) / pixel_size), 2.0);
		float bayer = (cellp.x * 2.0 + cellp.y * 3.0 - cellp.x * cellp.y * 4.0) / 4.0 - 0.375;
		float g = clamp(grain + bayer * 0.25, 0.0, 0.999) * 4.0;
		albedo = g < 1.0 ? px_wood_0 : (g < 2.0 ? px_wood_1 : (g < 3.0 ? px_wood_2 : px_wood_3));
	}
	float rough = pixel ? 0.6 : 0.42;
	float coat = pixel ? 0.0 : gloss;

	bool top = draw_grid && lnormal.y > 0.9;
	if (top) {
		// Grid: 10 lines each way, centred on the board.
		vec2 p = lp.xz + cell * 4.5;
		vec2 d = abs(p - round(p / cell) * cell);
		vec2 inside = step(vec2(-0.01), p) * step(p, cell * 9.0 + 0.01);
		float on_line;
		if (pixel) {
			// In the pixel look a line is exactly one texel wide, whatever line_width says: the
			// texel that holds the line, picked by index. Comparing the distance to half a texel
			// lost whole lines that fall on a texel border (between ranks f and g) to rounding.
			highp vec2 q = lpos.xz + cell * 4.5;
			highp vec2 line_texel = floor((round(q / cell) * cell - cell * 4.5) / pixel_size);
			vec2 hit = step(abs(floor(lpos.xz / pixel_size) - line_texel), vec2(0.5));
			on_line = max(hit.x * inside.y, hit.y * inside.x);
		} else {
			float half_w = line_width * 0.5;
			on_line = max(step(d.x, half_w) * inside.y, step(d.y, half_w) * inside.x);
		}
		// Star points where lines 3 and 6 cross (square ones in the pixel look).
		vec2 sp = lp.xz;
		vec2 star = vec2(1.5) * cell;
		vec2 sd = abs(abs(sp) - star);
		float st = pixel ? step(max(sd.x, sd.y), pixel_size * 1.1) : step(length(abs(sp) - star), star_radius);
		float ink = max(on_line, st);
		albedo = mix(albedo, pixel ? px_line : line_color, ink * 0.92);
		rough = mix(rough, 0.25, ink);
	}

	ALBEDO = albedo;
	ROUGHNESS = rough;
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.18;
	SPECULAR = 0.5;
}
