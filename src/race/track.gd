class_name Track
extends Node3D
## Builds a complete race track from a definition: spline road, curbs, shoulders, lego walls,
## elevated skirts, ramps, boost pads, item boxes, start gantry, sky and themed scenery.

const STEP := 2.5
const CURB := 1.2
const WALL_T := 1.0
const CHUNK := 110.0

var def: Dictionary
var theme: Dictionary
var curve: Curve3D
var length := 0.0
var width := 17.0
var shoulder := 5.0
var half_road := 8.5
var half_corridor := 14.7
var ground_y := -0.1
var kill_y := -25.0
var bumps := 0.0
var ramp_offsets: Array = []
var boost_offsets: Array = []
var item_offsets: Array = []
var minimap_pts := PackedVector2Array()
var bounds := Rect2()
var start_lights: Array[StandardMaterial3D] = []
var gravity_scale := 1.0
var is_space := false
var _spinners: Array = []  # [Node3D, speed]

# sampled frame cache
var _s: PackedFloat32Array
var _p: PackedVector3Array
var _r: PackedVector3Array
var _u: PackedVector3Array
var _rng := RandomNumberGenerator.new()


func build(d: Dictionary) -> void:
	def = d
	theme = Tracks.theme(d["theme"])
	width = d["width"]
	shoulder = d["shoulder"]
	half_road = width * 0.5
	half_corridor = half_road + CURB + shoulder
	ground_y = theme.get("ground_y", -0.1)
	kill_y = ground_y - 12.0
	bumps = d.get("bumps", 0.0)
	gravity_scale = d.get("gravity", 1.0)
	is_space = theme.get("space", false)
	_rng.seed = hash(d["id"])
	_make_curve(d["points"])
	_plan_features()
	_sample()
	_build_environment()
	_build_road()
	_build_walls()
	_build_ground()
	_build_start()
	_build_features()
	_build_decor()
	_build_details()


func _process(dt: float) -> void:
	for sp in _spinners:
		var n: Node3D = sp[0]
		n.rotate_object_local(Vector3.UP, float(sp[1]) * dt)


# ------------------------------------------------------------------ curve + queries

func _make_curve(pts: Array) -> void:
	curve = Curve3D.new()
	curve.bake_interval = 0.5
	var n := pts.size()
	for i in n + 1:
		var p: Vector3 = pts[i % n]
		var prev: Vector3 = pts[(i - 1 + n) % n]
		var next: Vector3 = pts[(i + 1) % n]
		var tan := (next - prev) / 6.0
		curve.add_point(p, -tan, tan)
	length = curve.get_baked_length()
	minimap_pts.clear()
	var steps := int(length / 8.0)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in steps:
		var p := curve.sample_baked(length * i / steps, true)
		var v := Vector2(p.x, p.z)
		minimap_pts.append(v)
		mn = Vector2(minf(mn.x, v.x), minf(mn.y, v.y))
		mx = Vector2(maxf(mx.x, v.x), maxf(mx.y, v.y))
	bounds = Rect2(mn, mx - mn)


func bump(s: float) -> float:
	if bumps <= 0.0:
		return 0.0
	s = fposmod(s, length)
	if s < 70.0 or s > length - 50.0:
		return 0.0
	for r in ramp_offsets:
		if absf(s - r) < 30.0:
			return 0.0
	for b in boost_offsets:
		if absf(s - b) < 10.0:
			return 0.0
	for it in item_offsets:
		if absf(s - it) < 8.0:
			return 0.0
	return bumps * (0.5 - 0.5 * cos(s * TAU / 20.0)) * (0.6 + 0.4 * sin(s * TAU / 150.0))


func point_at(s: float) -> Vector3:
	s = fposmod(s, length)
	var p := curve.sample_baked(s, true)
	p.y += bump(s)
	return p


func tangent_at(s: float) -> Vector3:
	return (point_at(s + 1.5) - point_at(s - 1.5)).normalized()


func right_at(s: float) -> Vector3:
	var t := tangent_at(s)
	return Vector3(t.x, 0, t.z).normalized().cross(Vector3.UP).normalized()


func frame_at(s: float) -> Transform3D:
	var t := tangent_at(s)
	var r := Vector3(t.x, 0, t.z).normalized().cross(Vector3.UP).normalized()
	var u := r.cross(t).normalized()
	return Transform3D(Basis(r, u, -t), point_at(s))


func closest_offset(pos: Vector3) -> float:
	return curve.get_closest_offset(pos)


func heading_at(s: float) -> float:
	var t := tangent_at(s)
	return atan2(-t.x, -t.z)


func grid_transform(i: int) -> Transform3D:
	var row := i / 2
	var col := i % 2
	var s := length - 9.0 - row * 7.0
	var lat := (-1.0 if col == 0 else 1.0) * half_road * 0.42 + (1.2 if row % 2 == 1 else -1.2)
	var f := frame_at(s)
	return Transform3D(Basis(Vector3.UP, heading_at(s)), f.origin + f.basis.x * lat + Vector3.UP * 0.6)


func _straightness(s: float) -> float:
	var a := tangent_at(s - 12.0)
	var b := tangent_at(s + 35.0)
	a.y = 0
	b.y = 0
	return a.normalized().angle_to(b.normalized())


func _plan_features() -> void:
	var cands := []
	var s := 70.0
	while s < length - 50.0:
		cands.append({"s": s, "a": _straightness(s)})
		s += 5.0
	cands.sort_custom(func(x, y): return x["a"] < y["a"])
	var taken := []
	ramp_offsets = _pick(cands, int(def.get("ramps", 0)), 0.15, 110.0, taken)
	boost_offsets = _pick(cands, int(def.get("boosts", 0)), 0.25, 80.0, taken)
	item_offsets.clear()
	for f in [0.2, 0.5, 0.8]:
		var at: float = length * f
		for tries in 20:
			var ok := true
			for t in taken:
				if absf(t - at) < 25.0:
					ok = false
			if ok:
				break
			at += 9.0
		item_offsets.append(at)
		taken.append(at)


func _pick(cands: Array, n: int, max_angle: float, spacing: float, taken: Array) -> Array:
	var out := []
	for relax in 3:
		for c in cands:
			if out.size() >= n:
				break
			if c["a"] > max_angle * (1.0 + relax):
				continue
			var ok := true
			for t in taken:
				if absf(t - c["s"]) < spacing:
					ok = false
					break
			if ok:
				out.append(c["s"])
				taken.append(c["s"])
	return out


func _sample() -> void:
	var n := int(ceil(length / STEP))
	_s = PackedFloat32Array()
	_p = PackedVector3Array()
	_r = PackedVector3Array()
	_u = PackedVector3Array()
	for i in n + 1:
		var s := length * i / n
		var f := frame_at(s)
		_s.append(s)
		_p.append(f.origin)
		_r.append(f.basis.x)
		_u.append(f.basis.y)


# ------------------------------------------------------------------ geometry helpers

