class_name StudCounter
extends Control
## Shows the player's stud balance with a stud icon.


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var sb := UI.box(Color(0.05, 0.08, 0.12, 0.8), 25, 3, Color(1, 1, 1, 0.2))
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var c := Vector2(size.y * 0.5 + 4, size.y * 0.5)
	draw_circle(c, size.y * 0.34, Color("#c9a21c"))
	draw_circle(c - Vector2(2, 2), size.y * 0.28, UI.YELLOW)
	var txt := "%d studs" % Save.studs()
	draw_string(UI.font(), Vector2(size.y + 6, size.y * 0.68), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
