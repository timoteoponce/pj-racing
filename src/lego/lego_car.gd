class_name LegoCar
extends Node3D
## Visual lego car assembled from the parts in a build. Faces -Z, origin at ground level.

const DARK := "c:3a3b3d"
const SKIN := "c:f6d23c"

var build_data := {}
var wheel_radius := 0.45
var length := 3.4
var width := 2.0
var top_y := 1.0
var _wheel_spin: Array[Node3D] = []
var _front_pivots: Array[Node3D] = []
var _flames: Array[Node3D] = []
var _spin := 0.0
var _boost_vis := 0.0
var _bob := 0.0
var _antenna: Node3D
var _roof := Vector3.INF  # top of the roof, when the body has one


func build(b: Dictionary) -> void:
	build_data = b
	for c in get_children():
		c.queue_free()
	_wheel_spin.clear()
	_front_pivots.clear()
	_flames.clear()
	_antenna = null
	_roof = Vector3.INF

	var chassis := Parts.get_part(b.get("chassis", "ch_kart"))
	var cls: String = chassis.get("cls", "kart")
	var wheels_id: String = b.get("wheels", "wh_std")
	var paint := Parts.paint_keys(b)
	var pri: String = paint["pri"]
	var sec: String = paint["sec"]
	var acc: String = paint["acc"]

	# --- proportions per vehicle class
	var L := 3.0
	var W := 1.8
	var plate_h := 0.24
	var r := 0.42
	var ww := 0.38
	var wheelbase := 2.0
	var track := 1.95
	var ride := 0.3
	match cls:
		"car":
			L = 3.6; W = 2.0; plate_h = 0.3; r = 0.45; ww = 0.42; wheelbase = 2.5; track = 2.05; ride = 0.32
		"monster":
			L = 3.6; W = 2.1; plate_h = 0.4; r = 1.0; ww = 0.85; wheelbase = 2.7; track = 2.6; ride = 1.25
	match wheels_id:
		"wh_monster":
			if cls != "monster":
				r = 0.9; ww = 0.75; ride = 1.05; track += 0.45
		"wh_slick":
			ww *= 1.35
		"wh_knobby":
			r *= 1.12; ww *= 1.1; ride += 0.05
	if chassis["id"] == "ch_titan":
		r *= 1.15; ride += 0.15; track += 0.1
	length = L
	width = W
	wheel_radius = r

	var lm := LegoMesh.new()
	var y0 := ride + plate_h  # top of chassis plate
	# chassis plate with studs
	lm.box(DARK if cls != "kart" else pri, Transform3D(Basis(), Vector3(0, ride + plate_h * 0.5, 0)), Vector3(W, plate_h, L), true, 0.4)
	# bumpers
	lm.box(sec, Transform3D(Basis(), Vector3(0, ride + 0.1, -L * 0.5 - 0.12)), Vector3(W * 0.95, 0.3, 0.25))
	lm.box(sec, Transform3D(Basis(), Vector3(0, ride + 0.1, L * 0.5 + 0.1)), Vector3(W * 0.9, 0.26, 0.2))
	# headlights
	for sx in [-1.0, 1.0]:
		lm.cylinder(LegoMesh.glow(Color("#fff6b0")), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * W * 0.32, ride + plate_h + 0.12, -L * 0.5 - 0.05)), 0.12, 0.08, 10)
		lm.box(LegoMesh.glow(Color("#ff2020")), Transform3D(Basis(), Vector3(sx * W * 0.35, ride + 0.2, L * 0.5 + 0.21)), Vector3(0.3, 0.14, 0.04))
	# monster truck suspension + axles
	if ride > 0.8:
		for z in [-wheelbase * 0.5, wheelbase * 0.5]:
			lm.box(DARK, Transform3D(Basis(), Vector3(0, r, z)), Vector3(track, 0.22, 0.22))
			for sx in [-1.0, 1.0]:
				lm.cylinder("chrome", Transform3D(Basis(Vector3.BACK, sx * 0.35), Vector3(sx * track * 0.28, (r + ride) * 0.5 + 0.1, z)), 0.12, ride - r + 0.5, 8)
				lm.cylinder(acc, Transform3D(Basis(Vector3.BACK, sx * 0.35), Vector3(sx * track * 0.28, (r + ride) * 0.5 + 0.1, z)), 0.17, 0.35, 8)

	var seat_z := L * 0.06
	_build_body(lm, b.get("body", "bd_box"), cls, L, W, y0, pri, sec, acc, seat_z)
	_build_engine(lm, b.get("engine", "en_v4"), L, W, y0)
	_build_spoiler(lm, b.get("spoiler", "sp_none"), L, W, y0, sec, acc)
	_build_driver(lm, b.get("driver", "dr_none"), y0, seat_z, sec, acc)
	_build_extras(lm, Parts.extras_of(b), {"L": L, "W": W, "y0": y0, "ride": ride, "plate_h": plate_h, "r": r, "ww": ww, "wheelbase": wheelbase, "track": track, "seat_z": seat_z}, pri, sec, acc)
	top_y = y0 + 1.6

	var body := lm.to_instance()
	add_child(body)
	_build_wheels(wheels_id, r, ww, wheelbase, track, sec, pri)