class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var faces := PackedVector3Array()
	var collide := true

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, nrm: Vector3) -> void:
		_tri(a, b, c, ua, ub, uc, nrm)
		_tri(a, c, d, ua, uc, ud, nrm)

	func _tri(a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, nrm: Vector3) -> void:
		if (b - a).cross(c - a).dot(nrm) > 0.0:
			var t := b
			b = c
			c = t
			var tu := ub
			ub = uc
			uc = tu
		v.append(a)
		v.append(b)
		v.append(c)
		uv.append(ua)
		uv.append(ub)
		uv.append(uc)
		n.append(nrm)
		n.append(nrm)
		n.append(nrm)
		if collide:
			faces.append(a)
			faces.append(b)
			faces.append(c)

	func mesh(mat: Material) -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, mat)
		return m


func _static(faces: PackedVector3Array, group: String) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	if group != "":
		sb.add_to_group(group)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)
	add_child(sb)
	return sb


func _add_mesh(m: Mesh, shadows := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _lat(i: int, l: float) -> Vector3:
	return _p[i] + _r[i] * l


# ------------------------------------------------------------------ builders

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	if is_space:
		sky.sky_material = _space_sky()
	else:
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = theme["sky_top"]
		sm.sky_horizon_color = theme["sky_horizon"]
		sm.ground_horizon_color = theme["sky_horizon"]
		sm.ground_bottom_color = theme["hill"]
		sm.sun_angle_max = 20.0
		sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55 if theme["night"] else 0.45
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = theme["sky_top"].lerp(Color.WHITE, 0.5)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.adjustment_contrast = 1.08
	env.glow_enabled = theme["night"]
	env.glow_intensity = 0.8
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = theme["fog"]
	env.fog_density = float(theme["fog_density"]) * 0.45
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_color = theme["sun"]
	sun.light_energy = theme["sun_energy"]
	sun.shadow_enabled = Game.quality >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0 if Game.quality >= 2 else 70.0
	sun.shadow_bias = 0.08
	add_child(sun)


const SPACE_SKY := """
shader_type sky;
uniform vec3 top_col;
uniform vec3 mid_col;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = mix(mid_col, top_col, smoothstep(0.0, 0.7, abs(d.y)));
	float n = noise(d * 2.5) * 0.55 + noise(d * 6.0) * 0.3 + noise(d * 13.0) * 0.15;
	float neb = smoothstep(0.42, 0.85, n);
	vec3 nebc = mix(vec3(0.95, 0.25, 0.75), vec3(0.25, 0.55, 1.0), noise(d * 1.7 + 5.0));
	col += nebc * neb * 0.5;
	for (int layer = 0; layer < 2; layer++) {
		float sc = layer == 0 ? 55.0 : 110.0;
		vec3 p = d * sc;
		vec3 c = floor(p);
		vec3 f = fract(p) - 0.5;
		float r = hash(c + float(layer) * 31.0);
		if (r > 0.9) {
			vec3 o = vec3(hash(c + 3.1), hash(c + 7.7), hash(c + 1.3)) - 0.5;
			float dist = length(f - o * 0.6);
			float tw = 0.75 + 0.25 * sin(TIME * (2.0 + r * 4.0) + r * 90.0);
			float b = smoothstep(0.16, 0.0, dist) * (0.8 + 14.0 * (r - 0.9)) * tw;
			col += b * mix(vec3(1.0, 0.85, 0.7), vec3(0.7, 0.85, 1.0), hash(c + 9.0));
		}
	}
	COLOR = col;
}
"""


func _space_sky() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SPACE_SKY
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("top_col", Color(theme["sky_top"]))
	m.set_shader_parameter("mid_col", Color(theme["sky_horizon"]))
	return m


func _build_road() -> void:
	var road := Surf.new()
	var curbs := Surf.new()
	var shoulders := Surf.new()
	var skirt := Surf.new()
	skirt.collide = false
	var hr := half_road
	var hc := half_corridor
	var outer := hc + WALL_T
	for i in _s.size() - 1:
		var j := i + 1
		var v0 := _s[i] / width
		var v1 := _s[j] / width
		var n0 := _u[i]
		# asphalt
		road.quad(_lat(i, -hr), _lat(i, hr), _lat(j, hr), _lat(j, -hr), Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1), n0)
		# curbs
		var c0 := _s[i] / 3.2
		var c1 := _s[j] / 3.2
		for sgn in [-1.0, 1.0]:
			curbs.quad(_lat(i, sgn * hr), _lat(i, sgn * (hr + CURB)), _lat(j, sgn * (hr + CURB)), _lat(j, sgn * hr), Vector2(0, c0), Vector2(1, c0), Vector2(1, c1), Vector2(0, c1), n0)
			shoulders.quad(_lat(i, sgn * (hr + CURB)), _lat(i, sgn * outer), _lat(j, sgn * outer), _lat(j, sgn * (hr + CURB)), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, n0)
			# skirt down to the ground (outer face)
			var a := _lat(i, sgn * outer)
			var b := _lat(j, sgn * outer)
			var a2 := Vector3(a.x, ground_y - 1.0, a.z)
			var b2 := Vector3(b.x, ground_y - 1.0, b.z)
			if is_space:  # floating slab instead of a wall down to the ground
				a2 = a - _u[i] * 1.6
				b2 = b - _u[j] * 1.6
			skirt.quad(a, b, b2, a2, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, _r[i] * sgn)
		if is_space:
			var d := _u[i] * 1.6
			var e := _u[j] * 1.6
			skirt.quad(_lat(i, -outer) - d, _lat(i, outer) - d, _lat(j, outer) - e, _lat(j, -outer) - e, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, -n0)
	var road_mat := Tex.mat(Tex.rainbow(), false, Vector3.ONE, 0.22) if is_space else Tex.mat(Tex.road(theme["road"]))
	road_mat.roughness = 0.7
	_add_mesh(road.mesh(road_mat))
	var wc: Array = theme["walls"]
	if is_space:
		_add_mesh(curbs.mesh(Tex.mat(Tex.stripes(Color("#f4f4f4"), Color("#3bc8ff")), false, Vector3.ONE, 0.9)))
		_add_mesh(shoulders.mesh(Tex.mat(Tex.baseplate(theme["shoulder"]), true, Vector3.ONE * 0.5, 0.25)))
		_add_mesh(skirt.mesh(Tex.mat(Tex.stripes(Color("#2a1a6a"), Color("#9b5bff"), 4), true, Vector3.ONE * 0.4, 0.6)), false)
	else:
		_add_mesh(curbs.mesh(Tex.mat(Tex.stripes(wc[0], Color("#f4f4f4") if wc[0] != Color("#f4f4f4") else Color("#c91a09")))))
		_add_mesh(shoulders.mesh(Tex.mat(Tex.baseplate(theme["shoulder"]), true, Vector3.ONE * 0.5)))
		_add_mesh(skirt.mesh(Tex.mat(Tex.bricks(theme["skirt"]), true, Vector3.ONE * 0.25)), true)
	var all := road.faces
	all.append_array(curbs.faces)
	_static(all, "road")
	_static(shoulders.faces, "offroad")


