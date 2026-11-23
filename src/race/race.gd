extends Node3D
## Runs one race: builds the track, spawns karts on the grid, split-screen cameras + HUDs,
## countdown, lap counting, positions, rubber-banding, items, pause menu and results.

var track: Track
var karts: Array[Kart] = []
var humans: Array[Kart] = []
var huds: Array[Hud] = []
var cams: Array[ChaseCam] = []
var laps := 3
var state := "intro"
var timer := 2.2
var race_time := 0.0
var finish_order: Array[Kart] = []
var _ui: CanvasLayer
var _big: Label
var _pause: Control
var _end_timer := -1.0
var _first_finish := -1.0
var _last_count := 99
var _base_quality := 2


func _ready() -> void:
	laps = Game.laps
	Sfx.music("race")
	_base_quality = Game.quality
	var n_humans := Game.humans.size() if not Game.demo else 0
	if n_humans >= 3:
		Game.quality = maxi(0, Game.quality - 1)
	track = Track.new()
	add_child(track)
	track.build(Tracks.get_def(Game.current_track()))
	var order := Game.grid_order()
	for i in order.size():
		var e: Dictionary = order[i]
		var k := Kart.new()
		k.setup(e, track, self, Game.difficulty)
		add_child(k)
		k.place_at(track.grid_transform(i))
		karts.append(k)
		if k.is_human:
			humans.append(k)
	humans.sort_custom(func(a, b): return a.slot < b.slot)
	_build_views()


