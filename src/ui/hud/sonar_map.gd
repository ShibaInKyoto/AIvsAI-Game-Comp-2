class_name SonarMap
extends Control
## Chart of the zone that fills in wherever sonar pings reach. Shown small in
## the HUD corner; Tab enlarges it. Drawn from a 1 px-per-meter image of the
## terrain field masked by a reveal image.

const SHADER := """
shader_type canvas_item;
uniform sampler2D terrain_tex : filter_linear;
uniform sampler2D reveal_tex : filter_linear;
uniform vec4 water_color : source_color = vec4(0.1, 0.6, 0.7, 0.85);
uniform vec4 rock_color : source_color = vec4(0.02, 0.06, 0.08, 0.6);
void fragment() {
	float open = texture(terrain_tex, UV).r;
	float seen = texture(reveal_tex, UV).r;
	float edge = smoothstep(0.35, 0.5, open) * (1.0 - smoothstep(0.5, 0.65, open));
	vec4 c = mix(rock_color, water_color, smoothstep(0.45, 0.55, open));
	c.rgb += vec3(0.4, 1.0, 1.0) * edge * 0.8;
	c.a *= seen;
	COLOR = c;
}
"""

var level: Level
var sub: Submarine
var expanded := false

var _terrain_img: Image
var _reveal_img: Image
var _reveal_tex: ImageTexture
var _mat: ShaderMaterial
var _size_m := Vector2.ONE
var _marks: Array[Dictionary] = []
var _map_rect: TextureRect
var _overlay: Control


func _ready() -> void:
	_map_rect = TextureRect.new()
	_map_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_rect)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_marks)
	add_child(_overlay)


func bind(p_level: Level, p_sub: Submarine) -> void:
	level = p_level
	sub = p_sub
	_size_m = level.size()
	var w := maxi(int(_size_m.x), 8)
	var h := maxi(int(_size_m.y), 8)
	_terrain_img = Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var v := level.field.sample(Vector2(x + 0.5, -(y + 0.5)))
			_terrain_img.set_pixel(x, y, Color.from_hsv(0, 0, clampf(0.5 + v * 0.25, 0.0, 1.0)))
	_reveal_img = Image.create(w, h, false, Image.FORMAT_L8)
	_reveal_img.fill(Color.BLACK)
	_reveal_tex = ImageTexture.create_from_image(_reveal_img)
	_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	_mat.shader = shader
	_mat.set_shader_parameter(&"terrain_tex", ImageTexture.create_from_image(_terrain_img))
	_mat.set_shader_parameter(&"reveal_tex", _reveal_tex)
	_map_rect.texture = _reveal_tex
	_map_rect.material = _mat
	_marks.clear()
	# The entry chamber is always known.
	reveal(level.layout.start, 14.0)
	if not Events.sonar_pinged.is_connected(_on_ping):
		Events.sonar_pinged.connect(_on_ping)


func _on_ping(origin: Vector2, ping_range: float) -> void:
	reveal(origin, ping_range)
	for e in level.entities:
		if e.alive and e.pos.distance_to(origin) < ping_range:
			if e is SalvageCache:
				_marks.append({"pos": e.pos, "color": UiTheme.WARN, "node": e})
			elif e is LogBeacon:
				_marks.append({"pos": e.pos, "color": UiTheme.GOOD, "node": e})


## Marks a circle of the chart as charted.
func reveal(center: Vector2, radius: float) -> void:
	if _reveal_img == null:
		return
	var w := _reveal_img.get_width()
	var h := _reveal_img.get_height()
	var cx := int(center.x)
	var cy := int(-center.y)
	var r := int(radius)
	for y in range(maxi(cy - r, 0), mini(cy + r + 1, h)):
		for x in range(maxi(cx - r, 0), mini(cx + r + 1, w)):
			var d := Vector2(x - cx, y - cy).length()
			if d <= radius:
				var a := clampf((radius - d) / 6.0, 0.0, 1.0)
				if a > _reveal_img.get_pixel(x, y).r:
					_reveal_img.set_pixel(x, y, Color(a, a, a))
	_reveal_tex.update(_reveal_img)


func _process(_delta: float) -> void:
	_overlay.queue_redraw()


func _draw() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.03, 0.05, 0.55)
	bg.border_color = Color(UiTheme.ACCENT, 0.35)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	draw_style_box(bg, Rect2(Vector2.ZERO, size).grow(4))


func _to_map(p: Vector2) -> Vector2:
	return Vector2(p.x / _size_m.x * size.x, -p.y / _size_m.y * size.y)


func _draw_marks() -> void:
	if level == null:
		return
	for m in _marks:
		if is_instance_valid(m.node) and (m.node as Entity).alive:
			_overlay.draw_circle(_to_map(m.pos), 3.0, m.color)
	if level.exit_known or sub.stats.always_compass:
		_overlay.draw_arc(_to_map(level.layout.exit), 5.0, 0, TAU, 16, UiTheme.GOOD, 2.0)
	if sub:
		var p := _to_map(sub.pos)
		_overlay.draw_circle(p, 3.5, Color.WHITE)
		_overlay.draw_line(p, p + sub.aim * 9.0, Color(1, 1, 1, 0.7), 1.5)
