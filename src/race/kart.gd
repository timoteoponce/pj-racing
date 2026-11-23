class_name Kart
extends CharacterBody3D
## Arcade kart: speed/heading model on a CharacterBody3D, drifting with mini-turbos,
## ramp tricks, items, bumping and monster-truck crushing.

signal lap_completed(kart: Kart, lap: int)

const GRAVITY := 40.0
const ITEMS := ["turbo", "triple", "missile", "oil", "shield"]

var entry := {}
var racer_name := "CPU"
var racer_id := ""
var is_human := false
var slot := -1
var color := Color.RED
var track: Track
var race: Node
var ai: KartAI

# tuning (from stats)
var max_speed := 34.0
var accel := 22.0
var turn_rate := 2.2
var grip := 7.0
var weight := 5.0
var offroad_mult := 0.6
var is_monster := false
var easy_drive := false  # kids mode: automatic gas, gentle steering help, softer wall hits
var ai_mult := 1.0

# dynamics
var speed := 0.0
var heading := 0.0
var surface := "road"
var spin_timer := 0.0
var boost_timer := 0.0
var boost_power := 1.0
var shield_timer := 0.0
var invuln_timer := 0.0
var drifting := false
var drift_dir := 0.0
var drift_charge := 0.0
var air_time := 0.0
var _was_on_floor := true
var _on_ramp := false
var _ramp_launch := false
var _trick := false
var _trick_spin := 0.0
var _spin_vis := 0.0
var _up := Vector3.UP
var _hop := 0.0
var _bump_cd := {}
var _offtrack := 0.0
var _hazard := 0.0
var _stuck := 0.0

# items
var item := ""
var item_uses := 0
var item_roll := 0.0

# race state
var controls_enabled := false
var offset := 0.0
var lap := 0
var max_lap := 0
var progress := 0.0
var finished := false
var finish_time := 0.0
var place := 1
var wrong_way := 0.0

# input
var in_throttle := 0.0
var in_steer := 0.0
var in_drift := false
var in_item := false
var in_look := false

var model: Node3D
var car: LegoCar
var engine: AudioStreamPlayer
var _sparks: Array[CPUParticles3D] = []
var _dust: CPUParticles3D
var _shield_mi: MeshInstance3D
var _shield_mat: StandardMaterial3D