func _build_body(lm: LegoMesh, body: String, cls: String, L: float, W: float, y0: float, pri: String, sec: String, acc: String, seat_z: float) -> void:
	match body:
		"bd_none":
			# bare frame: a little nose cone and side rails
			lm.box(acc, _at(0, y0 + 0.1, -L * 0.42), Vector3(W * 0.5, 0.2, L * 0.12), true)
			for sx in [-1.0, 1.0]:
				lm.box(pri, _at(sx * W * 0.44, y0 + 0.1, 0), Vector3(0.16, 0.2, L * 0.7), true, 0.16)
		"bd_box":
			_roof = Vector3(0, y0 + 1.49, L * 0.12)
			lm.box(pri, _at(0, y0 + 0.22, -L * 0.3), Vector3(W * 0.92, 0.44, L * 0.38), true)
			lm.box(pri, _at(0, y0 + 0.36, L * 0.36), Vector3(W * 0.92, 0.72, L * 0.24), true)
			for sx in [-1.0, 1.0]:
				lm.box(pri, _at(sx * W * 0.4, y0 + 0.25, seat_z), Vector3(W * 0.12, 0.5, L * 0.32), true)
				lm.box(sec, _at(sx * W * 0.4, y0 + 0.95, seat_z - 0.05), Vector3(0.12, 0.95, 0.12))
			lm.box("glass", Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, y0 + 0.72, -L * 0.12)), Vector3(W * 0.8, 0.05, 0.75))
			lm.box(sec, _at(0, y0 + 1.42, L * 0.12), Vector3(W * 0.92, 0.14, L * 0.44), true)
		"bd_wedge":
			lm.box(pri, _at(0, y0 + 0.1, -L * 0.28), Vector3(W * 0.92, 0.2, L * 0.44), true)
			lm.box(pri, _at(0, y0 + 0.3, -L * 0.2), Vector3(W * 0.7, 0.2, L * 0.28), true)
			lm.box(acc, _at(0, y0 + 0.5, -L * 0.14), Vector3(W * 0.4, 0.2, L * 0.16), true)
			for sx in [-1.0, 1.0]:
				lm.box(sec, _at(sx * W * 0.38, y0 + 0.25, L * 0.12), Vector3(W * 0.2, 0.5, L * 0.5), true)
			lm.box(pri, _at(0, y0 + 0.3, L * 0.38), Vector3(W * 0.92, 0.6, L * 0.22), true)
			lm.box("glass", Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3(0, y0 + 0.75, -L * 0.04)), Vector3(W * 0.55, 0.04, 0.45))
		"bd_pickup":
			lm.box(pri, _at(0, y0 + 0.25, -L * 0.34), Vector3(W * 0.92, 0.5, L * 0.3), true)
			for sx in [-1.0, 1.0]:
				lm.box(pri, _at(sx * W * 0.41, y0 + 0.3, seat_z - 0.1), Vector3(W * 0.1, 0.6, L * 0.3))
				lm.box(pri, _at(sx * W * 0.41, y0 + 1.0, seat_z + 0.25), Vector3(0.14, 0.8, 0.14))
			lm.box(pri, _at(0, y0 + 0.7, seat_z + 0.32), Vector3(W * 0.92, 1.4, 0.18))
			lm.box("glass", Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0, y0 + 0.88, seat_z - 0.42)), Vector3(W * 0.82, 0.05, 0.85))
			lm.box(pri, _at(0, y0 + 1.46, seat_z), Vector3(W * 0.92, 0.14, 0.8), true)
			_roof = Vector3(0, y0 + 1.53, seat_z)
			# bed
			var bz := L * 0.32
			lm.box(sec, _at(0, y0 + 0.05, bz), Vector3(W * 0.92, 0.1, L * 0.36))
			for sx in [-1.0, 1.0]:
				lm.box(sec, _at(sx * W * 0.42, y0 + 0.3, bz), Vector3(0.16, 0.5, L * 0.36), true)
			lm.box(acc, _at(0, y0 + 0.3, bz + L * 0.17), Vector3(W * 0.92, 0.5, 0.14), true)
		"bd_bubble":
			lm.box(pri, _at(0, y0 + 0.2, -L * 0.3), Vector3(W * 0.9, 0.4, L * 0.36), true)
			lm.cylinder(pri, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, y0 + 0.2, -L * 0.48)), W * 0.3, 0.3, 14)
			lm.box(pri, _at(0, y0 + 0.2, L * 0.3), Vector3(W * 0.9, 0.4, L * 0.36), true)
			lm.frustum("glass", _at(0, y0 + 0.6, seat_z), W * 0.46, W * 0.2, 1.2, 16, true, false)
			lm.cylinder(sec, _at(0, y0 + 0.04, seat_z), W * 0.48, 0.12, 16)
		"bd_rocket":
			lm.cylinder(pri, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, y0 + 0.3, -L * 0.15)), W * 0.3, L * 0.5, 14)
			lm.frustum(sec, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, y0 + 0.3, -L * 0.5)), W * 0.3, 0.06, L * 0.28, 14)
			for sx in [-1.0, 1.0]:
				lm.box(acc, Transform3D(Basis(Vector3.FORWARD, sx * 0.5), Vector3(sx * W * 0.45, y0 + 0.4, L * 0.32)), Vector3(0.1, 0.9, L * 0.25))
				lm.box(pri, _at(sx * W * 0.38, y0 + 0.2, L * 0.2), Vector3(W * 0.18, 0.4, L * 0.4), true)
			lm.box(acc, _at(0, y0 + 0.75, L * 0.42), Vector3(0.1, 0.9, L * 0.16))
		"bd_cyber":
			lm.wedge(pri, Transform3D(Basis(), Vector3(0, y0, -L * 0.22)), Vector3(W * 0.95, 0.9, L * 0.55))
			lm.box(pri, _at(0, y0 + 0.45, L * 0.28), Vector3(W * 0.95, 0.9, L * 0.45), true)
			lm.box(LegoMesh.glow(Color("#3df0ff")), _at(0, y0 + 0.92, L * 0.06), Vector3(W * 0.95, 0.04, 0.08))
			lm.box("glass", Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, y0 + 0.95, -L * 0.03)), Vector3(W * 0.7, 0.05, 0.6))
	# always a seat
	lm.box(DARK, _at(0, y0 + 0.12, seat_z + 0.2), Vector3(0.7, 0.24, 0.6))
	lm.box(DARK, _at(0, y0 + 0.45, seat_z + 0.48), Vector3(0.7, 0.7, 0.14))
	# steering wheel
	lm.cylinder(DARK, Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3(0, y0 + 0.62, seat_z - 0.45)), 0.2, 0.06, 12)


