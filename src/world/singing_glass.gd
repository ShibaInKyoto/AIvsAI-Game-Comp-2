class_name SingingGlass
extends Entity
## In the first Abyssal Vents zone a seam of volcanic glass seals a chamber off
## the main tunnel, a cache glinting in the dark behind it. Glass rings at its
## own note (log_06: "sing the right note at a wine glass and it shatters"):
## every sonar ping that reaches it sets it ringing, and pinged again while it
## still rings it rings higher. Three in a row, a rising chord, and it
## shatters, opening the way in. The Choir asks the same of the sub at the
## bottom: answer it, and keep answering.

const ZONE := BiomeLibrary.FURNACE_ZONE - 1
## How long it rings after a ping reaches it: the next ping must land within this.
const RING_TIME := 6.5
## The chord it rings, as pitch scales of its note: a major triad.
const CHORD: Array[float] = [1.0, 1.26, 1.5]
## Chamber sizes to try, largest first.
const POCKET_SIZES: Array[float] = [4.0, 3.2, 2.7]
## The rock between the tunnel and the chamber: the glass seam.
const WALL := 2.2
const NECK_RADIUS := 2.2
const OPEN_TIME := 0.9
const RESEARCH := 8
const CRYSTALS := 34
const GLOW := Color(0.72, 0.55, 1.0)

## Hints shown once per session: on first coming near, and on the first ring.
static var _explained := false
static var _ring_explained := false

## Where the seam meets the tunnel, and the way into the rock from there.
var wall: Vector2
var normal: Vector2
var chamber: Vector2
var pocket_radius := 4.0
var rings := 0
var shattered := false
var _tangent: Vector2
var _lobe := Vector2.INF
var _ringing := 0.0
var _flare := 0.0
var _arrivals := PackedFloat32Array()
var _neck: TrenchShift.Morph
var _open := -1.0
var _rig: Node3D
var _crystals: Array[Transform3D] = []
var _mat: ShaderMaterial
var _light: OmniLight3D
var _t := 0.0


## Seals a chamber off a straight stretch of the main tunnel; returns the
## glass, or null if the rock nowhere along it will hold one.
static func place(level: Level, rng: RandomNumberGenerator, avoid: PackedVector2Array) -> SingingGlass:
	var path := level.layout.main_path
	if path.size() < 12:
		return null
	# The middle of the zone first; then anywhere but its ends.
	var middle := _shuffled(int(path.size() * 0.25), int(path.size() * 0.75), rng)
	var wide := _shuffled(int(path.size() * 0.12), int(path.size() * 0.88), rng)
	for size_r in POCKET_SIZES:
		for order in [middle, wide]:
			for i: int in order:
				var glass := _site(level, i, avoid, size_r)
				if glass:
					level.add_entity(glass)
					return glass
	return null


static func _shuffled(from: int, to: int, rng: RandomNumberGenerator) -> Array[int]:
	var order: Array[int] = []
	for i in range(from, to):
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


## A seam beside main-path point [param i] sealing a chamber of radius
## [param pocket_r], or null if the rock there will not hold one.
static func _site(level: Level, i: int, avoid: PackedVector2Array, pocket_r: float) -> SingingGlass:
	var layout := level.layout
	var path := layout.main_path
	var field := level.field
	var size := layout.size()
	var p := path[i]
	var tangent := (path[mini(i + 2, path.size() - 1)] - path[maxi(i - 2, 0)]).normalized()
	var sides: Array[float] = [1.0, -1.0]
	if i % 2 == 1:
		sides.reverse()
	for side in sides:
		var n := tangent.orthogonal() * side
		var reach := 0.0
		while reach < 12.0 and field.sample(p + n * reach) > 0.3:
			reach += 0.5
		if reach >= 12.0 or reach < 1.5:
			continue
		var wall_at := p + n * reach
		var c := wall_at + n * (pocket_r + WALL)
		var margin := pocket_r + 3.0
		if c.x < margin or c.x > size.x - margin or c.y > -margin or c.y < -(size.y - margin):
			continue
		# Solid all round but for the seam, so the chamber opens only into this tunnel.
		if field.sample(c) > -(pocket_r + WALL - 0.4):
			continue
		# A flat face of rock: open water all along the front of the seam.
		if field.sample(wall_at - n * 1.2 + tangent * 1.8) < 0.3 or field.sample(wall_at - n * 1.2 - tangent * 1.8) < 0.3:
			continue
		if c.distance_to(layout.start) < 25.0 or c.distance_to(layout.exit) < 20.0:
			continue
		# Clear of anything placed on the wall the neck will open through.
		if LevelPopulator.in_guarded_room(level, c) or _near_any(wall_at, avoid, 7.0) or _near_any(c, avoid, 7.0):
			continue
		var glass := SingingGlass.new()
		glass.wall = wall_at
		glass.normal = n
		glass.chamber = c
		glass.pocket_radius = pocket_r
		glass._tangent = tangent
		var lobe := c + tangent * 2.0 + n * 1.0
		if field.sample(lobe) < -(pocket_r * 0.7 + 1.2):
			glass._lobe = lobe
		glass.pos = wall_at + n * (WALL * 0.5)
		return glass
	return null


