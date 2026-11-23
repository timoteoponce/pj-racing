class_name Hud
extends Control
## Per-player heads-up display: position, lap, time, item slot, speed, drift charge, minimap, messages.

var race: Node
var kart: Kart
var compact := false
var _pos: Label
var _pos_of: Label
var _lap: Label
var _time: Label
var _speed: Label
var _msg: Label
var _msg_t := 0.0
var _item: ItemIcon
var _map: Minimap
var _tag: Label
var _last_place := 0


func setup(r: Node, k: Kart, is_compact: bool) -> void:
	race = r
	kart = k
	compact = is_compact


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()
	var sc := 0.72 if compact else 1.0
	_pos = UI.label("1st", int(78 * sc), Color.WHITE, int(14 * sc))
	UI.pin(_pos, 0, 0, 22, 6, 200 * sc, 100 * sc)
	add_child(_pos)
	_pos_of = UI.label("/8", int(28 * sc), Color.WHITE, int(8 * sc))
	add_child(_pos_of)
	_lap = UI.label("LAP 1/3", int(30 * sc), UI.YELLOW, int(8 * sc))
	UI.pin(_lap, 0, 0, 26, 6 + 92 * sc, 260, 44 * sc)
	add_child(_lap)
	_time = UI.label("0:00.00", int(26 * sc), Color.WHITE, int(7 * sc))
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.pin(_time, 1, 0, -240, 14, 220, 40)
	add_child(_time)
	_item = ItemIcon.new()
	_item.kart = kart
	_item.custom_minimum_size = Vector2(96, 96) * sc
	_item.size = Vector2(96, 96) * sc
	UI.pin(_item, 0.5, 0, -48 * sc, 12, 96 * sc, 96 * sc)
	add_child(_item)
	_speed = UI.label("0", int(40 * sc), Color.WHITE, int(10 * sc))
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.pin(_speed, 1, 1, -260, -70 * sc, 240, 60 * sc)
	add_child(_speed)
	_msg = UI.label("", int(56 * sc), UI.YELLOW, int(14 * sc))
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.pin(_msg, 0.5, 0.5, -450, -150 * sc, 900, 100 * sc)
	add_child(_msg)
	_map = Minimap.new()
	_map.race = race
	_map.focus = kart
	var ms := 210.0 * sc
	UI.pin(_map, 0, 1, 14, -ms - 14, ms, ms)
	add_child(_map)
	if kart.is_human and race.humans.size() > 1:
		_tag = UI.label("P%d" % (kart.slot + 1), int(26 * sc), kart.color, int(8 * sc))
		_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UI.pin(_tag, 1, 0, -120, 50 * sc + 12, 100, 40)
		add_child(_tag)


func message(text: String, col := UI.YELLOW, dur := 2.0) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", col)
	_msg_t = dur
	_msg.pivot_offset = _msg.size * 0.5
	_msg.scale = Vector2.ONE * 1.4
	create_tween().tween_property(_msg, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _process(dt: float) -> void:
	if kart == null:
		return
	var sc := 0.72 if compact else 1.0
	var n: int = race.karts.size()
	_pos.text = UI.ordinal(kart.place)
	_pos.add_theme_color_override("font_color", UI.place_color(kart.place))
	_pos_of.text = "/%d" % n
	var fw := _pos.get_theme_font("font").get_string_size(_pos.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _pos.get_theme_font_size("font_size")).x
	_pos_of.position = Vector2(_pos.position.x + fw + 6, _pos.position.y + 46 * sc)
	if kart.place != _last_place:
		_pos.pivot_offset = _pos.size * 0.5
		_pos.scale = Vector2.ONE * 1.25
		create_tween().tween_property(_pos, "scale", Vector2.ONE, 0.2)
		_last_place = kart.place
	var laps: int = race.laps
	_lap.text = "LAP %d/%d" % [clampi(kart.max_lap, 1, laps), laps] if not kart.finished else "FINISHED"
	_time.text = UI.time_str(kart.finish_time if kart.finished else race.race_time)
	_speed.text = "%d km/h" % int(absf(kart.speed) * 3.6)
	var dl := kart.drift_level() if kart.drifting else 0
	var dc: Color = [Color.WHITE, Color(0.4, 0.7, 1.0), Color(1.0, 0.6, 0.2), Color(0.9, 0.4, 1.0)][dl]
	_speed.add_theme_color_override("font_color", dc if kart.drifting else (UI.ORANGE if kart.boost_timer > 0.0 else Color.WHITE))
	if _msg_t > 0.0:
		_msg_t -= dt
		_msg.modulate.a = clampf(_msg_t * 3.0, 0.0, 1.0)
	elif kart.wrong_way > 1.0 and not kart.finished:
		_msg.text = "WRONG WAY!"
		_msg.add_theme_color_override("font_color", UI.RED)
		_msg.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
	else:
		_msg.modulate.a = 0.0


# ------------------------------------------------------------------ helpers

class ItemIcon:
	extends Control
	var kart: Kart
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var sb := UI.box(Color(0.05, 0.08, 0.12, 0.75), int(size.x * 0.18), 4, Color(1, 1, 1, 0.85))
		draw_style_box(sb, r)
		if kart == null:
			return
		var it := kart.item
		if kart.item_roll > 0.0:
			it = Kart.ITEMS[int(_t * 14.0) % Kart.ITEMS.size()]
		if it == "":
			return
		var c := size * 0.5
		var s := size.x * 0.32
		Hud.draw_item(self, it, c, s)
		if it == "triple" and kart.item_roll <= 0.0:
			draw_string(UI.font(), Vector2(size.x * 0.62, size.y * 0.92), "x%d" % kart.item_uses, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size.x * 0.22), Color.WHITE)