func _build_walls() -> void:
	var hc := half_corridor
	var wc: Array = theme["walls"]
	var col := Surf.new()
	var lm := LegoMesh.new()
	var chunk_len := 40
	for i in _s.size() - 1:
		var j := i + 1
		for sgn in [-1.0, 1.0]:
			var a := _lat(i, sgn * (hc + WALL_T * 0.5))
			var b := _lat(j, sgn * (hc + WALL_T * 0.5))
			var dir := b - a
			var z := dir.normalized()
			var x := Vector3.UP.cross(z).normalized()
			var center := (a + b) * 0.5 + Vector3.UP * 0.6
			var c: Color = wc[(i / 2 + (1 if sgn > 0 else 0)) % wc.size()]
			var k := LegoMesh.key(c)
			if is_space:
				c = wc[(i / 3) % wc.size()]
				k = LegoMesh.glow(c)
			lm.box(k, Transform3D(Basis(x, Vector3.UP, z), center), Vector3(WALL_T, 1.2, dir.length() + 0.08))
			lm.studs_on(k, Transform3D(Basis(x, Vector3.UP, z), center + Vector3.UP * 0.6), WALL_T, dir.length(), 1.25, 6)
			# collision: inner face, taller than the visual so karts don't hop out
			var ia := _lat(i, sgn * hc)
			var ib := _lat(j, sgn * hc)
			col.quad(ia - Vector3.UP, ib - Vector3.UP, ib + Vector3.UP * 3.0, ia + Vector3.UP * 3.0, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, -_r[i] * sgn)
		if (i + 1) % chunk_len == 0 or i == _s.size() - 2:
			add_child(lm.to_instance(Game.quality >= 2))
			lm = LegoMesh.new()
	_static(col.faces, "wall")


func _build_ground() -> void:
	var size := maxf(bounds.size.x, bounds.size.y) + 900.0
	var center := bounds.get_center()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	var mat := Tex.mat(Tex.baseplate(theme["ground"]), true, Vector3.ONE * 0.5)
	if theme["ground_kind"] == "hazard":
		mat.emission_enabled = true
		mat.emission = theme["ground"]
		mat.emission_energy_multiplier = 1.6
		mat.emission_texture = mat.albedo_texture
	pm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(center.x, ground_y, center.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = not is_space
	add_child(mi)
	var sb := StaticBody3D.new()
	sb.add_to_group(theme["ground_kind"])
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size, 2.0, size)
	cs.shape = bs
	cs.position = Vector3(center.x, ground_y - 1.0, center.y)
	sb.add_child(cs)
	add_child(sb)


func _build_start() -> void:
	var f := frame_at(0.0)
	# checkered line
	var line := Surf.new()
	line.collide = false
	var a := f.origin + f.basis.y * 0.04
	var x := f.basis.x
	var z := f.basis.z
	line.quad(a - x * half_road - z * 1.6, a + x * half_road - z * 1.6, a + x * half_road + z * 1.6, a - x * half_road + z * 1.6, Vector2(0, 0), Vector2(half_road / 1.6, 0), Vector2(half_road / 1.6, 1), Vector2(0, 1), f.basis.y)
	_add_mesh(line.mesh(Tex.mat(Tex.checker(8))))
	# gantry
	var lm := LegoMesh.new()
	var span := half_corridor + 2.5
	var hb := Transform3D(Basis(Vector3.UP, heading_at(0.0)), f.origin)
	for sgn in [-1.0, 1.0]:
		for k in 7:
			var c := Color("#c91a09") if k % 2 == 0 else Color("#f4f4f4")
			lm.box(LegoMesh.key(c), hb * Transform3D(Basis(), Vector3(sgn * span, 0.5 + k, 0)), Vector3(1.6, 1.0, 1.6), k == 6, 0.8)
	lm.box(LegoMesh.key(Color("#1b2a34")), hb * Transform3D(Basis(), Vector3(0, 7.6, 0)), Vector3(span * 2 + 1.6, 1.4, 1.0), true, 0.8)
	add_child(lm.to_instance(true))
	for side in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.text = "PJ-RACING"
		lbl.font_size = 180
		lbl.pixel_size = 0.01
		lbl.outline_size = 30
		lbl.modulate = Color("#f2cd37")
		lbl.outline_modulate = Color("#1b2a34")
		lbl.double_sided = false
		lbl.transform = hb * Transform3D(Basis(Vector3.UP, 0.0 if side > 0 else PI), Vector3(-3.0 * side, 7.6, 0.52 * side))
		add_child(lbl)
	# start lights
	for k in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#330000")
		m.emission_enabled = true
		m.emission = Color("#000000")
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.45
		cyl.height = 0.2
		cyl.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.transform = hb * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(5.0 + k * 1.2, 7.6, 0.55))
		add_child(mi)
		start_lights.append(m)
	# grandstand along the right side after the line
	var gs := LegoMesh.new()
	var gf := frame_at(22.0)
	var gt := Transform3D(Basis(Vector3.UP, heading_at(22.0)), gf.origin + gf.basis.x * (half_corridor + 7.0))
	gt.origin.y = maxf(gf.origin.y, ground_y)
	var shirt_cols := ["c:c91a09", "c:0055bf", "c:237841", "c:f2cd37", "c:fe8a18", "c:ff79c6", "c:f4f4f4", "c:81007b"]
	for row in 4:
		gs.box(LegoMesh.key(Color("#a0a5a9")), gt * Transform3D(Basis(), Vector3(row * 1.6, row * 1.0 + 0.5, 0)), Vector3(1.6, 1.0 + row * 2.0, 24.0), false)
		for k in 14:
			if _rng.randf() < 0.85:
				var pz := -11.0 + k * 1.65
				gs.box(shirt_cols[_rng.randi() % shirt_cols.size()], gt * Transform3D(Basis(), Vector3(row * 1.6, row * 2.0 + 1.25, pz)), Vector3(0.6, 0.5, 0.8))
				gs.cylinder(LegoMesh.key(Color("#f6d23c")), gt * Transform3D(Basis(), Vector3(row * 1.6, row * 2.0 + 1.7, pz)), 0.22, 0.38, 8)
	gs.box(LegoMesh.key(Color("#0055bf")), gt * Transform3D(Basis(), Vector3(7.5, 6.5, 0)), Vector3(0.6, 13.0, 24.0), false)
	gs.box(LegoMesh.key(Color("#f4f4f4")), gt * Transform3D(Basis(), Vector3(2.5, 10.0, 0)), Vector3(11.0, 0.4, 25.0), true, 1.0)
	add_child(gs.to_instance(true))


