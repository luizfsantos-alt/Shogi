class_name KomaMesh
## Builds the mesh of one koma (shogi piece) in code: a pentagonal wedge, thicker at the base
## than at the tip, with rounded edges and small defects. Every seed gives a different piece.
##
## Units are centimetres. Local axes: X across the piece, Y through its thickness (the front
## face looks up +Y), the tip points to -Z. The wedge is symmetric about Y = 0, so a piece lying
## on the board tilts slightly toward its tip, like a real one (see `rest_tilt`).
##
## Vertex colours carry data for koma.gdshader:
##   r = edge wear (1 on the rounded edges), g = 1 on the front face, b = 1 on the back face.

## Width, length, thickness at the base, thickness at the tip (cm), close to a standard set.
const SIZES := {
	"K": Vector4(2.85, 3.20, 0.95, 0.58),
	"R": Vector4(2.75, 3.10, 0.92, 0.56),
	"B": Vector4(2.75, 3.10, 0.92, 0.56),
	"G": Vector4(2.65, 3.00, 0.88, 0.54),
	"S": Vector4(2.65, 3.00, 0.88, 0.54),
	"N": Vector4(2.55, 2.95, 0.85, 0.52),
	"L": Vector4(2.35, 2.90, 0.82, 0.50),
	"P": Vector4(2.25, 2.80, 0.80, 0.48),
}

const SHOULDER := 0.70     ## shoulders at this fraction of the length, from the base
const SHOULDER_W := 0.92   ## shoulder width relative to the base width
const BEVEL := 0.11        ## radius of the rounded edges
const BEVEL_STEPS := 4
const EDGE_STEP := 0.11    ## spacing of the outline points
const FACE_RINGS := 4      ## inner rings on the faces, so they can be slightly uneven

## Defects. Small on purpose: the piece should look used and handmade, not broken.
const WARP := 0.012        ## faces not perfectly flat
const EDGE_NOISE := 0.018  ## uneven edges
const CHIP_DEPTH := 0.045  ## small chips on the edges
const SIZE_JITTER := 0.008 ## pieces of the same kind differ by up to ~1%


## The pieces are drawn a little larger than a real set, so they read well on a phone.
const SCALE := 1.1

## The pixel look (Koma.pixel) uses thicker pieces with rounder edges: more side wall to shade.
static var thickness := 1.0
static var bevel := BEVEL
## Uneven faces; off in the pixel look, where the banded light would turn them into seams.
static var warp := WARP


static func size_of(kind: String) -> Vector4:
	var s: Vector4 = SIZES[kind] * SCALE
	return Vector4(s.x, s.y, s.z * thickness, s.w * thickness)


## Angle (radians, about X) that lays the wedge flat on its back face.
static func rest_tilt(kind: String) -> float:
	var s := size_of(kind)
	return atan(((s.z - s.w) * 0.5) / s.y)


## Height of the piece's centre above the board when it lies flat.
static func rest_height(kind: String) -> float:
	var s := size_of(kind)
	return (s.z * 0.5) * cos(rest_tilt(kind))