func setup(e: Dictionary, t: Track, r: Node, difficulty: int) -> void:
	entry = e
	track = t
	race = r
	racer_name = e["name"]
	racer_id = e["id"]
	is_human = e["human"]
	slot = e["slot"]
	color = e["color"]
	var b: Dictionary = e["build"]
	var stats := Parts.compute_stats(b, Save.upgrades() if is_human else {})
	is_monster = Parts.is_monster(b)
	max_speed = 25.0 + stats["spd"] * 2.0
	accel = 11.0 + stats["acc"] * 2.4
	turn_rate = 1.55 + stats["hnd"] * 0.11
	grip = 4.5 + stats["hnd"] * 0.45
	weight = stats["wgt"]
	offroad_mult = clampf(0.4 + stats["off"] * 0.055, 0.4, 0.97)
	easy_drive = is_human and bool(Save.setting("easy_drive", true))
	if not is_human:
		var m: float = [0.86, 0.95, 1.03][difficulty]
		max_speed *= m
		accel *= m
		ai = KartAI.new(self, difficulty)

	collision_layer = 2
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.8
	floor_stop_on_slope = true
	floor_block_on_wall = false
	max_slides = 4
	safe_margin = 0.04
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.05
	cs.shape = sh
	cs.position.y = 1.05
	add_child(cs)

	model = Node3D.new()
	add_child(model)
	car = LegoCar.new()
	model.add_child(car)
	car.build(b)
	if is_monster:
		car.scale = Vector3.ONE * 0.95

	for sx in [-1.0, 1.0]:
		var p := CPUParticles3D.new()
		p.amount = 20
		p.lifetime = 0.35
		p.emitting = false
		p.local_coords = false
		p.direction = Vector3(0, 1, 1)
		p.spread = 35.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 6.0
		p.gravity = Vector3(0, -12, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.0
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		sm.radial_segments = 6
		sm.rings = 3
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		sm.material = mat
		p.mesh = sm
		p.position = Vector3(sx * car.width * 0.5, 0.2, car.length * 0.45)
		model.add_child(p)
		_sparks.append(p)

	_dust = CPUParticles3D.new()
	_dust.amount = 16
	_dust.lifetime = 0.6
	_dust.emitting = false
	_dust.local_coords = false
	_dust.direction = Vector3(0, 1, 0.5)
	_dust.spread = 40.0
	_dust.initial_velocity_min = 1.0
	_dust.initial_velocity_max = 3.0
	_dust.gravity = Vector3(0, -2, 0)
	var dm := BoxMesh.new()
	dm.size = Vector3(0.3, 0.3, 0.3)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(track.theme["shoulder"]).lightened(0.15)
	dm.material = dmat
	_dust.mesh = dm
	_dust.position = Vector3(0, 0.2, car.length * 0.5)
	model.add_child(_dust)

	_shield_mat = StandardMaterial3D.new()
	_shield_mat.albedo_color = Color(0.4, 0.8, 1.0, 0.3)
	_shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shield_mat.emission_enabled = true
	_shield_mat.emission = Color(0.3, 0.7, 1.0)
	_shield_mat.emission_energy_multiplier = 1.2
	_shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sphm := SphereMesh.new()
	sphm.radius = 2.4
	sphm.height = 3.6
	sphm.material = _shield_mat
	_shield_mi = MeshInstance3D.new()
	_shield_mi.mesh = sphm
	_shield_mi.position.y = 1.3
	_shield_mi.visible = false
	_shield_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shield_mi)

	if is_human:
		engine = AudioStreamPlayer.new()
		engine.stream = Sfx.engine_stream
		engine.bus = "SFX"
		engine.volume_db = -14.0
		add_child(engine)


func place_at(xf: Transform3D) -> void:
	global_transform = Transform3D(Basis(), xf.origin)
	heading = xf.basis.get_euler().y
	rotation = Vector3(0, heading, 0)
	offset = track.closest_offset(global_position)
	velocity = Vector3.ZERO
	speed = 0.0
	if engine:
		engine.play()


func forward() -> Vector3:
	return Vector3(-sin(heading), 0, -cos(heading))


# ------------------------------------------------------------------ input

func _read_input() -> void:
	if is_human and not finished and not Game.autopilot:
		var p := "p%d_" % slot
		in_throttle = Input.get_action_strength(p + "accel") - Input.get_action_strength(p + "brake")
		if easy_drive:
			# automatic gas: just steer! (brake still reverses)
			var brk := Input.get_action_strength(p + "brake")
			in_throttle = -brk if brk > 0.1 else 1.0
		var raw := Input.get_action_strength(p + "right") - Input.get_action_strength(p + "left")
		# smooth digital (keyboard / d-pad) steering; analog sticks pass through almost directly
		var rate := 7.0 if absf(raw) > absf(in_steer) else 12.0
		in_steer = move_toward(in_steer, raw, rate * get_physics_process_delta_time())
		in_drift = Input.is_action_pressed(p + "drift")
		in_item = Input.is_action_just_pressed(p + "item")
		in_look = Input.is_action_pressed(p + "look")
	else:
		if ai == null:
			ai = KartAI.new(self, 1)
		ai.think(get_physics_process_delta_time())


# ------------------------------------------------------------------ physics

