class_name UI
extends RefCounted
## Shared look & feel: lego-yellow chunky buttons, rounded dark panels, big friendly font.

const YELLOW := Color("#f2cd37")
const RED := Color("#c91a09")
const BLUE := Color("#0055bf")
const GREEN := Color("#237841")
const DARK := Color("#1b2a34")
const ORANGE := Color("#fe8a18")

static var _theme: Theme
static var _font: SystemFont


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Fredoka", "Nunito", "Baloo 2", "Ubuntu", "Noto Sans", "DejaVu Sans", "sans-serif"])
		_font.font_weight = 800
		_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _font


static func box(bg: Color, radius := 14, border := 0, border_col := Color.TRANSPARENT, bottom := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	if bottom > 0:
		s.border_width_bottom = bottom
	s.border_color = border_col
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10 + bottom
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", box(YELLOW, 12, 0, YELLOW.darkened(0.3), 6))
	t.set_stylebox("hover", "Button", box(YELLOW.lightened(0.15), 12, 0, YELLOW.darkened(0.3), 6))
	t.set_stylebox("pressed", "Button", box(ORANGE, 12, 0, ORANGE.darkened(0.3), 2))
	t.set_stylebox("disabled", "Button", box(Color(0.5, 0.5, 0.5, 0.6), 12, 0, Color(0.3, 0.3, 0.3), 6))
	var focus := box(ORANGE, 12, 4, Color.WHITE, 6)
	focus.border_color = Color.WHITE
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "Button", box(ORANGE, 12, 0, ORANGE.darkened(0.3), 2))
	t.set_color("font_color", "Button", DARK)
	t.set_color("font_hover_color", "Button", DARK)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.2, 0.2, 0.2))
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", DARK)
	t.set_constant("outline_size", "Label", 0)
	var panel := box(Color(0.08, 0.11, 0.16, 0.88), 20, 3, Color(1, 1, 1, 0.12))
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 20
	panel.content_margin_bottom = 20
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = YELLOW
	fill.set_corner_radius_all(6)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_stylebox("slider", "HSlider", bg)
	_theme = t
	return t


## Button that gets a focused "selected" look (needed for gamepad navigation).
static func button(text: String, cb: Callable = Callable(), min_w := 320.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 58)
	b.focus_mode = Control.FOCUS_ALL
	if cb.is_valid():
		b.pressed.connect(func():
			Sfx.play("select")
			cb.call())
	wire_focus(b)
	return b


## Big chunky colored button (used for the main menu).
static func big_button(text: String, cb: Callable, col: Color, w := 460.0, h := 86.0, font_size := 34) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", font_size)
	b.set_meta("base_color", col)
	var fc := DARK if col.get_luminance() > 0.55 else Color.WHITE
	b.set_meta("font_color", fc)
	_apply_color(b, col, fc, false)
	b.pressed.connect(func():
		Sfx.play("select")
		cb.call())
	wire_focus(b)
	return b


static func _apply_color(b: Button, col: Color, fc: Color, focused: bool) -> void:
	var r := 18
	if focused:
		b.add_theme_stylebox_override("normal", box(col.lightened(0.15), r, 5, Color.WHITE, 9))
		b.add_theme_stylebox_override("hover", box(col.lightened(0.2), r, 5, Color.WHITE, 9))
	else:
		b.add_theme_stylebox_override("normal", box(col, r, 0, col.darkened(0.35), 9))
		b.add_theme_stylebox_override("hover", box(col.lightened(0.1), r, 0, col.darkened(0.35), 9))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.15), r, 0, col.darkened(0.4), 3))
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fc)


static func wire_focus(b: Control) -> void:
	b.focus_entered.connect(func():
		Sfx.play("click", 1.0, -6.0)
		if b is Button and b.has_meta("base_color"):
			_apply_color(b, b.get_meta("base_color"), b.get_meta("font_color"), true)
		elif b is Button:
			b.add_theme_stylebox_override("normal", box(ORANGE, 12, 4, Color.WHITE, 6))
			b.add_theme_stylebox_override("hover", box(ORANGE.lightened(0.1), 12, 4, Color.WHITE, 6))
			b.add_theme_color_override("font_color", Color.WHITE)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE * 1.05, 0.08))
	b.focus_exited.connect(func():
		if b is Button and b.has_meta("base_color"):
			_apply_color(b, b.get_meta("base_color"), b.get_meta("font_color"), false)
		elif b is Button:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_color_override("font_color")
			b.remove_theme_color_override("font_hover_color")
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.08))
	b.mouse_entered.connect(func():
		if b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus())


static func label(text: String, size := 22, col := Color.WHITE, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", DARK)
	return l


static func title(text: String, size := 64) -> Label:
	var l := label(text, size, YELLOW, maxi(8, size / 6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func center_box(parent: Control, w := 0.0) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	if w > 0.0:
		v.custom_minimum_size.x = w
	cc.add_child(v)
	return v


## Anchors a control to a point of its parent (ax, ay in 0..1) with a pixel rect offset from it.
static func pin(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h


static func ordinal(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "%dth" % n
	match n % 10:
		1: return "%dst" % n
		2: return "%dnd" % n
		3: return "%drd" % n
	return "%dth" % n


static func place_color(n: int) -> Color:
	match n:
		1: return Color("#ffd23d")
		2: return Color("#dfe6ee")
		3: return Color("#e0904a")
	return Color.WHITE


static func time_str(t: float) -> String:
	if t < 0.0:
		return "--:--.--"
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s]