static func _near_any(p: Vector2, points: PackedVector2Array, dist: float) -> bool:
	for q in points:
		if q.distance_squared_to(p) < dist * dist:
			return true
	return false


func setup() -> void:
	radius = 0.0
	active_radius = 120.0
	_carve_chamber()
	_furnish()
	_build()
	Events.sonar_pinged.connect(_on_ping)


func _exit_tree() -> void:
	if Events.sonar_pinged.is_connected(_on_ping):
		Events.sonar_pinged.disconnect(_on_ping)


## Hollows out the sealed chamber behind the seam.
func _carve_chamber() -> void:
	var shapes: Array[Array] = [[chamber, chamber, pocket_radius]]
	if _lobe != Vector2.INF:
		shapes.append([_lobe, _lobe, pocket_radius * 0.7])
	var m := TrenchShift.build_morph(level.field, shapes, false)
	_blend(m, 1.0)
	Events.terrain_changed.emit(m.bounds)


func _blend(m: TrenchShift.Morph, k: float) -> void:
	var values := PackedFloat32Array()
	values.resize(m.changed.size())
	for j in values.size():
		values[j] = m.from[j] + m.delta[j] * k
	level.field.write_indices(m.changed, values)
	if level.terrain:
		level.terrain.refresh_cells(level.field, m.changed)


## A cache waits in the chamber, lit by a glow bulb on its floor.
func _furnish() -> void:
	var cache := SalvageCache.new()
	cache.pos = chamber
	cache.salvage = int(level.rng.randi_range(9, 13) * (1.0 + level.zone * 0.35))
	cache.rich = true
	level.add_entity(cache)
	var floor_y := MeridianStation.floor_below(level.field, chamber, pocket_radius + 1.5)
	if floor_y != -INF:
		var bulb := GlowBulb.new()
		bulb.pos = Vector2(chamber.x + 1.2, floor_y + 0.5)
		# World +y is up.
		bulb.normal = Vector2(0.0, 1.0)
		bulb.color = GLOW
		level.add_entity(bulb)


## The seam's crystals: black glass prisms bristling from the rock between
## the tunnel and the chamber, toward the camera and out of either face.
func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(wall)
	_rig = Node3D.new()
	_rig.top_level = true
	add_child(_rig)
	var parts: Array = []
	var prism := _prism()
	for k in CRYSTALS:
		var s := rng.randf_range(-NECK_RADIUS, NECK_RADIUS) * (0.4 + 0.6 * sqrt(rng.randf()))
		var d := rng.randf_range(0.15, WALL - 0.15)
		var at := wall + normal * d + _tangent * s
		# Up on the ridge of rock: the deeper into the rock, the higher it stands.
		var depth := -minf(level.field.sample(at), 0.0)
		var z := TerrainRenderer.ROCK_HEIGHT * tanh(depth / 2.0) - 0.15
		# Out of the tunnel face or the chamber face, and towards the camera.
		var out := -normal if d < WALL * 0.5 else normal
		var dir := Vector3(out.x, out.y, 0.0) * rng.randf_range(0.3, 1.1) + Vector3(0.0, 0.0, 1.0)
		dir += Vector3(_tangent.x, _tangent.y, 0.0) * rng.randf_range(-0.5, 0.5)
		dir = dir.normalized()
		var length := rng.randf_range(0.7, 2.4) * (1.0 - 0.4 * absf(s) / NECK_RADIUS)
		var thick := length * rng.randf_range(0.1, 0.15)
		var basis := Basis(Quaternion(Vector3(1.0, 0.0, 0.0), dir))
		basis = basis * Basis(Vector3(1.0, 0.0, 0.0), rng.randf() * TAU)
		var xf := Transform3D(basis.scaled_local(Vector3(length, thick, thick)), Vector3(at.x, at.y, z))
		parts.append([prism, xf])
		_crystals.append(xf)
	var mesh := MeshInstance3D.new()
	mesh.mesh = MeshKit.merge(parts)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/fx/shaders/obsidian.gdshader")
	_mat.set_shader_parameter(&"glow_color", GLOW)
	mesh.material_override = _mat
	_rig.add_child(mesh)
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.omni_range = 9.0
	var front := wall - normal * 1.2
	_light.position = Vector3(front.x, front.y, 2.0)
	_rig.add_child(_light)
	_apply()


