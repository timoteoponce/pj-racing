extends Screen
## BUILD YOUR CAR: pick a part category tab, then click part tiles to snap them onto your car.
## Locked parts can be previewed and bought with studs. Parts won in races show a NEW! sticker.

const UPGRADE_COST := 250
const TAB_NAMES := {
	"chassis": "Car Type", "body": "Body", "engine": "Engine", "wheels": "Wheels",
	"spoiler": "Wing", "paint": "Paint", "driver": "Driver", "extras": "Extras", "upgrades": "Power-Ups",
}

var slot := 0
var cat := "chassis"
var _show: CarShowcase
var _stats: StatStuds
var _name: Label
var _tabs := {}
var _grid: GridContainer
var _scroll: ScrollContainer
var _info: Label
var _slot_btns: Array[Button] = []
var _armed := ""
var _start_tab := "chassis"
var _reset_armed := false
var _reset_btn: Button


static func tabs() -> Array:
	var t := ["chassis", "body", "engine", "wheels", "spoiler", "paint", "driver", "extras"]
	if not Parts.FREE_MODE:
		t.append("upgrades")
	return t


func setup(p: Dictionary) -> void:
	slot = clampi(int(p.get("slot", 0)), 0, Save.BUILD_SLOTS - 1)
	_start_tab = p.get("tab", "chassis")


func build() -> void:
	backdrop_colors = [Color("#1d6b34"), Color("#0b3a1c")]
	Sfx.music("menu")
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ---- left: the car
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.05
	root.add_child(left)
	_show = CarShowcase.new()
	_show.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show.cam_dist = 7.5
	_show.bg_top = Color("#4fb3ff")
	left.add_child(_show)
	var title := UI.title("BUILD YOUR CAR", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UI.pin(title, 0, 0, 24, 10, 600, 60)
	left.add_child(title)
	if not Parts.FREE_MODE:
		var studs := StudCounter.new()
		UI.pin(studs, 0, 0, 26, 76, 230, 50)
		left.add_child(studs)
	var card := PanelContainer.new()
	UI.pin(card, 0, 1, 20, -262, 430, 244)
	left.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)
	_name = UI.label("", 30, UI.YELLOW, 8)
	cv.add_child(_name)
	_stats = StatStuds.new()
	cv.add_child(_stats)

	# ---- right: parts
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(right)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	right.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(UI.label("My cars:", 20))
	for i in Save.BUILD_SLOTS:
		var b := UI.big_button(str(i + 1), func(): _select_slot(i), Color("#5b6b7a"), 54, 50, 24)
		top.add_child(b)
		_slot_btns.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(UI.big_button("New Name", _rename, Color("#ff79c6"), 150, 50, 20))

	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 8)
	tabs.add_theme_constant_override("v_separation", 8)
	v.add_child(tabs)
	for t in tabs():
		var b := UI.big_button(TAB_NAMES[t], func(): _select_tab(t, true), Color("#3a4a5a"), 128, 50, 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		_tabs[t] = b

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	v.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)

	_info = UI.label("", 18, Color.WHITE, 5)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(400, 50)
	v.add_child(_info)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	v.add_child(bottom)
	var surprise := UI.big_button("Surprise Me!", _surprise, Color("#9b4dff"), 180, 60, 22)
	surprise.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(surprise)
	_reset_btn = UI.big_button("Start Over", _start_over, Color("#d85a2a"), 150, 60, 22)
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_reset_btn)
	var done := UI.big_button("Done", on_back, UI.YELLOW, 120, 60, 22)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(done)

	_select_slot(slot)
	_select_tab(_start_tab, _start_tab != "chassis")
	if _start_tab == "chassis":
		focus_first(_tabs["chassis"])


# ------------------------------------------------------------------ actions

func _saved() -> Dictionary:
	return Save.get_build(slot)


func _select_slot(i: int) -> void:
	slot = i
	for k in _slot_btns.size():
		var b := _slot_btns[k]
		b.set_meta("base_color", UI.YELLOW if k == i else Color("#5b6b7a"))
		b.set_meta("font_color", UI.DARK if k == i else Color.WHITE)
		UI._apply_color(b, b.get_meta("base_color"), b.get_meta("font_color"), b.has_focus())
	_show.set_build(_saved(), true)
	_refresh_car()
	_fill_grid()


func _select_tab(t: String, focus_grid: bool) -> void:
	cat = t
	_armed = ""
	for k in _tabs:
		var b: Button = _tabs[k]
		b.set_meta("base_color", Color("#2fae4a") if k == t else Color("#3a4a5a"))
		UI._apply_color(b, b.get_meta("base_color"), Color.WHITE, b.has_focus())
	_fill_grid()
	if focus_grid:
		call_deferred("_focus_first_tile")


