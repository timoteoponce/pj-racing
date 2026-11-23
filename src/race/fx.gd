class_name Fx
extends RefCounted
## One-shot visual effects (lego brick bursts).

static var _brick_mesh: BoxMesh


static func burst(parent: Node, pos: Vector3, colors: Array, amount := 16, speed := 9.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _brick_mesh == null:
		_brick_mesh = BoxMesh.new()
		_brick_mesh.size = Vector3(0.35, 0.22, 0.5)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.3
		_brick_mesh.material = m
	var p := CPUParticles3D.new()
	p.mesh = _brick_mesh
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.1
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -30, 0)
	p.angular_velocity_min = -540
	p.angular_velocity_max = 540
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var cols := colors.duplicate()
	if cols.size() < 2:
		cols.append(cols[0] if cols.size() > 0 else Color.WHITE)
	var offs := PackedFloat32Array()
	var pc := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / (cols.size() - 1))
		pc.append(cols[i])
	var g := Gradient.new()
	g.offsets = offs
	g.colors = pc
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