func _build_features() -> void:
	var tall: bool = theme["decor"].has("tire_stack")
	var ramp_mat := Tex.mat(Tex.stripes(Color("#f2cd37"), Color("#1b2a34"), 6))
	LegoMesh.register("ramp", ramp_mat)
	for i in ramp_offsets.size():
		var s: float = ramp_offsets[i]
		var f := frame_at(s)
		var full := i % 2 == 0
		var w := (width - 1.0) if full else width * 0.48
		var lat := 0.0 if full else (half_road * 0.5 * (1.0 if i % 4 == 1 else -1.0))
		var h := 3.0 if tall else 2.2
		var ln := 10.0
		var xf := Transform3D(f.basis, f.origin + f.basis.x * lat - f.basis.y * 0.05)
		var lm := LegoMesh.new()
		lm.wedge("ramp", xf, Vector3(w, h, ln))
		add_child(lm.to_instance(true))
		var sb := StaticBody3D.new()
		sb.add_to_group("ramp")
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		var hx := w * 0.5
		var hz := ln * 0.5
		sh.points = PackedVector3Array([Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz), Vector3(hx, h, -hz), Vector3(-hx, h, -hz)])
		cs.shape = sh
		sb.add_child(cs)
		sb.transform = xf
		add_child(sb)
	for i in boost_offsets.size():
		var s: float = boost_offsets[i]
		var f := frame_at(s)
		var lat: float = [-0.45, 0.0, 0.45][i % 3] * half_road
		var pad := BoostPad.new()
		pad.transform = Transform3D(f.basis, f.origin + f.basis.x * lat + f.basis.y * 0.03)
		add_child(pad)
	for s in item_offsets:
		var f := frame_at(s)
		for k in 4:
			var lat := (-0.6 + 0.4 * k) * half_road
			var box := ItemBox.new()
			box.transform = Transform3D(Basis(), f.origin + f.basis.x * lat)
			add_child(box)


# ------------------------------------------------------------------ scenery

func _dist_to_track(p: Vector2) -> float:
	var best := INF
	for q in minimap_pts:
		best = minf(best, p.distance_squared_to(q))
	return sqrt(best)


func _build_decor() -> void:
	var chunks := {}
	var kinds: Array = theme["decor"]
	var r := bounds.grow(80.0)
	var placed := 0
	var target := int(clampf(r.get_area() / 420.0, 120.0, 340.0) * [0.5, 0.8, 1.0][Game.quality])
	var tries := 0
	while placed < target and tries < target * 6:
		tries += 1
		var p := Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))
		var d := _dist_to_track(p)
		var kind: String = kinds[_rng.randi() % kinds.size()]
		var clearance := half_corridor + WALL_T + (9.0 if kind == "building" or kind == "pyramid" else 3.5) + (8.0 if is_space else 0.0)
		if d < clearance:
			continue
		if d > clearance + 60.0 and _rng.randf() < 0.6:
			continue
		var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
		if not chunks.has(key):
			chunks[key] = LegoMesh.new()
		var y := ground_y
		if is_space:
			y = curve.sample_baked(curve.get_closest_offset(Vector3(p.x, 10.0, p.y))).y + _rng.randf_range(-28.0, 30.0)
		_decor(chunks[key], kind, Vector3(p.x, y, p.y), d - clearance)
		placed += 1
	for k in chunks:
		add_child(chunks[k].to_instance(Game.quality >= 2))
	if is_space:
		_build_planets()
		return
	# distant lego mountains
	var center := bounds.get_center()
	var rad := maxf(bounds.size.x, bounds.size.y) * 0.5 + 170.0
	var hills := LegoMesh.new()
	var hill_c: Color = theme["hill"]
	for i in 22:
		var a := TAU * i / 22.0 + _rng.randf_range(-0.1, 0.1)
		var pr := rad + _rng.randf_range(0, 80)
		var base := Vector3(center.x + cos(a) * pr, ground_y, center.y + sin(a) * pr)
		var layers := _rng.randi_range(3, 6)
		var w := _rng.randf_range(50, 90)
		for k in layers:
			var lw := w * (1.0 - float(k) / (layers + 1))
			var col := hill_c.lightened(0.04 * k)
			if theme["decor"].has("pine") and k >= layers - 2:
				col = Color("#f4f6ff")
			if theme["ground_kind"] == "hazard" and k == layers - 1:
				hills.box(LegoMesh.glow(Color("#ff6a00")), Transform3D(Basis(), base + Vector3(0, k * 9.0 + 9.5, 0)), Vector3(lw * 0.5, 1.0, lw * 0.5))
			hills.box(LegoMesh.key(col), Transform3D(Basis(Vector3.UP, a), base + Vector3(0, k * 9.0 + 4.5, 0)), Vector3(lw, 9.0, lw), k == layers - 1, 6.0, LegoMesh.key(col))
	add_child(hills.to_instance(false))