static func draw_item(ci: CanvasItem, it: String, c: Vector2, s: float) -> void:
	match it:
		"turbo":
			_flame(ci, c, s)
		"triple":
			_flame(ci, c + Vector2(-s * 0.55, s * 0.15), s * 0.6)
			_flame(ci, c + Vector2(s * 0.55, s * 0.15), s * 0.6)
			_flame(ci, c + Vector2(0, -s * 0.25), s * 0.7)
		"missile":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.9, -s * 0.45), Vector2(s * 1.4, s * 0.9)), Color("#c91a09"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.65), Vector2(s * 0.35, s * 0.22)), Color("#e33b2a"))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.65), Vector2(s * 0.35, s * 0.22)), Color("#e33b2a"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.5, -s * 0.45), c + Vector2(s * 1.05, 0), c + Vector2(s * 0.5, s * 0.45)]), Color.WHITE)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.9, -s * 0.3), c + Vector2(-s * 1.3, 0), c + Vector2(-s * 0.9, s * 0.3)]), UI.ORANGE)
		"oil":
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.9, Color("#141414"))
			ci.draw_circle(c + Vector2(-s * 0.3, -s * 0.1), s * 0.25, Color(1, 1, 1, 0.25))
			ci.draw_rect(Rect2(c + Vector2(s * 0.2, -s * 0.2), Vector2(s * 0.35, s * 0.25)), UI.YELLOW)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.5, s * 0.3), Vector2(s * 0.35, s * 0.25)), UI.RED)
		"shield":
			ci.draw_circle(c, s * 0.95, Color(0.3, 0.7, 1.0, 0.45))
			ci.draw_arc(c, s * 0.95, 0, TAU, 32, Color(0.6, 0.9, 1.0), s * 0.14, true)
			ci.draw_arc(c + Vector2(-s * 0.2, -s * 0.2), s * 0.45, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.8), s * 0.1, true)


static func _flame(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 1.1), c + Vector2(s * 0.6, s * 0.2), c + Vector2(s * 0.35, s * 0.8), c + Vector2(-s * 0.35, s * 0.8), c + Vector2(-s * 0.6, s * 0.2)]), UI.ORANGE)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.3, s * 0.35), c + Vector2(0, s * 0.75), c + Vector2(-s * 0.3, s * 0.35)]), UI.YELLOW)


class Minimap:
	extends Control
	var race: Node
	var focus: Kart

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if race == null or race.track == null:
			return
		var tr: Track = race.track
		var b := tr.bounds
		var pad := 10.0
		var scale_f := minf((size.x - pad * 2) / maxf(b.size.x, 1.0), (size.y - pad * 2) / maxf(b.size.y, 1.0))
		var off := (size - b.size * scale_f) * 0.5
		var to_map := func(v: Vector2) -> Vector2:
			return off + (v - b.position) * scale_f
		draw_circle(size * 0.5, size.x * 0.52, Color(0, 0, 0, 0.3))
		var pts := PackedVector2Array()
		for p in tr.minimap_pts:
			pts.append(to_map.call(p))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.1, 0.1, 0.12, 0.9), 9.0, true)
		draw_polyline(pts, Color(0.92, 0.92, 0.95), 4.0, true)
		var sp: Vector2 = to_map.call(tr.minimap_pts[0])
		draw_circle(sp, 5.0, Color.WHITE)
		draw_circle(sp, 3.0, Color.BLACK)
		for k in race.karts:
			if k == focus:
				continue
			var mp: Vector2 = to_map.call(Vector2(k.global_position.x, k.global_position.z))
			if k.is_human:
				draw_circle(mp, 7.0, Color.WHITE)
				draw_circle(mp, 5.5, k.color)
			else:
				draw_circle(mp, 4.5, Color(0, 0, 0, 0.6))
				draw_circle(mp, 3.5, k.color)
		if focus:
			var mp: Vector2 = to_map.call(Vector2(focus.global_position.x, focus.global_position.z))
			var f := focus.forward()
			var d := Vector2(f.x, f.z)
			var n := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([mp + d * 11.0, mp - d * 6.0 + n * 7.0, mp - d * 6.0 - n * 7.0]), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([mp + d * 8.0, mp - d * 4.0 + n * 5.0, mp - d * 4.0 - n * 5.0]), focus.color)
