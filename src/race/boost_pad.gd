class_name BoostPad
extends Area3D
## Glowing arrow pad on the road. Drive over it for a speed boost.

var _mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.5, 2.5, 6.0)
	cs.shape = bs
	cs.position.y = 1.0
	add_child(cs)
	_mat = Tex.mat(Tex.arrows(), false, Vector3(1, 2, 1), 1.6)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.5, 6.0)
	pm.material = _mat
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position.y = 0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	body_entered.connect(_on_body)


func _process(dt: float) -> void:
	_t += dt
	_mat.uv1_offset = Vector3(0, _t * 1.5, 0)


func _on_body(b: Node3D) -> void:
	if b is Kart:
		var k: Kart = b
		k.boost(1.1, 1.0)
		if k.is_human:
			Sfx.play("boost", 1.1)
