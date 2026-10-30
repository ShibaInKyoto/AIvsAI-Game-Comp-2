class_name SubSkins
extends RefCounted
## Liveries for the submarines, all won from [Challenges]. A paint recolors
## any frame. A skin is made for one frame and changes more than the color:
## a pattern across the plating (stripes, camouflage, rust, scales...) and a
## finish (chrome, glowing seams, an oil-slick sheen).

const SIZE := 256

## One livery. Its id is the id of the challenge that wins it.
class Livery:
	var id: String
	var name: String
	## The frame a skin was made for; &"" for a paint, which fits any.
	var frame: StringName
	var color: Color
	var accent: Color
	## plates, stripes, tiger, hazard, camo, rust, scales, carbon or stars.
	var pattern: StringName
	## &"" (painted metal), chrome, glow, pulse (glow that breathes) or sheen.
	var finish: StringName
	var glow: Color

	func _init(i: String, n: String, f: StringName, c: Color, a := Color.BLACK, p := &"plates", fin := &"",
			g := Color(0.3, 0.9, 1.0)) -> void:
		id = i
		name = n
		frame = f
		color = c
		accent = a
		pattern = p
		finish = fin
		glow = g

	func is_paint() -> bool:
		return frame == &""

static var _all: Array[Livery] = []
## Pattern masks by pattern: R accent, G shading, B glow.
static var _masks: Dictionary[StringName, Image] = {}
static var _textures: Dictionary[String, Array] = {}
static var _sheen: ShaderMaterial


static func all() -> Array[Livery]:
	if _all.is_empty():
		_all = [
			# Paints, one for each of the first challenges.
			Livery.new("first_descent", "Signal Yellow", &"", Color(1.0, 0.85, 0.15)),
			Livery.new("twilight", "Coral", &"", Color(1.0, 0.45, 0.45)),
			Livery.new("midnight", "Abyss Blue", &"", Color(0.15, 0.35, 0.85)),
			Livery.new("vents", "Magma", &"", Color(0.95, 0.3, 0.05)),
			Livery.new("hadal", "Pearl", &"", Color(0.92, 0.9, 0.85)),
			Livery.new("answer", "Choir Violet", &"", Color(0.6, 0.3, 0.95)),
			Livery.new("naturalist", "Kelp", &"", Color(0.35, 0.6, 0.25)),
			Livery.new("codex", "Lumen Teal", &"", Color(0.2, 0.9, 0.8)),
			Livery.new("archivist", "Black Box Orange", &"", Color(1.0, 0.5, 0.0)),
			Livery.new("lights_out", "Lure Teal", &"", Color(0.15, 0.62, 0.6)),
			Livery.new("lullaby", "Bone", &"", Color(0.86, 0.82, 0.72)),
			Livery.new("hunter", "Stalker Grey", &"", Color(0.35, 0.37, 0.4)),
			Livery.new("hoarder", "Gold", &"", Color(0.95, 0.75, 0.25)),
			Livery.new("fleet", "Chrome", &"", Color(0.8, 0.82, 0.85)),
			Livery.new("pressure", "Crimson", &"", Color(0.75, 0.05, 0.12)),
			Livery.new("veteran", "Navy", &"", Color(0.12, 0.16, 0.35)),
			Livery.new("ambusher", "Ink", &"", Color(0.09, 0.1, 0.14)),
			# Skins, three for each frame.
			Livery.new("lantern_survey", "Survey Stripes", &"lantern", Color(0.92, 0.92, 0.88),
				Color(1.0, 0.42, 0.05), &"stripes"),
			Livery.new("lantern_biolume", "Biolume", &"lantern", Color(0.06, 0.1, 0.14), Color.BLACK, &"plates",
				&"pulse", Color(0.2, 1.0, 0.8)),
			Livery.new("lantern_brass", "Old Brass", &"lantern", Color(0.8, 0.58, 0.24), Color(0.45, 0.3, 0.12),
				&"rust", &"chrome"),
			Livery.new("mako_tiger", "Tiger Shark", &"mako", Color(0.45, 0.5, 0.55), Color(0.14, 0.16, 0.2), &"tiger"),
			Livery.new("mako_racer", "Race Livery", &"mako", Color(0.95, 0.95, 0.95), Color(0.85, 0.08, 0.12),
				&"stripes"),
			Livery.new("mako_carbon", "Carbon", &"mako", Color(0.13, 0.13, 0.14), Color(0.05, 0.05, 0.06), &"carbon",
				&"glow", Color(1.0, 0.15, 0.1)),
			Livery.new("bathysphere_rust", "Rust Bucket", &"bathysphere", Color(0.42, 0.36, 0.3),
				Color(0.62, 0.3, 0.1), &"rust"),
			Livery.new("bathysphere_hazard", "Pressure Test", &"bathysphere", Color(0.98, 0.76, 0.08),
				Color(0.06, 0.06, 0.07), &"hazard"),
			Livery.new("bathysphere_chrome", "Abyssal Chrome", &"bathysphere", Color(0.82, 0.85, 0.9), Color.BLACK,
				&"plates", &"chrome"),
			Livery.new("whisper_camo", "Night Camo", &"whisper", Color(0.14, 0.15, 0.2), Color(0.26, 0.28, 0.34),
				&"camo"),
			Livery.new("whisper_ghost", "Ghost", &"whisper", Color(0.82, 0.86, 0.92), Color(0.6, 0.66, 0.76), &"scales",
				&"sheen"),
			Livery.new("whisper_stars", "Starfield", &"whisper", Color(0.03, 0.03, 0.06), Color.BLACK, &"stars",
				&"glow", Color(0.75, 0.85, 1.0)),
		]
	return _all


