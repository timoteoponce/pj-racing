class_name Tracks
extends RefCounted
## Track + theme definitions. Points are a closed loop (x, elevation, z); the first point is the start line.

static var _defs: Array = []


static func all() -> Array:
	if _defs.is_empty():
		_defs = _build()
	return _defs


static func get_def(id: String) -> Dictionary:
	for d in all():
		if d["id"] == id:
			return d
	return all()[0]


static func cups() -> Array:
	return [
		{"id": "stud", "name": "Stud Cup", "color": Color("#f2cd37"), "tracks": ["park", "dunes", "frost"]},
		{"id": "turbo", "name": "Turbo Cup", "color": Color("#c91a09"), "tracks": ["city", "lava", "mud"]},
		{"id": "grand", "name": "Grand Brick Prix", "color": Color("#4aa3ff"), "tracks": ["park", "city", "dunes", "lava", "frost", "mud"]},
	]


static func get_cup(id: String) -> Dictionary:
	for c in cups():
		if c["id"] == id:
			return c
	return cups()[0]


static func _build() -> Array:
	var t := []
	t.append({
		"id": "park", "name": "Brick Park", "theme": "meadow", "width": 17.0, "shoulder": 5.0,
		"desc": "Sunny meadows and lego trees. Perfect first race.",
		"points": [Vector3(0, 0, 0), Vector3(0, 0, -120), Vector3(20, 0, -170), Vector3(70, 3, -195), Vector3(120, 5, -170), Vector3(140, 5, -120), Vector3(120, 3, -80), Vector3(90, 0, -60), Vector3(90, 0, -20), Vector3(120, 0, 20), Vector3(130, 0, 70), Vector3(100, 0, 110), Vector3(40, 0, 120), Vector3(0, 0, 80)],
		"ramps": 1, "boosts": 3, "bumps": 0.0,
	})
	t.append({
		"id": "dunes", "name": "Dusty Dunes", "theme": "desert", "width": 17.0, "shoulder": 6.0,
		"desc": "Rolling sand hills, cactus alley and big jumps.",
		"points": [Vector3(0, 0, 0), Vector3(0, 0, -100), Vector3(-30, 3, -160), Vector3(-90, 8, -180), Vector3(-150, 6, -150), Vector3(-170, 2, -90), Vector3(-140, 0, -40), Vector3(-160, 0, 10), Vector3(-200, 4, 60), Vector3(-170, 8, 120), Vector3(-100, 6, 130), Vector3(-60, 2, 90), Vector3(-25, 0, 60)],
		"ramps": 3, "boosts": 3, "bumps": 0.6,
	})
	t.append({
		"id": "frost", "name": "Frosty Peaks", "theme": "snow", "width": 16.0, "shoulder": 5.0,
		"desc": "Climb the icy mountain, then race down the hairpin.",
		"points": [Vector3(0, 0, 0), Vector3(0, 2, -90), Vector3(30, 8, -150), Vector3(90, 14, -165), Vector3(135, 18, -125), Vector3(125, 16, -65), Vector3(75, 12, -50), Vector3(52, 10, -8), Vector3(80, 8, 40), Vector3(140, 6, 60), Vector3(170, 4, 120), Vector3(120, 2, 170), Vector3(50, 0, 150), Vector3(10, 0, 90)],
		"ramps": 1, "boosts": 4, "bumps": 0.0,
	})
	t.append({
		"id": "city", "name": "Neon Nights", "theme": "city", "width": 17.0, "shoulder": 3.0,
		"desc": "Glowing city blocks and tight street corners.",
		"points": [Vector3(0, 0, 0), Vector3(0, 0, -140), Vector3(20, 0, -172), Vector3(80, 0, -172), Vector3(102, 0, -140), Vector3(102, 0, -92), Vector3(130, 0, -62), Vector3(190, 0, -62), Vector3(212, 0, -30), Vector3(212, 0, 60), Vector3(182, 0, 92), Vector3(125, 0, 92), Vector3(92, 0, 62), Vector3(60, 0, 95), Vector3(22, 0, 95), Vector3(0, 0, 60)],
		"ramps": 0, "boosts": 5, "bumps": 0.0,
	})
	t.append({
		"id": "lava", "name": "Lava Foundry", "theme": "lava", "width": 16.0, "shoulder": 3.0,
		"desc": "Raised roads over molten lava. Don't fall in!",
		"points": [Vector3(0, 3, 60), Vector3(0, 3, -40), Vector3(-20, 5, -100), Vector3(-80, 7, -122), Vector3(-130, 7, -80), Vector3(-120, 5, -20), Vector3(-150, 3, 30), Vector3(-130, 5, 90), Vector3(-80, 9, 125), Vector3(-20, 11, 150), Vector3(30, 9, 150), Vector3(45, 6, 110), Vector3(20, 4, 85)],
		"ramps": 2, "boosts": 3, "bumps": 0.0,
	})
	t.append({
		"id": "mud", "name": "Monster Mud Pit", "theme": "mud", "width": 22.0, "shoulder": 6.0,
		"desc": "Bumps, mud and huge ramps. Monster trucks rule here.",
		"points": [Vector3(0, 0, 0), Vector3(0, 0, -100), Vector3(30, 3, -150), Vector3(100, 0, -165), Vector3(150, 4, -110), Vector3(140, 0, -40), Vector3(170, 5, 20), Vector3(150, 0, 90), Vector3(80, 3, 112), Vector3(30, 0, 80)],
		"ramps": 4, "boosts": 2, "bumps": 1.1,
	})
	return t