func _physics_process(dt: float) -> void:
	_read_input()
	_timers(dt)
	var on_floor := is_on_floor()
	var can_drive := controls_enabled and spin_timer <= 0.0

	var top := max_speed * ai_mult
	if on_floor and surface == "offroad" and boost_timer <= 0.0:
		top *= offroad_mult
	if boost_timer > 0.0:
		top = max_speed * (1.0 + 0.36 * boost_power)

	var thr := in_throttle if can_drive else 0.0
	if thr > 0.05:
		if speed < 0.0:
			speed += 50.0 * thr * dt
		else:
			speed += accel * (1.0 - 0.6 * clampf(speed / maxf(top, 1.0), 0.0, 1.0)) * thr * dt
	elif thr < -0.05:
		if speed > 0.5:
			speed -= 48.0 * -thr * dt
		else:
			speed = maxf(speed - accel * 0.7 * -thr * dt, -max_speed * 0.35)
	else:
		speed = move_toward(speed, 0.0, (9.0 if on_floor else 1.5) * dt)
	if boost_timer > 0.0:
		speed = move_toward(speed, top, 70.0 * dt)
	if speed > top:
		speed = move_toward(speed, top, (28.0 if on_floor else 4.0) * dt)
	if spin_timer > 0.0:
		speed = move_toward(speed, 0.0, 30.0 * dt)

	# steering
	var st := in_steer if can_drive else 0.0
	_update_drift(st, on_floor, dt)
	var yaw := 0.0
	if drifting:
		var tight := (st * drift_dir + 1.0) * 0.5
		yaw = drift_dir * turn_rate * lerpf(0.5, 1.4, tight)
	else:
		var sf := clampf(absf(speed) / 9.0, 0.0, 1.0)
		var damp := 1.0 - 0.3 * clampf(absf(speed) / max_speed, 0.0, 1.0)
		yaw = st * turn_rate * sf * damp
	if speed < -0.5:
		yaw = -yaw
	if not on_floor:
		yaw *= 0.45
	heading -= yaw * dt
	if easy_drive and on_floor and spin_timer <= 0.0 and speed > 6.0:
		_steer_assist(st, dt)
	rotation = Vector3(0, heading, 0)
	var fwd := forward()

	# velocity
	var planar := Vector3(velocity.x, 0, velocity.z)
	var desired := fwd * speed
	if on_floor:
		var g := grip * (0.42 if drifting else 1.0)
		if surface == "offroad":
			g *= 0.8
		planar = planar.lerp(desired, clampf(g * dt, 0.0, 1.0))
	else:
		planar = planar.lerp(desired, clampf(0.9 * dt, 0.0, 1.0))
	velocity.x = planar.x
	velocity.z = planar.z
	if on_floor:
		var n := get_floor_normal()
		velocity.y = -(n.x * planar.x + n.z * planar.z) / maxf(n.y, 0.3)
		if _ramp_launch:
			_ramp_launch = false
	else:
		velocity.y -= GRAVITY * dt
	var pre_vy := velocity.y
	move_and_slide()
	_after_slide(dt, fwd, pre_vy, on_floor)


