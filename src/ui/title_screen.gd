extends Screen
## Main menu: brick logo, rotating showcase of your garage cars, menu buttons.

var _show: CarShowcase
var _build_i := 0
var _t := 0.0


func build() -> void:
	Sfx.music("menu")
	Controls.clear_all()
	Controls.assign(0, "any")
	Game.demo = false
	_show = CarShowcase.new()
	_show.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show.cam_dist = 9.5
	_show.spin_speed = 0.35
	add_child(_show)
	_show.set_build(Save.get_build(0))
	# soft vignette on the left for readability
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.06, 0.12, 0.5)
	UI.pin(shade, 0, 0, 0, 0, 560, 4000)
	add_child(shade)

	var logo := BrickLogo.new()
	logo.text = "PJ-RACING"
	UI.pin(logo, 0.5, 0, -330, 22, 660, 130)
	add_child(logo)
	var sub := UI.label("BUILD IT  •  RACE IT  •  WIN IT!" if Parts.FREE_MODE else "BUILD IT  •  RACE IT  •  WIN NEW PARTS!", 22, Color.WHITE, 7)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.pin(sub, 0.5, 0, -400, 158, 800, 34)
	add_child(sub)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 18)
	UI.pin(menu, 0, 0.5, 50, -150, 470, 420)
	add_child(menu)
	var race := UI.big_button("RACE!", func(): Game.goto("arcade"), UI.YELLOW, 470, 96, 44)
	menu.add_child(race)
	var garage := UI.big_button("BUILD YOUR CAR", func(): Game.goto("garage"), Color("#2fae4a"), 470, 86, 32)
	menu.add_child(garage)
	menu.add_child(UI.big_button("RACE WITH FRIENDS", func(): Game.goto("versus"), Color("#2a7bd8"), 470, 76, 28))
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 10)
	menu.add_child(small)
	small.add_child(UI.big_button("Controls", func(): Game.goto("controls"), Color("#5b6b7a"), 150, 54, 20))
	small.add_child(UI.big_button("Settings", func(): Game.goto("settings"), Color("#5b6b7a"), 150, 54, 20))
	small.add_child(UI.big_button("Quit", func(): get_tree().quit(), Color("#5b6b7a"), 150, 54, 20))
	focus_first(race)

	# "new parts" badge next to the garage button
	var n_new: int = 0 if Parts.FREE_MODE else Save.data["new_parts"].size()
	if n_new > 0:
		var badge := Badge.new()
		badge.text = "%d NEW PART%s!" % [n_new, "S" if n_new > 1 else ""]
		badge.position = Vector2(330, -14)
		badge.size = Vector2(170, 40)
		garage.add_child(badge)

	if Parts.FREE_MODE:
		return
	var studs := StudCounter.new()
	UI.pin(studs, 1, 0, -250, 20, 230, 50)
	add_child(studs)

	var unlocked: int = Save.data["unlocked"].size()
	var info := UI.label("Lego parts collected: %d / %d" % [unlocked, Parts.parts.size()], 20, Color.WHITE, 6)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.pin(info, 1, 1, -620, -50, 600, 30)
	add_child(info)


func _process(dt: float) -> void:
	_t += dt
	if _t > 5.0:
		_t = 0.0
		_build_i = (_build_i + 1) % Save.BUILD_SLOTS
		_show.set_build(Save.get_build(_build_i), true)


func on_back() -> void:
	pass


## Logo where each letter sits on a colored lego brick.
class BrickLogo:
	extends Control
	var text := "PJ-RACING"
	var _t := 0.0
	const COLS := [Color("#c91a09"), Color("#f2cd37"), Color("#0055bf"), Color("#237841"), Color("#fe8a18")]

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var n := text.length()
		var gap := 8.0
		var w := (size.x - gap * (n - 1)) / n
		var h := size.y * 0.78
		var f := UI.font()
		for i in n:
			var ch := text[i]
			var bob := sin(_t * 3.0 + i * 0.6) * 6.0
			var x := i * (w + gap)
			var y := size.y - h + bob
			if ch == "-":
				draw_rect(Rect2(x + w * 0.15, y + h * 0.45, w * 0.7, h * 0.16), Color.WHITE)
				continue
			var c: Color = COLS[i % COLS.size()]
			var sb := StyleBoxFlat.new()
			sb.bg_color = c
			sb.set_corner_radius_all(8)
			sb.border_width_bottom = 8
			sb.border_color = c.darkened(0.35)
			draw_style_box(sb, Rect2(x, y, w, h))
			for s in 2:
				var sx := x + w * (0.27 + 0.46 * s)
				draw_rect(Rect2(sx - w * 0.15, y - h * 0.12, w * 0.3, h * 0.14), c.lightened(0.1))
				draw_rect(Rect2(sx - w * 0.15, y - h * 0.12, w * 0.3, h * 0.04), c.lightened(0.3))
			var fs := int(h * 0.78)
			var tw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2(x + (w - tw) * 0.5, y + h * 0.78)
			draw_string_outline(f, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color("#1b2a34"))
			draw_string(f, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)



## Pulsing "NEW!" sticker.
class Badge:
	extends Control
	var text := "NEW!"
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var s := 1.0 + sin(_t * 6.0) * 0.06
		draw_set_transform(size * 0.5, sin(_t * 3.0) * 0.08, Vector2(s, s))
		var r := Rect2(-size * 0.5, size)
		draw_style_box(UI.box(UI.RED, 20, 3, Color.WHITE), r)
		var f := UI.font()
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(f, Vector2(-tw * 0.5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
