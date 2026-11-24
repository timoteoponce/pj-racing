extends Node
## Global game flow: screen routing, race setup, tournaments and rewards.

const SCREENS := {
	"title": "res://src/ui/title_screen.gd",
	"arcade": "res://src/ui/arcade_setup.gd",
	"versus": "res://src/ui/versus_setup.gd",
	"tracks": "res://src/ui/track_select.gd",
	"garage": "res://src/ui/garage.gd",
	"controls": "res://src/ui/controls_screen.gd",
	"settings": "res://src/ui/settings_screen.gd",
	"race": "res://src/race/race.gd",
	"results": "res://src/ui/results_screen.gd",
}
const POINTS := [15, 12, 10, 8, 6, 4, 2, 1, 0, 0, 0, 0]
const CPU_NAMES := ["Brickster", "Stud Muffin", "Plato", "Axle Rose", "Torque", "Minnie Fig", "Gearbox", "Turbo Tina", "Bolt", "Dash", "Rusty", "Sprocket"]
const PLAYER_COLORS := [Color("#ff4a3d"), Color("#3d8bff"), Color("#47d65a"), Color("#ffd23d")]
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]
const LENGTH_NAMES := ["Short (2 laps)", "Normal (3 laps)", "Long (5 laps)"]
const LENGTH_LAPS := [2, 3, 5]

var main: Node
var current: Node

# session config
var mode := "arcade"  # "arcade" | "tournament"
var humans: Array = []  # [{slot, device, build_index, name}]
var cpu_count := 7
var difficulty := 1
var laps := 3
var track_queue: Array = []
var race_index := 0
var cup_id := ""
var roster: Array = []  # racers kept across a tournament
var standings := {}  # racer id -> points
var last_results: Array = []
var last_rewards: Array = []
var demo := false  # attract/smoke-test mode: all CPUs
var quality := 2  # 0 low, 1 medium, 2 high
var autopilot := false  # testing: CPU drives the human karts


func _ready() -> void:
	cpu_count = int(Save.setting("cpus", 7))
	difficulty = int(Save.setting("difficulty", 0))
	laps = int(Save.setting("laps", 3))
	quality = int(Save.setting("quality", 2))
	var args := OS.get_cmdline_user_args()
	autopilot = "--autoplay" in args
	if "--laps" in args:
		laps = int(args[args.find("--laps") + 1])
	if "--quality" in args:
		quality = int(args[args.find("--quality") + 1])


func goto(screen: String, params := {}) -> void:
	get_tree().paused = false
	if current and is_instance_valid(current):
		current.queue_free()
	var script: GDScript = load(SCREENS[screen])
	var node: Node = script.new()
	if node.has_method("setup"):
		node.setup(params)
	current = node
	main.add_child(node)


# ------------------------------------------------------------------ race setup

func start_arcade(track_id: String) -> void:
	mode = "arcade"
	track_queue = [track_id]
	race_index = 0
	_build_roster()
	goto("race")


func start_tournament(cup: String) -> void:
	mode = "tournament"
	cup_id = cup
	track_queue = Tracks.get_cup(cup)["tracks"].duplicate()
	race_index = 0
	_build_roster()
	standings.clear()
	for r in roster:
		standings[r["id"]] = 0
	goto("race")


func current_track() -> String:
	return track_queue[clampi(race_index, 0, track_queue.size() - 1)]


func _build_roster() -> void:
	roster.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for h in humans:
		roster.append({
			"id": "P%d" % (h["slot"] + 1), "name": h.get("name", "Player %d" % (h["slot"] + 1)),
			"human": true, "slot": h["slot"], "build": Save.get_build(h["build_index"]).duplicate(),
			"color": PLAYER_COLORS[h["slot"]],
		})
	var names := CPU_NAMES.duplicate()
	names.shuffle()
	var max_rarity: int = [1, 2, 3][difficulty]
	for i in cpu_count:
		var b := Parts.random_build(rng, max_rarity)
		roster.append({
			"id": "CPU%d" % i, "name": names[i % names.size()], "human": false, "slot": -1,
			"build": b, "color": Parts.paint_color(b),
		})


## Grid order: humans start at the back in arcade; in tournaments, reverse standings.
func grid_order() -> Array:
	var r := roster.duplicate()
	if mode == "tournament" and race_index > 0:
		r.sort_custom(func(a, b): return standings.get(a["id"], 0) < standings.get(b["id"], 0))
	else:
		var cpus := r.filter(func(x): return not x["human"])
		var hs := r.filter(func(x): return x["human"])
		cpus.shuffle()
		r = cpus + hs
	return r