func _after_slide(dt: float, fwd: Vector3, pre_vy: float, was_floor: bool) -> void:
	var on_floor := is_on_floor()
	var floor_group := ""
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		var n := c.get_normal()
		if other is Kart:
			_bump_kart(other, n, pre_vy)
		elif n.y > 0.6:
			if other is Node:
				for g in ["offroad", "hazard", "ramp", "road"]:
					if other.is_in_group(g):
						floor_group = g
						break
		elif n.y < 0.4 and other is Node and other.is_in_group("wall"):
			var into := -fwd.dot(Vector3(n.x, 0, n.z).normalized())
			if into > 0.45 and speed > 14.0:
				velocity += Vector3(n.x, 0, n.z).normalized() * speed * 0.25
				speed *= 0.8 if easy_drive else 0.55
				if is_human:
					Sfx.play("bump", randf_range(0.9, 1.1), -4.0)
	if floor_group != "":
		surface = floor_group
	_on_ramp = surface == "ramp" and on_floor

	# walls/obstacles bleed speed
	var actual := Vector3(velocity.x, 0, velocity.z).dot(fwd)
	if is_on_wall() and speed > 0.0 and actual < speed:
		speed = maxf(lerpf(speed, actual, 0.35), 0.0)

	# air / landing / ramp launch
	if _was_on_floor and not on_floor:
		air_time = 0.0
		if surface == "ramp":
			velocity.y += 6.0 if is_monster else 4.0
			_ramp_launch = true
			_trick = false
	if not on_floor:
		air_time += dt
		if _ramp_launch and not _trick and in_drift and air_time < 0.6 and controls_enabled:
			_trick = true
			_trick_spin = TAU
			if is_human:
				Sfx.play("select", 1.4)
	elif not _was_on_floor:
		if air_time > 0.35 and is_human:
			Sfx.play("land", 1.0, -6.0 if air_time < 0.8 else 0.0)
		if _trick:
			boost(0.8, 0.9)
			if is_human:
				Sfx.play("mini", 1.2)
		_trick = false
		_ramp_launch = false
		air_time = 0.0
	_was_on_floor = on_floor

	# easy driving: rescue a stuck kart after 2 seconds
	if easy_drive and controls_enabled and not finished and absf(speed) < 2.5 and spin_timer <= 0.0:
		_stuck += dt
		if _stuck > 2.0:
			_stuck = 0.0
			respawn()
	else:
		_stuck = 0.0

	# hazard / out of bounds
	if surface == "hazard" and on_floor:
		_hazard += dt
		if _hazard > 0.25:
			respawn()
	else:
		_hazard = 0.0
	if global_position.y < track.kill_y:
		respawn()
	var center := track.point_at(offset)
	var lat := Vector2(global_position.x - center.x, global_position.z - center.z).length()
	if lat > track.half_corridor + 4.0 and (on_floor or global_position.y < center.y - 3.0):
		_offtrack += dt
		if _offtrack > 1.0:
			respawn()
	else:
		_offtrack = 0.0


## Easy driving: gently aim at a point further down the road, pulling harder near the edges.
func _steer_assist(st: float, dt: float) -> void:
	var here := track.point_at(offset)
	var lat := (global_position - here).dot(track.right_at(offset))
	var look := 10.0 + absf(speed) * 0.3
	var keep := clampf(lat, -track.half_road * 0.5, track.half_road * 0.5)
	var aim := track.point_at(offset + look) + track.right_at(offset + look) * keep
	var to := aim - global_position
	var diff := wrapf(atan2(-to.x, -to.z) - heading, -PI, PI)
	if absf(diff) > PI * 0.6:
		return  # facing backwards: let the kid turn around themselves
	var edge := absf(lat) / track.half_road
	var strength := 0.8 + (2.2 if edge > 0.8 else 0.0)
	if absf(st) > 0.5 and signf(-st) != signf(diff):
		strength *= 0.3  # the player is steering on purpose, mostly respect it
	heading += clampf(diff, -1.0, 1.0) * strength * dt


func _update_drift(st: float, on_floor: bool, dt: float) -> void:
	if not drifting:
		if in_drift and on_floor and absf(st) > 0.3 and speed > 13.0 and spin_timer <= 0.0 and controls_enabled:
			drifting = true
			drift_dir = signf(st)
			drift_charge = 0.0
			_hop = 0.3
	else:
		if not in_drift or speed < 9.0 or spin_timer > 0.0:
			_end_drift()
		elif on_floor:
			drift_charge += dt * (0.7 + 0.6 * absf(st))


func drift_level() -> int:
	if drift_charge >= 2.4:
		return 3
	if drift_charge >= 1.4:
		return 2
	if drift_charge >= 0.6:
		return 1
	return 0


