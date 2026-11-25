extends Node
## Per-player input actions ("p0_accel", "p1_left", ...) bound to one device each.
## Devices: "any" (all keyboards keys + every pad), "kb1" (WASD side), "kb2" (arrows side), "padN".

signal pads_changed

const ACTIONS := ["accel", "brake", "left", "right", "drift", "item", "look", "pause", "ok", "back"]
const REMAPPABLE := ["accel", "brake", "drift", "item", "look", "pause"]
const ACTION_NAMES := {
	"accel": "Accelerate", "brake": "Brake / Reverse", "drift": "Drift / Hop",
	"item": "Use Item", "look": "Look Behind", "pause": "Pause",
}
const MAX_PLAYERS := 4

# Keyboard layouts. Shift keys use physical location so both halves can share a keyboard.
const KB1 := {
	"accel": [KEY_W], "brake": [KEY_S], "left": [KEY_A], "right": [KEY_D],
	"drift": [KEY_SPACE], "item": [KEY_E, KEY_F], "look": [KEY_Q], "pause": [KEY_ESCAPE],
	"ok": [KEY_SPACE, KEY_E], "back": [KEY_Q, KEY_ESCAPE],
}
const KB2 := {
	"accel": [KEY_UP], "brake": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
	"drift": [KEY_PERIOD, KEY_KP_1], "item": [KEY_ENTER, KEY_KP_0, KEY_SLASH], "look": [KEY_COMMA],
	"pause": [KEY_BACKSPACE, KEY_ESCAPE], "ok": [KEY_ENTER, KEY_KP_ENTER], "back": [KEY_BACKSPACE],
}

# Default PS-style mapping (SDL standard layout): Cross=A(0) Circle=B(1) Square=X(2) Triangle=Y(3)
# L1=9 R1=10 Select=4 Start=6.
const PAD_DEFAULT := {
	"accel": [JOY_BUTTON_A], "brake": [JOY_BUTTON_X], "drift": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B],
	"item": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_Y], "look": [JOY_BUTTON_BACK], "pause": [JOY_BUTTON_START],
}

var slot_device := ["", "", "", ""]


func _ready() -> void:
	for slot in MAX_PLAYERS:
		for a in ACTIONS:
			var name := act(slot, a)
			if not InputMap.has_action(name):
				InputMap.add_action(name, 0.3)
	# Godot's built-in ui_accept/ui_cancel are keyboard-only: let every pad press and go back
	# in menus (Cross/Square/Triangle/Start = accept, Circle = back). D-pad/stick navigation is built in.
	for b in [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START]:
		_add_ui_pad("ui_accept", b)
	_add_ui_pad("ui_cancel", JOY_BUTTON_B)
	# solo player defaults to "any device" so menus/races work out of the box
	assign(0, "any")
	Input.joy_connection_changed.connect(func(_d, _c): pads_changed.emit())


func _add_ui_pad(action: String, button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.device = -1  # all pads
	e.button_index = button
	InputMap.action_add_event(action, e)


func act(slot: int, a: String) -> String:
	return "p%d_%s" % [slot, a]


func pad_map() -> Dictionary:
	var m: Dictionary = PAD_DEFAULT.duplicate(true)
	var saved: Dictionary = Save.data.get("pad_map", {})
	for k in saved:
		if m.has(k) and saved[k] is Array and not saved[k].is_empty():
			m[k] = saved[k].map(func(v): return int(v))
	return m


func set_pad_button(action: String, button: int) -> void:
	var saved: Dictionary = Save.data["pad_map"]
	saved[action] = [button]
	Save.save_game()
	refresh()


func reset_pad_map() -> void:
	Save.data["pad_map"] = {}
	Save.save_game()
	refresh()


func refresh() -> void:
	for slot in MAX_PLAYERS:
		if slot_device[slot] != "":
			assign(slot, slot_device[slot])


func clear(slot: int) -> void:
	slot_device[slot] = ""
	for a in ACTIONS:
		InputMap.action_erase_events(act(slot, a))


func clear_all() -> void:
	for slot in MAX_PLAYERS:
		clear(slot)


func assign(slot: int, device: String) -> void:
	clear(slot)
	slot_device[slot] = device
	match device:
		"any":
			_bind_keys(slot, KB1)
			_bind_keys(slot, KB2)
			_bind_pad(slot, -1)
		"kb1":
			_bind_keys(slot, KB1)
		"kb2":
			_bind_keys(slot, KB2)
		_:
			if device.begins_with("pad"):
				_bind_pad(slot, int(device.substr(3)))


func _bind_keys(slot: int, layout: Dictionary) -> void:
	for a in layout:
		for key in layout[a]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(act(slot, a), e)


func _bind_pad(slot: int, dev: int) -> void:
	var m := pad_map()
	for a in m:
		for b in m[a]:
			_add_button(slot, a, dev, b)
	_add_button(slot, "left", dev, JOY_BUTTON_DPAD_LEFT)
	_add_button(slot, "right", dev, JOY_BUTTON_DPAD_RIGHT)
	_add_axis(slot, "left", dev, JOY_AXIS_LEFT_X, -1.0)
	_add_axis(slot, "right", dev, JOY_AXIS_LEFT_X, 1.0)
	_add_axis(slot, "accel", dev, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis(slot, "brake", dev, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_button(slot, "ok", dev, JOY_BUTTON_A)
	_add_button(slot, "ok", dev, JOY_BUTTON_START)
	_add_button(slot, "back", dev, JOY_BUTTON_B)


func _add_button(slot: int, a: String, dev: int, b: int) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = b
	InputMap.action_add_event(act(slot, a), e)


func _add_axis(slot: int, a: String, dev: int, axis: int, val: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = dev
	e.axis = axis
	e.axis_value = val
	InputMap.action_add_event(act(slot, a), e)


func device_label(device: String) -> String:
	match device:
		"any":
			return "Keyboard / Any Pad"
		"kb1":
			return "Keyboard (WASD)"
		"kb2":
			return "Keyboard (Arrows)"
	if device.begins_with("pad"):
		var id := int(device.substr(3))
		var n := Input.get_joy_name(id)
		return "Pad %d%s" % [id + 1, (" - " + n.left(18)) if n != "" else ""]
	return "-"


## Detects which device produced an event (for "press to join").
func device_of(e: InputEvent) -> String:
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.physical_keycode
		if k in [KEY_SPACE, KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_F]:
			return "kb1"
		if k in [KEY_ENTER, KEY_KP_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			return "kb2"
	elif e is InputEventJoypadButton and e.pressed:
		return "pad%d" % e.device
	return ""


const PAD_SHORT := {
	JOY_BUTTON_A: "Cross ✕", JOY_BUTTON_B: "Circle ○", JOY_BUTTON_X: "Square ▢", JOY_BUTTON_Y: "Triangle △",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
}


## Friendly name of the button(s) for an action on this player's device, e.g. "E or L1".
func button_hint(slot: int, action: String) -> String:
	var dev: String = slot_device[slot] if slot >= 0 and slot < MAX_PLAYERS else "any"
	var keys := []
	if dev == "any" or dev == "kb1":
		keys.append(OS.get_keycode_string(KB1[action][0]))
	if dev == "kb2":
		keys.append(OS.get_keycode_string(KB2[action][0]))
	if dev == "any" or dev.begins_with("pad"):
		var m := pad_map()
		if m.has(action) and not m[action].is_empty():
			keys.append(PAD_SHORT.get(int(m[action][0]), "button %d" % int(m[action][0])))
	return " or ".join(keys)