func _focus_first_tile() -> void:
	for c in _grid.get_children():
		if not c.is_queued_for_deletion():
			(c as Control).grab_focus()
			return


func _fill_grid() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	if cat == "upgrades":
		for k in Parts.UPGRADES:
			var tile := PartTile.new()
			tile.garage = self
			tile.upgrade = k
			_grid.add_child(tile)
		_info.text = "Power-Ups make ALL your cars better!"
		return
	for id in Parts.by_cat[cat]:
		var tile := PartTile.new()
		tile.garage = self
		tile.part_id = id
		_grid.add_child(tile)
	if cat == Parts.EXTRAS:
		_info.text = "Add as many extras as you like! Press again to take one off."
	else:
		_info.text = "Pick a part to snap it onto your car!"


func _refresh_car() -> void:
	var b := _saved()
	_name.text = b["name"]
	_stats.show_build(b)
	if _grid:
		for t in _grid.get_children():
			t.queue_redraw()


func preview(tile: PartTile) -> void:
	if tile.upgrade != "":
		var u: Dictionary = Parts.UPGRADES[tile.upgrade]
		var lvl := int(Save.upgrades().get(tile.upgrade, 0))
		_info.text = "%s makes the %s of ALL your cars better.  Level %d of %d." % [u["name"], Parts.STAT_NAMES[tile.upgrade], lvl, u["max"]]
		return
	var id := tile.part_id
	var p := Parts.get_part(id)
	var b := _saved().duplicate(true)
	if cat == Parts.EXTRAS:
		var ex: Array = Parts.extras_of(b)
		var on := id in ex
		if on:
			ex.erase(id)
		else:
			ex.append(id)
		b[Parts.EXTRAS] = ex
		# preview: show the car WITH the extra so you can see it
		_show.set_build(b if not on else _saved())
		_stats.show_build(b, _saved())
		_info.text = "%s  -  %s" % [p["name"], "on your car! Press to take it off." if on else "press to add it!"]
		return
	b[cat] = id
	_show.set_build(b)
	_stats.show_build(b, _saved())
	if Save.is_new(id):
		Save.mark_seen(id)
		Save.save_game()
	if Save.is_unlocked(id):
		_info.text = "%s  -  %s" % [p["name"], "on your car!" if _saved()[cat] == id else "press to put it on!"]
	else:
		var need: int = int(p["price"]) - Save.studs()
		if need > 0:
			_info.text = "%s is locked. Win races to unlock it, or save up %d more studs!" % [p["name"], need]
		else:
			_info.text = "%s is locked. Press to buy it for %d studs!" % [p["name"], p["price"]]


func activate(tile: PartTile) -> void:
	if tile.upgrade != "":
		_buy_upgrade(tile)
		return
	var id := tile.part_id
	var p := Parts.get_part(id)
	if cat == Parts.EXTRAS:
		_toggle_extra(id)
		tile.garage.preview(tile)
		return
	if Save.is_unlocked(id):
		var b := _saved()
		if b[cat] == id:
			Sfx.play("click")
			return
		b[cat] = id
		Save.set_build(slot, b)
		_snap(b)
		_info.text = "Snap! %s is on your car." % p["name"]
		return
	if Save.studs() < int(p["price"]):
		Sfx.play("denied")
		_info.text = "Not enough studs yet. Win races to earn more!"
		return
	if _armed != id:
		_armed = id
		Sfx.play("click", 1.4)
		_info.text = "Buy %s for %d studs? Press again to buy!" % [p["name"], p["price"]]
		return
	_armed = ""
	if Save.spend(p["price"]):
		Save.unlock(id)
		Save.mark_seen(id)
		var b := _saved()
		b[cat] = id
		Save.set_build(slot, b)
		Sfx.play("reward")
		_snap(b)
		_info.text = "You bought %s! It's on your car." % p["name"]


func _toggle_extra(id: String) -> void:
	var b := _saved()
	var ex: Array = Parts.extras_of(b).duplicate()
	var p := Parts.get_part(id)
	if id in ex:
		ex.erase(id)
		b[Parts.EXTRAS] = ex
		Save.set_build(slot, b)
		Sfx.play("back")
		_show.set_build(b, true)
		_refresh_car()
		_info.text = "%s taken off." % p["name"]
		return
	if ex.size() >= Parts.MAX_EXTRAS:
		Sfx.play("denied")
		_info.text = "That's a lot of extras! Take one off first (max %d)." % Parts.MAX_EXTRAS
		return
	ex.append(id)
	b[Parts.EXTRAS] = ex
	Save.set_build(slot, b)
	_snap(b)
	_info.text = "Snap! %s added." % p["name"]