func _end_drift() -> void:
	var lvl := drift_level()
	if lvl > 0 and spin_timer <= 0.0:
		boost(0.35 + 0.35 * lvl, 0.6 + 0.2 * lvl)
		if is_human:
			Sfx.play("mini", 0.9 + 0.15 * lvl)
	drifting = false
	drift_charge = 0.0


func _timers(dt: float) -> void:
	spin_timer = maxf(spin_timer - dt, 0.0)
	boost_timer = maxf(boost_timer - dt, 0.0)
	invuln_timer = maxf(invuln_timer - dt, 0.0)
	if shield_timer > 0.0:
		shield_timer = maxf(shield_timer - dt, 0.0)
	for k in _bump_cd.keys():
		_bump_cd[k] -= dt
		if _bump_cd[k] <= 0.0:
			_bump_cd.erase(k)
	if item_roll > 0.0:
		item_roll -= dt
		if item_roll <= 0.0:
			_finish_roll()
	if in_item and controls_enabled and item != "" and item_roll <= 0.0 and spin_timer <= 0.0:
		use_item()
	in_item = false


# ------------------------------------------------------------------ interactions

func _bump_kart(other: Kart, n: Vector3, pre_vy: float) -> void:
	var id := other.get_instance_id()
	if _bump_cd.has(id):
		return
	_bump_cd[id] = 0.3
	other._bump_cd[get_instance_id()] = 0.3
	# monster truck lands on someone: crush!
	if is_monster and weight >= other.weight + 2.0 and (pre_vy < -6.0 or global_position.y > other.global_position.y + 1.2):
		other.hit(self)
		velocity.y = 8.0
		return
	var hn := Vector3(n.x, 0, n.z).normalized()
	var total := weight + other.weight
	var strength := 9.0 + absf(speed - other.speed) * 0.3
	velocity += hn * strength * (other.weight / total) * 1.6
	other.velocity -= hn * strength * (weight / total) * 1.6
	if is_human or other.is_human:
		Sfx.play("bump", randf_range(0.8, 1.2), -2.0)


func boost(duration: float, power := 1.0) -> void:
	boost_power = maxf(power, boost_power) if boost_timer > 0.0 else power
	boost_timer = maxf(boost_timer, duration)


## Hit by an item or crushed. Shields absorb one hit.
func hit(_source: Node = null) -> void:
	if invuln_timer > 0.0 or finished:
		return
	if shield_timer > 0.0:
		shield_timer = 0.0
		invuln_timer = 0.6
		if is_human:
			Sfx.play("pop")
		Fx.burst(get_parent(), global_position + Vector3.UP * 1.3, [Color(0.4, 0.8, 1.0), Color.WHITE], 12, 7.0)
		return
	spin_timer = 1.3
	invuln_timer = 2.4
	speed *= 0.3
	drifting = false
	drift_charge = 0.0
	boost_timer = 0.0
	_spin_vis = TAU * 2.0
	Fx.burst(get_parent(), global_position + Vector3.UP * 1.2, [color, Color.WHITE, Color("#1b2a34"), Color("#f2cd37")], 18, 10.0)
	Sfx.play("hit", randf_range(0.9, 1.1), 0.0 if is_human else -8.0)


func respawn() -> void:
	var s := fposmod(offset - 6.0, track.length)
	var f := track.frame_at(s)
	global_position = f.origin + Vector3.UP * 1.2
	heading = track.heading_at(s)
	rotation = Vector3(0, heading, 0)
	velocity = Vector3.ZERO
	speed = 0.0
	drifting = false
	_offtrack = 0.0
	_hazard = 0.0
	surface = "road"
	invuln_timer = 2.0
	spin_timer = 0.0
	Fx.burst(get_parent(), global_position + Vector3.UP, [Color.WHITE, Color("#f2cd37")], 10, 5.0)


# ------------------------------------------------------------------ items

func give_item() -> void:
	if item != "" or item_roll > 0.0 or finished:
		return
	item_roll = 1.0
	if is_human:
		Sfx.play("pickup")


