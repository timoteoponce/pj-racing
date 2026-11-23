class_name CarShowcase
extends SubViewportContainer
## A 3D turntable that displays a lego car build (used by title, garage, setup and results).

var spin_speed := 0.5
var cam_height := 2.2
var cam_dist := 8.5
var bg_top := Color("#3b8fe8")
var bg_bottom := Color("#0a2a5e")
var transparent := false
var _vp: SubViewport
var _car: LegoCar
var _pivot: Node3D
var _cam: Camera3D
var _angle := 0.6
var _pending := {}
var _pop := 0.0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = transparent
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.audio_listener_enable_3d = false
	add_child(_vp)
	var env := Environment.new()
	if transparent:
		env.background_mode = Environment.BG_CLEAR_COLOR
	else:
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sm := ProceduralSkyMaterial.new()
		sm.sky_top_color = bg_top
		sm.sky_horizon_color = bg_top.lerp(Color.WHITE, 0.35)
		sm.ground_horizon_color = bg_top.lerp(Color.WHITE, 0.35)
		sm.ground_bottom_color = bg_top.darkened(0.35)
		sky.sky_material = sm
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 210, 0)
	fill.light_energy = 0.35
	fill.light_color = Color("#a0c8ff")
	_vp.add_child(fill)
	# turntable: a big round lego plate
	var lm := LegoMesh.new()
	lm.cylinder(LegoMesh.key(Color("#6b7078")), Transform3D(Basis(), Vector3(0, -0.2, 0)), 4.2, 0.4, 40)
	lm.cylinder(LegoMesh.key(UI.YELLOW), Transform3D(Basis(), Vector3(0, -0.42, 0)), 4.5, 0.12, 40)
	for i in 16:
		var a := TAU * i / 16.0
		lm.cylinder(LegoMesh.key(Color("#6b7078")), Transform3D(Basis(), Vector3(cos(a) * 3.7, 0.05, sin(a) * 3.7)), 0.25, 0.14, 10)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_pivot.add_child(lm.to_instance(true))
	_car = LegoCar.new()
	_pivot.add_child(_car)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_vp.add_child(_cam)
	if not _pending.is_empty():
		set_build(_pending)


func set_build(b: Dictionary, pop := false) -> void:
	if _car == null:
		_pending = b
		return
	_car.build(b)
	if pop:
		_pop = 1.0


## Lego bricks fly off the turntable (used when a part snaps on).
func burst(colors: Array) -> void:
	if _pivot:
		Fx.burst(_vp, Vector3(0, 1.5, 0), colors, 26, 9.0)


func _process(dt: float) -> void:
	if _pivot == null:
		return
	_angle += dt * spin_speed
	_pivot.rotation.y = _angle
	_pop = move_toward(_pop, 0.0, dt * 4.0)
	_car.scale = Vector3.ONE * (1.0 + sin(_pop * PI) * 0.12)
	var look_y := _car.top_y * 0.4
	_cam.position = Vector3(0, cam_height + _car.top_y * 0.3, cam_dist + _car.top_y * 0.4)
	_cam.look_at(Vector3(0, look_y, 0), Vector3.UP)
	_car.animate(dt, 4.0, sin(_angle * 1.3) * 0.6, false)
