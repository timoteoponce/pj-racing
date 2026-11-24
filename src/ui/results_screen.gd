extends Screen
## Race results, rewards (studs + new lego parts), tournament standings and final podium.

var final := false
var _extra: Array = []


func setup(p: Dictionary) -> void:
	final = p.get("final", false)


func build() -> void:
	backdrop_colors = [Color("#5a1e8c"), Color("#1e0a3e")] if final else [Color("#0f3d8c"), Color("#0a2a5e")]
	Sfx.music("podium")
	if final:
		_extra = Game.complete_tournament()
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 30
	root.offset_right = -30
	root.offset_top = 20
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	# left: results table
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)
	var title := "CHAMPIONSHIP" if final else ("RACE %d/%d RESULTS" % [Game.race_index + 1, Game.track_queue.size()] if Game.mode == "tournament" else "RACE RESULTS")
	left.add_child(UI.title(title, 48))
	var sub := UI.label(Tracks.get_cup(Game.cup_id)["name"] if (final or Game.mode == "tournament") else Tracks.get_def(Game.current_track())["name"], 22, Color.WHITE, 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(sub)
	var table := PanelContainer.new()
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(table)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	table.add_child(rows)
	if final or Game.mode == "tournament":
		var tbl := Game.tournament_table()
		var res_by_id := {}
		for r in Game.last_results:
			res_by_id[r["id"]] = r
		rows.add_child(_row("#", "Racer", "This race" if not final else "", "Points", UI.YELLOW, true))
		for i in tbl.size():
			var r: Dictionary = tbl[i]
			var this := ""
			if not final and res_by_id.has(r["id"]):
				this = "%s  +%d" % [UI.ordinal(res_by_id[r["id"]]["place"]), res_by_id[r["id"]].get("points", 0)]
			rows.add_child(_row(UI.ordinal(i + 1), r["name"] + ("  (P%d)" % (r["slot"] + 1) if r["human"] else ""), this, str(r["points"]), r["color"], r["human"], i))
	else:
		rows.add_child(_row("#", "Racer", "Time", "", UI.YELLOW, true))
		for r in Game.last_results:
			rows.add_child(_row(UI.ordinal(r["place"]), r["name"] + ("  (P%d)" % (r["slot"] + 1) if r["human"] else ""), UI.time_str(r["time"]) if r["finished"] else "--", "", r["color"], r["human"], r["place"] - 1))

	# right: winner car + rewards + buttons
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 460
	root.add_child(right)
	var winner_build := {}
	var winner_name := ""
	if final:
		var tbl := Game.tournament_table()
		for r in Game.roster:
			if r["id"] == tbl[0]["id"]:
				winner_build = r["build"]
				winner_name = r["name"]
	elif not Game.last_results.is_empty():
		winner_build = Game.last_results[0]["build"]
		winner_name = Game.last_results[0]["name"]
	var show := CarShowcase.new()
	show.custom_minimum_size = Vector2(460, 250)
	show.cam_dist = 9.0
	show.bg_top = Color("#ffb020") if final else Color("#3b8fe8")
	right.add_child(show)
	show.set_build(winner_build)
	var wl := UI.label(("CHAMPION: %s" if final else "WINNER: %s") % winner_name, 26, UI.YELLOW, 8)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(wl)

	var rewards := PanelContainer.new()
	rewards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rewards.visible = not Parts.FREE_MODE
	right.add_child(rewards)
	if Parts.FREE_MODE:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(spacer)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 4)
	rewards.add_child(rv)
	rv.add_child(UI.label("REWARDS", 22, UI.YELLOW, 5))
	var list: Array = _extra if final else Game.last_rewards
	var any_part := false
	var first_part_cat := "chassis"
	for rw in list:
		var who := UI.label("%s:  +%d studs" % [rw["name"], rw["studs"]], 20, Game.PLAYER_COLORS[clampi(rw["slot"], 0, 3)], 5)
		rv.add_child(who)
		for pid in rw["parts"]:
			var card := NewPartCard.new()
			card.part_id = pid
			if not any_part:
				first_part_cat = Parts.get_part(pid)["cat"]
			card.custom_minimum_size = Vector2(400, 64)
			rv.add_child(card)
			any_part = true
	if list.is_empty():
		rv.add_child(UI.label("Keep racing to earn studs and parts!", 18))
	if any_part:
		get_tree().create_timer(0.5).timeout.connect(func(): Sfx.play("reward"))

	var first: Button
	if final:
		if any_part:
			first = UI.big_button("Try it in the Garage!", func(): Game.goto("garage", {"tab": first_part_cat}), Color("#2fae4a"), 460, 64, 24)
			right.add_child(first)
			right.add_child(UI.button("Main Menu", func(): Game.goto("title"), 460))
		else:
			first = UI.button("Main Menu", func(): Game.goto("title"), 460)
			right.add_child(first)
	elif Game.mode == "tournament":
		if Game.is_tournament_over():
			first = UI.button("Final Standings  >", func(): Game.goto("results", {"final": true}), 460)
		else:
			var nxt: String = Tracks.get_def(Game.track_queue[Game.race_index + 1])["name"]
			first = UI.button("Next: %s  >" % nxt, func():
				Game.race_index += 1
				Game.goto("race"), 460)
		right.add_child(first)
		right.add_child(UI.button("Quit Tournament", func(): Game.goto("title"), 460))
	else:
		var slot := int(Game.humans[0]["build_index"]) if not Game.humans.is_empty() else 0
		if any_part:
			first = UI.big_button("Try it in the Garage!", func(): Game.goto("garage", {"slot": slot, "tab": first_part_cat}), Color("#2fae4a"), 460, 64, 24)
			right.add_child(first)
			right.add_child(UI.button("Race Again", func(): Game.start_arcade(Game.current_track()), 460))
		else:
			first = UI.button("Race Again", func(): Game.start_arcade(Game.current_track()), 460)
			right.add_child(first)
			right.add_child(UI.button("Build Your Car", func(): Game.goto("garage", {"slot": slot}), 460))
		right.add_child(UI.button("Choose Track", func(): Game.goto("tracks", {"mode": "arcade"}), 460))
		right.add_child(UI.button("Main Menu", func(): Game.goto("title"), 460))
	focus_first(first)
	if final:
		_confetti()
	if Game.autopilot:
		# smoke-test mode: advance automatically
		get_tree().create_timer(1.0).timeout.connect(func():
			if final:
				print("TOURNAMENT OK: champion=%s" % winner_name)
				get_tree().quit()
			elif Game.mode == "tournament":
				first.pressed.emit()
			else:
				print("ARCADE OK")
				get_tree().quit())