func _finish_roll() -> void:
	var n: int = max(race.karts.size(), 2) if race else 8
	var f := float(place - 1) / float(n - 1)
	var table: Dictionary
	if f < 0.2:
		table = {"oil": 40, "shield": 30, "turbo": 20, "missile": 10}
	elif f < 0.65:
		table = {"missile": 30, "turbo": 25, "oil": 20, "shield": 15, "triple": 10}
	else:
		table = {"triple": 35, "missile": 30, "turbo": 25, "shield": 10}
	var total := 0
	for k in table:
		total += table[k]
	var r := randi() % total
	for k in table:
		r -= table[k]
		if r < 0:
			item = k
			break
	item_uses = 3 if item == "triple" else 1
	if ai:
		ai.on_item()


func use_item() -> void:
	match item:
		"turbo", "triple":
			boost(1.2, 1.1)
			if is_human:
				Sfx.play("boost")
		"missile":
			race.spawn_missile(self)
			Sfx.play("fire", 1.0, 0.0 if is_human else -8.0)
		"oil":
			race.spawn_oil(self)
			Sfx.play("drop", 1.0, 0.0 if is_human else -10.0)
		"shield":
			shield_timer = 9.0
			if is_human:
				Sfx.play("shield")
	item_uses -= 1
	if item_uses <= 0:
		item = ""


# ------------------------------------------------------------------ visuals

func _process(dt: float) -> void:
	if model == null:
		return
	var target_up := get_floor_normal() if is_on_floor() else Vector3.UP
	_up = _up.lerp(target_up, clampf(dt * 10.0, 0.0, 1.0)).normalized()
	var back := Vector3(sin(heading), 0, cos(heading))
	var x := _up.cross(back).normalized()
	var z := x.cross(_up).normalized()
	var b := Basis(x, _up, z)
	_spin_vis = move_toward(_spin_vis, 0.0, dt * TAU * 1.6)
	_trick_spin = move_toward(_trick_spin, 0.0, dt * TAU * 2.2)
	var drift_yaw := -drift_dir * 0.38 if drifting else 0.0
	var lean := -in_steer * 0.06 * clampf(speed / max_speed, 0.0, 1.0)
	b = b * Basis(Vector3.UP, _spin_vis + drift_yaw) * Basis(Vector3.FORWARD, lean) * Basis(Vector3.RIGHT, -_trick_spin)
	model.global_basis = b
	_hop = move_toward(_hop, 0.0, dt * 1.5)
	model.position = Vector3(0, sin(_hop / 0.3 * PI) * 0.35 if _hop > 0.0 else 0.0, 0)
	car.animate(dt, speed, in_steer if spin_timer <= 0.0 else 0.0, boost_timer > 0.0)
	# drift sparks
	var lvl := drift_level() if drifting else 0
	var spark_col: Color = [Color(0.85, 0.85, 0.85), Color(0.3, 0.65, 1.0), Color(1.0, 0.55, 0.1), Color(0.85, 0.3, 1.0)][lvl]
	for p in _sparks:
		p.emitting = drifting and is_on_floor()
		p.color = spark_col
	_dust.emitting = surface == "offroad" and is_on_floor() and absf(speed) > 8.0
	_shield_mi.visible = shield_timer > 0.0
	if _shield_mi.visible:
		_shield_mi.rotation.y += dt * 2.0
	model.visible = invuln_timer <= 0.0 or spin_timer > 0.0 or fmod(invuln_timer, 0.2) < 0.13
	if engine:
		var r := clampf(absf(speed) / max_speed, 0.0, 1.4)
		engine.pitch_scale = 0.55 + r * 1.35 + (0.25 if boost_timer > 0.0 else 0.0)
		engine.volume_db = -16.0 + r * 5.0 - (4.0 if race and race.humans.size() > 1 else 0.0)
