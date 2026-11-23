extends Node
## Catalog of every lego part you can put on a car.
## Stats: spd (top speed), acc (acceleration), hnd (handling), wgt (weight), off (off-road).

const CATEGORIES := ["chassis", "body", "engine", "wheels", "spoiler", "paint", "driver"]
const CATEGORY_NAMES := {
	"chassis": "Chassis", "body": "Body", "engine": "Engine", "wheels": "Wheels",
	"spoiler": "Wing", "paint": "Paint", "driver": "Driver",
}
const STAT_KEYS := ["spd", "acc", "hnd", "wgt", "off"]
const STAT_NAMES := {
	"spd": "Speed", "acc": "Quick Start", "hnd": "Turning", "wgt": "Strength", "off": "Off-road",
}
const RARITY_NAMES := ["Starter", "Cool", "Rare", "Legendary"]
const FUN_NAMES := [
	"Turbo Taco", "Brick Rocket", "Stud Muffin", "Thunder Bolt", "Mud Monster", "Speedy Spaghetti",
	"Captain Crash", "Rainbow Racer", "Zoom Zoom", "Mega Bumper", "Lightning Lego", "Banana Blaster",
	"Wobbly Wonder", "Dino Dasher", "Pizza Pusher", "Noodle Nitro", "Cosmic Cruiser", "Big Wheel Bob",
	"Sir Skids-a-Lot", "Volcano Vroom", "Pickle Rocket", "Jelly Jet", "Robo Rascal", "Shark Attack",
]
const RARITY_COLORS := [Color("#d0d0d0"), Color("#7fd16b"), Color("#4aa3ff"), Color("#ffb020")]
const PRICES := [0, 350, 800, 1600]

## Workshop upgrades (global, bought with studs). Each level adds +0.5 to a stat.
const UPGRADES := {
	"spd": {"name": "Faster Engine", "max": 5},
	"acc": {"name": "Turbo Boost", "max": 5},
	"hnd": {"name": "Sticky Tires", "max": 5},
}

var parts := {}
var by_cat := {}


func _ready() -> void:
	for c in CATEGORIES:
		by_cat[c] = []
	_define()


func _add(cat: String, id: String, pname: String, rarity: int, stats := {}, extra := {}) -> void:
	var p := {"id": id, "cat": cat, "name": pname, "rarity": rarity, "price": PRICES[rarity], "stats": stats}
	p.merge(extra)
	parts[id] = p
	by_cat[cat].append(id)


func _define() -> void:
	# --- chassis: base stats + vehicle class
	_add("chassis", "ch_kart", "Go-Kart", 0, {"spd": 4, "acc": 7, "hnd": 7, "wgt": 3, "off": 3}, {"cls": "kart"})
	_add("chassis", "ch_racer", "Street Racer", 0, {"spd": 6, "acc": 5, "hnd": 5, "wgt": 4, "off": 2}, {"cls": "car"})
	_add("chassis", "ch_monster", "Monster Truck", 0, {"spd": 4, "acc": 5, "hnd": 3, "wgt": 8, "off": 8}, {"cls": "monster"})
	_add("chassis", "ch_buggy", "Dune Buggy", 1, {"spd": 5, "acc": 6, "hnd": 5, "wgt": 4, "off": 7}, {"cls": "kart"})
	_add("chassis", "ch_hyper", "Hyper GT", 2, {"spd": 8, "acc": 5, "hnd": 6, "wgt": 5, "off": 1}, {"cls": "car"})
	_add("chassis", "ch_titan", "Titan Crusher", 3, {"spd": 6, "acc": 5, "hnd": 4, "wgt": 10, "off": 10}, {"cls": "monster"})

	# --- bodies
	_add("body", "bd_box", "Brick Box", 0, {})
	_add("body", "bd_wedge", "Speed Wedge", 0, {"spd": 1, "acc": -1})
	_add("body", "bd_pickup", "Pickup", 0, {"wgt": 1, "off": 1, "spd": -1})
	_add("body", "bd_bubble", "Bubble Cab", 1, {"hnd": 1, "acc": 1, "wgt": -1})
	_add("body", "bd_rocket", "Rocket Hull", 2, {"spd": 2, "hnd": -1})
	_add("body", "bd_cyber", "Cyber Slab", 3, {"spd": 1, "hnd": 1, "wgt": 1, "acc": 1})

	# --- engines
	_add("engine", "en_v4", "Stud V4", 0, {})
	_add("engine", "en_v6", "Turbo V6", 1, {"spd": 1, "acc": 1})
	_add("engine", "en_volt", "Volt Cell", 1, {"acc": 2, "hnd": 1, "spd": -1})
	_add("engine", "en_v8", "Twin V8", 2, {"spd": 2, "acc": 1, "hnd": -1, "wgt": 1})
	_add("engine", "en_jet", "Jet Thruster", 3, {"spd": 3, "acc": 2, "hnd": -1})

	# --- wheels
	_add("wheels", "wh_std", "Classic", 0, {})
	_add("wheels", "wh_slick", "Slicks", 0, {"spd": 1, "hnd": 1, "off": -2})
	_add("wheels", "wh_monster", "Monster Tires", 0, {"off": 3, "wgt": 1, "hnd": -1, "spd": -1})
	_add("wheels", "wh_knobby", "Knobby", 1, {"off": 2, "acc": 1, "spd": -1})
	_add("wheels", "wh_gold", "Golden Rims", 3, {"spd": 1, "acc": 1, "hnd": 1, "off": 1})

	# --- spoilers
	_add("spoiler", "sp_none", "No Wing", 0, {})
	_add("spoiler", "sp_lip", "Lip", 0, {"hnd": 1})
	_add("spoiler", "sp_wing", "Big Wing", 1, {"hnd": 2, "spd": -1})
	_add("spoiler", "sp_twin", "Twin Fins", 2, {"hnd": 1, "spd": 1})

	# --- paints (primary, secondary, accent). Material keys "gold"/"chrome" are metallic.
	_add("paint", "pt_red", "Classic Red", 0, {}, {"pri": "c:c91a09", "sec": "c:f4f4f4", "acc": "c:1b2a34"})
	_add("paint", "pt_blue", "Ocean Blue", 0, {}, {"pri": "c:0055bf", "sec": "c:f2cd37", "acc": "c:1b2a34"})
	_add("paint", "pt_green", "Jungle Green", 0, {}, {"pri": "c:237841", "sec": "c:1b2a34", "acc": "c:f2cd37"})
	_add("paint", "pt_yellow", "Sunny Yellow", 0, {}, {"pri": "c:f2cd37", "sec": "c:1b2a34", "acc": "c:c91a09"})
	_add("paint", "pt_orange", "Sunset Orange", 1, {}, {"pri": "c:fe8a18", "sec": "c:81007b", "acc": "c:f4f4f4"})
	_add("paint", "pt_pink", "Bubblegum", 1, {}, {"pri": "c:ff79c6", "sec": "c:36aebf", "acc": "c:f4f4f4"})
	_add("paint", "pt_lime", "Midnight Lime", 1, {}, {"pri": "c:1b2a34", "sec": "c:bbe90b", "acc": "c:bbe90b"})
	_add("paint", "pt_police", "Police", 2, {}, {"pri": "c:f4f4f4", "sec": "c:1b2a34", "acc": "c:0055bf"})
	_add("paint", "pt_chrome", "Chrome", 2, {}, {"pri": "chrome", "sec": "c:1b2a34", "acc": "c:c91a09"})
	_add("paint", "pt_gold", "Solid Gold", 3, {}, {"pri": "gold", "sec": "c:1b2a34", "acc": "c:f4f4f4"})

	# --- drivers (headgear)
	_add("driver", "dr_helmet", "Racing Helmet", 0, {})
	_add("driver", "dr_cap", "Cool Cap", 0, {})
	_add("driver", "dr_viking", "Viking", 1, {"wgt": 1})
	_add("driver", "dr_astro", "Astronaut", 1, {"acc": 1})
	_add("driver", "dr_wizard", "Wizard Hat", 2, {"hnd": 1})
	_add("driver", "dr_crown", "Royal Crown", 3, {"spd": 1})


