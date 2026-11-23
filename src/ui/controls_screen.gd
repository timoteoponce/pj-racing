extends Screen
## Shows keyboard layouts, lists connected pads, live button tester and gamepad remapping.

const BTN_NAMES := {
	0: "Cross (A)", 1: "Circle (B)", 2: "Square (X)", 3: "Triangle (Y)", 4: "Select", 5: "Guide",
	6: "Start", 7: "L3", 8: "R3", 9: "L1", 10: "R1", 11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right",
}

var _pads: Label
var _tester: Label
var _rows := {}
var _waiting := ""
var _first: Button


func build() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_right = -30
	root.offset_top = 20
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	left.add_child(UI.title("CONTROLS", 48))
	var kb := PanelContainer.new()
	left.add_child(kb)
	var kv := VBoxContainer.new()
	kb.add_child(kv)
	kv.add_child(UI.label("KEYBOARD", 22, UI.YELLOW, 5))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	kv.add_child(grid)
	var lines := [
		["", "Left side (P-WASD)", "Right side (P-Arrows)"],
		["Steer", "A / D", "Left / Right"],
		["Accelerate", "W", "Up"],
		["Brake / Reverse", "S", "Down"],
		["Drift / Hop", "Space", ". (period)"],
		["Use item", "E or F", "Enter"],
		["Look behind", "Q", ", (comma)"],
		["Pause", "Esc", "Backspace"],
	]
	for l in lines:
		for i in 3:
			grid.add_child(UI.label(l[i], 18, UI.YELLOW if l[0] == "" or i == 0 else Color.WHITE))
	kv.add_child(UI.label("Solo / Arcade: both sides + any pad work at once.", 16, Color(1, 1, 1, 0.7)))
	var tips := PanelContainer.new()
	tips.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(tips)
	var tl := UI.label("TIPS\n• Hold Drift while turning: sparks go blue > orange > purple. Release for a mini-turbo!\n• Hold accelerate during the countdown for a rocket start.\n• Press Drift in the air after a ramp to do a trick: boost on landing.\n• Monster trucks crush karts when they land on them, and barely slow down off-road.", 17, Color.WHITE)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.add_child(tl)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 520
	root.add_child(right)
	var pp := PanelContainer.new()
	right.add_child(pp)
	var pv := VBoxContainer.new()
	pp.add_child(pv)
	pv.add_child(UI.label("GAMEPADS (PS2 USB)", 22, UI.YELLOW, 5))
	_pads = UI.label("", 17)
	pv.add_child(_pads)
	_tester = UI.label("Press any pad button to test it...", 17, Color("#7fd16b"))
	pv.add_child(_tester)
	right.add_child(UI.label("Gamepad layout (applies to all pads) - select an action, then press the pad button:", 16, Color(1, 1, 1, 0.8)))
	for a in Controls.REMAPPABLE:
		var b := UI.button("", func(): _start_remap(a), 520)
		b.custom_minimum_size.y = 46
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		right.add_child(b)
		_rows[a] = b
		if _first == null:
			_first = b
	right.add_child(UI.label("Steering: left stick or D-pad  •  Triggers also accelerate/brake", 15, Color(1, 1, 1, 0.65)))
	var hb := HBoxContainer.new()
	right.add_child(hb)
	hb.add_child(UI.button("Reset Layout", func():
		Controls.reset_pad_map()
		_refresh(), 250))
	hb.add_child(UI.button("Back", on_back, 250))
	Controls.pads_changed.connect(_refresh_pads)
	_refresh()
	_refresh_pads()
	focus_first(_first)


func _refresh() -> void:
	var m := Controls.pad_map()
	for a in _rows:
		var names: Array = m[a].map(func(b): return BTN_NAMES.get(b, "Button %d" % b))
		var b: Button = _rows[a]
		b.text = "%s:   %s" % [Controls.ACTION_NAMES[a], " / ".join(names)]
		if _waiting == a:
			b.text = "%s:   ...press a pad button (Esc cancels)" % Controls.ACTION_NAMES[a]


func _refresh_pads() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_pads.text = "No pads detected. Plug in your USB controllers."
		return
	var t := []
	for id in pads:
		t.append("Pad %d: %s%s" % [id + 1, Input.get_joy_name(id), "" if Input.is_joy_known(id) else "  (unmapped - remap below)"])
	_pads.text = "\n".join(t)


func _start_remap(a: String) -> void:
	_waiting = a
	_refresh()


func _input(e: InputEvent) -> void:
	if e is InputEventJoypadButton and e.pressed:
		_tester.text = "Pad %d pressed: %s (button %d)" % [e.device + 1, BTN_NAMES.get(e.button_index, "?"), e.button_index]
		if _waiting != "":
			Controls.set_pad_button(_waiting, e.button_index)
			Sfx.play("buy")
			var a := _waiting
			_waiting = ""
			_refresh()
			get_viewport().set_input_as_handled()
			_rows[a].call_deferred("grab_focus")
	elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.6:
		_tester.text = "Pad %d axis %d: %.2f" % [e.device + 1, e.axis, e.axis_value]
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE and _waiting != "":
		_waiting = ""
		_refresh()
		get_viewport().set_input_as_handled()


func on_back() -> void:
	if _waiting != "":
		return
	Game.goto("title")
