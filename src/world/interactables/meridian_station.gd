class_name MeridianStation
extends Entity
## The ruins of Meridian Deep, the research station whose logs tell the
## story, settled on the floor of the final zone's station gallery (off the
## middle chamber) behind the playfield. Two habitat modules flank a domed hub; a few windows still have
## power. The trench grew rock over the escape lock. The mast beacon that
## drew the expedition down still pings: each ping charts the cave around
## it, marks what swims nearby and is loud enough to draw hunters. The first
## time the sub comes near, its arrival is announced and the survey earns
## research.

## How far behind the play plane the station stands.
const DEPTH := -7.0
const BEACON_PERIOD := 7.0
const BEACON_RANGE := 28.0
const ARRIVE_RANGE := 16.0
## The beacon only pings while the sub is this close.
const HEARING := 70.0
const SURVEY_RESEARCH := 10
const HULL := Color(0.78, 0.76, 0.68)
const BAND := Color(0.86, 0.42, 0.12)
const FRAME := Color(0.17, 0.19, 0.21)
const ROCK := Color(0.2, 0.18, 0.17)
const GLASS := Color(0.04, 0.05, 0.06)
const BEACON_COLOR := Color(0.4, 1.0, 0.6)

var greeted := false
var _t := 0.0
var _flicker := 1.0
var _flicker_timer := 0.0
var _mat: ShaderMaterial
var _warm: OmniLight3D
var _beacon_light: OmniLight3D
var _hum: AudioStreamPlayer3D


## The y of the floor straight below [param p] (which must be in open water),
## or -INF if there is rock at [param p] or no floor within [param max_drop].
static func floor_below(field: TerrainField, p: Vector2, max_drop := 30.0) -> float:
	if field.sample(p) <= 0.5:
		return -INF
	var q := p
	while p.y - q.y < max_drop:
		if field.sample(q) < 0.05:
			# The field is steep near rock: home in on the surface itself.
			var above := q.y + 0.25
			var below := q.y
			for _i in 6:
				var mid := (above + below) * 0.5
				if field.sample(Vector2(q.x, mid)) < 0.0:
					below = mid
				else:
					above = mid
			return (above + below) * 0.5
		q.y -= 0.25
	return -INF


func setup() -> void:
	radius = 0.0
	active_radius = 220.0
	var rig := Node3D.new()
	# The floor behind the play plane rises, so the rig sits a little higher.
	rig.position = Vector3(0.0, PropScatter.surface_offset(DEPTH) - 0.3, DEPTH)
	rig.rotation.z = 0.035
	add_child(rig)
	var body := MeshInstance3D.new()
	body.mesh = _build_mesh()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/fx/shaders/station.gdshader")
	_mat.set_shader_parameter(&"sediment_tint", level.biome.sediment_tint if level else Color(0.4, 0.38, 0.34))
	body.material_override = _mat
	rig.add_child(body)
	var name_plate := Label3D.new()
	name_plate.text = "MERIDIAN DEEP"
	name_plate.font = UiTheme.TITLE_FONT_FILE
	name_plate.font_size = 64
	name_plate.outline_size = 0
	name_plate.pixel_size = 0.0085
	name_plate.modulate = Color(0.1, 0.15, 0.24, 0.9)
	name_plate.shaded = true
	name_plate.position = Vector3(-6.2, 3.45, 1.53)
	rig.add_child(name_plate)
	_warm = OmniLight3D.new()
	_warm.light_color = Color(1.0, 0.75, 0.45)
	_warm.omni_range = 10.0
	_warm.light_energy = 0.8
	_warm.position = Vector3(-2.0, 3.2, 3.0)
	rig.add_child(_warm)
	var beacon := MeshInstance3D.new()
	beacon.mesh = MeshKit.sphere(0.28, 10, 6)
	beacon.material_override = MeshKit.emissive_material(BEACON_COLOR, 6.0)
	beacon.position = Vector3(0.6, 9.0, 0.0)
	rig.add_child(beacon)
	_beacon_light = OmniLight3D.new()
	_beacon_light.light_color = BEACON_COLOR
	_beacon_light.omni_range = 14.0
	_beacon_light.light_energy = 0.0
	_beacon_light.position = Vector3(0.6, 9.0, 1.5)
	rig.add_child(_beacon_light)
	# The failing power hums, and stutters with the lights.
	_hum = AudioStreamPlayer3D.new()
	var hum := Audio.get_stream(&"station_hum")
	if hum is AudioStreamOggVorbis:
		(hum as AudioStreamOggVorbis).loop = true
	_hum.stream = hum
	_hum.bus = &"SFX"
	_hum.unit_size = 8.0
	_hum.max_distance = 45.0
	_hum.volume_db = -10.0
	_hum.position = Vector3(0.0, 3.2, 1.0)
	rig.add_child(_hum)
	if hum:
		_hum.play()
	_t = BEACON_PERIOD - 1.5