func _decor(lm: LegoMesh, kind: String, p: Vector3, room: float) -> void:
	var rot := Basis(Vector3.UP, _rng.randf() * TAU)
	var at := func(x: float, y: float, z: float) -> Transform3D:
		return Transform3D(rot, p + rot * Vector3(x, y, z))
	match kind:
		"tree":
			var trunk := LegoMesh.key(Color("#6b3d1f"))
			lm.box(trunk, at.call(0, 1.5, 0), Vector3(1.0, 3.0, 1.0))
			var g := LegoMesh.key([Color("#237841"), Color("#4b9f4a"), Color("#2f8f3a")][_rng.randi() % 3])
			var s := _rng.randf_range(0.8, 1.4)
			lm.box(g, at.call(0, 3.0 + 0.9 * s, 0), Vector3(4, 1.8, 4) * s, true, 1.0 * s)
			lm.box(g, at.call(0, 3.0 + 2.6 * s, 0), Vector3(3, 1.6, 3) * s, true, 1.0 * s)
			lm.box(g, at.call(0, 3.0 + 4.0 * s, 0), Vector3(1.8, 1.2, 1.8) * s, true, 0.9 * s)
		"bush":
			var g := LegoMesh.key(Color("#3c8f3a"))
			lm.box(g, at.call(0, 0.7, 0), Vector3(2.4, 1.4, 2.0), true, 0.8)
			lm.box(LegoMesh.key(Color("#c91a09")), at.call(0.5, 1.5, 0.3), Vector3(0.4, 0.3, 0.4))
		"flower":
			for k in 5:
				var c: Color = [Color("#c91a09"), Color("#f2cd37"), Color("#f4f4f4"), Color("#ff79c6"), Color("#0055bf")][_rng.randi() % 5]
				var o := Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2))
				lm.box(LegoMesh.key(Color("#237841")), at.call(o.x, 0.4, o.z), Vector3(0.15, 0.8, 0.15))
				lm.cylinder(LegoMesh.key(c), at.call(o.x, 0.85, o.z), 0.35, 0.2, 8)
		"pine":
			var g := LegoMesh.key(Color("#1f5f3a"))
			var snow := LegoMesh.key(Color("#f4f6ff"))
			lm.box(LegoMesh.key(Color("#5a3a20")), at.call(0, 1, 0), Vector3(0.8, 2, 0.8))
			var s := _rng.randf_range(0.8, 1.5)
			for k in 4:
				var w := (4.0 - k * 0.9) * s
				lm.box(g, at.call(0, (2.0 + k * 1.4) * s, 0), Vector3(w, 1.2 * s, w))
				lm.box(snow, at.call(0, (2.65 + k * 1.4) * s, 0), Vector3(w * 0.8, 0.14, w * 0.8), k == 3, 0.8)
		"snowman":
			var w := LegoMesh.key(Color("#f4f6ff"))
			lm.box(w, at.call(0, 1.0, 0), Vector3(2.4, 2.0, 2.4))
			lm.box(w, at.call(0, 2.7, 0), Vector3(1.7, 1.4, 1.7))
			lm.box(w, at.call(0, 3.9, 0), Vector3(1.2, 1.0, 1.2))
			lm.frustum(LegoMesh.key(Color("#fe8a18")), Transform3D(rot * Basis(Vector3.RIGHT, -PI * 0.5), p + rot * Vector3(0, 3.9, -0.9)), 0.15, 0.0, 0.6, 6)
			lm.cylinder(LegoMesh.key(Color("#1b1b1b")), at.call(0, 4.6, 0), 0.6, 0.8, 10)
		"cactus":
			var g := LegoMesh.key(Color("#4f9a3a"))
			var h := _rng.randf_range(4.0, 7.0)
			lm.box(g, at.call(0, h * 0.5, 0), Vector3(1.2, h, 1.2), true, 0.6)
			lm.box(g, at.call(1.2, h * 0.45, 0), Vector3(1.2, 0.8, 0.8))
			lm.box(g, at.call(1.6, h * 0.6, 0), Vector3(0.8, 1.8, 0.8), true, 0.4)
			lm.box(g, at.call(-1.1, h * 0.6, 0), Vector3(1.0, 0.8, 0.8))
			lm.box(g, at.call(-1.4, h * 0.72, 0), Vector3(0.8, 1.4, 0.8), true, 0.4)
		"palm":
			var trunk := LegoMesh.key(Color("#8a5a2a"))
			for k in 6:
				lm.box(trunk, at.call(k * 0.25, 0.6 + k * 1.1, 0), Vector3(0.8, 1.1, 0.8))
			for k in 5:
				var a := TAU * k / 5.0
				lm.box(LegoMesh.key(Color("#2f8f3a")), Transform3D(rot * Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.35), p + rot * Vector3(1.25, 7.0, 0) + rot * Basis(Vector3.UP, a) * Vector3(0, 0, 1.6)), Vector3(0.9, 0.15, 3.4))
		"rock":
			var c := LegoMesh.key(Color("#6b6e72").lerp(theme["hill"], 0.3))
			var s := _rng.randf_range(1.0, 2.5)
			lm.box(c, at.call(0, 0.8 * s, 0), Vector3(2.5, 1.6, 2.0) * s, true, 0.8 * s)
			lm.box(c, at.call(0.6 * s, 2.0 * s, 0.2 * s), Vector3(1.4, 1.0, 1.2) * s, true, 0.7 * s)
		"pyramid":
			var c := Color("#d8b26a")
			var s := _rng.randf_range(0.8, 1.4)
			for k in 6:
				var w := (14.0 - k * 2.3) * s
				lm.box(LegoMesh.key(c.darkened(0.03 * k)), at.call(0, (k + 0.5) * 1.6 * s, 0), Vector3(w, 1.6 * s, w), k == 5, 1.0)
		"building":
			var w := _rng.randf_range(8, 16)
			var dpt := _rng.randf_range(8, 16)
			var h := _rng.randf_range(14, 48)
			var body := LegoMesh.key([Color("#2a2d4a"), Color("#3a2a4a"), Color("#1f3344"), Color("#33334a")][_rng.randi() % 4])
			lm.box(body, at.call(0, h * 0.5, 0), Vector3(w, h, dpt), true, 2.0)
			var wc := LegoMesh.glow([Color("#2be0ff"), Color("#ff2bd6"), Color("#fff27a"), Color("#a0ffb0")][_rng.randi() % 4])
			var floors := int(h / 3.5)
			for f in floors:
				if _rng.randf() < 0.75:
					var y := 2.5 + f * 3.5
					lm.box(wc, at.call(0, y, 0), Vector3(w + 0.08, 1.0, dpt * 0.7))
					lm.box(wc, at.call(0, y, 0), Vector3(w * 0.7, 1.0, dpt + 0.08))
			lm.box(LegoMesh.glow(Color("#ff2020")), at.call(0, h + 2.0, 0), Vector3(0.3, 4.0, 0.3))
		"lamp":
			lm.box(LegoMesh.key(Color("#1b2a34")), at.call(0, 3, 0), Vector3(0.4, 6, 0.4))
			lm.box(LegoMesh.glow(Color("#fff2b0")), at.call(0, 6.2, 0), Vector3(1.0, 0.5, 1.0))
		"volcano_rock":
			var c := LegoMesh.key(Color("#2a2220"))
			var h := _rng.randf_range(3, 9)
			lm.box(c, at.call(0, h * 0.5, 0), Vector3(3, h, 3), true, 1.0)
			lm.box(LegoMesh.glow(Color("#ff5a00")), at.call(0, h * 0.4, 1.52), Vector3(0.4, h * 0.6, 0.05))
		"lava_tower":
			var h := _rng.randf_range(10, 20)
			lm.box(LegoMesh.key(Color("#3a3a3a")), at.call(0, h * 0.5, 0), Vector3(4, h, 4), false)
			lm.box(LegoMesh.glow(Color("#ff8a00")), at.call(0, h + 0.5, 0), Vector3(3, 1.0, 3), true, 1.0)
			lm.box(LegoMesh.key(Color("#f2cd37")), at.call(0, h * 0.7, 0), Vector3(4.1, 0.6, 4.1))
		"tire_stack":
			for k in _rng.randi_range(2, 5):
				lm.cylinder("rubber", at.call(0, 0.35 + k * 0.7, 0), 1.0, 0.7, 12)
		"wreck":
			var c := LegoMesh.key(Color.from_hsv(_rng.randf(), 0.7, 0.8))
			lm.box(c, at.call(0, 0.6, 0), Vector3(2.0, 0.7, 3.6), true, 0.4)
			lm.box(c, Transform3D(rot * Basis(Vector3.FORWARD, 0.3), p + rot * Vector3(0, 1.1, 0.3)), Vector3(1.8, 0.4, 1.6))
			for k in 4:
				lm.cylinder("rubber", Transform3D(rot * Basis(Vector3.BACK, PI * 0.5), p + rot * Vector3(-1.1 if k % 2 == 0 else 1.1, 0.45, -1.2 if k < 2 else 1.2)), 0.45, 0.35, 10)
		"house":
			var wall := LegoMesh.key([Color("#f4f4f4"), Color("#f2cd37"), Color("#9fc3e9"), Color("#ffb0c8")][_rng.randi() % 4])
			var roof := LegoMesh.key([Color("#c91a09"), Color("#0055bf"), Color("#6b3d1f")][_rng.randi() % 3])
			lm.box(wall, at.call(0, 2.0, 0), Vector3(6, 4, 5))
			for k in 4:
				lm.box(roof, at.call(0, 4.4 + k * 0.8, 0), Vector3(6.6, 0.8, 5.6 - k * 1.4))
			lm.box(LegoMesh.key(Color("#6b3d1f")), at.call(0, 1.2, 2.52), Vector3(1.2, 2.4, 0.1))
			for wx in [-1.9, 1.9]:
				lm.box("glass", at.call(wx, 2.4, 2.52), Vector3(1.2, 1.1, 0.1))
			lm.box(LegoMesh.key(Color("#8a8a8a")), at.call(1.8, 5.8, -0.8), Vector3(0.8, 2.0, 0.8))
		"windmill":
			var wall := LegoMesh.key(Color("#f4f4f4"))
			lm.frustum(wall, at.call(0, 4.5, 0), 2.6, 1.6, 9.0, 10)
			lm.frustum(LegoMesh.key(Color("#c91a09")), at.call(0, 10.0, 0), 2.0, 0.2, 2.2, 10)
			var hub: Vector3 = at.call(0, 8.0, -2.0).origin
			var fwd := rot * Vector3(0, 0, -1)
			var side := rot * Vector3(1, 0, 0)
			var spin := _rng.randf() * TAU
			for k in 4:
				var a := spin + TAU * k / 4.0
				var dirv := side * cos(a) + Vector3.UP * sin(a)
				_bar(lm, LegoMesh.key(Color("#6b3d1f")), hub, hub + dirv * 5.5, 0.3)
				_bar(lm, LegoMesh.key(Color("#f4f4f4")), hub + dirv * 1.5 + fwd * 0.2 + dirv.cross(fwd) * 0.6, hub + dirv * 5.3 + fwd * 0.2 + dirv.cross(fwd) * 0.6, 0.9)
			lm.cylinder(LegoMesh.key(Color("#1b2a34")), Transform3D(rot * Basis(Vector3.RIGHT, PI * 0.5), hub), 0.5, 0.6, 10)
		"tent":
			var c1 := LegoMesh.key([Color("#c91a09"), Color("#0055bf"), Color("#fe8a18")][_rng.randi() % 3])
			var c2 := LegoMesh.key(Color("#f4f4f4"))
			for k in 4:
				var z := -2.25 + k * 1.5
				for sgn in [-1.0, 1.0]:
					lm.box(c1 if k % 2 == 0 else c2, Transform3D(rot * Basis(Vector3.BACK, sgn * 0.75), p + rot * Vector3(sgn * 1.05, 1.4, z)), Vector3(0.2, 3.3, 1.5))
			lm.box(LegoMesh.key(Color("#6b3d1f")), at.call(0, 3.2, 0), Vector3(0.2, 0.2, 6.4))
		"igloo":
			var w := LegoMesh.key(Color("#f4f6ff"))
			var r := _rng.randf_range(2.5, 3.5)
			for k in 4:
				var y := (k + 0.5) * r / 4.0
				lm.cylinder(w, at.call(0, y, 0), sqrt(r * r - y * y), r / 4.0, 14)
			lm.box(w, at.call(0, 0.8, r - 0.2), Vector3(1.8, 1.6, 1.6))
			lm.box(LegoMesh.key(Color("#1b2a34")), at.call(0, 0.7, r + 0.62), Vector3(1.0, 1.3, 0.05))
		"billboard":
			var cols := [Color("#ff2bd6"), Color("#2be0ff"), Color("#fff27a"), Color("#a0ffb0")]
			for sx in [-3.0, 3.0]:
				lm.box(LegoMesh.key(Color("#1b2a34")), at.call(sx, 4.0, 0), Vector3(0.5, 8, 0.5))
			lm.box(LegoMesh.key(Color("#1b2a34")), at.call(0, 8.5, 0), Vector3(9, 4.6, 0.5))
			lm.box(LegoMesh.glow(cols[_rng.randi() % 4]), at.call(0, 8.5, 0.3), Vector3(8.2, 3.8, 0.1))
			lm.box(LegoMesh.glow(cols[_rng.randi() % 4]), at.call(0, 8.5, -0.3), Vector3(8.2, 3.8, 0.1))
			lm.box(LegoMesh.glow(Color("#f4f4f4")), at.call(0, 8.9, 0.36), Vector3(5.0, 0.5, 0.05))
			lm.box(LegoMesh.glow(Color("#f4f4f4")), at.call(-1.0, 7.9, 0.36), Vector3(3.0, 0.5, 0.05))
		"barrel":
			for k in _rng.randi_range(1, 3):
				var o := Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5))
				var c := LegoMesh.key([Color("#c91a09"), Color("#0055bf"), Color("#f2cd37")][_rng.randi() % 3])
				lm.cylinder(c, at.call(o.x, 0.9, o.z), 0.7, 1.8, 12)
				lm.cylinder(LegoMesh.key(Color("#1b2a34")), at.call(o.x, 0.6, o.z), 0.72, 0.12, 12)
				lm.cylinder(LegoMesh.key(Color("#1b2a34")), at.call(o.x, 1.3, o.z), 0.72, 0.12, 12)
				if theme["ground_kind"] == "hazard":
					lm.cylinder(LegoMesh.glow(Color("#7dff3a")), at.call(o.x, 1.82, o.z), 0.55, 0.06, 12)
		"asteroid":
			var b := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
			var c := LegoMesh.key(Color("#5a5068").lerp(Color("#8a7a6a"), _rng.randf()))
			var s := _rng.randf_range(1.5, 4.0)
			lm.box(c, Transform3D(b, p), Vector3(2.4, 1.8, 2.0) * s, true, 0.8 * s)
			lm.box(c, Transform3D(b, p + b * Vector3(0.8, -0.9, 0.4) * s), Vector3(1.6, 1.4, 1.4) * s, true, 0.7 * s)
			lm.box(c, Transform3D(b, p + b * Vector3(-0.9, 0.3, -0.6) * s), Vector3(1.2, 1.2, 1.2) * s)
			if _rng.randf() < 0.4:
				lm.box(LegoMesh.glow(Color("#3bc8ff")), Transform3D(b, p + b * Vector3(0, 0.95, 0) * s), Vector3(0.5, 0.6, 0.5) * s)
		"star":
			var k := LegoMesh.glow([Color("#ffe23b"), Color("#fff6b0"), Color("#ffb03b")][_rng.randi() % 3])
			var s := _rng.randf_range(1.2, 2.6)
			for i in 5:
				var a := TAU * i / 5.0 + PI * 0.5
				var tip := p + rot * Vector3(cos(a), sin(a), 0) * 2.0 * s
				_bar(lm, k, p, tip, 0.9 * s)
			lm.cylinder(k, Transform3D(rot * Basis(Vector3.RIGHT, PI * 0.5), p), 0.9 * s, 0.7 * s, 10)
		"satellite":
			var b := Basis.from_euler(Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf() * TAU, _rng.randf_range(-0.6, 0.6)))
			lm.box("gold", Transform3D(b, p), Vector3(1.6, 1.6, 2.2))
			for sx in [-1.0, 1.0]:
				lm.box(LegoMesh.key(Color("#a0a5a9")), Transform3D(b, p + b * Vector3(sx * 1.6, 0, 0)), Vector3(1.6, 0.15, 0.15))
				lm.box(LegoMesh.key(Color("#1f3a8a")), Transform3D(b, p + b * Vector3(sx * 3.6, 0, 0)), Vector3(3.0, 0.1, 1.8), true, 0.5, LegoMesh.glow(Color("#3b6bff")))
			lm.frustum("chrome", Transform3D(b * Basis(Vector3.RIGHT, -PI * 0.5), p + b * Vector3(0, 0, -1.4)), 0.2, 1.1, 0.6, 12)
			lm.box(LegoMesh.glow(Color("#ff3b3b")), Transform3D(b, p + b * Vector3(0, 1.1, 0)), Vector3(0.25, 0.5, 0.25))
		"rocket":
			var tilt := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.5, 0.5))
			var body := LegoMesh.key(Color("#f4f4f4"))
			var acc := LegoMesh.key([Color("#c91a09"), Color("#0055bf"), Color("#fe8a18")][_rng.randi() % 3])
			lm.cylinder(body, Transform3D(tilt, p + tilt * Vector3(0, 3, 0)), 1.0, 6.0, 12)
			lm.cylinder(acc, Transform3D(tilt, p + tilt * Vector3(0, 4.0, 0)), 1.02, 0.6, 12)
			lm.frustum(acc, Transform3D(tilt, p + tilt * Vector3(0, 7.2, 0)), 1.0, 0.0, 2.4, 12)
			lm.cylinder("glass", Transform3D(tilt * Basis(Vector3.RIGHT, PI * 0.5), p + tilt * Vector3(0, 5.0, 0.95)), 0.4, 0.15, 10)
			for i in 3:
				var fb := tilt * Basis(Vector3.UP, TAU * i / 3.0)
				lm.box(acc, Transform3D(fb, p + fb * Vector3(0, 0.6, 1.3)), Vector3(0.2, 2.0, 1.2))
			lm.frustum(LegoMesh.glow(Color("#ff8a2b")), Transform3D(tilt, p + tilt * Vector3(0, -1.0, 0)), 0.1, 0.8, 2.0, 10)
			lm.frustum(LegoMesh.glow(Color("#fff27a")), Transform3D(tilt, p + tilt * Vector3(0, -0.5, 0)), 0.1, 0.5, 1.2, 10)
		"ufo":
			var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.3, 0.3))
			lm.frustum("chrome", Transform3D(b, p), 4.0, 2.4, 0.9, 16)
			lm.frustum("chrome", Transform3D(b, p - b * Vector3(0, 0.7, 0)), 1.6, 4.0, 0.5, 16)
			lm.frustum("glass", Transform3D(b, p + b * Vector3(0, 1.0, 0)), 1.8, 0.8, 1.2, 12)
			lm.box(LegoMesh.key(Color("#3bff7a")), Transform3D(b, p + b * Vector3(0, 0.9, 0)), Vector3(0.6, 0.8, 0.6))
			for i in 8:
				var a := TAU * i / 8.0
				lm.box(LegoMesh.glow([Color("#3bff7a"), Color("#ff3bd6")][i % 2]), Transform3D(b, p + b * Vector3(cos(a) * 3.3, -0.1, sin(a) * 3.3)), Vector3(0.4, 0.3, 0.4))
		"crystal":
			var k := LegoMesh.glow([Color("#3bc8ff"), Color("#ff3bd6"), Color("#9b5bff")][_rng.randi() % 3])
			var s := _rng.randf_range(1.0, 2.2)
			for i in 3:
				var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.RIGHT, _rng.randf_range(-0.4, 0.4))
				var h := _rng.randf_range(2.0, 4.0) * s
				lm.frustum(k, Transform3D(b, p + b * Vector3(0, h * 0.5, 0)), 0.6 * s, 0.0, h, 6)
				lm.frustum(k, Transform3D(b, p - b * Vector3(0, h * 0.3, 0)), 0.0, 0.6 * s, h * 0.6, 6)