func _row(a: String, b: String, c: String, d: String, col: Color, bold: bool, idx := -1) -> Control:
	var h := HBoxContainer.new()
	var sz := 22 if bold else 20
	var pc := UI.place_color(idx + 1) if idx >= 0 and idx < 3 else Color.WHITE
	var la := UI.label(a, sz, pc if idx >= 0 else UI.YELLOW, 5)
	la.custom_minimum_size.x = 70
	h.add_child(la)
	var sw := ColorRect.new()
	sw.color = col
	sw.custom_minimum_size = Vector2(14, 14)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if idx >= 0:
		h.add_child(sw)
	var lb := UI.label(b, sz, Color.WHITE if not bold or idx < 0 else UI.YELLOW, 5)
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(lb)
	var lc := UI.label(c, sz, Color(1, 1, 1, 0.85), 5)
	lc.custom_minimum_size.x = 150
	h.add_child(lc)
	var ld := UI.label(d, sz, UI.YELLOW, 5)
	ld.custom_minimum_size.x = 70
	ld.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(ld)
	if idx >= 0:
		h.modulate.a = 0.0
		var tw := h.create_tween()
		tw.tween_interval(0.06 * idx)
		tw.tween_property(h, "modulate:a", 1.0, 0.2)
	return h


func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.amount = 160
	p.lifetime = 4.0
	p.position = Vector2(get_viewport_rect().size.x * 0.5, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(get_viewport_rect().size.x * 0.5, 10)
	p.direction = Vector2(0, 1)
	p.spread = 30
	p.initial_velocity_min = 80
	p.initial_velocity_max = 200
	p.gravity = Vector2(0, 120)
	p.angular_velocity_min = -300
	p.angular_velocity_max = 300
	p.scale_amount_min = 6
	p.scale_amount_max = 12
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([UI.RED, UI.YELLOW, UI.BLUE, Color("#47d65a"), Color.WHITE])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g
	add_child(p)


func on_back() -> void:
	pass


## Big shiny "NEW PART!" sticker for the rewards list.
class NewPartCard:
	extends Control
	var part_id := ""
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var p := Parts.get_part(part_id)
		if p.is_empty():
			return
		var col: Color = Parts.RARITY_COLORS[p["rarity"]]
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var sb := UI.box(col.darkened(0.55), 14, 3, col.lerp(Color.WHITE, pulse * 0.6))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		# little brick icon
		var c := Vector2(40, size.y * 0.55)
		draw_rect(Rect2(c + Vector2(-16, -16), Vector2(12, 7)), col.lightened(0.2))
		draw_rect(Rect2(c + Vector2(4, -16), Vector2(12, 7)), col.lightened(0.2))
		draw_style_box(UI.box(col, 5, 0, col.darkened(0.3), 4), Rect2(c + Vector2(-22, -10), Vector2(44, 22)))
		var f := UI.font()
		draw_string(f, Vector2(76, 26), "NEW %s!" % Parts.CATEGORY_NAMES[p["cat"]].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.YELLOW)
		draw_string(f, Vector2(76, 52), "%s  (%s)" % [p["name"], Parts.RARITY_NAMES[p["rarity"]]], HORIZONTAL_ALIGNMENT_LEFT, size.x - 84, 22, Color.WHITE)