## A unit glass prism along +X: six flat faces and a pointed tip.
static func _prism() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var sides := 6
	var shoulder := 0.78
	for j in sides:
		var a0 := TAU * j / sides
		var a1 := TAU * (j + 1) / sides
		var b0 := Vector3(0.0, cos(a0), sin(a0))
		var b1 := Vector3(0.0, cos(a1), sin(a1))
		var s0 := b0 + Vector3(shoulder, 0.0, 0.0)
		var s1 := b1 + Vector3(shoulder, 0.0, 0.0)
		var tip := Vector3(1.0, 0.0, 0.0)
		for v in [b0, s0, b1, b1, s0, s1, s0, tip, s1]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _on_ping(origin: Vector2, ping_range: float) -> void:
	# Only the sub's own sonar is a note it answers.
	var sub := level.player
	if sub == null or origin.distance_to(sub.pos) > 1.5:
		return
	var d := origin.distance_to(pos)
	if shattered or d > ping_range:
		return
	_arrivals.append(level.time + d / Level.SONAR_SPEED)


func tick(delta: float) -> void:
	_t += delta
	var sub := level.player
	if not _explained and not shattered and sub and sub.alive and sub.pos.distance_to(pos) < 18.0:
		_explained = true
		Events.toast.emit("Volcanic glass seals off a chamber here. Glass sings back - try your sonar on it.",
			UiTheme.ACCENT)
	var now := level.time
	var k := 0
	while k < _arrivals.size():
		if _arrivals[k] <= now:
			_arrivals.remove_at(k)
			_ring()
		else:
			k += 1
	if _ringing > 0.0:
		_ringing = maxf(_ringing - delta, 0.0)
		if _ringing == 0.0 and not shattered:
			rings = 0
	_flare = maxf(_flare - delta * 2.5, 0.0)
	if _open >= 0.0:
		_open = minf(_open + delta / OPEN_TIME, 1.0)
		_blend(_neck, smoothstep(0.0, 1.0, _open))
		if _open >= 1.0:
			_open = -1.0
			Events.terrain_changed.emit(_neck.bounds)
	_apply()


## A ping has reached the glass: it rings, a note higher if it was still ringing.
func _ring() -> void:
	if shattered:
		return
	rings = rings + 1 if _ringing > 0.0 else 1
	_ringing = RING_TIME
	_flare = 1.0
	Audio.play_at(&"glass_ring", pos, -4.0 + rings * 1.5, 0.0, CHORD[rings - 1])
	Fx.shockwave(level, pos, 2.5 + rings, GLOW, 0.6)
	if rings >= CHORD.size():
		_shatter()
		return
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < 45.0:
		if rings == 1 and not _ring_explained:
			_ring_explained = true
			Events.toast.emit("The glass rings! Ping again before it falls silent.", UiTheme.ACCENT)
		elif rings == 2:
			Events.toast.emit("It rings higher. Once more!", UiTheme.ACCENT)


func _shatter() -> void:
	shattered = true
	_arrivals.clear()
	Wonders.witness("glass")
	_neck = TrenchShift.build_morph(level.field, [[wall - normal * 1.0, chamber, NECK_RADIUS]], false)
	_open = 0.0
	Audio.play_at(&"glass_shatter", pos, 2.0, 0.0)
	level.emit_noise(pos, 20.0, self)
	Fx.flash(level, pos, GLOW, 14.0, 0.5)
	Fx.shockwave(level, pos, 7.0, GLOW, 0.7)
	# Shards of it fly, still lit from within.
	var shard := MeshKit.transformed(_prism(), Transform3D(Basis().scaled(Vector3(1.8, 0.4, 0.4)), Vector3.ZERO))
	var shard_mat := MeshKit.emissive_material(GLOW, 2.5)
	for k in 5:
		var at := wall + normal * (WALL * 0.5) + _tangent * lerpf(-NECK_RADIUS, NECK_RADIUS, k / 4.0)
		Fx.rubble(level, at, shard, shard_mat, 5)
		Fx.sparkle(level, at, GLOW)
	Events.shake_requested.emit(0.45)
	Settings.rumble_pulse(0.3, 0.4)
	_rig.visible = false
	var sub := level.player
	if sub and sub.alive:
		sub.run.research += RESEARCH
		sub.show_gain(RESEARCH, " research", UiTheme.ACCENT)
	Events.toast.emit("The chord shatters the glass. The chamber behind it lies open.", UiTheme.GOOD)


func _apply() -> void:
	if shattered:
		_light.light_energy = 0.0
		return
	var ring := _ringing / RING_TIME
	var shimmer := 0.85 + 0.15 * sin(_t * (9.0 + rings * 4.0))
	var glow := 0.05 * (1.0 + sin(_t * 0.9)) + (0.35 + 0.35 * rings) * ring * shimmer + 1.6 * _flare
	_mat.set_shader_parameter(&"ring", glow)
	_light.light_energy = 0.05 + 0.9 * ring * rings + 2.0 * _flare
	# Ringing, the whole seam hums.
	var hum := 0.025 * ring * sin(_t * 70.0)
	_rig.position = Vector3(_tangent.x, _tangent.y, 0.0) * hum
