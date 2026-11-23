class_name StatStuds
extends Control
## Car stats shown as rows of lego studs (easy to read for kids).
## When a compare build is set, studs gained show green and studs lost show red.

const STUDS := 6
const COLORS := {"spd": Color("#ff5a3d"), "acc": Color("#ffb020"), "hnd": Color("#3dc8ff"), "wgt": Color("#b07cff"), "off": Color("#6bd16b")}

var stats := {}
var compare := {}
var row_h := 34.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(380, row_h * Parts.STAT_KEYS.size())


func show_build(b: Dictionary, base: Dictionary = {}) -> void:
	stats = Parts.compute_stats(b, Save.upgrades())
	compare = Parts.compute_stats(base, Save.upgrades()) if not base.is_empty() else {}
	queue_redraw()


static func studs_for(v: float) -> int:
	return clampi(roundi(v / 12.0 * STUDS + 0.25), 1, STUDS)


func _draw() -> void:
	var f := UI.font()
	var y := 0.0
	for k in Parts.STAT_KEYS:
		if not stats.has(k):
			continue
		draw_string_outline(f, Vector2(0, y + row_h * 0.7), Parts.STAT_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, UI.DARK)
		draw_string(f, Vector2(0, y + row_h * 0.7), Parts.STAT_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		var n := studs_for(stats[k])
		var old := studs_for(compare[k]) if compare.has(k) else n
		var col: Color = COLORS[k]
		var r := row_h * 0.36
		for i in STUDS:
			var c := Vector2(150 + i * (r * 2 + 8) + r, y + row_h * 0.5)
			draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
			var fill := Color(1, 1, 1, 0.12)
			if i < n:
				fill = col
				if i >= old:
					fill = Color("#47e05a")
			elif i < old:
				fill = Color("#ff3030").darkened(0.2)
			draw_circle(c, r, fill)
			if i < n or i < old:
				draw_circle(c - Vector2(r * 0.25, r * 0.25), r * 0.45, Color(1, 1, 1, 0.3))
		y += row_h
