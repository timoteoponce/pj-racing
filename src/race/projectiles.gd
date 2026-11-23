class_name Projectile
extends Node3D
## Brick Missile (homes along the track to the next kart ahead) and Oil Slick (trap).

var kind := "missile"
var owner_kart: Kart
var target: Kart
var race: Node
var track: Track
var s := 0.0
var lat := 0.0
var age := 0.0
var life := 6.0
var speed := 78.0


static func missile(r: Node, shooter: Kart) -> Projectile:
	var p := Projectile.new()
	p.kind = "missile"
	p.race = r
	p.track = shooter.track
	p.owner_kart = shooter
	p.s = shooter.offset + 3.0
	var c := p.track.point_at(p.s)
	p.lat = (shooter.global_position - c).dot(p.track.right_at(p.s))
	p.speed = maxf(78.0, shooter.speed + 30.0)
	# next kart ahead by progress
	var best := INF
	for k in r.karts:
		if k == shooter or k.finished:
			continue
		var d: float = k.progress - shooter.progress
		if d > 0.0 and d < best:
			best = d
			p.target = k
	var lm := LegoMesh.new()
	lm.box(LegoMesh.key(Color("#c91a09")), Transform3D(), Vector3(0.9, 0.7, 1.6), true, 0.4)
	lm.frustum(LegoMesh.key(Color("#f4f4f4")), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -1.1)), 0.35, 0.05, 0.6, 10)
	lm.frustum(LegoMesh.glow(Color("#ff9a2a")), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 1.2)), 0.3, 0.0, 0.9, 8)
	p.add_child(lm.to_instance(true))
	return p


static func oil(r: Node, dropper: Kart) -> Projectile:
	var p := Projectile.new()
	p.kind = "oil"
	p.race = r
	p.track = dropper.track
	p.owner_kart = dropper
	p.life = 45.0
	var lm := LegoMesh.new()
	lm.cylinder(LegoMesh.key(Color("#141414")), Transform3D(Basis(), Vector3(0, 0.05, 0)), 1.6, 0.08, 18)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 7:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.3, 1.4)
		var col: Color = [Color("#c91a09"), Color("#f2cd37"), Color("#0055bf"), Color("#f4f4f4")][i % 4]
		lm.box(LegoMesh.key(col), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * d, 0.2, sin(a) * d)), Vector3(0.4, 0.24, 0.4), true, 0.4)
	p.add_child(lm.to_instance(false))
	return p


func _physics_process(dt: float) -> void:
	age += dt
	if age > life:
		_pop()
		return
	if kind == "missile":
		s += speed * dt
		var want := global_position
		if target and is_instance_valid(target) and not target.finished and target.global_position.distance_to(global_position) < 28.0:
			want = global_position.move_toward(target.global_position + Vector3.UP * 0.9, speed * dt)
		else:
			if target and is_instance_valid(target):
				var tc := track.point_at(target.offset)
				var tl := (target.global_position - tc).dot(track.right_at(target.offset))
				lat = move_toward(lat, tl, dt * 10.0)
			want = track.point_at(s) + track.right_at(s) * lat + Vector3.UP * 0.9
		var dir := want - global_position
		if dir.length() > 0.01:
			look_at(global_position + dir, Vector3.UP)
		global_position = want
	for k in race.karts:
		if k == owner_kart and age < 0.6:
			continue
		var d: Vector3 = k.global_position + Vector3.UP * 0.9 - global_position
		var hit_r := 2.0 if kind == "missile" else 1.9
		if Vector2(d.x, d.z).length() < hit_r and absf(d.y) < 2.0:
			k.hit(owner_kart)
			_pop()
			return


func _pop() -> void:
	Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, [Color("#c91a09"), Color("#f2cd37"), Color("#1b2a34")], 14, 8.0)
	queue_free()