## Where the beacon pings from, on the gameplay plane.
func beacon_pos() -> Vector2:
	return pos + Vector2(0.6, 9.0 + PropScatter.surface_offset(DEPTH))


func tick(delta: float) -> void:
	_t += delta
	if _t >= BEACON_PERIOD:
		_t -= BEACON_PERIOD
		_ping()
	# Each ping shows as a flash of the beacon and the sonar wave it sends.
	_beacon_light.light_energy = 3.0 * maxf(1.0 - _t * 1.5, 0.0)
	# The failing circuit stutters: long stretches lit, sudden drop-outs.
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		var out := level.rng.randf() < 0.3
		_flicker = level.rng.randf_range(0.0, 0.15) if out else level.rng.randf_range(0.9, 1.3)
		_flicker_timer = level.rng.randf_range(0.04, 0.16) if out else level.rng.randf_range(0.3, 2.2)
	_mat.set_shader_parameter(&"failing_energy", 1.6 * _flicker)
	_warm.light_energy = 0.55 + 0.35 * _flicker
	_hum.volume_db = -10.0 + linear_to_db(clampf(_flicker, 0.1, 1.0))
	var sub := level.player
	if not greeted and sub and sub.alive and sub.pos.distance_to(pos + Vector2(0.0, 3.0)) < ARRIVE_RANGE:
		_greet(sub)


func _ping() -> void:
	var at := beacon_pos()
	# Quiet while the Choir sings (its duel needs every ping slot for the
	# pilot's answers) and when nobody is near enough to hear it.
	var sub := level.player
	if level.boss and level.boss.active or sub == null or sub.pos.distance_to(at) > HEARING:
		return
	Audio.play_at(&"beacon_ping", at, -1.0, 0.02, 0.8)
	level.ping(at, BEACON_RANGE, 2.5)
	level.emit_noise(at, 12.0, self)


func _greet(sub: Submarine) -> void:
	greeted = true
	Events.banner.emit("MERIDIAN DEEP", "Its beacon is still pinging.")
	sub.run.research += SURVEY_RESEARCH
	sub.show_gain(SURVEY_RESEARCH, " research", UiTheme.ACCENT)
	Events.toast.emit("Station survey: +%d research" % SURVEY_RESEARCH, UiTheme.ACCENT)


## Uniformly coloured copy of [param mesh]; [param window] goes in alpha
## (1 = lit, 0.5 = failing, 0 = hull) for the station shader.
static func _part(mesh: Mesh, color: Color, window := 0.0) -> ArrayMesh:
	var c := Color(color, window)
	return MeshKit.painted(MeshKit.transformed(mesh, Transform3D.IDENTITY), func(_v: Vector3) -> Color: return c)