func _start_over() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Sure? Press again"
		_info.text = "Start Over puts this car back to the basic frame (it keeps its name and paint)."
		Sfx.play("click", 1.4)
		return
	_reset_armed = false
	_reset_btn.text = "Start Over"
	var old := _saved()
	var b := Parts.base_build(old.get("paint", "pt_red"))
	b["name"] = old.get("name", "My Car")
	Save.set_build(slot, b)
	Sfx.play("pop")
	_snap(b)
	_info.text = "Back to the basic frame. Now build something awesome!"


func _buy_upgrade(tile: PartTile) -> void:
	var k := tile.upgrade
	var lvl := int(Save.upgrades().get(k, 0))
	var u: Dictionary = Parts.UPGRADES[k]
	if lvl >= int(u["max"]):
		Sfx.play("denied")
		_info.text = "%s is already maxed out!" % u["name"]
		return
	var cost := UPGRADE_COST * (lvl + 1)
	if Save.studs() < cost:
		Sfx.play("denied")
		_info.text = "You need %d more studs. Win races to earn more!" % (cost - Save.studs())
		return
	if _armed != k:
		_armed = k
		Sfx.play("click", 1.4)
		_info.text = "Buy %s level %d for %d studs? Press again!" % [u["name"], lvl + 1, cost]
		return
	_armed = ""
	Save.spend(cost)
	Save.upgrades()[k] = lvl + 1
	Save.save_game()
	Sfx.play("reward")
	_snap(_saved())
	_info.text = "%s is now level %d!" % [u["name"], lvl + 1]


func _snap(b: Dictionary) -> void:
	_show.set_build(b, true)
	_show.burst([Parts.paint_color(b), UI.YELLOW, Color.WHITE, UI.RED])
	_refresh_car()


func _surprise() -> void:
	var b := _saved()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for c in Parts.CATEGORIES:
		var pool: Array = Parts.by_cat[c].filter(func(id): return Save.is_unlocked(id))
		b[c] = pool[rng.randi() % pool.size()]
	b[Parts.EXTRAS] = Parts.random_extras(rng)
	Save.set_build(slot, b)
	Sfx.play("reward")
	_snap(b)
	_info.text = "Ta-da! A brand new combo!"


func _rename() -> void:
	var b := _saved()
	var names: Array = Parts.FUN_NAMES.filter(func(n): return n != b["name"])
	b["name"] = names[randi() % names.size()]
	Save.set_build(slot, b)
	Sfx.play("pickup")
	_refresh_car()


func on_back() -> void:
	Save.save_game()
	Game.goto("title")


# ------------------------------------------------------------------ part tile