func _build_engine(lm: LegoMesh, engine: String, L: float, W: float, y0: float) -> void:
	var z := L * 0.5 - 0.2
	var exhausts := []
	match engine:
		"en_tiny":
			lm.box("c:6b6e72", _at(0, y0 + 0.2, z - 0.1), Vector3(0.5, 0.35, 0.4), true)
			exhausts = [Vector3(0.15, y0 + 0.2, z + 0.25)]
		"en_v4":
			lm.box("c:6b6e72", _at(0, y0 + 0.3, z - 0.15), Vector3(0.8, 0.5, 0.6), true)
			exhausts = [Vector3(-0.25, y0 + 0.3, z + 0.35), Vector3(0.25, y0 + 0.3, z + 0.35)]
		"en_v6":
			lm.box("c:6b6e72", _at(0, y0 + 0.35, z - 0.15), Vector3(1.0, 0.6, 0.7), true)
			lm.cylinder("chrome", _at(0, y0 + 0.8, z - 0.15), 0.25, 0.35, 12)
			exhausts = [Vector3(-0.35, y0 + 0.35, z + 0.4), Vector3(0.35, y0 + 0.35, z + 0.4)]
		"en_v8":
			for sx in [-1.0, 1.0]:
				lm.box("c:a01010", _at(sx * 0.3, y0 + 0.4, z - 0.2), Vector3(0.5, 0.7, 0.8), true)
				for k in 2:
					lm.cylinder("chrome", _at(sx * (0.55 + 0.12), y0 + 0.9, z - 0.4 + k * 0.35), 0.08, 0.7, 8)
			lm.box("chrome", _at(0, y0 + 0.82, z - 0.2), Vector3(0.5, 0.14, 0.6))
			exhausts = [Vector3(-0.67, y0 + 1.25, z - 0.4), Vector3(0.67, y0 + 1.25, z - 0.4), Vector3(-0.67, y0 + 1.25, z - 0.05), Vector3(0.67, y0 + 1.25, z - 0.05)]
		"en_jet":
			lm.cylinder("chrome", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, y0 + 0.5, z)), 0.42, 1.1, 16)
			lm.cylinder(LegoMesh.glow(Color("#ff8a20")), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, y0 + 0.5, z + 0.56)), 0.3, 0.04, 16)
			exhausts = [Vector3(0, y0 + 0.5, z + 0.6)]
		"en_volt":
			lm.box("c:1b2a34", _at(0, y0 + 0.3, z - 0.15), Vector3(1.0, 0.5, 0.6), true)
			for k in 3:
				lm.cylinder(LegoMesh.glow(Color("#3da8ff")), _at(-0.3 + k * 0.3, y0 + 0.7, z - 0.15), 0.1, 0.35, 10)
			exhausts = [Vector3(0, y0 + 0.3, z + 0.2)]
	for e in exhausts:
		var vertical: bool = e.y > y0 + 1.0
		if not vertical and engine != "en_jet" and engine != "en_volt":
			lm.cylinder("chrome", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), e - Vector3(0, 0, 0.15)), 0.09, 0.4, 8)
		var f := Node3D.new()
		f.position = e
		if not vertical:
			f.rotation.x = PI * 0.5
		var flm := LegoMesh.new()
		flm.frustum(LegoMesh.glow(Color("#ff9a2a")), Transform3D(Basis(), Vector3(0, 0.35, 0)), 0.16, 0.0, 0.7, 8)
		flm.frustum(LegoMesh.glow(Color("#fff27a")), Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.09, 0.0, 0.4, 8)
		var fi := flm.to_instance(false)
		f.add_child(fi)
		f.scale = Vector3.ONE * 0.01
		f.visible = false
		add_child(f)
		_flames.append(f)