## A brick-built ball: stacked round plates, like a lego planet.
func _ball(lm: LegoMesh, k: String, c: Vector3, r: float, layers := 8, seg := 16) -> void:
	var h := 2.0 * r / layers
	for i in layers:
		var y := -r + (i + 0.5) * h
		lm.cylinder(k, Transform3D(Basis(), c + Vector3(0, y, 0)), sqrt(maxf(r * r - y * y, 0.0)) + h * 0.15, h, seg)


## A square bar between two points.
func _bar(lm: LegoMesh, k: String, a: Vector3, b: Vector3, thick: float) -> void:
	var z := (b - a).normalized()
	var x := Vector3.UP.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	lm.box(k, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(thick, thick, a.distance_to(b)))


func _build_planets() -> void:
	var center := bounds.get_center()
	var rad := maxf(bounds.size.x, bounds.size.y) * 0.5 + 220.0
	var palette := [
		[Color("#e8743b"), Color("#c94a2a")], [Color("#3b8ee8"), Color("#2fbf6a")], [Color("#c45bff"), Color("#ff79c6")],
		[Color("#f2cd37"), Color("#e8a23b")], [Color("#3bc8c8"), Color("#f4f4f4")], [Color("#ff5a6b"), Color("#ffb0c8")],
		[Color("#8a7aff"), Color("#3b3b9b")],
	]
	for i in palette.size():
		var a := TAU * i / palette.size() + _rng.randf_range(-0.2, 0.2)
		var pr := rad + _rng.randf_range(0.0, 140.0)
		var r := _rng.randf_range(22.0, 55.0) if i != 2 else 85.0
		var pos := Vector3(center.x + cos(a) * pr, _rng.randf_range(-30.0, 90.0), center.y + sin(a) * pr)
		var cols: Array = palette[i]
		var lm := LegoMesh.new()
		var layers := 12
		var h := 2.0 * r / layers
		for k in layers:
			var y := -r + (k + 0.5) * h
			var c: Color = cols[0] if (k / 2) % 2 == 0 else cols[1]
			lm.cylinder(LegoMesh.key(c), Transform3D(Basis(), Vector3(0, y, 0)), sqrt(maxf(r * r - y * y, 0.0)) + h * 0.15, h, 20)
		if i % 2 == 0:  # ring
			lm.cylinder(LegoMesh.key(cols[1].lightened(0.3)), Transform3D(), r * 1.9, r * 0.03, 28)
			lm.cylinder(LegoMesh.key(cols[0].lightened(0.4)), Transform3D(), r * 1.55, r * 0.05, 28)
		var holder := Node3D.new()
		holder.position = pos
		holder.rotation = Vector3(_rng.randf_range(-0.5, 0.5), 0, _rng.randf_range(-0.5, 0.5))
		add_child(holder)
		var mi := lm.to_instance(false)
		holder.add_child(mi)
		_spinners.append([mi, _rng.randf_range(0.03, 0.12) * (1.0 if i % 2 == 0 else -1.0)])
	# a glowing star (sun) and a little moon close to the track
	var sun_lm := LegoMesh.new()
	_ball(sun_lm, LegoMesh.glow(Color("#fff2b0")), Vector3.ZERO, 40.0, 10, 20)
	var sun := sun_lm.to_instance(false)
	sun.position = Vector3(center.x - rad * 1.3, 160.0, center.y - rad * 0.9)
	add_child(sun)
	var moon_lm := LegoMesh.new()
	_ball(moon_lm, LegoMesh.key(Color("#c8c8d0")), Vector3.ZERO, 14.0, 8, 16)
	for k in 5:
		var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.2, 1), _rng.randf_range(-1, 1)).normalized()
		moon_lm.cylinder(LegoMesh.key(Color("#9a9aa6")), Transform3D(Basis(Vector3.UP, 0), d * 13.0), 2.5, 2.0, 10)
	var moon := moon_lm.to_instance(false)
	moon.position = Vector3(center.x + bounds.size.x * 0.15, 70.0, center.y + 20.0)
	add_child(moon)
	_spinners.append([moon, 0.08])


