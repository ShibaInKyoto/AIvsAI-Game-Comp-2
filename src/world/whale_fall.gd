class_name WhaleFall
extends Entity
## The "whale fall" zone event: the skeleton of a great whale lying on the
## floor behind the playfield, its spine following the rock, ribs splayed
## and half collapsed, the skull at one end with its jaws fallen open.
## Bone-eating worms glow red along it. Life gathers at a fall: the populator
## adds shoals and glow bulbs around it, and the first close look at the
## carcass earns research.

const DEPTH := -5.0
const VERTEBRAE := 15
const SPACING := 1.15
const SURVEY_RANGE := 12.0
const SURVEY_RESEARCH := 6
const BONE := Color(0.95, 0.91, 0.8)
const WORM := Color(1.0, 0.3, 0.35)

## Spine points on the gameplay plane, tail first.
var spine := PackedVector2Array()
## +1 if the skull lies to the right of the tail.
var heading := 1.0
var surveyed := false
var _light: OmniLight3D
var _worm_mat: StandardMaterial3D
var _t := 0.0


## Finds the longest stretch of floor that a skeleton can lie along, clear of
## [param avoid], and adds the fall there; returns it, or null if the zone
## has no stretch long enough.
static func place(level: Level, rng: RandomNumberGenerator, avoid: PackedVector2Array) -> WhaleFall:
	var layout := level.layout
	var best := PackedVector2Array()
	var anchors := layout.anchors.duplicate()
	for i in range(anchors.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: LevelLayout.Anchor = anchors[i]
		anchors[i] = anchors[j]
		anchors[j] = tmp
	var tried := 0
	for a: LevelLayout.Anchor in anchors:
		if tried >= 60:
			break
		if a.normal.y < 0.75 or a.pos.distance_to(layout.start) < 25.0 or a.pos.distance_to(layout.exit) < 18.0:
			continue
		if not layout.is_reachable(a.pos + a.normal * 3.0) or not _clear_of(a.pos, avoid, 10.0):
			continue
		tried += 1
		var line := _floor_line(level.field, a.pos)
		if line.size() > best.size():
			best = line
		if best.size() >= VERTEBRAE:
			break
	if best.size() < 10:
		return null
	var fall := WhaleFall.new()
	fall.spine = best
	fall.heading = 1.0 if rng.randf() < 0.5 else -1.0
	if fall.heading < 0.0:
		fall.spine.reverse()
	@warning_ignore("integer_division")
	fall.pos = best[best.size() / 2]
	level.add_entity(fall)
	return fall


## Floor heights at vertebra spacing either side of [param from], as long as
## the floor stays within a step of its neighbour (a skeleton drapes over
## gentle slopes, not cliffs).
static func _floor_line(field: TerrainField, from: Vector2) -> PackedVector2Array:
	var y0 := MeridianStation.floor_below(field, from + Vector2(0.0, 2.5), 5.0)
	if y0 == -INF:
		return PackedVector2Array()
	var at := Vector2(from.x, y0)
	var line := PackedVector2Array([at])
	for dir: float in [-1.0, 1.0]:
		var last := at
		for k in VERTEBRAE:
			var x := last.x + dir * SPACING
			var y := MeridianStation.floor_below(field, Vector2(x, last.y + 2.5), 5.0)
			if y == -INF or absf(y - last.y) > 1.2:
				break
			last = Vector2(x, y)
			if dir < 0.0:
				line.insert(0, last)
			else:
				line.append(last)
			if line.size() >= VERTEBRAE:
				return line
	return line


static func _clear_of(p: Vector2, points: PackedVector2Array, dist: float) -> bool:
	for q in points:
		if q.distance_squared_to(p) < dist * dist:
			return false
	return true


func setup() -> void:
	radius = 0.0
	active_radius = 120.0
	# The rig is built in world space: entity position is only its anchor.
	var rig := Node3D.new()
	rig.top_level = true
	add_child(rig)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spine)
	var bones := MeshInstance3D.new()
	bones.mesh = _build_bones(rng)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/fx/shaders/station.gdshader")
	mat.set_shader_parameter(&"sediment_tint", level.biome.sediment_tint)
	mat.set_shader_parameter(&"seams", 0.0)
	mat.set_shader_parameter(&"metal", 0.0)
	bones.material_override = mat
	rig.add_child(bones)
	var worms := MeshInstance3D.new()
	worms.mesh = _build_worms(rng)
	_worm_mat = MeshKit.emissive_material(WORM, 2.5)
	worms.material_override = _worm_mat
	rig.add_child(worms)
	_light = OmniLight3D.new()
	_light.light_color = WORM
	_light.omni_range = 9.0
	_light.light_energy = 0.45
	@warning_ignore("integer_division")
	var mid := spine[spine.size() / 2]
	_light.position = Vector3(mid.x, mid.y + 2.5, DEPTH + 3.0)
	rig.add_child(_light)