func _build_spoiler(lm: LegoMesh, sp: String, L: float, W: float, y0: float, sec: String, acc: String) -> void:
	var z := L * 0.5 - 0.1
	match sp:
		"sp_lip":
			lm.box(acc, _at(0, y0 + 0.75, z), Vector3(W * 0.9, 0.1, 0.35), true)
			lm.box(acc, _at(0, y0 + 0.5, z + 0.1), Vector3(W * 0.8, 0.45, 0.1))
		"sp_wing":
			for sx in [-1.0, 1.0]:
				lm.box(sec, _at(sx * W * 0.32, y0 + 0.85, z), Vector3(0.12, 0.9, 0.2))
			lm.box(acc, Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0, y0 + 1.35, z)), Vector3(W * 1.05, 0.1, 0.6), true)
		"sp_twin":
			for sx in [-1.0, 1.0]:
				lm.box(acc, Transform3D(Basis(Vector3.BACK, sx * 0.25), Vector3(sx * W * 0.4, y0 + 0.9, z)), Vector3(0.1, 1.0, 0.6))
				lm.box(sec, _at(sx * W * 0.4, y0 + 0.35, z), Vector3(0.3, 0.3, 0.5), true)


func _build_driver(lm: LegoMesh, dr: String, y0: float, z: float, sec: String, acc: String) -> void:
	lm.box(sec, _at(0, y0 + 0.55, z), Vector3(0.6, 0.5, 0.34))  # torso
	for sx in [-1.0, 1.0]:
		lm.box(sec, Transform3D(Basis(Vector3.RIGHT, 1.0), Vector3(sx * 0.36, y0 + 0.62, z - 0.18)), Vector3(0.16, 0.42, 0.16))
		lm.box(SKIN, _at(sx * 0.36, y0 + 0.55, z - 0.42), Vector3(0.14, 0.14, 0.14))
	lm.cylinder(SKIN, _at(0, y0 + 0.86, z), 0.1, 0.12, 10)  # neck
	var hy := y0 + 1.08
	lm.cylinder(SKIN, _at(0, hy, z), 0.22, 0.36, 14)  # head
	# smile + eyes
	lm.box("c:1b1b1b", _at(-0.08, hy + 0.05, z - 0.215), Vector3(0.05, 0.07, 0.02))
	lm.box("c:1b1b1b", _at(0.08, hy + 0.05, z - 0.215), Vector3(0.05, 0.07, 0.02))
	lm.box("c:1b1b1b", _at(0, hy - 0.07, z - 0.215), Vector3(0.16, 0.03, 0.02))
	match dr:
		"dr_helmet":
			lm.frustum(acc, _at(0, hy + 0.12, z + 0.02), 0.27, 0.2, 0.36, 14, true, false)
			lm.box("glass", _at(0, hy + 0.05, z - 0.2), Vector3(0.4, 0.14, 0.06))
		"dr_cap":
			lm.cylinder(acc, _at(0, hy + 0.22, z), 0.24, 0.14, 14)
			lm.box(acc, _at(0, hy + 0.17, z - 0.28), Vector3(0.36, 0.04, 0.22))
		"dr_viking":
			lm.frustum("c:8a8f96", _at(0, hy + 0.2, z), 0.25, 0.12, 0.22, 14)
			for sx in [-1.0, 1.0]:
				lm.frustum("c:f4f0e0", Transform3D(Basis(Vector3.BACK, -sx * 0.9), Vector3(sx * 0.3, hy + 0.28, z)), 0.08, 0.01, 0.35, 8)
		"dr_astro":
			lm.cylinder("c:f4f4f4", _at(0, hy + 0.02, z), 0.3, 0.5, 16)
			lm.box("gold", _at(0, hy + 0.03, z - 0.27), Vector3(0.38, 0.24, 0.06))
		"dr_wizard":
			lm.cylinder("c:3a2a8a", _at(0, hy + 0.19, z), 0.34, 0.04, 16)
			lm.frustum("c:3a2a8a", _at(0, hy + 0.5, z), 0.22, 0.02, 0.6, 12)
		"dr_crown":
			lm.cylinder("gold", _at(0, hy + 0.22, z), 0.23, 0.12, 14, false, false)
			for k in 5:
				var a := TAU * k / 5.0
				lm.frustum("gold", _at(cos(a) * 0.2, hy + 0.34, z + sin(a) * 0.2), 0.06, 0.0, 0.14, 6)


