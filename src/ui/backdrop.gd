class_name Backdrop
extends Control
## Animated lego-baseplate background: a gradient with slowly scrolling studs.

var colors := [Color("#0f3d8c"), Color("#0a2a5e")]
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true


func _process(dt: float) -> void:
	_t += dt
	queue_redraw()


func _draw() -> void:
	var r := get_rect()
	var c0: Color = colors[0]
	var c1: Color = colors[1]
	var bands := 12
	for i in bands:
		var y0 := r.size.y * i / bands
		draw_rect(Rect2(0, y0, r.size.x, r.size.y / bands + 1), c0.lerp(c1, float(i) / bands))
	var g := 56.0
	var off := Vector2(fmod(_t * 14.0, g), fmod(_t * 8.0, g))
	var y := -g
	while y < r.size.y + g:
		var x := -g
		while x < r.size.x + g:
			var p := Vector2(x, y) + off
			draw_circle(p + Vector2(2, 3), 15, Color(0, 0, 0, 0.12))
			draw_circle(p, 15, Color(1, 1, 1, 0.07))
			draw_circle(p - Vector2(3, 3), 9, Color(1, 1, 1, 0.04))
			x += g
		y += g