static func find(id: String) -> Livery:
	for s in all():
		if s.id == id:
			return s
	return null


## The plain livery a frame leaves the yard in.
static func factory(frame_id: StringName) -> Livery:
	var f := Catalog.frame(frame_id)
	return Livery.new("", "Factory paint", frame_id, f.hull_color if f else Color(1.0, 0.6, 0.1))


## Albedo and glow textures for a skin's pattern in its colors.
static func textures(skin: Livery) -> Array[ImageTexture]:
	var key := "%s/%s/%s/%s" % [skin.pattern, skin.color.to_html(), skin.accent.to_html(), skin.glow.to_html()]
	if not _textures.has(key):
		var mask := _mask(skin.pattern)
		var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		var glow := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for y in SIZE:
			for x in SIZE:
				var m := mask.get_pixel(x, y)
				albedo.set_pixel(x, y, skin.color.lerp(skin.accent, m.r) * m.g)
				glow.set_pixel(x, y, skin.glow * m.b)
		albedo.generate_mipmaps()
		glow.generate_mipmaps()
		_textures[key] = [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(glow)]
	var out: Array[ImageTexture] = []
	out.assign(_textures[key])
	return out


## The oil-slick pass a sheen finish draws over the hull.
static func sheen() -> ShaderMaterial:
	if _sheen == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 hue = 0.5 + 0.5 * cos(6.2831 * (f * 1.3 + vec3(0.0, 0.33, 0.67)) + TIME * 0.4);
	ALBEDO = hue * f * 0.55;
}
"""
		_sheen = ShaderMaterial.new()
		_sheen.shader = shader
	return _sheen


static func _mask(pattern: StringName) -> Image:
	if _masks.has(pattern):
		return _masks[pattern]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var noise := _noise(pattern)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var stars := _stars(rng) if pattern == &"stars" else PackedFloat32Array()
	for y in SIZE:
		for x in SIZE:
			var seam := _seam(x, y)
			var shade := _plate_shade(x, y)
			var accent := 0.0
			var glow := 1.0 if seam else 0.0
			var n := noise.get_pixel(x, y).r if noise else 0.0
			match pattern:
				&"stripes":
					var band := y % SIZE
					accent = 1.0 if (band >= 100 and band < 128) or (band >= 134 and band < 140) else 0.0
				&"tiger":
					accent = 1.0 if sin(x * TAU / 64.0 + sin(y * TAU / SIZE) * 1.6 + n * 2.0) > 0.45 else 0.0
				&"hazard":
					accent = 1.0 if (x + y) % 64 < 32 else 0.0
				&"camo":
					accent = 1.0 if n > 0.56 else 0.0
					shade *= 0.72 if n < 0.36 else 1.0
				&"rust":
					accent = smoothstep(0.42, 0.68, n)
					shade *= 0.85 + 0.15 * n
				&"scales":
					accent = _scale_edge(x, y)
					shade *= 0.88 + 0.12 * (1.0 - accent)
				&"carbon":
					var weave := (x / 8 + y / 8) % 2 == 0
					var t := float(x % 8 if weave else y % 8) / 8.0
					shade = 0.65 + 0.35 * sin(t * PI)
					glow = 1.0 if seam and y % 64 < 2 else 0.0
				&"stars":
					glow = stars[y * SIZE + x]
			img.set_pixel(x, y, Color(accent, shade, glow))
	_masks[pattern] = img
	return img


static func _noise(pattern: StringName) -> Image:
	if not [&"camo", &"rust", &"tiger"].has(pattern):
		return null
	var fn := FastNoiseLite.new()
	fn.seed = 11
	fn.frequency = 0.02 if pattern == &"rust" else 0.014
	fn.fractal_octaves = 4 if pattern == &"rust" else 2
	var img := fn.get_seamless_image(SIZE, SIZE)
	img.convert(Image.FORMAT_RGB8)
	return img


## Plating seams, as on the factory hull (see [SubmarineModel]).
static func _seam(x: int, y: int) -> bool:
	var row := int(y / 64.0)
	return y % 64 < 2 or (x + row * 37) % 96 < 2


static func _plate_shade(x: int, y: int) -> float:
	if _seam(x, y):
		return 0.55
	var row := int(y / 64.0)
	var rx := (x + row * 37) % 96
	var c := 0.7 if (rx == 8 or rx == 88) and y % 64 % 12 == 6 else 1.0
	return c * (0.94 + 0.06 * sin(float(x) * 0.05 + float(y) * 0.11))


## A night sky: soft discs of light, wrapping round the edges.
static func _stars(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var sky := PackedFloat32Array()
	sky.resize(SIZE * SIZE)
	for _i in 70:
		var c := Vector2(rng.randf() * SIZE, rng.randf() * SIZE)
		var r := rng.randf_range(1.2, 2.6)
		var bright := rng.randf_range(0.5, 1.0)
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var p := Vector2(floorf(c.x) + dx, floorf(c.y) + dy)
				var d := p.distance_to(c)
				if d < r:
					var i := posmod(int(p.y), SIZE) * SIZE + posmod(int(p.x), SIZE)
					sky[i] = maxf(sky[i], bright * (1.0 - d / r))
	return sky


## 1 on the rim of each overlapping scale, 0 inside.
static func _scale_edge(x: int, y: int) -> float:
	var row := int(y / 16.0)
	var cx := (x + (8 if row % 2 == 1 else 0)) % 16 - 8
	var cy := y % 16
	var d := Vector2(cx, cy).length()
	return 1.0 if d > 9.0 and d < 11.0 else 0.0
