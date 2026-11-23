extends Screen
## "Pick your car": choose one of your 4 garage cars, then a track.

var _show: CarShowcase
var _name: Label
var _type: Label
var _stats: StatStuds
var _build := 0


func build() -> void:
	Sfx.music("menu")
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	_show = CarShowcase.new()
	_show.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_show.size_flags_stretch_ratio = 1.4
	_show.cam_dist = 8.0
	root.add_child(_show)
	var side := PanelContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(side)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	side.add_child(v)
	v.add_child(UI.title("PICK YOUR CAR", 48))

	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(picker)
	var prev := UI.big_button("<", func(): _pick(-1), UI.YELLOW, 70, 70, 36)
	picker.add_child(prev)
	var mid := VBoxContainer.new()
	mid.custom_minimum_size.x = 300
	mid.add_theme_constant_override("separation", 0)
	picker.add_child(mid)
	_name = UI.label("", 30, UI.YELLOW, 8)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_name)
	_type = UI.label("", 18, Color(1, 1, 1, 0.8))
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_type)
	var nxt := UI.big_button(">", func(): _pick(1), UI.YELLOW, 70, 70, 36)
	picker.add_child(nxt)

	_stats = StatStuds.new()
	_stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_stats)

	var go := UI.big_button("PICK A TRACK  >", _go, UI.YELLOW, 440, 84, 32)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(go)
	var gar := UI.big_button("Change it in the Garage", func(): Game.goto("garage", {"slot": _build}), Color("#2fae4a"), 440, 60, 22)
	gar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(gar)
	var back := UI.big_button("Back", on_back, Color("#5b6b7a"), 440, 54, 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	_build = clampi(int(Game.humans[0]["build_index"]) if not Game.humans.is_empty() else 0, 0, Save.BUILD_SLOTS - 1)
	_refresh(false)
	focus_first(go)


func _input(e: InputEvent) -> void:
	# left/right anywhere on this screen flips through cars (unless a side button is focused)
	var f := get_viewport().gui_get_focus_owner()
	if f is Button and (f.text == "<" or f.text == ">"):
		return
	if e.is_action_pressed("ui_left"):
		_pick(-1)
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("ui_right"):
		_pick(1)
		get_viewport().set_input_as_handled()


func _pick(d: int) -> void:
	_build = posmod(_build + d, Save.BUILD_SLOTS)
	Sfx.play("click", 1.2)
	_refresh(true)


func _refresh(pop: bool) -> void:
	var b := Save.get_build(_build)
	_show.set_build(b, pop)
	_name.text = b["name"]
	_type.text = "%s  •  car %d of %d" % [Parts.get_part(b["chassis"])["name"], _build + 1, Save.BUILD_SLOTS]
	_stats.show_build(b)


func _go() -> void:
	Game.humans = [{"slot": 0, "device": "any", "build_index": _build, "name": "Player 1"}]
	Controls.clear_all()
	Controls.assign(0, "any")
	Game.goto("tracks", {"mode": "arcade"})


func on_back() -> void:
	Game.goto("title")
