class_name KartAI
extends RefCounted
## CPU driver: follows the track spline with a wandering racing line, slows for bends,
## avoids karts ahead, drifts on long corners (hard), uses items and un-sticks itself.

var kart: Kart
var difficulty := 1
var lane := 0.0
var lane_target := 0.0
var lane_timer := 0.0
var item_timer := 0.0
var stuck := 0.0
var reverse := 0.0
var _rng := RandomNumberGenerator.new()


func _init(k: Kart, diff: int) -> void:
	kart = k
	difficulty = diff
	_rng.randomize()
	lane = _rng.randf_range(-0.5, 0.5)
	lane_target = lane


func on_item() -> void:
	item_timer = _rng.randf_range(0.8, 4.0)


func think(dt: float) -> void:
	var tr := kart.track
	var s := kart.offset
	var spd := absf(kart.speed)
	lane_timer -= dt
	if lane_timer <= 0.0:
		lane_target = _rng.randf_range(-0.55, 0.55)
		lane_timer = _rng.randf_range(2.0, 5.0)

	var look := 9.0 + spd * 0.45
	# avoid karts directly ahead
	if kart.race:
		for o in kart.race.karts:
			if o == kart:
				continue
			var rel: Vector3 = kart.to_local(o.global_position)
			if rel.z < -1.0 and rel.z > -14.0 and absf(rel.x) < 2.6 and o.speed < kart.speed + 2.0:
				lane_target = clampf(lane + (0.5 if rel.x < 0.0 else -0.5), -0.7, 0.7)
				break
	lane = move_toward(lane, lane_target, dt * 0.6)

	var target := tr.point_at(s + look) + tr.right_at(s + look) * lane * tr.half_road
	var local := kart.to_local(target)
	var ang := atan2(local.x, -local.z)
	var steer := clampf(ang * 2.4, -1.0, 1.0)

	var t1 := tr.tangent_at(s + 6.0)
	var t2 := tr.tangent_at(s + 6.0 + 20.0 + spd * 0.6)
	t1.y = 0
	t2.y = 0
	var bend := t1.normalized().angle_to(t2.normalized())
	var throttle := 1.0
	var limit := kart.max_speed * (1.0 - clampf((bend - 0.5) * 0.45, 0.0, 0.45))
	if spd > limit:
		throttle = -0.3 if spd > limit + 6.0 else 0.25

	# hard CPUs drift through long bends for mini-turbos
	var drift := false
	if difficulty >= 2 and bend > 0.55 and spd > 18.0:
		drift = true
	if kart.drifting and bend < 0.25:
		drift = false

	# un-stick
	if kart.controls_enabled and spd < 2.5 and kart.spin_timer <= 0.0:
		stuck += dt
	else:
		stuck = 0.0
	if stuck > 1.2:
		reverse = 1.0
		stuck = 0.0
	if reverse > 0.0:
		reverse -= dt
		throttle = -1.0
		steer = -steer

	kart.in_throttle = throttle
	kart.in_steer = steer
	kart.in_drift = drift
	kart.in_look = false
	kart.in_item = _decide_item(dt, bend)


func _decide_item(dt: float, bend: float) -> bool:
	if kart.item == "" or kart.item_roll > 0.0:
		return false
	item_timer -= dt
	if item_timer > 0.0:
		return false
	match kart.item:
		"turbo", "triple":
			if bend < 0.2:
				item_timer = 0.6
				return true
		"missile":
			if kart.place > 1:
				return true
			item_timer = 1.0
		"oil", "shield":
			return true
	return false
