class_name Wrecks
extends RefCounted
## The "wreck field" zone event: the broken hulls of an earlier expedition's
## submersibles, settled on the floor behind the playfield with their salvage
## spilled around them.

const COUNT := 3
const MIN_SPACING := 30.0
const RUST := Color(0.58, 0.38, 0.26)
const RUST_DARK := Color(0.32, 0.24, 0.2)

static var _mesh: ArrayMesh


## Lays wrecks on suitable floor and returns a water point beside each one,
## where the populator spills their salvage.
static func scatter(level: Level, rng: RandomNumberGenerator, avoid: PackedVector2Array) -> PackedVector2Array:
	var layout := level.layout
	var spots := PackedVector2Array()
	var xforms: Array[Transform3D] = []
	var anchors := layout.anchors.duplicate()
	for i in range(anchors.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: LevelLayout.Anchor = anchors[i]
		anchors[i] = anchors[j]
		anchors[j] = tmp
	for a: LevelLayout.Anchor in anchors:
		if xforms.size() >= COUNT:
			break
		if a.normal.y < 0.7 or a.pos.distance_to(layout.start) < 25.0:
			continue
		var water := a.pos + a.normal * 3.0
		if not layout.is_reachable(water) or _near(water, spots, MIN_SPACING) or _near(water, avoid, 8.0):
			continue
		var z := rng.randf_range(-3.4, -2.4)
		# Hull axis about a radius above the floor, settled a little into the silt.
		var base := a.pos + a.normal * (PropScatter.surface_offset(z) + 0.9)
		var basis := Basis(Vector3.BACK, a.normal.angle() - PI * 0.5) * Basis(Vector3.UP, rng.randf_range(-0.45, 0.45))
		basis = basis * Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12))
		xforms.append(Transform3D(basis.scaled(Vector3.ONE * rng.randf_range(0.85, 1.2)), Vector3(base.x, base.y, z)))
		spots.append(water)
	if xforms.is_empty():
		return spots
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _wreck_mesh()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_custom_data(i, Color(0.0, rng.randf(), rng.randf_range(0.85, 1.05), 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material(level.biome)
	level.add_child(mmi)
	return spots


static func _near(p: Vector2, points: PackedVector2Array, dist: float) -> bool:
	for q in points:
		if q.distance_squared_to(p) < dist * dist:
			return true
	return false


static func _material(biome: BiomeDef) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PropScatter.ROCK_SHADER
	m.set_shader_parameter(&"rock_albedo", TerrainRenderer.ROCK_ALBEDO)
	m.set_shader_parameter(&"rock_rough", TerrainRenderer.ROCK_ROUGH)
	m.set_shader_parameter(&"tint_a", RUST)
	m.set_shader_parameter(&"tint_b", RUST_DARK)
	m.set_shader_parameter(&"sediment_tint", biome.sediment_tint)
	m.set_shader_parameter(&"tex_scale", 0.6)
	return m


## A submersible snapped in two: the bow with its conning tower, the stern
## bent away from the break, torn plating and a fallen rudder.
static func _wreck_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var bow := MeshKit.lathe(PackedVector2Array([Vector2(0, 1.35), Vector2(0.55, 1.3), Vector2(0.85, 0.95),
		Vector2(1, 0.2)]), 5.0, 16, 10)
	var stern := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.35), Vector2(0.35, 0.95), Vector2(1, 1.3)]), 4.2, 16, 8)
	var tower := BoxMesh.new()
	tower.size = Vector3(1.6, 1.2, 0.9)
	var plate := MeshKit.fin(PackedVector2Array([Vector2(0, -0.6), Vector2(0.9, -0.3), Vector2(0.6, 0.1),
		Vector2(1.1, 0.5), Vector2(0, 0.6)]), 0.05)
	var rudder := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(1.2, 0.2), Vector2(1.0, 1.1),
		Vector2(0, 0.9)]), 0.08)
	var parts := [
		[bow, Transform3D(Basis(), Vector3(2.8, 0.0, 0.0))],
		[stern, Transform3D(Basis(Vector3.BACK, -0.28) * Basis(Vector3.UP, 0.3), Vector3(-2.2, -0.35, 0.3))],
		[tower, Transform3D(Basis(Vector3.BACK, 0.06), Vector3(2.3, 1.55, 0.0))],
		[plate, Transform3D(Basis(Vector3.UP, 0.6), Vector3(0.35, 0.5, 1.0))],
		[plate, Transform3D(Basis(Vector3.UP, 2.4) * Basis(Vector3.BACK, 2.6), Vector3(0.3, -0.4, -1.0))],
		[rudder, Transform3D(Basis(Vector3.RIGHT, 1.35) * Basis(Vector3.BACK, 0.2), Vector3(-5.6, -1.1, 0.8))],
	]
	var grime := FastNoiseLite.new()
	grime.frequency = 0.6
	_mesh = MeshKit.painted(MeshKit.merge(parts), func(v: Vector3) -> Color:
		var g := 0.8 + grime.get_noise_3dv(v) * 0.25
		return Color(g, g, g, 0.0))
	return _mesh
