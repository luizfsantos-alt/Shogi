// The vignette of the pixel look: the same darkening toward the corners as the lacquer look's
// gradient, but in a few flat steps with an ordered dither between them, in blocks of screen
// pixels as big as the texels of the board.
shader_type canvas_item;

uniform float block = 4.0;     // screen pixels per dither cell
uniform float start = 0.5;     // where the darkening begins (0 centre, 1 edge)
uniform float strength = 0.75;
uniform vec3 shade : source_color = vec3(0.0);

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / block);
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = (cell + 0.5) * block / res;
	vec2 d = (uv - 0.5) * vec2(res.x / res.y, 1.0);
	float r = length(d) / length(vec2(res.x / res.y, 1.0) * 0.5);
	float v = clamp((r - start) / (1.0 - start), 0.0, 1.0);
	// 4×4 Bayer threshold.
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	float t = (float(m[y * 4 + x]) + 0.5) / 16.0;
	float steps = 4.0;
	float level = floor(v * steps + t) / steps;
	COLOR = vec4(shade, level * strength);
}