func tick(delta: float) -> void:
	_t += delta
	var glow := 2.2 + sin(_t * 1.3) * 0.5
	_worm_mat.emission_energy_multiplier = glow
	_light.light_energy = 0.35 + 0.1 * sin(_t * 1.3)
	var sub := level.player
	if not surveyed and sub and sub.alive and sub.pos.distance_to(pos) < SURVEY_RANGE:
		surveyed = true
		sub.run.research += SURVEY_RESEARCH
		sub.show_gain(SURVEY_RESEARCH, " research", UiTheme.ACCENT)
		Events.toast.emit("Whale fall surveyed: +%d research" % SURVEY_RESEARCH, UiTheme.ACCENT)


## Where a bone at spine point [param i] sits, in world space: behind the
## play plane, on the floor that rises towards the back of the cave.
func _bone_at(i: int, lift := 0.0) -> Vector3:
	var p := spine[clampi(i, 0, spine.size() - 1)]
	return Vector3(p.x, p.y + PropScatter.surface_offset(DEPTH) - 0.15 + lift, DEPTH)


## Cylinder from [param a] to [param b].
static func _segment(a: Vector3, b: Vector3, r: float) -> Array:
	var m := CylinderMesh.new()
	m.top_radius = r * 0.85
	m.bottom_radius = r
	m.height = a.distance_to(b)
	m.radial_segments = 7
	m.rings = 1
	var y := (b - a).normalized()
	var x := y.cross(Vector3.BACK)
	if x.length_squared() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return [m, Transform3D(Basis(x, y, z), (a + b) * 0.5)]


func _build_bones(rng: RandomNumberGenerator) -> ArrayMesh:
	var parts: Array = []
	var n := spine.size()
	var ball := MeshKit.ball(1.0, 0.0, 10, 6)
	for i in n:
		var t := float(i) / (n - 1)
		var r := lerpf(0.28, 0.62, smoothstep(0.0, 0.8, t))
		var at := _bone_at(i, r * 0.6)
		parts.append([ball, Transform3D(Basis().scaled(Vector3(r * 0.9, r * 0.85, r)), at)])
		# Neural spine up, transverse processes out to the sides.
		var lean := rng.randf_range(-0.25, 0.25)
		parts.append(_segment(at, at + Vector3(lean - heading * 0.2, r * 2.2, 0.0), r * 0.22))
		for s: float in [-1.0, 1.0]:
			parts.append(_segment(at, at + Vector3(0.0, -r * 0.2, s * r * 1.8), r * 0.18))
		# Ribs along the chest arch up out of the silt and sweep back towards
		# the tail, the near and far sides a little apart; some have fallen
		# over sideways and stand lower.
		if t > 0.38 and t < 0.92:
			var length := 3.6 * r / 0.62
			for s: float in [-1.0, 1.0]:
				var stand := rng.randf_range(0.35, 1.0)
				var prev := at
				for k in range(1, 8):
					var th := k / 7.0 * 1.75
					var rise := sin(th) * length
					var p := at + Vector3(-heading * (1.0 - cos(th)) * length * 0.45, rise * stand,
						s * (0.35 + rise * sqrt(1.0 - stand * stand) * 0.9))
					parts.append(_segment(prev, p, r * lerpf(0.3, 0.14, k / 7.0)))
					prev = p
	# The skull beyond the last vertebra, tipped nose-down, and the jaws
	# fallen open in front of it.
	var head := _bone_at(n - 1, 0.55) + Vector3(heading * 2.6, -0.1, 0.0)
	var skull := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.25), Vector2(0.15, 0.85), Vector2(0.45, 1.1),
		Vector2(0.8, 0.65), Vector2(1.0, 0.2)]), 4.8, 14, 10, 0.55, 1.0)
	var skull_basis := Basis(Vector3.UP, 0.0 if heading > 0.0 else PI) * Basis(Vector3.BACK, -0.12)
	parts.append([skull, Transform3D(skull_basis, head)])
	for s: float in [-1.0, 1.0]:
		var root := head + Vector3(-heading * 1.4, -0.45, s * 0.6)
		var tip := root + Vector3(heading * 5.0, -0.35, s * 1.7)
		var mid := (root + tip) * 0.5 + Vector3(0.0, 0.25, s * 0.35)
		parts.append(_segment(root, mid, 0.2))
		parts.append(_segment(mid, tip, 0.17))
	var grime := FastNoiseLite.new()
	grime.frequency = 0.5
	return MeshKit.painted(MeshKit.merge(parts), func(v: Vector3) -> Color:
		var g := 0.85 + grime.get_noise_3dv(v) * 0.2
		return Color(BONE.r * g, BONE.g * g, BONE.b * g, 0.0))


## Bone-eating worms: clusters of glowing specks along the spine and skull.
func _build_worms(rng: RandomNumberGenerator) -> ArrayMesh:
	var speck := MeshKit.sphere(0.06, 6, 3)
	var parts: Array = []
	for i in 9:
		@warning_ignore("integer_division")
		var at := _bone_at(rng.randi_range(spine.size() / 3, spine.size() - 1), 0.5)
		for k in 6:
			var off := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.1, 0.5), rng.randf_range(-0.3, 0.6))
			parts.append([speck, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.7, 1.4)), at + off)])
	return MeshKit.merge(parts)
