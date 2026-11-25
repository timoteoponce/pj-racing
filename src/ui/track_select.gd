extends Screen
## Track picker (arcade) or cup picker (tournament) with track outline previews.

var mode := "arcade"
var _desc: Label


func setup(p: Dictionary) -> void:
	mode = p.get("mode", "arcade")


func build() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 40
	v.offset_right = -40
	v.offset_top = 24
	v.offset_bottom = -24
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	v.add_child(UI.title("CHOOSE A TRACK" if mode == "arcade" else "CHOOSE A CUP", 52))
	var first: Control
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	v.add_child(grid)
	if mode == "arcade":
		for d in Tracks.all():
			var card := TrackCard.new()
			card.setup_track(d)
			card.pressed.connect(func():
				Sfx.play("go")
				Game.start_arcade(d["id"]))
			card.focus_entered.connect(func(): _desc.text = d["desc"])
			grid.add_child(card)
			if first == null:
				first = card
	else:
		for c in Tracks.cups():
			var card := TrackCard.new()
			card.setup_cup(c)
			card.pressed.connect(func():
				Sfx.play("go")
				_save_opts()
				Game.start_tournament(c["id"]))
			var names: Array = c["tracks"].map(func(id): return Tracks.get_def(id)["name"])
			card.focus_entered.connect(func(): _desc.text = " • ".join(names))
			grid.add_child(card)
			if first == null:
				first = card
	_desc = UI.label("", 22, Color.WHITE, 6)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_desc)
	var back := UI.button("Back", on_back, 260)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	focus_first(first)


func _save_opts() -> void:
	Save.data["settings"]["cpus"] = Game.cpu_count
	Save.data["settings"]["difficulty"] = Game.difficulty
	Save.data["settings"]["laps"] = Game.laps
	Save.save_game()


func on_back() -> void:
	Game.goto("arcade" if mode == "arcade" else "versus")


class TrackCard:
	extends Button
	var title_text := ""
	var sub := ""
	var col := Color.WHITE
	var col2 := Color.WHITE
	var outlines: Array = []  # Array of PackedVector2Array (normalized 0..1)
	var trophy := 0
	var _focused := false

	func _init() -> void:
		custom_minimum_size = Vector2(250, 180)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		focus_mode = Control.FOCUS_ALL
		flat = true
		focus_entered.connect(func():
			_focused = true
			Sfx.play("click", 1.0, -6.0)
			queue_redraw())
		focus_exited.connect(func():
			_focused = false
			queue_redraw())
		mouse_entered.connect(grab_focus)

	func setup_track(d: Dictionary) -> void:
		title_text = d["name"]
		var th := Tracks.theme(d["theme"])
		col = th["sky_top"]
		col2 = th["ground"]
		sub = d.get("level", "")
		outlines = [_outline(d["points"])]

	func setup_cup(c: Dictionary) -> void:
		title_text = c["name"]
		col = c["color"]
		col2 = c["color"].darkened(0.5)
		sub = "%d races" % c["tracks"].size()
		trophy = int(Save.data["trophies"].get(c["id"], 0))
		for id in c["tracks"]:
			outlines.append(_outline(Tracks.get_def(id)["points"]))

	static func _outline(pts: Array) -> PackedVector2Array:
		var curve := Curve2D.new()
		var n := pts.size()
		for i in n + 1:
			var p: Vector3 = pts[i % n]
			var tan: Vector3 = (pts[(i + 1) % n] - pts[(i - 1 + n) % n]) / 6.0
			curve.add_point(Vector2(p.x, p.z), -Vector2(tan.x, tan.z), Vector2(tan.x, tan.z))
		var baked := curve.get_baked_points()
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for p in baked:
			mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
			mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
		var span := maxf(mx.x - mn.x, mx.y - mn.y)
		var out := PackedVector2Array()
		for p in baked:
			out.append((p - (mn + mx) * 0.5) / span + Vector2(0.5, 0.5))
		return out

	func _process(_dt: float) -> void:
		if _focused:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008) if _focused else 0.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.15)
		sb.set_corner_radius_all(18)
		sb.border_width_bottom = 10
		sb.border_color = col2
		if _focused:
			sb.set_border_width_all(6)
			sb.border_width_bottom = 12
			sb.border_color = Color.WHITE.lerp(UI.YELLOW, pulse)
		draw_style_box(sb, r)
		var f := UI.font()
		# track outline(s)
		var area := Rect2(size.x * 0.46, 58, size.x * 0.5, size.y - 70)
		var k := outlines.size()
		for i in k:
			var cell := area
			if k > 1:
				var cols := 3 if k > 4 else k
				var rows := int(ceil(float(k) / cols))
				var cw := area.size.x / cols
				var ch := area.size.y / rows
				cell = Rect2(area.position + Vector2((i % cols) * cw, (i / cols) * ch), Vector2(cw, ch))
			var s := minf(cell.size.x, cell.size.y) * 0.9
			var o := cell.position + (cell.size - Vector2(s, s)) * 0.5
			var pts := PackedVector2Array()
			for p in outlines[i]:
				pts.append(o + p * s)
			draw_polyline(pts, Color(0, 0, 0, 0.35), 8.0 if k == 1 else 5.0, true)
			draw_polyline(pts, Color.WHITE, 4.0 if k == 1 else 2.5, true)
			if pts.size() > 0:
				draw_circle(pts[0], 5.0 if k == 1 else 3.0, UI.RED)
		var tfs := 28 if f.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x < size.x - 36 else 22
		draw_string_outline(f, Vector2(18, 44), title_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, tfs, 8, UI.DARK)
		draw_string(f, Vector2(18, 44), title_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, tfs, Color.WHITE)
		draw_string_outline(f, Vector2(18, 82), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, UI.DARK)
		draw_string(f, Vector2(18, 82), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.YELLOW)
		if trophy > 0:
			var tc: Color = [UI.place_color(1), UI.place_color(2), UI.place_color(3)][clampi(trophy - 1, 0, 2)]
			var c := Vector2(40, size.y - 46)
			draw_rect(Rect2(c + Vector2(-14, 14), Vector2(28, 8)), tc.darkened(0.3))
			draw_rect(Rect2(c + Vector2(-4, 4), Vector2(8, 12)), tc)
			draw_circle(c + Vector2(0, -6), 14, tc)
			draw_string(f, c + Vector2(24, 12), "Best: %s" % UI.ordinal(trophy), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
