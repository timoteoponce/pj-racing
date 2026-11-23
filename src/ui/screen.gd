class_name Screen
extends Control
## Base class for menu screens: full-rect, themed, animated backdrop, back on ui_cancel.

var backdrop := true
var backdrop_colors := [Color("#0f3d8c"), Color("#0a2a5e")]


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()


func _ready() -> void:
	if backdrop:
		var b := Backdrop.new()
		b.colors = backdrop_colors
		add_child(b)
	build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func build() -> void:
	pass


func on_back() -> void:
	pass


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("back")
		on_back()


func focus_first(c: Control) -> void:
	c.call_deferred("grab_focus")
