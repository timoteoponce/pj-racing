extends Node
## Root node: owns the current screen. Supports CLI flags for testing:
##   -- --demo [track_id]   all-CPU race that quits when finished (smoke test)
##   -- --race track_id     jump straight into an arcade race
##   -- --screen name       open a screen directly

var _fps_label: Label


func _ready() -> void:
	Game.main = self
	get_window().title = "PJ-Racing"
	get_window().min_size = Vector2i(960, 540)
	var args := OS.get_cmdline_user_args()
	var fps := CanvasLayer.new()
	fps.layer = 100
	add_child(fps)
	_fps_label = Label.new()
	_fps_label.position = Vector2(8, 4)
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.visible = "--fps" in args
	fps.add_child(_fps_label)
	if "--pad-test" in args:
		_pad_test()
		return
	if "--demo" in args:
		Game.demo = true
		Game.humans = []
		var i := args.find("--demo")
		var tid: String = args[i + 1] if args.size() > i + 1 else "park"
		if not "--laps" in args:
			Game.laps = 1
		Game.start_arcade(tid)
	elif "--race" in args or "--tournament" in args:
		var tour := "--tournament" in args
		var i := args.find("--tournament" if tour else "--race")
		var n := 1
		if "--players" in args:
			n = int(args[args.find("--players") + 1])
		Game.humans = []
		for p in n:
			Game.humans.append({"slot": p, "device": "any" if p == 0 else "pad%d" % (p - 1), "build_index": p % 4, "name": "Player %d" % (p + 1)})
			Controls.assign(p, Game.humans[p]["device"])
		if tour:
			Game.start_tournament(args[i + 1] if args.size() > i + 1 else "stud")
		else:
			Game.start_arcade(args[i + 1] if args.size() > i + 1 else "park")
	elif "--screen" in args:
		var i := args.find("--screen")
		Game.humans = [{"slot": 0, "device": "any", "build_index": 0, "name": "Player 1"}]
		var params := {}
		if "--demo-build" in args:
			# dev: load a showcase build into car 1 (test save only)
			var parts_csv: String = args[args.find("--demo-build") + 1]
			var b := Save.get_build(0)
			var ex := []
			for id in parts_csv.split(","):
				var p := Parts.get_part(id)
				if p.is_empty():
					continue
				if p["cat"] == Parts.EXTRAS:
					ex.append(id)
				else:
					b[p["cat"]] = id
			b[Parts.EXTRAS] = ex
		if "--tab" in args:
			params["tab"] = args[args.find("--tab") + 1]
		Game.goto(args[i + 1], params)
	else:
		Game.goto("title")


var _fps_t := 0.0


## Smoke test: drives the menus with simulated gamepad buttons (Cross = enter, Circle = back).
func _pad_test() -> void:
	Game.goto("title")
	var steps := [
		[JOY_BUTTON_A, "arcade_setup.gd"],   # RACE! -> pick your car
		[JOY_BUTTON_B, "title_screen.gd"],   # back to title
		[JOY_BUTTON_DPAD_DOWN, "title_screen.gd"],
		[JOY_BUTTON_A, "garage.gd"],         # BUILD YOUR CAR
		[JOY_BUTTON_B, "title_screen.gd"],
	]
	for st in steps:
		await get_tree().create_timer(0.6).timeout
		for pressed in [true, false]:
			var e := InputEventJoypadButton.new()
			e.device = 0
			e.button_index = st[0]
			e.pressed = pressed
			Input.parse_input_event(e)
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		var cur: String = Game.current.get_script().resource_path.get_file()
		if cur != st[1]:
			print("PAD TEST FAILED: after button %d expected %s, got %s" % [st[0], st[1], cur])
			get_tree().quit(1)
			return
	print("PAD TEST OK")
	get_tree().quit()


func _process(dt: float) -> void:
	if "--fps-log" in OS.get_cmdline_user_args():
		_fps_t += dt
		if _fps_t > 2.0:
			_fps_t = 0.0
			print("FPS %d draws=%d prims=%d objs=%d proc=%.1fms phys=%.1fms" % [Engine.get_frames_per_second(),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	if _fps_label.visible:
		_fps_label.text = "%d fps" % Engine.get_frames_per_second()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_F11:
			Save.set_setting("fullscreen", not Save.setting("fullscreen", false))
		elif e.physical_keycode == KEY_F3:
			_fps_label.visible = not _fps_label.visible
