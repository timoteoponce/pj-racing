extends Screen
## Settings: driving help, race options, audio, display and progress.

var _reset_armed := false
var _reset_btn: Button


func build() -> void:
	var v := UI.center_box(self, 560)
	v.add_theme_constant_override("separation", 10)
	v.add_child(UI.title("SETTINGS", 50))

	var easy := Cycler.new("Easy Driving (auto gas)", ["Off", "On"], 1 if Save.setting("easy_drive", true) else 0)
	easy.changed.connect(func(i): Save.set_setting("easy_drive", i == 1))
	v.add_child(easy)
	var laps_idx := maxi(0, Game.LENGTH_LAPS.find(Game.laps))
	var length := Cycler.new("Race Length", Game.LENGTH_NAMES, laps_idx)
	length.changed.connect(func(i):
		Game.laps = Game.LENGTH_LAPS[i]
		Save.set_setting("laps", Game.laps))
	v.add_child(length)
	var cpus := Cycler.new("Computer Racers", range(0, 8), Game.cpu_count)
	cpus.changed.connect(func(i):
		Game.cpu_count = i
		Save.set_setting("cpus", i))
	v.add_child(cpus)
	var diff := Cycler.new("Computer Skill", Game.DIFFICULTY_NAMES, Game.difficulty)
	diff.changed.connect(func(i):
		Game.difficulty = i
		Save.set_setting("difficulty", i))
	v.add_child(diff)

	var vols := []
	for i in 11:
		vols.append("%d%%" % (i * 10))
	var music := Cycler.new("Music", vols, roundi(float(Save.setting("music", 0.7)) * 10))
	music.changed.connect(func(i): Save.set_setting("music", i / 10.0))
	v.add_child(music)
	var sfx := Cycler.new("Sound FX", vols, roundi(float(Save.setting("sfx", 0.9)) * 10))
	sfx.changed.connect(func(i):
		Save.set_setting("sfx", i / 10.0)
		Sfx.play("pickup"))
	v.add_child(sfx)
	var fs := Cycler.new("Fullscreen", ["Off", "On"], 1 if Save.setting("fullscreen", false) else 0)
	fs.changed.connect(func(i): Save.set_setting("fullscreen", i == 1))
	v.add_child(fs)
	var q := Cycler.new("Graphics", ["Low", "Medium", "High"], int(Save.setting("quality", 2)))
	q.changed.connect(func(i):
		Game.quality = i
		Save.set_setting("quality", i))
	v.add_child(q)
	for c in v.get_children():
		if c is Cycler:
			c.custom_minimum_size = Vector2(560, 48)
	_reset_btn = UI.button("Reset Progress", _reset, 560)
	v.add_child(_reset_btn)
	v.add_child(UI.button("Back", on_back, 560))
	focus_first(easy)


func _reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Press again to ERASE all progress"
		return
	var settings: Dictionary = Save.data["settings"].duplicate()
	Save.data = Save.defaults()
	Save.data["settings"] = settings
	Save.save_game()
	Sfx.play("back")
	_reset_btn.text = "Progress reset"
	_reset_armed = false


func on_back() -> void:
	Game.goto("title")
