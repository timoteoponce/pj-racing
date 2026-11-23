class_name Tex
extends RefCounted
## Procedurally generated textures (baseplate studs, road plates, curbs, checker, arrows).

static var _cache := {}


static func _img(w: int, h: int) -> Image:
	return Image.create(w, h, true, Image.FORMAT_RGBA8)


static func _finish(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A lego baseplate cell: flat color with one shaded stud. Tile with UV scale.
static func baseplate(c: Color) -> ImageTexture:
	var k := "bp" + c.to_html()
	if _cache.has(k):
		return _cache[k]
	var s := 32
	var img := _img(s, s)
	var center := Vector2(s * 0.5, s * 0.5)
	for y in s:
		for x in s:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := c
			var d := p.distance_to(center)
			var r := s * 0.3
			if d < r:
				var lit := (center - p).dot(Vector2(1, 1).normalized()) / r
				col = c.lightened(0.10 + 0.12 * lit)
			elif d < r + 2.0:
				var shade := (p - center).dot(Vector2(1, 1).normalized()) / r
				col = c.darkened(0.05 + 0.18 * clampf(shade, 0.0, 1.0))
			var edge := mini(mini(x, y), mini(s - 1 - x, s - 1 - y))
			if edge == 0:
				col = col.darkened(0.06)
			img.set_pixel(x, y, col)
	var t := _finish(img)
	_cache[k] = t
	return t


## Smooth road plate: base color with subtle tile seams and a dashed center line.
static func road(c: Color) -> ImageTexture:
	var k := "rd" + c.to_html()
	if _cache.has(k):
		return _cache[k]
	var w := 128
	var h := 128
	var img := _img(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in h:
		for x in w:
			var col := c.lightened(rng.randf_range(-0.02, 0.02))
			if y % 64 == 0 or x % 64 == 0:
				col = c.darkened(0.12)
			if absi(x - w / 2) <= 1 and (y % 64) < 30:
				col = Color("#f4f4f4")
			if x < 3 or x > w - 4:
				col = Color("#f4f4f4")
			img.set_pixel(x, y, col)
	var t := _finish(img)
	_cache[k] = t
	return t


static func stripes(a: Color, b: Color, n := 2) -> ImageTexture:
	var k := "st%s%s%d" % [a.to_html(), b.to_html(), n]
	if _cache.has(k):
		return _cache[k]
	var s := 64
	var img := _img(s, s)
	for y in s:
		for x in s:
			img.set_pixel(x, y, a if (y * n / s) % 2 == 0 else b)
	var t := _finish(img)
	_cache[k] = t
	return t


static func checker(n := 8) -> ImageTexture:
	var k := "ck%d" % n
	if _cache.has(k):
		return _cache[k]
	var s := 128
	var img := _img(s, s)
	for y in s:
		for x in s:
			var on := ((x * n / s) + (y * n / s)) % 2 == 0
			img.set_pixel(x, y, Color("#f4f4f4") if on else Color("#1b1b1b"))
	var t := _finish(img)
	_cache[k] = t
	return t


static func arrows() -> ImageTexture:
	if _cache.has("arrows"):
		return _cache["arrows"]
	var s := 64
	var img := _img(s, s)
	for y in s:
		for x in s:
			var col := Color("#ff8a00")
			var fx := absf(x - s * 0.5) / (s * 0.5)
			var fy := fposmod(float(y) / s * 2.0 + fx * 0.7, 1.0)
			if fy < 0.35:
				col = Color("#fff04a")
			img.set_pixel(x, y, col)
	var t := _finish(img)
	_cache["arrows"] = t
	return t


## Brick wall pattern for track skirts.
static func bricks(c: Color) -> ImageTexture:
	var k := "br" + c.to_html()
	if _cache.has(k):
		return _cache[k]
	var s := 64
	var img := _img(s, s)
	for y in s:
		for x in s:
			var row := y / 16
			var xo := (x + (16 if row % 2 == 1 else 0)) % 32
			var col := c
			if y % 16 == 0 or xo == 0:
				col = c.darkened(0.3)
			elif y % 16 == 1 or xo == 1:
				col = c.lightened(0.12)
			img.set_pixel(x, y, col)
	var t := _finish(img)
	_cache[k] = t
	return t


static func mat(tex: Texture2D, triplanar := false, scale := Vector3.ONE, emissive := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.9
	m.metallic_specular = 0.12
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_triplanar = triplanar
	m.uv1_world_triplanar = triplanar
	m.uv1_scale = scale
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = emissive
	return m
