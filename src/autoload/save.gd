extends Node
## Persistent profile: studs, unlocked parts, garage builds, upgrades, settings.

const PATH := "user://pj_racing_save.json"
const TEST_PATH := "user://pj_racing_test_save.json"
const BUILD_SLOTS := 4
## Bump to migrate old saves. v2: garage cars restart from the new base car.
const VERSION := 2

var data := {}
var path := PATH


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--demo" in args or "--autoplay" in args or "--screen" in args or OS.has_environment("PJ_DEBUG"):
		path = TEST_PATH  # smoke tests never touch the real profile
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	load_game()


func defaults() -> Dictionary:
	var builds := []
	for i in BUILD_SLOTS:
		builds.append(Parts.default_build(i))
	return {
		"version": VERSION,
		"studs": 300,
		"unlocked": Parts.starters(),
		"builds": builds,
		"upgrades": {"spd": 0, "acc": 0, "hnd": 0},
		"trophies": {},
		"races_won": 0,
		"settings": {"music": 0.7, "sfx": 0.9, "fullscreen": false, "laps": 3, "cpus": 7, "difficulty": 0, "quality": 2, "easy_drive": true},
		"new_parts": [],
		"pad_map": {},
	}


func load_game() -> void:
	data = defaults()
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in parsed:
				if data.has(k) and typeof(data[k]) == TYPE_DICTIONARY and parsed[k] is Dictionary:
					data[k].merge(parsed[k], true)
				else:
					data[k] = parsed[k]
	if int(data.get("version", 1)) < 2:
		data["builds"] = defaults()["builds"]
		data["version"] = VERSION
	# sanitize builds against the catalog (parts may have been renamed)
	var builds: Array = data["builds"]
	while builds.size() < BUILD_SLOTS:
		builds.append(Parts.default_build(builds.size()))
	for i in builds.size():
		var b: Dictionary = builds[i]
		var d := Parts.default_build(i)
		for c in Parts.CATEGORIES:
			if not Parts.parts.has(b.get(c, "")) or not is_unlocked(b[c]):
				b[c] = d[c]
		if not b.has("name"):
			b["name"] = d["name"]
		var ex: Array = Parts.extras_of(b).filter(func(id): return Parts.parts.has(id) and is_unlocked(id))
		b[Parts.EXTRAS] = ex.slice(0, Parts.MAX_EXTRAS)
	for id in Parts.starters():
		if not is_unlocked(id):
			data["unlocked"].append(id)
	apply_settings()


func save_game() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func setting(key: String, def = null):
	return data["settings"].get(key, def)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	apply_settings()
	save_game()


func apply_settings() -> void:
	var fs: bool = data["settings"].get("fullscreen", false)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	if is_instance_valid(get_node_or_null("/root/Sfx")):
		get_node("/root/Sfx").apply_volumes()


func is_unlocked(id: String) -> bool:
	return Parts.FREE_MODE or data["unlocked"].has(id)


func unlock(id: String) -> void:
	if not data["unlocked"].has(id):
		data["unlocked"].append(id)
		data["new_parts"].append(id)


func is_new(id: String) -> bool:
	return not Parts.FREE_MODE and data["new_parts"].has(id)


func mark_seen(id: String) -> void:
	data["new_parts"].erase(id)


func locked_parts() -> Array:
	var out := []
	for id in Parts.parts:
		if not data["unlocked"].has(id):
			out.append(id)
	return out


func studs() -> int:
	return int(data["studs"])


func add_studs(n: int) -> void:
	data["studs"] = studs() + n


func spend(n: int) -> bool:
	if studs() < n:
		return false
	data["studs"] = studs() - n
	save_game()
	return true


func get_build(i: int) -> Dictionary:
	return data["builds"][clampi(i, 0, BUILD_SLOTS - 1)]


func set_build(i: int, b: Dictionary) -> void:
	data["builds"][i] = b
	save_game()


func upgrades() -> Dictionary:
	return data["upgrades"]