static func _cylinder(r: float, h: float, sides := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## The whole station but its lights, baked into one mesh.
func _build_mesh() -> ArrayMesh:
	var module := _part(MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.55), Vector2(0.05, 1.3),
		Vector2(0.11, 1.5), Vector2(0.89, 1.5), Vector2(0.95, 1.3), Vector2(1.0, 0.55)]), 7.5, 18, 12), HULL)
	var band := _part(MeshKit.lathe(PackedVector2Array([Vector2(0, 1.56), Vector2(1, 1.56)]), 0.35, 18, 1), BAND)
	var hub := _part(MeshKit.ball(2.2, 0.0, 18, 12), HULL)
	var collar := _part(MeshKit.lathe(PackedVector2Array([Vector2(0, 0.8), Vector2(1, 0.8)]), 0.4, 14, 1), BAND)
	var tube := _part(MeshKit.lathe(PackedVector2Array([Vector2(0, 0.7), Vector2(1, 0.7)]), 2.2, 12, 1), FRAME)
	var leg := _part(_cylinder(0.13, 9.0, 6), FRAME)
	var strut := _part(_box(Vector3(0.12, 0.12, 2.6)), FRAME)
	var mast := _part(_cylinder(0.09, 5.6, 6), FRAME)
	var spar := _part(_box(Vector3(1.6, 0.08, 0.08)), FRAME)
	var lock := _part(MeshKit.lathe(PackedVector2Array([Vector2(0, 0.95), Vector2(1, 0.8)]), 1.6, 14, 1), BAND)
	var growth := _part(MeshKit.ball(2.4, 0.0, 14, 10), ROCK)
	var lit := _part(_box(Vector3(0.5, 0.32, 0.08)), GLASS, 1.0)
	var failing := _part(_box(Vector3(0.5, 0.32, 0.08)), GLASS, 0.5)
	var dead := _part(_box(Vector3(0.5, 0.32, 0.08)), GLASS)
	var porthole := _part(_box(Vector3(0.7, 0.7, 0.08)), GLASS, 1.0)
	var parts: Array = []
	var left := Vector3(-6.2, 2.9, 0.0)
	var right := Vector3(6.1, 2.6, 0.0)
	var right_basis := Basis(Vector3.BACK, -0.07)
	parts.append([module, Transform3D(Basis(), left)])
	parts.append([module, Transform3D(right_basis, right)])
	for dx: float in [-2.9, 2.9]:
		parts.append([band, Transform3D(Basis(), left + Vector3(dx, 0, 0))])
		parts.append([band, Transform3D(right_basis, right + right_basis * Vector3(dx, 0, 0))])
	parts.append([hub, Transform3D(Basis(), Vector3(0, 3.2, 0))])
	parts.append([collar, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 5.25, 0))])
	parts.append([tube, Transform3D(Basis(), Vector3(-2.6, 3.0, 0))])
	parts.append([tube, Transform3D(Basis(Vector3.BACK, -0.04), Vector3(2.6, 2.85, 0))])
	# Legs run well down into the silt so uneven floor never shows a gap.
	for x: float in [-8.6, -3.8, 4.0, 8.4]:
		for z: float in [-1.0, 1.0]:
			parts.append([leg, Transform3D(Basis(), Vector3(x, 1.5 - 4.5 - (0.15 if x > 0 else 0.0), z))])
		parts.append([strut, Transform3D(Basis(), Vector3(x, 0.6, 0.0))])
	parts.append([mast, Transform3D(Basis(Vector3.BACK, -0.05), Vector3(0.45, 6.2, 0))])
	parts.append([spar, Transform3D(Basis(), Vector3(0.55, 8.2, 0))])
	# The escape lock at the far end of the right module, half swallowed by rock.
	parts.append([lock, Transform3D(right_basis, right + right_basis * Vector3(4.4, 0, 0))])
	parts.append([growth, Transform3D(Basis().scaled(Vector3(1.25, 1.0, 1.15)), Vector3(11.6, 2.0, 0.2))])
	parts.append([growth, Transform3D(Basis().scaled(Vector3(0.8, 0.6, 0.9)), Vector3(9.8, 0.6, 1.0))])
	# Windows on the side facing the camera: most dark, a few lit, some failing.
	var left_windows: Array[ArrayMesh] = [dead, lit, lit, failing, dead]
	for i in left_windows.size():
		var at := left + Vector3(-2.2 + i * 1.1, -0.35, 1.47)
		parts.append([left_windows[i], Transform3D(Basis(), at)])
	var right_windows: Array[ArrayMesh] = [failing, dead, dead, lit]
	for i in right_windows.size():
		var at := right + right_basis * Vector3(-1.8 + i * 1.2, 0.1, 1.47)
		parts.append([right_windows[i], Transform3D(right_basis, at)])
	parts.append([porthole, Transform3D(Basis(), Vector3(0, 3.5, 2.12))])
	# The berth of the last escape pod, empty: Hale and Sato took it up (log_10).
	# An open docking ring on the left module, its clamps sprung wide and the
	# umbilicals torn off and trailing down the hull.
	var berth := left + Vector3(1.4, 1.45, 0.0)
	var ring := _part(MeshKit.lathe(PackedVector2Array([Vector2(0, 0.82), Vector2(0.4, 0.86), Vector2(1, 0.82)]),
		0.45, 16, 2), BAND)
	parts.append([ring, Transform3D(Basis(Vector3.BACK, PI * 0.5), berth + Vector3(0, 0.22, 0))])
	var clamp := _part(_box(Vector3(0.14, 0.7, 0.18)), FRAME)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var out := Vector3(cos(a), 0.0, sin(a))
		var tilt := Basis(out.cross(Vector3.UP).normalized(), -0.75)
		parts.append([clamp, Transform3D(tilt, berth + out * 0.95 + Vector3(0, 0.55, 0))])
	var cable := _part(_cylinder(0.05, 1.0, 5), FRAME)
	for c: Array in [[Vector3(-0.3, 0.3, 0.75), Vector3(-0.9, -0.9, 1.25)], [Vector3(0.4, 0.3, 0.7),
			Vector3(1.1, -1.25, 1.3)]]:
		var a: Vector3 = berth + c[0]
		var b: Vector3 = berth + c[1]
		var y := (b - a).normalized()
		var x := y.cross(Vector3.BACK).normalized()
		# Stretched along its own axis to span a to b.
		parts.append([cable, Transform3D(Basis(x, y * a.distance_to(b), x.cross(y)), (a + b) * 0.5)])
	return MeshKit.merge(parts)
