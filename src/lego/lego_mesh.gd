class_name LegoMesh
extends RefCounted
## Accumulates lego-style geometry (bricks with studs, cylinders, cones) grouped by material
## and commits it into a single multi-surface ArrayMesh: few draw calls, lots of bricks.
##
## Material keys: "c:rrggbb" plastic, "glow:rrggbb" emissive, "glass", "chrome", "gold",
## or any key registered with LegoMesh.register().

static var _mat_cache := {}

var _groups := {}


static func key(c: Color) -> String:
	return "c:" + c.to_html(false)


static func glow(c: Color) -> String:
	return "glow:" + c.to_html(false)


static func register(k: String, m: Material) -> void:
	_mat_cache[k] = m


static func material(k: String) -> Material:
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	var parts := k.split(":")
	match parts[0]:
		"c":
			m.albedo_color = Color.html(parts[1])
			m.roughness = 0.28
			m.metallic_specular = 0.7
		"glow":
			m.albedo_color = Color.html(parts[1])
			m.emission_enabled = true
			m.emission = Color.html(parts[1])
			m.emission_energy_multiplier = 2.2
		"glass":
			m.albedo_color = Color(0.55, 0.8, 1.0, 0.42)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic_specular = 1.0
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"chrome":
			m.albedo_color = Color(0.82, 0.85, 0.9)
			m.metallic = 0.85
			m.roughness = 0.18
		"gold":
			m.albedo_color = Color(1.0, 0.76, 0.18)
			m.metallic = 0.9
			m.roughness = 0.22
		"rubber":
			m.albedo_color = Color(0.09, 0.09, 0.1)
			m.roughness = 0.75
		_:
			m.albedo_color = Color.MAGENTA
	_mat_cache[k] = m
	return m


func is_empty() -> bool:
	return _groups.is_empty()


func _g(k: String) -> Dictionary:
	if not _groups.has(k):
		_groups[k] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
	return _groups[k]


## Triangle with winding fixed so its front face points along n (Godot uses clockwise fronts).
func tri(k: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	var g := _g(k)
	var base: int = g["v"].size()
	if na == Vector3.ZERO:
		na = n
		nb = n
		nc = n
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	g["v"].append(a)
	g["v"].append(b)
	g["v"].append(c)
	g["n"].append(na)
	g["n"].append(nb)
	g["n"].append(nc)
	g["uv"].append(Vector2(a.x + a.z, a.y))
	g["uv"].append(Vector2(b.x + b.z, b.y))
	g["uv"].append(Vector2(c.x + c.z, c.y))
	g["i"].append(base)
	g["i"].append(base + 1)
	g["i"].append(base + 2)


func quad(k: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	tri(k, a, b, c, n)
	tri(k, a, c, d, n)


## Box centered at xf.origin. With studs=true, adds lego studs on the top face.
func box(k: String, xf: Transform3D, size: Vector3, studs := false, pitch := 0.4, stud_k := "") -> void:
	var h := size * 0.5
	var c := []
	for i in 8:
		c.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	var bx := xf.basis.x.normalized()
	var by := xf.basis.y.normalized()
	var bz := xf.basis.z.normalized()
	quad(k, c[2], c[3], c[7], c[6], by)  # top
	quad(k, c[0], c[1], c[5], c[4], -by)  # bottom
	quad(k, c[1], c[3], c[7], c[5], bx)  # +x
	quad(k, c[0], c[2], c[6], c[4], -bx)  # -x
	quad(k, c[4], c[5], c[7], c[6], bz)  # +z
	quad(k, c[0], c[1], c[3], c[2], -bz)  # -z
	if studs:
		studs_on(stud_k if stud_k != "" else k, xf.translated_local(Vector3(0, h.y, 0)), size.x, size.z, pitch)


## Grid of studs on a surface whose center/orientation is top_xf (Y up = stud axis).
func studs_on(k: String, top_xf: Transform3D, sx: float, sz: float, pitch := 0.4, seg := 8) -> void:
	var nx := maxi(1, roundi(sx / pitch))
	var nz := maxi(1, roundi(sz / pitch))
	var px := sx / nx
	var pz := sz / nz
	var r := minf(px, pz) * 0.3
	var hh := minf(px, pz) * 0.18
	for ix in nx:
		for iz in nz:
			var lp := Vector3(-sx * 0.5 + (ix + 0.5) * px, hh * 0.5, -sz * 0.5 + (iz + 0.5) * pz)
			cylinder(k, top_xf.translated_local(lp), r, hh, seg, true, false)


## Frustum along local Y, centered on xf.origin. r0 bottom radius, r1 top radius.
func frustum(k: String, xf: Transform3D, r0: float, r1: float, h: float, seg := 12, top_cap := true, bottom_cap := true) -> void:
	var by := xf.basis.y.normalized()
	var slope := (r0 - r1) / maxf(h, 0.001)
	var prev_b := Vector3.ZERO
	var prev_t := Vector3.ZERO
	var prev_n := Vector3.ZERO
	var top_c := xf * Vector3(0, h * 0.5, 0)
	var bot_c := xf * Vector3(0, -h * 0.5, 0)
	for i in seg + 1:
		var a := TAU * float(i) / seg
		var dir := Vector3(cos(a), 0, sin(a))
		var pb := xf * (dir * r0 + Vector3(0, -h * 0.5, 0))
		var pt := xf * (dir * r1 + Vector3(0, h * 0.5, 0))
		var nrm := (xf.basis * (dir + Vector3(0, slope, 0))).normalized()
		if i > 0:
			var face_n := (prev_n + nrm).normalized()
			tri(k, prev_b, pb, pt, face_n, prev_n, nrm, nrm)
			tri(k, prev_b, pt, prev_t, face_n, prev_n, nrm, prev_n)
			if top_cap and r1 > 0.0:
				tri(k, top_c, prev_t, pt, by)
			if bottom_cap and r0 > 0.0:
				tri(k, bot_c, prev_b, pb, -by)
		prev_b = pb
		prev_t = pt
		prev_n = nrm


func cylinder(k: String, xf: Transform3D, r: float, h: float, seg := 12, top_cap := true, bottom_cap := true) -> void:
	frustum(k, xf, r, r, h, seg, top_cap, bottom_cap)


## Wedge/ramp: bottom rectangle size.x by size.z, rising to size.y at the -Z end.
func wedge(k: String, xf: Transform3D, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var a := xf * Vector3(-hx, 0, hz)
	var b := xf * Vector3(hx, 0, hz)
	var c := xf * Vector3(hx, 0, -hz)
	var d := xf * Vector3(-hx, 0, -hz)
	var e := xf * Vector3(hx, size.y, -hz)
	var f := xf * Vector3(-hx, size.y, -hz)
	var up_n := (xf.basis * Vector3(0, size.z, size.y)).normalized()
	quad(k, a, b, e, f, up_n)
	quad(k, d, c, e, f, -xf.basis.z.normalized())
	tri(k, a, d, f, -xf.basis.x.normalized())
	tri(k, b, c, e, xf.basis.x.normalized())
	quad(k, a, b, c, d, -xf.basis.y.normalized())


func commit(mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	for k in _groups:
		var g: Dictionary = _groups[k]
		if g["v"].is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g["v"]
		arr[Mesh.ARRAY_NORMAL] = g["n"]
		arr[Mesh.ARRAY_TEX_UV] = g["uv"]
		arr[Mesh.ARRAY_INDEX] = g["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(k))
	return mesh


func to_instance(shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