func _build_wheels(wid: String, r: float, ww: float, wheelbase: float, track: float, sec: String, pri: String) -> void:
	var lm := LegoMesh.new()
	var axis := Basis(Vector3.BACK, PI * 0.5)  # cylinder Y -> X
	var seg := 18
	lm.cylinder("rubber", Transform3D(axis, Vector3.ZERO), r, ww, seg)
	var hub_k := "chrome"
	match wid:
		"wh_gold":
			hub_k = "gold"
		"wh_monster":
			hub_k = pri
		"wh_knobby":
			hub_k = sec
	lm.cylinder(hub_k, Transform3D(axis, Vector3(ww * 0.5 + 0.01, 0, 0)), r * 0.58, 0.06, 14)
	lm.cylinder(hub_k, Transform3D(axis, Vector3(ww * 0.5 + 0.05, 0, 0)), r * 0.2, 0.1, 10)
	if wid in ["wh_monster", "wh_knobby"] or r > 0.8:
		var n := 14 if r > 0.8 else 12
		for i in n:
			var a := TAU * i / n
			var p := Vector3(0, sin(a) * r, cos(a) * r)
			var b := Basis(Vector3.RIGHT, PI * 0.5 - a)
			lm.box("rubber", Transform3D(b, p), Vector3(ww * 0.9, r * 0.12, r * 0.22))
	var mesh := lm.commit()
	for i in 4:
		var front := i < 2
		var left := i % 2 == 0
		var pivot := Node3D.new()
		pivot.position = Vector3((-1 if left else 1) * track * 0.5, r, (-1 if front else 1) * wheelbase * 0.5)
		add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if left:
			mi.rotation.y = PI
		spin.add_child(mi)
		_wheel_spin.append(spin)
		if front:
			_front_pivots.append(pivot)


