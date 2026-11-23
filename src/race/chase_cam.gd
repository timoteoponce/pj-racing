class_name ChaseCam
extends Camera3D
## Smooth third-person camera that follows a kart. Widens FOV with speed and boosts.

var target: Kart
var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var _init_done := false
var intro := 0.0  # seconds of orbiting intro before the race


func _ready() -> void:
	near = 0.2
	far = 1400.0
	fov = 70.0
	current = true


func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var k := target
	var fwd := k.forward()
	var back := -fwd
	if k.in_look:
		back = fwd
	var dist := 7.2 + clampf(k.speed / k.max_speed, 0.0, 1.3) * 1.2
	var height := 3.0
	if k.is_monster:
		dist += 1.2
		height += 0.9
	var want := k.global_position + back * dist + Vector3.UP * height
	var look := k.global_position + Vector3.UP * 1.5 - back * 4.0
	if intro > 0.0:
		intro -= dt
		var a := intro * 0.9
		want = k.global_position + Vector3(sin(heading_angle(k) + a), 0, cos(heading_angle(k) + a)) * (8.0 + intro * 3.0) + Vector3.UP * (2.5 + intro)
		look = k.global_position + Vector3.UP * 1.2
	if not _init_done:
		_pos = want
		_look = look
		_init_done = true
	var t := 1.0 - exp(-dt * (9.0 if k.in_look else 6.5))
	_pos = _pos.lerp(want, t)
	_pos.y = maxf(_pos.y, k.global_position.y + 1.0)
	_look = _look.lerp(look, 1.0 - exp(-dt * 12.0))
	global_position = _pos
	if _pos.distance_to(_look) > 0.1:
		look_at(_look, Vector3.UP)
	var fov_target := 70.0 + clampf(k.speed / k.max_speed, 0.0, 1.4) * 12.0 + (8.0 if k.boost_timer > 0.0 else 0.0)
	fov = lerpf(fov, fov_target, 1.0 - exp(-dt * 4.0))


func heading_angle(k: Kart) -> float:
	return k.heading
