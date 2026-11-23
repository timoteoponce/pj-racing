extends Screen
## Versus Tournament lobby: up to 4 local players join with their own device
## (each PS2 pad, or the keyboard split in two halves), pick a car and ready up.

var _panels: Array[JoinPanel] = []
var _hint: Label
var _ready_t := -1.0


func build() -> void:
	Sfx.music("menu")
	Controls.clear_all()
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28
	v.offset_right = -28
	v.offset_top = 18
	v.offset_bottom = -18
	add_child(v)
	v.add_child(UI.title("VERSUS TOURNAMENT", 50))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for i in Controls.MAX_PLAYERS:
		var p := JoinPanel.new()
		p.slot = i
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(p)
		_panels.append(p)
	_hint = UI.label("", 20, Color.WHITE, 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_hint)
	_update_hint()


func _joined() -> Array[JoinPanel]:
	var out: Array[JoinPanel] = []
	for p in _panels:
		if p.device != "":
			out.append(p)
	return out


func _input(e: InputEvent) -> void:
	if not (e is InputEventKey or e is InputEventJoypadButton) or not e.is_pressed() or e.is_echo():
		return
	# route to joined players first
	for p in _panels:
		if p.device == "":
			continue
		var s := p.slot
		if e.is_action_pressed(Controls.act(s, "left")):
			p.cycle(-1)
		elif e.is_action_pressed(Controls.act(s, "right")):
			p.cycle(1)
		elif e.is_action_pressed(Controls.act(s, "ok")):
			p.set_ready(not p.is_ready)
		elif e.is_action_pressed(Controls.act(s, "back")):
			if p.is_ready:
				p.set_ready(false)
			else:
				p.leave()
		else:
			continue
		get_viewport().set_input_as_handled()
		_update_hint()
		return
	# join with a fresh device
	var dev := _join_device(e)
	if dev != "":
		for p in _panels:
			if p.device == dev:
				return
		for p in _panels:
			if p.device == "":
				p.join(dev)
				Sfx.play("select")
				get_viewport().set_input_as_handled()
				_update_hint()
				return
		return
	# nobody owns this input: escape / circle leaves the lobby
	var back: bool = (e is InputEventKey and e.physical_keycode == KEY_ESCAPE) or (e is InputEventJoypadButton and e.button_index == JOY_BUTTON_B)
	if back and _joined().is_empty():
		get_viewport().set_input_as_handled()
		Sfx.play("back")
		Game.goto("title")


func _unhandled_input(_e: InputEvent) -> void:
	pass  # all input handled in _input


func _join_device(e: InputEvent) -> String:
	if e is InputEventKey:
		match e.physical_keycode:
			KEY_SPACE:
				return "kb1"
			KEY_ENTER, KEY_KP_ENTER:
				return "kb2"
	elif e is InputEventJoypadButton:
		if e.button_index in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_X, JOY_BUTTON_Y]:
			return "pad%d" % e.device
	return ""


func _update_hint() -> void:
	var j := _joined()
	if j.is_empty():
		_hint.text = "Join: press CROSS/START on a pad  •  SPACE (WASD side)  •  ENTER (Arrows side)        ESC: back"
	elif j.all(func(p): return p.is_ready):
		_hint.text = "Everyone is ready!"
		_ready_t = 1.0
	else:
		_hint.text = "Left/Right: choose car  •  Accept: ready  •  Back: leave        Up to 4 players"
		_ready_t = -1.0


func _process(dt: float) -> void:
	if _ready_t > 0.0:
		_ready_t -= dt
		if _ready_t <= 0.0:
			_start()


func _start() -> void:
	var j := _joined()
	if j.is_empty() or not j.all(func(p): return p.is_ready):
		return
	Game.humans.clear()
	Controls.clear_all()
	# compact slots so players are P1..Pn in join order
	for i in j.size():
		var p: JoinPanel = j[i]
		Game.humans.append({"slot": p.slot, "device": p.device, "build_index": p.build, "name": "Player %d" % (p.slot + 1)})
		Controls.assign(p.slot, p.device)
	# menu navigation for the next screen works with any device via ui_* actions
	Game.goto("tracks", {"mode": "tournament"})


class JoinPanel:
	extends PanelContainer
	var slot := 0
	var device := ""
	var build := 0
	var is_ready := false
	var _v: VBoxContainer
	var _show: CarShowcase
	var _name: Label
	var _car: Label
	var _dev: Label
	var _state: Label
	var _join_hint: Label

	func _ready() -> void:
		_v = VBoxContainer.new()
		_v.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(_v)
		_name = UI.label("PLAYER %d" % (slot + 1), 30, Game.PLAYER_COLORS[slot], 8)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_v.add_child(_name)
		_dev = UI.label("", 16, Color(1, 1, 1, 0.7))
		_dev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_v.add_child(_dev)
		_show = CarShowcase.new()
		_show.custom_minimum_size = Vector2(200, 220)
		_show.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_show.cam_dist = 10.0
		_show.bg_top = Game.PLAYER_COLORS[slot].darkened(0.2)
		_v.add_child(_show)
		_car = UI.label("", 20, Color.WHITE, 6)
		_car.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_v.add_child(_car)
		_state = UI.label("", 26, UI.YELLOW, 7)
		_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_v.add_child(_state)
		_join_hint = UI.label("PRESS\nTO JOIN", 34, Color(1, 1, 1, 0.5), 6)
		_join_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_join_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_join_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_v.add_child(_join_hint)
		build = slot
		_refresh()

	func join(dev: String) -> void:
		device = dev
		Controls.assign(slot, dev)
		is_ready = false
		_show.set_build(Save.get_build(build), true)
		_refresh()

	func leave() -> void:
		Controls.clear(slot)
		device = ""
		is_ready = false
		Sfx.play("back")
		_refresh()

	func cycle(d: int) -> void:
		if is_ready:
			return
		build = posmod(build + d, Save.BUILD_SLOTS)
		_show.set_build(Save.get_build(build), true)
		Sfx.play("click", 1.2)
		_refresh()

	func set_ready(r: bool) -> void:
		is_ready = r
		Sfx.play("select" if r else "back")
		_refresh()

	func _refresh() -> void:
		var joined := device != ""
		_show.visible = joined
		_car.visible = joined
		_state.visible = joined
		_dev.visible = joined
		_join_hint.visible = not joined
		if joined:
			var b := Save.get_build(build)
			_car.text = "<  %s  >\n%s" % [b["name"], Parts.get_part(b["chassis"])["name"]]
			_dev.text = Controls.device_label(device)
			_state.text = "READY!" if is_ready else "choose your car"
			_state.add_theme_color_override("font_color", Color("#47d65a") if is_ready else UI.YELLOW)
		var sb := UI.box(Color(0.08, 0.11, 0.16, 0.88), 20, 4, Game.PLAYER_COLORS[slot] if joined else Color(1, 1, 1, 0.15))
		if is_ready:
			sb.bg_color = Game.PLAYER_COLORS[slot].darkened(0.6)
		add_theme_stylebox_override("panel", sb)