static func theme(name: String) -> Dictionary:
	match name:
		"desert":
			return {
				"sky_top": Color("#3d8ee0"), "sky_horizon": Color("#f6d7a0"), "ground": Color("#e4c27a"),
				"shoulder": Color("#d6a95a"), "road": Color("#8a7a6a"), "skirt": Color("#c98c4a"),
				"walls": [Color("#c91a09"), Color("#f4f4f4")], "sun": Color("#fff1d0"), "sun_energy": 1.25,
				"fog": Color("#f2dcb0"), "fog_density": 0.002, "night": false, "ground_kind": "offroad",
				"decor": ["cactus", "cactus", "rock", "pyramid", "palm"], "hill": Color("#d89a52"),
			}
		"snow":
			return {
				"sky_top": Color("#6fa8dc"), "sky_horizon": Color("#e8f1ff"), "ground": Color("#f2f6ff"),
				"shoulder": Color("#cfe0f5"), "road": Color("#6f7a8a"), "skirt": Color("#8aa4c2"),
				"walls": [Color("#0055bf"), Color("#f4f4f4")], "sun": Color("#ffffff"), "sun_energy": 1.05,
				"fog": Color("#e6eefa"), "fog_density": 0.003, "night": false, "ground_kind": "offroad",
				"decor": ["pine", "pine", "pine", "snowman", "rock"], "hill": Color("#e8eef8"),
			}
		"city":
			return {
				"sky_top": Color("#0b0b2a"), "sky_horizon": Color("#4a1e6a"), "ground": Color("#2a2d38"),
				"shoulder": Color("#3a3f4c"), "road": Color("#33363f"), "skirt": Color("#24262e"),
				"walls": [Color("#ff2bd6"), Color("#1b2a34"), Color("#2be0ff"), Color("#1b2a34")],
				"sun": Color("#9aa8ff"), "sun_energy": 0.45, "fog": Color("#2a1840"), "fog_density": 0.004,
				"night": true, "ground_kind": "offroad", "decor": ["building", "building", "building", "lamp"],
				"hill": Color("#1b1d26"),
			}
		"lava":
			return {
				"sky_top": Color("#1a0505"), "sky_horizon": Color("#a8320f"), "ground": Color("#ff5a00"),
				"shoulder": Color("#3a2a26"), "road": Color("#3d3836"), "skirt": Color("#2a201e"),
				"walls": [Color("#1b2a34"), Color("#f2cd37")], "sun": Color("#ffb080"), "sun_energy": 0.7,
				"fog": Color("#5a1a08"), "fog_density": 0.004, "night": true, "ground_kind": "hazard",
				"ground_y": -3.0, "decor": ["rock", "rock", "volcano_rock", "lava_tower"], "hill": Color("#2a1a16"),
			}
		"mud":
			return {
				"sky_top": Color("#4f86c6"), "sky_horizon": Color("#d8d0b8"), "ground": Color("#6b4a2a"),
				"shoulder": Color("#8d6a40"), "road": Color("#5e4a38"), "skirt": Color("#5a3d22"),
				"walls": [Color("#f2cd37"), Color("#1b2a34")], "sun": Color("#fff3dc"), "sun_energy": 1.15,
				"fog": Color("#cfc4a8"), "fog_density": 0.0025, "night": false, "ground_kind": "offroad",
				"decor": ["tire_stack", "wreck", "rock", "tree"], "hill": Color("#6b5a3a"),
			}
	return {
		"sky_top": Color("#3b8fe8"), "sky_horizon": Color("#cfe8ff"), "ground": Color("#4b9f4a"),
		"shoulder": Color("#6ab04c"), "road": Color("#7a7f88"), "skirt": Color("#8a6a48"),
		"walls": [Color("#c91a09"), Color("#f4f4f4")], "sun": Color("#fff6e0"), "sun_energy": 1.2,
		"fog": Color("#d6ecff"), "fog_density": 0.0018, "night": false, "ground_kind": "offroad",
		"decor": ["tree", "tree", "flower", "bush", "tree"], "hill": Color("#3f8f3e"),
	}