static func build(kind: String, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var s := size_of(kind)
	var w := s.x * (1.0 + rng.randf_range(-SIZE_JITTER, SIZE_JITTER))
	var h := s.y * (1.0 + rng.randf_range(-SIZE_JITTER, SIZE_JITTER))
	var t_base := s.z
	var t_tip := s.w

	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.9

	# Outline in 2D (x across, y along the piece, tip at +y), counter-clockwise, rounded corners.
	var corners := PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5),
		Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5 * SHOULDER_W, -h * 0.5 + h * SHOULDER),
		Vector2(0.0, h * 0.5),
		Vector2(-w * 0.5 * SHOULDER_W, -h * 0.5 + h * SHOULDER),
	])
	var radii := [0.16, 0.16, 0.22, 0.14, 0.22]
	var outline := _rounded_outline(corners, radii)
	var normals := _outline_normals(outline)

	# Chips: a few spots on the outline where the edge is worn away.
	var chips: Array[Vector3] = [] # (index along outline, radius in points, depth)
	for i in rng.randi_range(1, 3):
		chips.append(Vector3(rng.randi() % outline.size(), rng.randf_range(2.0, 4.5), CHIP_DEPTH * rng.randf_range(0.5, 1.0)))

	var thickness := func(y: float) -> float:
		return lerp(t_base, t_tip, (y + h * 0.5) / h)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- Rounded edges and side wall: one smooth band all around. -------------------------
	# Profile from the back face edge (bottom) to the front face edge (top), quarter circles.
	var profile: Array[Vector3] = [] # (inset, which face: -1 back / +1 front, angle 0..1)
	for i in BEVEL_STEPS + 1:
		var a := -PI * 0.5 + (PI * 0.5) * i / BEVEL_STEPS
		profile.append(Vector3(bevel * (1.0 - cos(a)), -1.0, sin(a))) # back bevel, sin from -1 to 0
	for i in BEVEL_STEPS + 1:
		var a := (PI * 0.5) * i / BEVEL_STEPS
		profile.append(Vector3(bevel * (1.0 - cos(a)), 1.0, sin(a)))  # front bevel, sin from 0 to 1

	var n := outline.size()
	var rows: Array = []
	for p in profile:
		var row := PackedVector3Array()
		var row_n := PackedVector3Array()
		var row_wear := PackedFloat32Array()
		for i in n:
			var chip := _chip_at(chips, i, n)
			# Edges wear more than flat parts; chips cut into the rounded edge most.
			var edge_weight := 0.4 + 0.6 * absf(p.z)
			var inset := p.x + chip * (0.4 + 0.6 * absf(p.z))
			var pt := outline[i] - normals[i] * inset
			var half := float(thickness.call(pt.y)) * 0.5
			var y := 0.0
			if p.y < 0.0:
				y = -half + bevel + bevel * p.z
			else:
				y = half - bevel + bevel * p.z
			# Uneven edges: push along the outline normal and a little in height.
			var e := noise.get_noise_3d(pt.x * 3.0, y * 3.0, pt.y * 3.0) * EDGE_NOISE * edge_weight
			pt += normals[i] * e
			y += noise.get_noise_2d(pt.x * 2.0 + 17.0, pt.y * 2.0) * warp
			row.append(Vector3(pt.x, y, -pt.y))
			# Analytic normal of the rounded profile (corrected later for the wedge slope).
			var c := cos(asin(clampf(p.z, -1.0, 1.0)))
			var nn := Vector3(normals[i].x * c, p.z, -normals[i].y * c).normalized()
			row_n.append(nn)
			row_wear.append(clampf(1.0 - abs(abs(p.z) - 0.6) * 2.2, 0.0, 1.0) + chip * 12.0)
		rows.append([row, row_n, row_wear])

	for r in rows.size() - 1:
		var a_row: Array = rows[r]
		var b_row: Array = rows[r + 1]
		for i in n:
			var j := (i + 1) % n
			var quad := [[a_row, i], [a_row, j], [b_row, j], [b_row, i]]
			_tri(st, quad[0], quad[2], quad[1], w, h)
			_tri(st, quad[0], quad[3], quad[2], w, h)

	# --- Front and back faces: rings toward the centre, slightly uneven. ------------------
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= outline.size()
	for face in [1.0, -1.0]:
		var edge_row: Array = rows[rows.size() - 1] if face > 0.0 else rows[0]
		var edge_pts: PackedVector3Array = edge_row[0]
		var ring_rows: Array = []
		for k in FACE_RINGS + 1:
			var f := 1.0 - float(k) / FACE_RINGS
			var row := PackedVector3Array()
			for i in n:
				var e := edge_pts[i]
				var p2 := centre + (Vector2(e.x, -e.z) - centre) * f
				var half := float(thickness.call(p2.y)) * 0.5
				var y: float = face * half
				if k > 0:
					y += noise.get_noise_2d(p2.x * 1.3 + face * 31.0, p2.y * 1.3) * warp * 1.5
				else:
					y = e.y
				row.append(Vector3(p2.x, y, -p2.y))
			ring_rows.append(row)
		for k in FACE_RINGS:
			var outer: PackedVector3Array = ring_rows[k]
			var inner: PackedVector3Array = ring_rows[k + 1]
			for i in n:
				var j := (i + 1) % n
				if face > 0.0:
					_face_tri(st, [outer[i], inner[j], outer[j]], face, w, h)
					_face_tri(st, [outer[i], inner[i], inner[j]], face, w, h)
				else:
					_face_tri(st, [outer[i], outer[j], inner[j]], face, w, h)
					_face_tri(st, [outer[i], inner[j], inner[i]], face, w, h)

	st.index()
	st.generate_tangents()
	return st.commit()