func get_part(id: String) -> Dictionary:
	return parts.get(id, {})


func starters() -> Array:
	var out := []
	for id in parts:
		if parts[id]["rarity"] == 0:
			out.append(id)
	return out


func default_build(i: int) -> Dictionary:
	var presets := [
		{"chassis": "ch_kart", "body": "bd_box", "engine": "en_v4", "wheels": "wh_std", "spoiler": "sp_lip", "paint": "pt_red", "driver": "dr_helmet"},
		{"chassis": "ch_monster", "body": "bd_pickup", "engine": "en_v4", "wheels": "wh_monster", "spoiler": "sp_none", "paint": "pt_blue", "driver": "dr_cap"},
		{"chassis": "ch_racer", "body": "bd_wedge", "engine": "en_v4", "wheels": "wh_slick", "spoiler": "sp_lip", "paint": "pt_yellow", "driver": "dr_helmet"},
		{"chassis": "ch_kart", "body": "bd_wedge", "engine": "en_v4", "wheels": "wh_std", "spoiler": "sp_none", "paint": "pt_green", "driver": "dr_cap"},
	]
	var b: Dictionary = presets[i % presets.size()].duplicate()
	b["name"] = ["Red Rocket", "Blue Monster", "Yellow Zoomer", "Green Machine"][i % 4]
	return b


func random_build(rng: RandomNumberGenerator, max_rarity := 3) -> Dictionary:
	var b := {"name": "CPU"}
	for c in CATEGORIES:
		var pool: Array = by_cat[c].filter(func(id): return parts[id]["rarity"] <= max_rarity)
		b[c] = pool[rng.randi() % pool.size()]
	return b


func is_monster(build: Dictionary) -> bool:
	return get_part(build.get("chassis", ""))["cls"] == "monster" or build.get("wheels", "") == "wh_monster"


func compute_stats(build: Dictionary, upgrades := {}) -> Dictionary:
	var s := {}
	for k in STAT_KEYS:
		s[k] = 0.0
	for c in CATEGORIES:
		var p := get_part(build.get(c, ""))
		if p.is_empty():
			continue
		for k in p["stats"]:
			s[k] += float(p["stats"][k])
	for k in upgrades:
		if s.has(k):
			s[k] += 0.5 * float(upgrades[k])
	for k in STAT_KEYS:
		s[k] = clampf(s[k], 1.0, 12.0)
	return s


func paint_keys(build: Dictionary) -> Dictionary:
	var p := get_part(build.get("paint", "pt_red"))
	if p.is_empty():
		p = get_part("pt_red")
	return {"pri": p["pri"], "sec": p["sec"], "acc": p["acc"]}


func paint_color(build: Dictionary) -> Color:
	var key: String = paint_keys(build)["pri"]
	match key:
		"gold":
			return Color("#ffc832")
		"chrome":
			return Color("#d8dce2")
	return Color.html(key.substr(2))