func _build_extras(lm: LegoMesh, extras: Array, d: Dictionary, pri: String, sec: String, acc: String) -> void:
	if extras.is_empty():
		return
	var L: float = d["L"]
	var W: float = d["W"]
	var y0: float = d["y0"]
	var ride: float = d["ride"]
	var r: float = d["r"]
	var seat_z: float = d["seat_z"]
	var front := -L * 0.5
	var back := L * 0.5
	# roof-mounted extras need a roof: open cars get a roll bar behind the driver
	if ("ex_siren" in extras or "ex_roofbar" in extras) and _roof == Vector3.INF:
		var rz := seat_z + 0.62
		for sx in [-1.0, 1.0]:
			lm.box("c:1b2a34", _at(sx * W * 0.38, y0 + 0.78, rz), Vector3(0.16, 1.56, 0.16))
		lm.box("c:1b2a34", _at(0, y0 + 1.6, rz), Vector3(W * 0.84, 0.16, 0.22), true)
		_roof = Vector3(0, y0 + 1.68, rz)
	for ex in extras:
		match ex:
			"ex_lights":
				for sx in [-1.0, 1.0]:
					var p := Vector3(sx * W * 0.3, y0 + 0.28, front - 0.18)
					lm.cylinder("chrome", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p), 0.26, 0.14, 14)
					lm.cylinder(LegoMesh.glow(Color("#fffbe0")), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p - Vector3(0, 0, 0.06)), 0.2, 0.06, 14)
			"ex_bullbar":
				var z := front - 0.42
				for sx in [-1.0, 1.0]:
					lm.cylinder("chrome", _at(sx * W * 0.36, ride + 0.35, z), 0.07, 0.9, 8)
				for h in [ride + 0.1, ride + 0.6]:
					lm.cylinder("chrome", Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, h, z)), 0.07, W * 0.78, 8)
			"ex_pipes":
				for sx in [-1.0, 1.0]:
					var p := Vector3(sx * (W * 0.5 + 0.14), ride + 0.2, 0.1)
					lm.cylinder("chrome", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p), 0.12, L * 0.55, 10)
					lm.cylinder("c:1b1b1b", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 0, L * 0.28)), 0.08, 0.04, 10)
			"ex_mudflaps":
				for sx in [-1.0, 1.0]:
					lm.box("rubber", _at(sx * float(d["track"]) * 0.5, r * 0.75, float(d["wheelbase"]) * 0.5 + r + 0.08), Vector3(float(d["ww"]) * 0.9, r * 1.1, 0.06))
			"ex_flag":
				var base := Vector3(-W * 0.4, y0, back - 0.25)
				lm.cylinder("c:1b2a34", _at(base.x, y0 + 1.2, base.z), 0.05, 2.4, 6)
				for i in 3:
					for j in 2:
						var col := "c:f4f4f4" if (i + j) % 2 == 0 else "c:1b1b1b"
						lm.box(col, _at(base.x - 0.12 - i * 0.22, y0 + 2.25 - j * 0.22, base.z), Vector3(0.22, 0.22, 0.03))
			"ex_antenna":
				_antenna = Node3D.new()
				_antenna.position = Vector3(W * 0.4, y0, back - 0.25)
				var alm := LegoMesh.new()
				alm.cylinder("c:1b1b1b", _at(0, 0.9, 0), 0.03, 1.8, 6)
				alm.box(acc, _at(0, 1.85, 0), Vector3(0.22, 0.22, 0.22), true, 0.22)
				_antenna.add_child(alm.to_instance(false))
				add_child(_antenna)
			"ex_siren":
				lm.box("c:1b2a34", Transform3D(Basis(), _roof + Vector3(0, 0.06, 0)), Vector3(W * 0.6, 0.12, 0.3))
				lm.box(LegoMesh.glow(Color("#ff2020")), Transform3D(Basis(), _roof + Vector3(-W * 0.15, 0.24, 0)), Vector3(W * 0.26, 0.24, 0.26))
				lm.box(LegoMesh.glow(Color("#2060ff")), Transform3D(Basis(), _roof + Vector3(W * 0.15, 0.24, 0)), Vector3(W * 0.26, 0.24, 0.26))
			"ex_roofbar":
				var off := Vector3(0, 0, -0.22) if "ex_siren" in extras else Vector3.ZERO
				lm.box("c:1b2a34", Transform3D(Basis(), _roof + off + Vector3(0, 0.08, 0)), Vector3(W * 0.85, 0.16, 0.2))
				for i in 4:
					var x := (-1.5 + i) * W * 0.2
					lm.cylinder(LegoMesh.glow(Color("#fff27a")), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), _roof + off + Vector3(x, 0.26, -0.08)), 0.11, 0.12, 10)
			"ex_horns":
				for sx in [-1.0, 1.0]:
					lm.frustum("c:f4f0e0", Transform3D(Basis(Vector3.BACK, -sx * 1.0), Vector3(sx * W * 0.32, y0 + 0.62, front + 0.35)), 0.13, 0.01, 0.75, 8)
			"ex_fin":
				lm.wedge(acc, Transform3D(Basis(Vector3.UP, PI), Vector3(0, y0 + 0.02, back - 0.55)), Vector3(0.1, 1.1, 1.0))
			"ex_boosters":
				for sx in [-1.0, 1.0]:
					var p := Vector3(sx * (W * 0.5 + 0.1), y0 + 0.35, back - 0.4)
					lm.cylinder("chrome", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p), 0.2, 0.9, 12)
					lm.cylinder(acc, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 0, -0.5)), 0.21, 0.12, 12)
					lm.cylinder(LegoMesh.glow(Color("#ff8a20")), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 0, 0.46)), 0.14, 0.03, 12)
					_add_flame(p + Vector3(0, 0, 0.5), false)
			"ex_number":
				for sx in [-1.0, 1.0]:
					var p := Vector3(sx * (W * 0.5 + 0.02), y0 + 0.12, 0.05)
					lm.cylinder("c:f4f4f4", Transform3D(Basis(Vector3.BACK, PI * 0.5), p), 0.34, 0.04, 16)
					lm.box("c:1b1b1b", _at(p.x + sx * 0.025, p.y, p.z), Vector3(0.02, 0.4, 0.09))
					lm.box("c:1b1b1b", _at(p.x + sx * 0.025, p.y + 0.15, p.z - 0.07), Vector3(0.02, 0.09, 0.09))