## Adds a triangle of the edge band, with smooth profile normals.
static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, w: float, h: float) -> void:
	for v in [a, b, c]:
		var row: Array = v[0]
		var i: int = v[1]
		var p: Vector3 = row[0][i]
		st.set_normal(row[1][i])
		st.set_color(Color(clampf(row[2][i], 0.0, 1.0), 0.0, 0.0))
		st.set_uv(_face_uv(p, 1.0, w, h))
		st.add_vertex(p)


## Adds a triangle of a flat face, with the face normal (keeps the uneven surface visible).
static func _face_tri(st: SurfaceTool, pts: Array, face: float, w: float, h: float) -> void:
	var nrm: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	if nrm.y * face < 0.0:
		nrm = -nrm
	var col := Color(0.0, 1.0, 0.0) if face > 0.0 else Color(0.0, 0.0, 1.0)
	for p in pts:
		st.set_normal(nrm)
		st.set_color(col)
		st.set_uv(_face_uv(p, face, w, h))
		st.add_vertex(p)


## Texture coordinates on a face: the engraving image covers the piece's outline box, tip at
## the top of the image. The back face is mirrored so it reads correctly once the piece flips.
static func _face_uv(p: Vector3, face: float, w: float, h: float) -> Vector2:
	var u := (p.x + w * 0.5) / w
	if face < 0.0:
		u = 1.0 - u
	return Vector2(u, (p.z + h * 0.5) / h)


static func _chip_at(chips: Array[Vector3], i: int, n: int) -> float:
	var depth := 0.0
	for c in chips:
		var d := absf(float(i) - c.x)
		d = minf(d, n - d)
		if d < c.y:
			depth = maxf(depth, c.z * (0.5 + 0.5 * cos(PI * d / c.y)))
	return depth


## Polygon with rounded corners, resampled every EDGE_STEP.
static func _rounded_outline(corners: PackedVector2Array, radii: Array) -> PackedVector2Array:
	var arcs: Array = [] # per corner: [start point, end point, arc points]
	var m := corners.size()
	for i in m:
		var p := corners[i]
		var d_prev := (corners[(i - 1 + m) % m] - p).normalized()
		var d_next := (corners[(i + 1) % m] - p).normalized()
		var half := d_prev.angle_to(d_next) * 0.5
		var r: float = radii[i]
		var dist := r / tan(absf(half))
		var bis := (d_prev + d_next).normalized()
		var centre := p + bis * (r / sin(absf(half)))
		var a0 := (p + d_prev * dist - centre).angle()
		var a1 := (p + d_next * dist - centre).angle()
		var sweep := wrapf(a1 - a0, -PI, PI)
		var steps := maxi(3, int(ceil(absf(sweep) * r / EDGE_STEP)) + 2)
		var pts := PackedVector2Array()
		for k in steps + 1:
			var a := a0 + sweep * k / steps
			pts.append(centre + Vector2(cos(a), sin(a)) * r)
		arcs.append(pts)
	var out := PackedVector2Array()
	for i in m:
		var arc: PackedVector2Array = arcs[i]
		out.append_array(arc)
		var a := arc[arc.size() - 1]
		var next_arc: PackedVector2Array = arcs[(i + 1) % m]
		var b := next_arc[0]
		var steps := int(a.distance_to(b) / EDGE_STEP)
		for k in range(1, steps):
			out.append(a.lerp(b, float(k) / steps))
	return out


## Outward normals of a counter-clockwise outline.
static func _outline_normals(outline: PackedVector2Array) -> PackedVector2Array:
	var n := outline.size()
	var out := PackedVector2Array()
	for i in n:
		var t := outline[(i + 1) % n] - outline[(i - 1 + n) % n]
		out.append(Vector2(t.y, -t.x).normalized())
	return out