# ------------------------------------------------------------------ results + rewards

## results: Array of {id, name, human, slot, place, time, finished}
func complete_race(results: Array) -> void:
	last_results = results
	if OS.has_environment("PJ_DEBUG"): for r in results: if r["human"]: print("HUMAN RESULT place=%d finished=%s time=%.1f" % [r["place"], r["finished"], r["time"]])
	last_rewards = []
	if demo:
		return
	if Parts.FREE_MODE:
		for r in results:
			if mode == "tournament":
				r["points"] = POINTS[r["place"] - 1] if r["place"] - 1 < POINTS.size() else 0
				standings[r["id"]] = standings.get(r["id"], 0) + r["points"]
		Save.save_game()
		return
	var mult: float = [0.7, 1.0, 1.5][difficulty]
	for r in results:
		if mode == "tournament":
			r["points"] = POINTS[r["place"] - 1] if r["place"] - 1 < POINTS.size() else 0
			standings[r["id"]] = standings.get(r["id"], 0) + r["points"]
		if not r["human"]:
			continue
		var studs := 0
		match int(r["place"]):
			1: studs = 250
			2: studs = 160
			3: studs = 110
			_: studs = maxi(20, 70 - 8 * int(r["place"]))
		studs = int(studs * mult)
		var rw := {"name": r["name"], "slot": r["slot"], "studs": studs, "parts": []}
		Save.add_studs(studs)
		if r["place"] == 1:
			Save.data["races_won"] = int(Save.data.get("races_won", 0)) + 1
			var p := _grant_random_part(0)
			if p != "":
				rw["parts"].append(p)
		elif r["place"] <= 3 and randf() < 0.5:
			var p := _grant_random_part(1)
			if p != "":
				rw["parts"].append(p)
		last_rewards.append(rw)
	Save.save_game()


func is_tournament_over() -> bool:
	return mode == "tournament" and race_index >= track_queue.size() - 1


## Called after the final tournament race: bonus rewards for the champions.
func complete_tournament() -> Array:
	var table := tournament_table()
	if Parts.FREE_MODE:
		if not table.is_empty() and table[0]["human"]:
			Save.data["trophies"][cup_id] = 1
		Save.save_game()
		return []
	var extra := []
	for i in table.size():
		var r: Dictionary = table[i]
		if not r["human"]:
			continue
		var rw := {"name": r["name"], "slot": r["slot"], "studs": 0, "parts": []}
		if i == 0:
			rw["studs"] = 600
			for k in 2:
				var p := _grant_random_part(1)
				if p != "":
					rw["parts"].append(p)
			var best := int(Save.data["trophies"].get(cup_id, 99))
			Save.data["trophies"][cup_id] = mini(best, 1)
		elif i < 3:
			rw["studs"] = 300 - i * 80
			var p := _grant_random_part(0)
			if p != "":
				rw["parts"].append(p)
			var best := int(Save.data["trophies"].get(cup_id, 99))
			Save.data["trophies"][cup_id] = mini(best, i + 1)
		else:
			rw["studs"] = 80
		Save.add_studs(rw["studs"])
		extra.append(rw)
	Save.save_game()
	return extra


func tournament_table() -> Array:
	var table := []
	for r in roster:
		table.append({"id": r["id"], "name": r["name"], "human": r["human"], "slot": r["slot"], "points": standings.get(r["id"], 0), "color": r["color"]})
	table.sort_custom(func(a, b): return a["points"] > b["points"])
	return table


## Unlocks a random locked part, weighted toward lower rarities. min_rarity biases rarer.
func _grant_random_part(min_rarity: int) -> String:
	var pool := Save.locked_parts()
	if pool.is_empty():
		Save.add_studs(300)
		return ""
	var weights := []
	var total := 0.0
	for id in pool:
		var r: int = Parts.parts[id]["rarity"]
		var w: float = [10.0, 10.0, 4.0, 1.5][r]
		if r < min_rarity:
			w *= 0.5
		weights.append(w)
		total += w
	var pick := randf() * total
	for i in pool.size():
		pick -= weights[i]
		if pick <= 0.0:
			Save.unlock(pool[i])
			return pool[i]
	Save.unlock(pool[-1])
	return pool[-1]