class PartTile:
	extends Button
	var garage: Node
	var part_id := ""
	var upgrade := ""
	var _focused := false
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(150, 118)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_mode = Control.FOCUS_ALL
		flat = true

	func _ready() -> void:
		focus_entered.connect(func():
			_focused = true
			Sfx.play("click", 1.1, -6.0)
			garage.preview(self)
			queue_redraw())
		focus_exited.connect(func():
			_focused = false
			queue_redraw())
		mouse_entered.connect(grab_focus)
		pressed.connect(func(): garage.activate(self))

	func _process(dt: float) -> void:
		_t += dt
		if _focused or (part_id != "" and Save.is_new(part_id)):
			queue_redraw()

	func _draw() -> void:
		var f := UI.font()
		var r := Rect2(Vector2.ZERO, size)
		var p := Parts.get_part(part_id) if part_id != "" else {}
		var unlocked := upgrade != "" or Save.is_unlocked(part_id)
		var equipped: bool = part_id != "" and (part_id in Parts.extras_of(garage._saved()) if p.get("cat", "") == Parts.EXTRAS else garage._saved().get(p.get("cat", ""), "") == part_id)
		var bg := Color("#24344a")
		if equipped:
			bg = Color("#1f7a3a")
		elif not unlocked:
			bg = Color("#2a2a30")
		var sb := UI.box(bg, 16, 0, Color.WHITE, 0)
		var rar: int = p.get("rarity", 1) if upgrade == "" else 2
		sb.border_width_bottom = 7
		sb.border_color = Parts.RARITY_COLORS[rar]
		if _focused:
			sb.set_border_width_all(5)
			sb.border_width_bottom = 8
			sb.border_color = Color.WHITE.lerp(UI.YELLOW, 0.5 + 0.5 * sin(_t * 8.0))
		draw_style_box(sb, r)
		var c := Vector2(size.x * 0.5, 38)
		if upgrade != "":
			_draw_upgrade_icon(c)
		elif p["cat"] == "paint":
			draw_circle(c + Vector2(-12, 2), 22, Color(0, 0, 0, 0.3))
			draw_circle(c + Vector2(-14, 0), 22, _key_color(p["pri"]))
			draw_circle(c + Vector2(16, 6), 14, _key_color(p["sec"]))
			draw_circle(c + Vector2(-20, -6), 7, Color(1, 1, 1, 0.35))
		else:
			_draw_brick(c, Parts.paint_color(garage._saved()) if unlocked else Color("#555a60"))
		var title: String = p.get("name", "") if upgrade == "" else Parts.UPGRADES[upgrade]["name"]
		_text(f, title, 84, 17, Color.WHITE)
		var status := ""
		var scol := Color(1, 1, 1, 0.75)
		if upgrade != "":
			var lvl := int(Save.upgrades().get(upgrade, 0))
			var mx := int(Parts.UPGRADES[upgrade]["max"])
			status = "MAX!" if lvl >= mx else "Lv %d  •  %d studs" % [lvl, 250 * (lvl + 1)]
			scol = UI.YELLOW
		elif equipped:
			status = "ON YOUR CAR"
			scol = Color("#9dffb0")
		elif not unlocked:
			status = "LOCKED  %d studs" % p["price"]
			scol = Color("#ffb0a0")
		else:
			status = _mods(p)
		_text(f, status, 106, 14, scol)
		if not unlocked:
			_draw_lock(Vector2(size.x - 22, 22))
		if part_id != "" and Save.is_new(part_id):
			var s := 1.0 + sin(_t * 7.0) * 0.08
			draw_set_transform(Vector2(30, 18), -0.3, Vector2(s, s))
			draw_style_box(UI.box(UI.RED, 10, 2, Color.WHITE), Rect2(-26, -12, 52, 24))
			draw_string(f, Vector2(-20, 6), "NEW!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
			draw_set_transform(Vector2.ZERO)

	func _text(f: Font, t: String, y: float, fs: int, col: Color) -> void:
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := maxf(6.0, (size.x - w) * 0.5)
		draw_string(f, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12, fs, col)

	static func _mods(p: Dictionary) -> String:
		if p["cat"] == "chassis":
			return {"kart": "Small & nimble", "car": "Fast racer", "monster": "BIG & strong"}.get(p.get("cls", ""), "")
		var out := []
		for k in p["stats"]:
			var v: int = p["stats"][k]
			out.append("%s%d %s" % ["+" if v > 0 else "", v, Parts.STAT_NAMES[k]])
		return "Just for looks" if out.is_empty() else ", ".join(out.slice(0, 2))

	static func _key_color(k: String) -> Color:
		match k:
			"gold":
				return Color("#ffc832")
			"chrome":
				return Color("#d8dce2")
		return Color.html(k.substr(2))

	func _draw_brick(c: Vector2, col: Color) -> void:
		for i in 2:
			var sx := c.x - 15 + i * 30
			draw_rect(Rect2(sx - 9, c.y - 22, 18, 10), col.lightened(0.15))
		draw_style_box(UI.box(col, 6, 0, col.darkened(0.35), 5), Rect2(c + Vector2(-30, -14), Vector2(60, 32)))

	func _draw_lock(c: Vector2) -> void:
		draw_arc(c + Vector2(0, -4), 7, PI, TAU, 10, Color.WHITE, 3)
		draw_rect(Rect2(c + Vector2(-10, -3), Vector2(20, 15)), Color.WHITE)
		draw_circle(c + Vector2(0, 4), 2.5, Color("#2a2a30"))

	func _draw_upgrade_icon(c: Vector2) -> void:
		var lvl := int(Save.upgrades().get(upgrade, 0))
		var mx := int(Parts.UPGRADES[upgrade]["max"])
		for i in mx:
			var x := c.x - (mx - 1) * 12 + i * 24
			draw_circle(Vector2(x, c.y + 6), 10, Color(0, 0, 0, 0.3))
			draw_circle(Vector2(x, c.y + 4), 10, StatStuds.COLORS[upgrade] if i < lvl else Color(1, 1, 1, 0.15))
		Hud._flame(self, c + Vector2(0, -16), 9)