func _build_views() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	_ui.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("#1b2a34")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	_ui.add_child(bg)
	_ui.move_child(bg, 0)
	var targets: Array[Kart] = []
	targets.assign(humans)
	if targets.is_empty():
		targets.append(karts[0])  # spectator / demo
	var n := targets.size()
	var cols := 1 if n <= 2 else 2
	var rows := 1 if n == 1 else 2
	var idx := 0
	for r in rows:
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		root.add_child(row)
		for c in cols:
			var cell := Control.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cell.clip_contents = true
			row.add_child(cell)
			if idx < n:
				var svc := SubViewportContainer.new()
				svc.stretch = true
				svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				cell.add_child(svc)
				var sv := SubViewport.new()
				var q := Game.quality
				sv.msaa_3d = Viewport.MSAA_2X if (q >= 2 and n <= 2) else Viewport.MSAA_DISABLED
				sv.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
				sv.scaling_3d_scale = [0.7, 0.85, 1.0][q] * (1.0 if n <= 2 else 0.9)
				sv.audio_listener_enable_3d = false
				svc.add_child(sv)
				var cam := ChaseCam.new()
				cam.target = targets[idx]
				cam.intro = timer
				sv.add_child(cam)
				cams.append(cam)
				var hud := Hud.new()
				hud.setup(self, targets[idx], n > 1)
				cell.add_child(hud)
				huds.append(hud)
			else:
				var map := Hud.Minimap.new()
				map.race = self
				map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				cell.add_child(map)
				var lbl := UI.label(Tracks.get_def(Game.current_track())["name"], 30, UI.YELLOW, 8)
				lbl.position = Vector2(20, 12)
				cell.add_child(lbl)
			idx += 1
	_big = UI.label("", 150, UI.YELLOW, 26)
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ui.add_child(_big)
	var title := UI.label("%s  -  %s" % [Tracks.get_def(Game.current_track())["name"], ("Race %d/%d" % [Game.race_index + 1, Game.track_queue.size()]) if Game.mode == "tournament" else "%d Laps" % laps], 40, Color.WHITE, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.pin(title, 0.5, 1, -500, -130, 1000, 60)
	title.name = "IntroTitle"
	_ui.add_child(title)
	if not humans.is_empty():
		var easy := bool(Save.setting("easy_drive", true))
		var hint := PanelContainer.new()
		hint.theme = UI.theme()
		hint.name = "ControlsHint"
		UI.pin(hint, 0.5, 1, -430, -70 if humans.size() == 1 else -50, 860, 60)
		var hl := UI.label(("GAS IS AUTOMATIC!   " if easy else "GAS: W / Up / Cross   ") + "STEER: arrows, A/D or stick   •   DRIFT: Space / R1   •   ITEM: E / L1", 18, Color.WHITE, 5)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_child(hl)
		_ui.add_child(hint)


func _big_text(t: String, col := UI.YELLOW) -> void:
	_big.text = t
	_big.add_theme_color_override("font_color", col)
	_big.pivot_offset = _big.size * 0.5
	_big.scale = Vector2.ONE * 1.6
	_big.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_big, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _exit_tree() -> void:
	Game.quality = _base_quality


func _physics_process(dt: float) -> void:
	match state:
		"intro":
			timer -= dt
			if timer <= 0.0:
				state = "countdown"
				timer = 3.0
				var t := _ui.get_node_or_null("IntroTitle")
				if t:
					t.queue_free()
		"countdown":
			timer -= dt
			var n := int(ceil(timer))
			if n != _last_count and n > 0:
				_last_count = n
				_big_text(str(n), Color.WHITE)
				Sfx.play("count")
				for i in track.start_lights.size():
					var lit := i < 3 - n + 1
					track.start_lights[i].emission = Color("#ff2020") if lit else Color.BLACK
					track.start_lights[i].albedo_color = Color("#ff3030") if lit else Color("#330000")
			if timer <= 0.0:
				state = "race"
				var hint := _ui.get_node_or_null("ControlsHint")
				if hint:
					var tw := hint.create_tween()
					tw.tween_interval(2.0)
					tw.tween_property(hint, "modulate:a", 0.0, 0.6)
					tw.tween_callback(hint.queue_free)
				_big_text("GO!", Color("#47d65a"))
				Sfx.play("go")
				for m in track.start_lights:
					m.emission = Color("#20ff40")
					m.albedo_color = Color("#30ff50")
					m.emission_energy_multiplier = 3.0
				for k in karts:
					k.controls_enabled = true
					# rocket start for players holding the gas on GO
					if k.is_human and k.in_throttle > 0.5:
						k.boost(0.8, 0.8)
		"race":
			race_time += dt
			if _big.modulate.a > 0.0:
				_big.modulate.a = maxf(0.0, _big.modulate.a - dt * 1.2)
	_update_progress(dt)
	_rubber_band()
	_check_end(dt)


func _update_progress(dt: float) -> void:
	var L := track.length
	for k in karts:
		var off := track.closest_offset(k.global_position)
		var d := off - k.offset
		if d < -L * 0.5:
			k.lap += 1
			if k.lap > k.max_lap:
				k.max_lap = k.lap
				_on_new_lap(k)
		elif d > L * 0.5:
			k.lap -= 1
		k.offset = off
		k.progress = (k.lap - 1) * L + off
		var t := track.tangent_at(off)
		if k.forward().dot(Vector3(t.x, 0, t.z).normalized()) < -0.3 and absf(k.speed) > 4.0 and state == "race":
			k.wrong_way += dt
		else:
			k.wrong_way = 0.0
	var running: Array[Kart] = []
	running.assign(karts.filter(func(k): return not k.finished))
	running.sort_custom(func(a, b): return a.progress > b.progress)
	var p := 1
	for k in finish_order:
		k.place = p
		p += 1
	for k in running:
		k.place = p
		p += 1


func _on_new_lap(k: Kart) -> void:
	if k.max_lap <= 1 or state != "race":
		return
	if k.max_lap > laps:
		_finish(k)
		return
	var hud := _hud_for(k)
	if hud:
		if k.max_lap == laps:
			hud.message("FINAL LAP!", UI.RED, 2.5)
			Sfx.play("final")
		else:
			hud.message("LAP %d" % k.max_lap, UI.YELLOW, 1.5)
			Sfx.play("lap")


func _finish(k: Kart) -> void:
	if k.finished:
		return
	k.finished = true
	k.finish_time = race_time
	finish_order.append(k)
	k.place = finish_order.size()
	if _first_finish < 0.0:
		_first_finish = race_time
	var hud := _hud_for(k)
	if hud:
		hud.message("FINISH!  %s" % UI.ordinal(k.place), UI.place_color(k.place), 6.0)
		Sfx.play("finish")
		if k.place <= 3:
			Fx.burst(self, k.global_position + Vector3.UP * 3.0, [UI.YELLOW, UI.RED, UI.BLUE, Color.WHITE], 30, 14.0)


func _hud_for(k: Kart) -> Hud:
	for h in huds:
		if h.kart == k:
			return h
	return null


func _rubber_band() -> void:
	var ref := -INF
	for h in humans:
		ref = maxf(ref, h.progress)
	if humans.is_empty():
		return
	var catchup: float = [1.03, 1.06, 1.09][Game.difficulty]
	for k in karts:
		if k.is_human:
			continue
		var d := k.progress - ref
		if d < -120.0:
			k.ai_mult = catchup + 0.03
		elif d < -40.0:
			k.ai_mult = catchup
		elif d > 150.0:
			k.ai_mult = 0.93
		elif d > 60.0:
			k.ai_mult = 0.97
		else:
			k.ai_mult = 1.0


func _check_end(dt: float) -> void:
	if state != "race":
		return
	if _end_timer >= 0.0:
		_end_timer -= dt
		if _end_timer < 0.0:
			_end_race()
		return
	var all_humans_done := humans.size() > 0 and humans.all(func(h): return h.finished)
	var everyone_done := finish_order.size() == karts.size()
	var demo_done := humans.is_empty() and _first_finish >= 0.0 and race_time - _first_finish > 6.0
	var timeout := _first_finish >= 0.0 and race_time - _first_finish > 50.0
	if all_humans_done or everyone_done or demo_done or timeout:
		_end_timer = 3.5 if not humans.is_empty() else 0.5


func _end_race() -> void:
	state = "done"
	var running: Array[Kart] = []
	running.assign(karts.filter(func(k): return not k.finished))
	running.sort_custom(func(a, b): return a.progress > b.progress)
	var order: Array[Kart] = []
	order.assign(finish_order)
	order.append_array(running)
	var results := []
	for i in order.size():
		var k := order[i]
		results.append({
			"id": k.racer_id, "name": k.racer_name, "human": k.is_human, "slot": k.slot,
			"place": i + 1, "time": k.finish_time if k.finished else -1.0, "finished": k.finished,
			"color": k.color, "build": k.entry["build"],
		})
	Game.complete_race(results)
	if Game.demo:
		print("DEMO RACE OK: track=%s time=%.1f winner=%s finished=%d/%d" % [Game.current_track(), race_time, results[0]["name"], finish_order.size(), karts.size()])
		get_tree().quit()
		return
	Game.goto("results")


# ------------------------------------------------------------------ items

func spawn_missile(k: Kart) -> void:
	var p := Projectile.missile(self, k)
	add_child(p)
	var f := track.frame_at(p.s)
	p.global_position = f.origin + f.basis.x * p.lat + Vector3.UP * 0.9


func spawn_oil(k: Kart) -> void:
	var p := Projectile.oil(self, k)
	add_child(p)
	p.global_position = k.global_position - k.forward() * 3.2 + Vector3.UP * 0.05


# ------------------------------------------------------------------ pause

func _unhandled_input(e: InputEvent) -> void:
	if state == "done" or Game.demo:
		return
	var want: bool = e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE
	for h in humans:
		if e.is_action_pressed("p%d_pause" % h.slot):
			want = true
	if state == "intro" and (e.is_action_pressed("ui_accept") or e.is_action_pressed("p0_ok")):
		timer = 0.0
	if want and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_open_pause()


func _open_pause() -> void:
	get_tree().paused = true
	Sfx.play("back")
	_pause = PauseMenu.new()
	_pause.race = self
	_ui.add_child(_pause)


func restart() -> void:
	get_tree().paused = false
	Game.goto("race")


func quit_to_menu() -> void:
	get_tree().paused = false
	Controls.assign(0, "any")
	Game.goto("title")


class PauseMenu:
	extends Control
	var race: Node

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		theme = UI.theme()
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var v := UI.center_box(self, 380)
		v.add_child(UI.title("PAUSED", 64))
		var resume := UI.button("Resume", _resume)
		v.add_child(resume)
		if Game.mode == "arcade":
			v.add_child(UI.button("Restart Race", func(): race.restart()))
		v.add_child(UI.button("Quit to Menu", func(): race.quit_to_menu()))
		resume.call_deferred("grab_focus")

	func _resume() -> void:
		get_tree().paused = false
		queue_free()

	func _unhandled_input(e: InputEvent) -> void:
		var esc: bool = e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE
		var pause_btn := false
		for i in Controls.MAX_PLAYERS:
			if Controls.slot_device[i] != "" and e.is_action_pressed("p%d_pause" % i):
				pause_btn = true
		if esc or pause_btn or e.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_resume()
