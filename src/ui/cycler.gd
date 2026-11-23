class_name Cycler
extends Button
## A "< value >" selector: left/right (keyboard, d-pad, stick) or click to cycle options.

signal changed(index: int)

var prefix := ""
var options: Array = []
var index := 0
var accept_cycles := true


func _init(pfx := "", opts: Array = [], idx := 0) -> void:
	prefix = pfx
	options = opts
	index = idx
	custom_minimum_size = Vector2(420, 54)
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_CENTER


func _ready() -> void:
	UI.wire_focus(self)
	pressed.connect(func():
		if accept_cycles:
			step(1))
	refresh()


func set_options(opts: Array, idx: int) -> void:
	options = opts
	index = clampi(idx, 0, maxi(opts.size() - 1, 0))
	refresh()


func _gui_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_left"):
		step(-1)
		accept_event()
	elif e.is_action_pressed("ui_right"):
		step(1)
		accept_event()


func step(d: int) -> void:
	if options.is_empty():
		return
	index = posmod(index + d, options.size())
	Sfx.play("click", 1.2)
	refresh()
	changed.emit(index)


func refresh() -> void:
	if options.is_empty():
		text = prefix
		return
	var v := str(options[index])
	text = ("%s:  <  %s  >" % [prefix, v]) if prefix != "" else ("<  %s  >" % v)
