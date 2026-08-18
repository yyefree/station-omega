class_name TexGen
extends RefCounted

static var _cache: Dictionary = {}
const _ROUGH_KINDS := ["steel", "polymer", "wood", "carbon", "gunmetal", "knurl", "plastic"]
const _SIZE := 512

static func mat(color: Color, kind: String, scale: float, rough: float,
		metallic := 0.0, triplanar := true) -> StandardMaterial3D:
	var entry: Dictionary = _cache.get(kind, {})
	if entry.is_empty():
		var img := _bake_albedo(kind)
		entry = {
			"albedo": ImageTexture.create_from_image(img),
			"normal": ImageTexture.create_from_image(_bake_normal(img, 2.2)),
		}
		if kind in _ROUGH_KINDS:
			entry["rough"] = ImageTexture.create_from_image(_bake_rough(img))
		_cache[kind] = entry
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = entry["albedo"]
	m.normal_enabled = true
	m.normal_texture = entry["normal"]
	m.roughness = rough
	m.metallic = metallic
	if entry.has("rough"):
		m.roughness_texture = entry["rough"]
	m.uv1_scale = Vector3(scale, scale, 1.0)
	if triplanar:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
	return m

static func _gen_noise(seed_i: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_i
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 5
	n.fractal_gain = 0.5
	return n

static func _bake_albedo(kind: String) -> Image:
	var size := _SIZE
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	match kind:
		"ground":
			var n := _gen_noise(11, 0.06)
			var n2 := _gen_noise(12, 0.018)
			var n3 := _gen_noise(13, 0.005)
			for y in size:
				for x in size:
					var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
					var b := (n2.get_noise_2d(x, y) + 1.0) * 0.5
					var wide := (n3.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.35 + v * 0.45 + (b - 0.5) * 0.2 + (wide - 0.5) * 0.15, 0.2, 0.95)
					var r := t * clampf(0.92 + wide * 0.16, 0.88, 1.08)
					var g := t * clampf(0.85 + b * 0.12, 0.82, 1.0)
					var bl := t * clampf(0.7 + v * 0.1, 0.68, 0.85)
					img.set_pixel(x, y, Color(r, g, bl, 1.0))
		"stone":
			var n := _gen_noise(21, 0.04)
			var n2 := _gen_noise(22, 0.012)
			var n3 := _gen_noise(23, 0.004)
			for y in size:
				for x in size:
					var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
					var b := (n2.get_noise_2d(x, y) + 1.0) * 0.5
					var wide := (n3.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.4 + v * 0.5 + (b - 0.5) * 0.3 + (wide - 0.5) * 0.2, 0.25, 0.95)
					var r := t * clampf(0.98 + wide * 0.08, 0.95, 1.08)
					var g := t * clampf(0.96 + b * 0.06, 0.93, 1.04)
					var bl := t * clampf(0.92 + v * 0.08, 0.88, 1.0)
					img.set_pixel(x, y, Color(r, g, bl, 1.0))
		"brick":
			var n := _gen_noise(31, 0.05)
			var n2 := _gen_noise(32, 0.016)
			for y in size:
				for x in size:
					var row := int(y / 64)
					var ox := 32 if row % 2 == 1 else 0
					var lx := (x + ox) % 64
					var ly := y % 64
					var mortar := lx < 4 or lx > 59 or ly < 4 or ly > 59
					if mortar:
						var mv := (n2.get_noise_2d(x, y) + 1.0) * 0.45
						var mg := 0.42 + mv * 0.15
						img.set_pixel(x, y, Color(mg, mg * 0.97, mg * 0.94, 1.0))
					else:
						var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
						var b := (n2.get_noise_2d(x, y) + 1.0) * 0.5
						var t := clampf(0.45 + v * 0.45 + (b - 0.5) * 0.25, 0.3, 0.9)
						var rv := t * clampf(1.02 + v * 0.08, 0.98, 1.12)
						var gv := t * clampf(0.88 + b * 0.06, 0.84, 0.96)
						var bv := t * clampf(0.78 + v * 0.06, 0.74, 0.88)
						img.set_pixel(x, y, Color(rv, gv, bv, 1.0))
		"wood":
			var wn := _gen_noise(41, 0.18)
			var wn2 := _gen_noise(42, 0.04)
			var wn3 := _gen_noise(43, 0.012)
			for y in size:
				for x in size:
					var seam := (x % 128) < 4 or (x % 128) > 123
					var g := (wn.get_noise_2d(x * 1.5, y * 4.0) + 1.0) * 0.5
					var k := (wn2.get_noise_2d(x * 3.0, y * 3.0) + 1.0) * 0.5
					var wide := (wn3.get_noise_2d(x, y) + 1.0) * 0.5
					var t := 0.38
					if not seam:
						t = clampf(0.42 + g * 0.35 + (k - 0.5) * 0.12 + (wide - 0.5) * 0.1, 0.3, 0.88)
					var r := t * clampf(1.05 + wide * 0.1, 1.0, 1.15)
					var gv := t * clampf(0.88 + g * 0.08, 0.84, 0.98)
					var bv := t * clampf(0.72 + k * 0.06, 0.68, 0.82)
					img.set_pixel(x, y, Color(r, gv, bv, 1.0))
			var rng_w := RandomNumberGenerator.new()
			rng_w.seed = 414
			for i in 12:
				var cx := rng_w.randi_range(32, size - 32)
				var cy := rng_w.randi_range(32, size - 32)
				var rad := rng_w.randi_range(6, 18)
				for dy in range(-rad, rad + 1):
					for dx in range(-rad, rad + 1):
						var d := sqrt(float(dx * dx + dy * dy))
						if d <= float(rad):
							var qx := cx + dx
							var qy := cy + dy
							if qx >= 0 and qx < size and qy >= 0 and qy < size:
								var blend := 1.0 - d / float(rad)
								var kv := 0.18 + sin(d * 2.8) * 0.1
								_blend_px(img, qx, qy, Color(kv * 1.1, kv * 0.85, kv * 0.6), blend * 0.6)
		"metal":
			var mn := _gen_noise(51, 0.1)
			var mn2 := _gen_noise(52, 0.025)
			for y in size:
				for x in size:
					var g := (mn.get_noise_2d(x * 0.6, y * 3.0) + 1.0) * 0.5
					var wide := (mn2.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.55 + g * 0.35 + (wide - 0.5) * 0.1, 0.35, 0.95)
					var r := t * clampf(0.98 + wide * 0.04, 0.96, 1.04)
					var gv := t * clampf(1.0 + g * 0.02, 0.98, 1.04)
					var bv := t * clampf(1.04 + wide * 0.04, 1.0, 1.1)
					img.set_pixel(x, y, Color(r, gv, bv, 1.0))
		"steel":
			var sn := _gen_noise(61, 0.14)
			var sn2 := _gen_noise(62, 0.018)
			for y in size:
				for x in size:
					var g := (sn.get_noise_2d(x * 0.4, y * 3.0) + 1.0) * 0.5
					var p := (sn2.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.65 + g * 0.28 + (p - 0.5) * 0.12, 0.4, 0.95)
					var r := t * clampf(1.0 + g * 0.03, 0.98, 1.05)
					var gv := t * clampf(1.0 + p * 0.02, 0.99, 1.04)
					var bv := t * clampf(1.02 + g * 0.03, 1.0, 1.08)
					img.set_pixel(x, y, Color(r, gv, bv, 1.0))
			var rng_s := RandomNumberGenerator.new()
			rng_s.seed = 613
			for i in 50:
				var sx := rng_s.randi_range(0, size - 1)
				var sy := rng_s.randi_range(0, size - 1)
				var ang := rng_s.randf_range(0.0, PI)
				var len_f := rng_s.randf_range(8.0, 48.0)
				var sdx := cos(ang)
				var sdy := sin(ang)
				var bright := rng_s.randf() > 0.45
				for k in int(len_f):
					var px := int(sx + sdx * k)
					var py := int(sy + sdy * k)
					if px >= 0 and px < size and py >= 0 and py < size:
						_blend_px(img, px, py, Color(0.95, 0.96, 0.98) if bright else Color(0.25, 0.26, 0.3), 0.5)
		"polymer":
			var pn := _gen_noise(71, 0.45)
			var pn2 := _gen_noise(72, 0.08)
			for y in size:
				for x in size:
					var g := (pn.get_noise_2d(x, y) + 1.0) * 0.5
					var wide := (pn2.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.55 + g * 0.3 + (wide - 0.5) * 0.08, 0.38, 0.95)
					img.set_pixel(x, y, Color(t * 0.98, t * 0.98, t, 1.0))
			var rng_p := RandomNumberGenerator.new()
			rng_p.seed = 712
			for i in 2200:
				var px := rng_p.randi_range(0, size - 1)
				var py := rng_p.randi_range(0, size - 1)
				_blend_px(img, px, py, Color(0.38, 0.38, 0.42), 0.35)
				if rng_p.randf() < 0.3:
					var gx := rng_p.randi_range(-1, 1)
					var gy := rng_p.randi_range(-1, 1)
					var qx := px + gx
					var qy := py + gy
					if qx >= 0 and qx < size and qy >= 0 and qy < size:
						_blend_px(img, qx, qy, Color(0.38, 0.38, 0.42), 0.25)
		"plastic":
			var ppn := _gen_noise(73, 0.35)
			var ppn2 := _gen_noise(74, 0.06)
			for y in size:
				for x in size:
					var g := (ppn.get_noise_2d(x, y) + 1.0) * 0.5
					var wide := (ppn2.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.5 + g * 0.28 + (wide - 0.5) * 0.08, 0.38, 0.92)
					img.set_pixel(x, y, Color(t * 0.99, t * 0.99, t * 1.01, 1.0))
			var rng_pl := RandomNumberGenerator.new()
			rng_pl.seed = 734
			for i in 1200:
				var px := rng_pl.randi_range(0, size - 1)
				var py := rng_pl.randi_range(0, size - 1)
				_blend_px(img, px, py, Color(0.36, 0.36, 0.4), 0.3)
		"carbon":
			var cn := _gen_noise(81, 0.25)
			var cn2 := _gen_noise(82, 0.04)
			for y in size:
				for x in size:
					var weave := ((x % 12) < 6) != ((y % 12) < 6)
					var g := (cn.get_noise_2d(x, y) + 1.0) * 0.5
					var wide := (cn2.get_noise_2d(x, y) + 1.0) * 0.5
					var t := 0.25 + g * 0.18 + (wide - 0.5) * 0.06
					if not weave:
						t = 0.42 + g * 0.2 + (wide - 0.5) * 0.06
					img.set_pixel(x, y, Color(t * 0.96, t * 0.97, t * 1.02, 1.0))
		"grass":
			var gn := _gen_noise(91, 0.08)
			var gn2 := _gen_noise(92, 0.022)
			var gn3 := _gen_noise(93, 0.006)
			for y in size:
				for x in size:
					var v := (gn.get_noise_2d(x, y) + 1.0) * 0.5
					var b := (gn2.get_noise_2d(x, y) + 1.0) * 0.5
					var wide := (gn3.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.35 + v * 0.45 + (b - 0.5) * 0.18 + (wide - 0.5) * 0.12, 0.22, 0.88)
					var r := t * clampf(0.82 + wide * 0.12, 0.78, 0.98)
					var gv := t * clampf(1.02 + v * 0.08, 0.96, 1.12)
					var bv := t * clampf(0.72 + b * 0.08, 0.68, 0.85)
					img.set_pixel(x, y, Color(r, gv, bv, 1.0))
			var rng_g := RandomNumberGenerator.new()
			rng_g.seed = 913
			for i in 280:
				var gx := rng_g.randi_range(0, size - 1)
				var gy := rng_g.randi_range(0, size - 1)
				for k in 3:
					var qx := gx + rng_g.randi_range(-1, 1)
					var qy := gy + rng_g.randi_range(-1, 1)
					if qx >= 0 and qx < size and qy >= 0 and qy < size:
						_blend_px(img, qx, qy, Color(0.6, 0.78, 0.42), 0.35)
		"leaf":
			var ln := _gen_noise(101, 0.12)
			var ln2 := _gen_noise(102, 0.04)
			var ln3 := _gen_noise(103, 0.01)
			for y in size:
				for x in size:
					var v := (ln.get_noise_2d(x, y) + 1.0) * 0.5
					var b := (ln2.get_noise_2d(x * 2.0, y * 2.0) + 1.0) * 0.5
					var wide := (ln3.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.3 + v * 0.5 + (b - 0.5) * 0.25 + (wide - 0.5) * 0.1, 0.2, 0.85)
					var r := t * clampf(0.78 + wide * 0.12, 0.72, 0.92)
					var gv := t * clampf(1.08 + v * 0.08, 1.0, 1.2)
					var bv := t * clampf(0.65 + b * 0.08, 0.58, 0.78)
					img.set_pixel(x, y, Color(r, gv, bv, 1.0))
			var rng_l := RandomNumberGenerator.new()
			rng_l.seed = 1013
			for i in 180:
				var lx := rng_l.randi_range(12, size - 13)
				var ly := rng_l.randi_range(12, size - 13)
				var rad := rng_l.randi_range(5, 12)
				for dy in range(-rad, rad + 1):
					for dx in range(-rad, rad + 1):
						if sqrt(float(dx * dx + dy * dy)) <= float(rad):
							var qx := lx + dx
							var qy := ly + dy
							if qx >= 0 and qx < size and qy >= 0 and qy < size:
								_blend_px(img, qx, qy, Color(0.72, 0.92, 0.55), 0.4)
		"vine":
			var vn := _gen_noise(111, 0.05)
			var vn2 := _gen_noise(112, 0.015)
			for y in size:
				for x in size:
					var streak := (x % 32) < 5
					var v := (vn.get_noise_2d(x, y * 3.0) + 1.0) * 0.5
					var b := (vn2.get_noise_2d(x, y) + 1.0) * 0.5
					if streak:
						var sv := 0.28 + v * 0.15
						img.set_pixel(x, y, Color(sv * 0.85, sv * 1.1, sv * 0.7, 1.0))
					else:
						var t := clampf(0.38 + v * 0.35 + (b - 0.5) * 0.2, 0.25, 0.8)
						img.set_pixel(x, y, Color(t * 0.82, t * 1.05, t * 0.65, 1.0))
		"gunmetal":
			var gn := _gen_noise(121, 0.12)
			var gn2 := _gen_noise(122, 0.03)
			var gn3 := _gen_noise(123, 0.008)
			for y in size:
				for x in size:
					var g := (gn.get_noise_2d(x * 0.5, y * 2.5) + 1.0) * 0.5
					var p := (gn2.get_noise_2d(x, y) + 1.0) * 0.5
					var wide := (gn3.get_noise_2d(x, y) + 1.0) * 0.5
					var t := clampf(0.38 + g * 0.25 + (p - 0.5) * 0.1 + (wide - 0.5) * 0.06, 0.25, 0.78)
					var r := t * clampf(0.96 + wide * 0.06, 0.93, 1.04)
					var gv := t * clampf(0.98 + g * 0.04, 0.95, 1.06)
					var bv := t * clampf(1.04 + p * 0.04, 1.0, 1.12)
					img.set_pixel(x, y, Color(r, gv, bv, 1.0))
			var rng_gm := RandomNumberGenerator.new()
			rng_gm.seed = 1213
			for i in 36:
				var sx := rng_gm.randi_range(0, size - 1)
				var sy := rng_gm.randi_range(0, size - 1)
				var ang := rng_gm.randf_range(0.0, PI)
				var len_f := rng_gm.randf_range(10.0, 40.0)
				for k in int(len_f):
					var px := int(sx + cos(ang) * k)
					var py := int(sy + sin(ang) * k)
					if px >= 0 and px < size and py >= 0 and py < size:
						_blend_px(img, px, py, Color(0.6, 0.62, 0.68) if rng_gm.randf() > 0.5 else Color(0.18, 0.19, 0.22), 0.45)
		"knurl":
			for y in size:
				for x in size:
					var d1 := (x + y) % 16
					var d2 := (x - y + size) % 16
					var edge1 := d1 < 1 or d1 > 14
					var edge2 := d2 < 1 or d2 > 14
					var n_val := ((_gen_noise(131, 0.3).get_noise_2d(x, y) + 1.0) * 0.5) * 0.06
					if edge1 or edge2:
						var t := 0.52 + n_val
						img.set_pixel(x, y, Color(t, t * 0.99, t * 1.01, 1.0))
					elif (d1 < 4 or d1 > 11) and (d2 < 4 or d2 > 11):
						var t := 0.38 + n_val
						img.set_pixel(x, y, Color(t, t * 0.99, t * 1.01, 1.0))
					else:
						var t := 0.28 + n_val
						img.set_pixel(x, y, Color(t, t * 0.99, t * 1.01, 1.0))
	return img

static func _blend_px(img: Image, x: int, y: int, c: Color, k: float) -> void:
	var prev := img.get_pixel(x, y)
	img.set_pixel(x, y, prev.lerp(c, k))

static func _bake_rough(img: Image, strength := 2.0) -> Image:
	var size := img.get_width()
	var out := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var hl := img.get_pixel((x - 1 + size) % size, y).get_luminance()
			var hr := img.get_pixel((x + 1) % size, y).get_luminance()
			var hb := img.get_pixel(x, (y - 1 + size) % size).get_luminance()
			var ht := img.get_pixel(x, (y + 1) % size).get_luminance()
			var g := absf(hr - hl) + absf(ht - hb)
			var r := clampf(0.5 + g * strength, 0.15, 1.0)
			out.set_pixel(x, y, Color(r, r, r, 1.0))
	return out

static func _bake_normal(img: Image, strength := 2.2) -> Image:
	var size := img.get_width()
	var out := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var hl := img.get_pixel((x - 1 + size) % size, y).get_luminance()
			var hr := img.get_pixel((x + 1) % size, y).get_luminance()
			var hb := img.get_pixel(x, (y - 1 + size) % size).get_luminance()
			var ht := img.get_pixel(x, (y + 1) % size).get_luminance()
			var gx := (hr - hl) * strength
			var gy := (ht - hb) * strength
			var n := Vector3(-gx, -gy, 1.0).normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return out
