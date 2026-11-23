class_name ItemBox
extends Area3D
## Floating "?" lego brick. Gives the kart a random item, respawns after a few seconds.

var _mesh: MeshInstance3D
var _label: Label3D
var _mat: StandardMaterial3D
var _t := randf() * 10.0
var _respawn := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.7
	cs.shape = sh
	cs.position.y = 1.2
	add_child(cs)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1, 1, 1, 0.75)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 0.8
	_mat.roughness = 0.2
	var lm := LegoMesh.new()
	LegoMesh.register("itembox", _mat)
	lm.box("itembox", Transform3D(), Vector3(1.5, 1.5, 1.5), true, 0.75)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = lm.commit()
	_mesh.position.y = 1.4
	_mesh.material_override = _mat
	add_child(_mesh)
	_label = Label3D.new()
	_label.text = "?"
	_label.font_size = 120
	_label.outline_size = 24
	_label.modulate = Color.WHITE
	_label.outline_modulate = Color("#1b2a34")
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = false
	_label.position.y = 1.4
	add_child(_label)
	body_entered.connect(_on_body)


func _process(dt: float) -> void:
	_t += dt
	_mesh.rotation = Vector3(0.4, _t * 1.6, 0.2)
	_mesh.position.y = 1.4 + sin(_t * 2.5) * 0.15
	var hue := fposmod(_t * 0.15, 1.0)
	_mat.albedo_color = Color.from_hsv(hue, 0.65, 1.0, 0.8)
	_mat.emission = Color.from_hsv(hue, 0.7, 0.6)
	if _respawn > 0.0:
		_respawn -= dt
		var s := clampf(1.0 - _respawn / 0.4, 0.0, 1.0) if _respawn < 0.4 else 0.0
		_mesh.scale = Vector3.ONE * maxf(s, 0.01)
		_label.visible = _respawn <= 0.0
		if _respawn <= 0.0:
			_mesh.scale = Vector3.ONE


func _on_body(b: Node3D) -> void:
	if _respawn > 0.0 or not (b is Kart):
		return
	var k: Kart = b
	k.give_item()
	_respawn = 1.6
	_label.visible = false
	_mesh.scale = Vector3.ONE * 0.01
	Fx.burst(get_parent(), global_position + Vector3.UP * 1.4, [Color.from_hsv(randf(), 0.7, 1.0), Color.WHITE], 10, 6.0)