# ------------------------------------------------------------------ trackside details

func _clear_of_features(s: float, margin: float) -> bool:
	for r in ramp_offsets:
		if absf(s - r) < margin + 15.0:
			return false
	for b in boost_offsets + item_offsets:
		if absf(s - b) < margin:
			return false
	return true


func _base_y(top: Vector3) -> float:
	return top.y - 2.0 if is_space else ground_y


## Chevron signs on the outside of sharp corners, banner arches over the road and flags on the walls.
func _build_details() -> void:
	var lm := LegoMesh.new()
	var wc: Array = theme["walls"]
	var night: bool = theme["night"]
	var hc := half_corridor + WALL_T
	# corner chevrons
	var s := 45.0
	while s < length - 25.0:
		var a := tangent_at(s - 6.0)
		var b := tangent_at(s + 22.0)
		a.y = 0
		b.y = 0
		var turn := a.normalized().signed_angle_to(b.normalized(), Vector3.UP)
		if absf(turn) > 0.5:
			var sgn := 1.0 if turn > 0.0 else -1.0  # outside of the corner
			_chevron(lm, s, sgn, hc + 1.4, night)
			s += 11.0
		else:
			s += 5.0
	# banner arches
	var banners := ["GO! GO! GO!", "TURBO TIME!", "FULL SPEED!", "YOU CAN DO IT!", "ZOOOOM!"]
	if is_space:
		banners = ["TO THE STARS!", "ZOOOOM!", "STAR POWER!"]
	var placed := 0
	for f in [0.33, 0.62, 0.86]:
		var at: float = length * f
		for tries in 12:
			if _clear_of_features(at, 6.0):
				break
			at += 7.0
		_arch(lm, at, banners[(_rng.randi() + placed) % banners.size()], wc, night)
		placed += 1
	# flags on the walls
	var fs := 30.0
	var side := 1.0
	while fs < length - 15.0:
		var fr := frame_at(fs)
		var base := fr.origin + fr.basis.x * side * (half_corridor + WALL_T * 0.5) + Vector3.UP * 1.2
		var c: Color = wc[int(fs / 30.0) % wc.size()]
		var pole := LegoMesh.key(Color("#a0a5a9"))
		lm.box(pole, Transform3D(Basis(), base + Vector3.UP * 2.0), Vector3(0.18, 4.0, 0.18))
		var t := fr.basis.z  # flag waves backwards (with the wind of the racers)
		var fk := LegoMesh.glow(c) if night else LegoMesh.key(c)
		lm.box(fk, Transform3D(Basis(fr.basis.x, Vector3.UP, t), base + Vector3.UP * 3.4 + t * 0.75), Vector3(0.06, 1.0, 1.5))
		lm.cylinder("gold", Transform3D(Basis(), base + Vector3.UP * 4.05), 0.16, 0.16, 8)
		fs += 34.0
		side = -side
	add_child(lm.to_instance(Game.quality >= 2))