func _add_flame(e: Vector3, vertical: bool) -> void:
	var f := Node3D.new()
	f.position = e
	if not vertical:
		f.rotation.x = PI * 0.5
	var flm := LegoMesh.new()
	flm.frustum(LegoMesh.glow(Color("#ff9a2a")), Transform3D(Basis(), Vector3(0, 0.35, 0)), 0.16, 0.0, 0.7, 8)
	flm.frustum(LegoMesh.glow(Color("#fff27a")), Transform3D(Basis(), Vector3(0, 0.2, 0)), 0.09, 0.0, 0.4, 8)
	f.add_child(flm.to_instance(false))
	f.scale = Vector3.ONE * 0.01
	f.visible = false
	add_child(f)
	_flames.append(f)


static func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))


func animate(dt: float, speed: float, steer: float, boosting: bool) -> void:
	_spin += speed * dt / maxf(wheel_radius, 0.1)
	for w in _wheel_spin:
		w.rotation.x = -_spin
	for p in _front_pivots:
		p.rotation.y = lerpf(p.rotation.y, -steer * 0.45, minf(1.0, dt * 12.0))
	_boost_vis = move_toward(_boost_vis, 1.0 if boosting else 0.0, dt * 6.0)
	if _antenna:
		_antenna.rotation.x = clampf(speed / 40.0, -0.3, 0.45) + sin(_spin * 0.35) * 0.08
	for f in _flames:
		f.visible = _boost_vis > 0.02
		var flick := 0.85 + 0.3 * randf()
		f.scale = Vector3(1, flick * 1.4, 1) * maxf(_boost_vis, 0.01)
