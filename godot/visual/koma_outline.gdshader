// The dark outline around a koma in the pixel look: the back faces of the piece, pushed out
// along their normals and drawn flat, like the black line around a 16-bit sprite.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec3 outline_color : source_color = vec3(0.05, 0.03, 0.03);
uniform float width = 0.07; // cm

void vertex() {
	// Only the rounded edge band grows; the flat faces (vertex colour g/b) sink inside the piece,
	// or slivers of the hull would show through them as thin dark lines.
	float face = clamp(COLOR.g + COLOR.b, 0.0, 1.0);
	VERTEX += NORMAL * width * (1.0 - 2.0 * face);
}

void fragment() {
	ALBEDO = outline_color;
}