func _chevron(lm: LegoMesh, s: float, sgn: float, lat: float, night: bool) -> void:
	var f := frame_at(s)
	var r := f.basis.x
	r.y = 0
	r = r.normalized()
	var t := -f.basis.z
	t.y = 0
	t = t.normalized()
	var top := f.origin + r * sgn * lat + Vector3.UP * 2.6
	var board_k := LegoMesh.key(Color("#1b2a34")) if night else LegoMesh.key(Color("#f2cd37"))
	var mark_k := LegoMesh.glow(Color("#ffe23b") if not is_space else Color("#ff3bd6")) if night else LegoMesh.key(Color("#c91a09"))
	var bb := Basis(r, Vector3.UP, -t)
	lm.box(board_k, Transform3D(bb, top), Vector3(0.3, 2.0, 2.4))
	# ">" pointing in the driving direction, on the road-facing side
	var face := top - r * sgn * 0.2
	var tip := face + t * 0.55
	_bar(lm, mark_k, face - t * 0.45 + Vector3.UP * 0.6, tip, 0.34)
	_bar(lm, mark_k, face - t * 0.45 - Vector3.UP * 0.6, tip, 0.34)
	var by := _base_y(top)
	var ph := top.y - 1.0 - by
	if ph > 0.2:
		lm.box(LegoMesh.key(Color("#a0a5a9")), Transform3D(Basis(), Vector3(top.x, by + ph * 0.5, top.z)), Vector3(0.25, ph, 0.25))


func _arch(lm: LegoMesh, s: float, text: String, wc: Array, night: bool) -> void:
	var f := frame_at(s)
	var hb := Basis(Vector3.UP, heading_at(s))
	var span := half_corridor + WALL_T + 1.0
	var road_y := f.origin.y
	for sgn: float in [-1.0, 1.0]:
		var foot := f.origin + hb.x * sgn * span
		var by := minf(_base_y(foot), road_y)
		var h := road_y + 9.0 - by
		var n := int(ceil(h / 1.5))
		for k in n:
			var c: Color = wc[k % wc.size()]
			var key := LegoMesh.glow(c) if is_space else LegoMesh.key(c)
			lm.box(key, Transform3D(hb, Vector3(foot.x, by + 0.75 + k * 1.5, foot.z)), Vector3(1.4, 1.5, 1.4))
		# balloons on top
		var top := Vector3(foot.x, road_y + 9.8, foot.z)
		var bcols := [Color("#c91a09"), Color("#0055bf"), Color("#f2cd37"), Color("#237841"), Color("#ff79c6")]
		for k in 3:
			var o := hb * Vector3(sgn * (0.4 + 0.6 * k), 1.6 + 0.9 * k, (k - 1) * 0.9)
			var bk := LegoMesh.glow(bcols[(k + int(s)) % 5]) if night else LegoMesh.key(bcols[(k + int(s)) % 5])
			_bar(lm, LegoMesh.key(Color("#f4f4f4")), top, top + o - Vector3.UP * 0.8, 0.06)
			_ball(lm, bk, top + o, 0.75, 4, 10)
	var beam_c := Color("#1b2a34")
	lm.box(LegoMesh.key(beam_c), Transform3D(hb, f.origin + Vector3.UP * 8.4), Vector3(span * 2 + 1.4, 1.8, 0.8), true, 0.7)
	for side: float in [1.0, -1.0]:
		var lbl := Label3D.new()
		lbl.text = text
		lbl.font_size = 150
		lbl.pixel_size = 0.01
		lbl.outline_size = 26
		lbl.modulate = Color("#ffe23b") if not is_space else Color("#9bf0ff")
		lbl.outline_modulate = Color("#1b2a34")
		lbl.double_sided = false
		lbl.transform = Transform3D(hb * Basis(Vector3.UP, 0.0 if side > 0 else PI), f.origin + Vector3.UP * 8.4 + hb.z * 0.42 * side)
		add_child(lbl)
