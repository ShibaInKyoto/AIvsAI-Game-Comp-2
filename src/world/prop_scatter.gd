class_name PropScatter
extends RefCounted
## Decorates a zone with instanced props placed on reachable wall anchors.
## Each prop type becomes one MultiMeshInstance3D (one draw call).

const SHADER := preload("res://src/fx/shaders/prop.gdshader")
const ROCK_SHADER := preload("res://src/fx/shaders/rock_prop.gdshader")

## placement: floor / ceiling / wall / any. density: chance per anchor.
## Optional yaw: max spin (radians) around the up axis; default is any.
const DEFS: Dictionary[StringName, Dictionary] = {
	&"kelp": {"placement": "floor", "density": 0.22, "scale": Vector2(0.6, 1.4), "z": Vector2(-4.5, 1.5),
		"sway": 0.9, "height": 6.0, "rough": 0.7},
	&"rock": {"placement": "any", "density": 0.18, "scale": Vector2(0.5, 2.0), "z": Vector2(-3.0, 1.0),
		"sway": 0.0, "height": 1.0, "rough": 0.9},
	&"coral": {"placement": "floor", "density": 0.2, "scale": Vector2(0.8, 1.8), "z": Vector2(-3.5, 0.0),
		"sway": 0.03, "height": 1.6, "rough": 0.6},
	&"anemone": {"placement": "wall", "density": 0.12, "scale": Vector2(0.6, 1.3), "z": Vector2(-3.0, 0.0),
		"sway": 0.18, "height": 0.9, "rough": 0.4},
	&"fan": {"placement": "wall", "density": 0.12, "scale": Vector2(0.8, 1.7), "z": Vector2(-4.0, -1.0),
		"sway": 0.12, "height": 1.4, "rough": 0.6, "yaw": 0.6},
	&"crystal": {"placement": "any", "density": 0.1, "scale": Vector2(0.5, 1.5), "z": Vector2(-3.5, 0.5),
		"sway": 0.0, "height": 1.0, "rough": 0.15},
	&"mushroom": {"placement": "floor", "density": 0.16, "scale": Vector2(1.0, 2.4), "z": Vector2(-3.0, 0.0),
		"sway": 0.03, "height": 1.0, "rough": 0.5},
	&"spine": {"placement": "floor", "density": 0.025, "scale": Vector2(0.8, 1.5), "z": Vector2(-4.0, -1.0),
		"sway": 0.0, "height": 3.0, "rough": 0.5},
	&"tubeworm": {"placement": "floor", "density": 0.2, "scale": Vector2(0.6, 1.4), "z": Vector2(-3.0, 0.0),
		"sway": 0.06, "height": 1.2, "rough": 0.5},
	&"chimney": {"placement": "floor", "density": 0.05, "scale": Vector2(0.7, 1.4), "z": Vector2(-4.0, -1.5),
		"sway": 0.0, "height": 5.0, "rough": 0.9},
}

static var _meshes: Dictionary[StringName, Mesh] = {}
static var _materials: Dictionary[StringName, ShaderMaterial] = {}


static func scatter(level: Level) -> void:
	var layout := level.layout
	var biome := level.biome
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.zone_seed ^ 0x9e3779b9
	for id in biome.props:
		if not DEFS.has(id):
			continue
		var def: Dictionary = DEFS[id]
		var density: float = def.density * biome.props[id] * (Settings.quality + 2) / 4.0
		var xforms: Array[Transform3D] = []
		var customs: Array[Color] = []
		for a in layout.anchors:
			if rng.randf() > density or not _placement_ok(def.placement, a.normal):
				continue
			if a.pos.distance_to(layout.start) < 6.0:
				continue
			var z := rng.randf_range(def.z.x, def.z.y)
			var base := a.pos + a.normal * _surface_offset(z)
			var up := a.normal
			if def.placement == "floor":
				up = (a.normal + Vector2.UP * 1.2).normalized()
			var max_yaw: float = def.get("yaw", PI)
			var basis := Basis(Vector3.BACK, up.angle() - PI * 0.5) * Basis(Vector3.UP, rng.randf_range(-max_yaw, max_yaw))
			basis = basis.scaled(Vector3.ONE * rng.randf_range(def.scale.x, def.scale.y))
			xforms.append(Transform3D(basis, Vector3(base.x, base.y, z)))
			customs.append(Color(rng.randf(), rng.randf(), rng.randf_range(0.75, 1.15), rng.randf_range(0.6, 1.2)))
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _mesh(id)
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_custom_data(i, customs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _material(id, biome)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if id == &"rock" or id == &"kelp" \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(mmi)
		if id == &"chimney":
			_add_vent_plumes(level, xforms)


static func _placement_ok(placement: String, n: Vector2) -> bool:
	match placement:
		"floor":
			return n.y > 0.45
		"ceiling":
			return n.y < -0.45
		"wall":
			return absf(n.y) < 0.75
	return true


## Distance along the wall normal at which the terrain relief sits at depth z
## (inverse of the relief profile in terrain.gdshader).
static func _surface_offset(z: float) -> float:
	if z < 0.0:
		return 2.4 * atanh(clampf(-z / TerrainRenderer.BACK_DEPTH, 0.0, 0.95))
	return -2.0 * atanh(clampf(z / TerrainRenderer.ROCK_HEIGHT, 0.0, 0.95))


static func _add_vent_plumes(level: Level, xforms: Array[Transform3D]) -> void:
	for xf in xforms:
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 12.0
		pm.initial_velocity_min = 1.5
		pm.initial_velocity_max = 3.0
		pm.gravity = Vector3(0, 0.8, 0)
		pm.scale_min = 1.5
		pm.scale_max = 4.0
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.5
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0.9, 0.45, 0.15, 0.5), Color(0.15, 0.12, 0.12, 0.35), Color(0.05, 0.05,
				0.05, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		var ramp := GradientTexture1D.new()
		ramp.gradient = g
		pm.color_ramp = ramp
		var p := GPUParticles3D.new()
		p.amount = 24
		p.lifetime = 4.0
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.8, 0.8)
		q.material = Fx.particle_material(Fx.soft_texture(), false)
		p.draw_pass_1 = q
		p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 20, 12))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level.add_child(p)
		p.global_transform = Transform3D(Basis(), xf * Vector3(0, 5.0, 0))
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.45, 0.15)
		light.omni_range = 8.0
		light.light_energy = 1.5
		level.add_child(light)
		light.global_position = xf * Vector3(0, 5.2, 0) + Vector3(0, 0, 1.5)


static func _material(id: StringName, biome: BiomeDef) -> ShaderMaterial:
	var key := StringName("%s/%s" % [id, biome.id])
	if _materials.has(key):
		return _materials[key]
	if id == &"rock":
		_materials[key] = _rock_material(biome)
		return _materials[key]
	var def: Dictionary = DEFS[id]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"sway", def.sway)
	m.set_shader_parameter(&"height", def.height)
	m.set_shader_parameter(&"roughness", def.rough)
	m.set_shader_parameter(&"glow_color", biome.glow_color)
	var glow := 0.0
	var tint_a := Color(1, 1, 1)
	var tint_b := Color(1, 1, 1)
	match id:
		&"kelp":
			tint_a = Color(0.85, 0.95, 0.6)
			tint_b = Color(1.0, 0.8, 0.55)
		&"coral":
			tint_a = Color(1.0, 0.45, 0.5)
			tint_b = Color(1.0, 0.7, 0.35)
			glow = 1.6 if biome.id == &"reef" else 0.4
		&"anemone":
			tint_a = Color(1.0, 0.5, 0.8)
			tint_b = Color(0.6, 0.6, 1.0)
			glow = 2.4
		&"fan":
			tint_a = Color(0.9, 0.3, 0.55)
			tint_b = Color(0.6, 0.35, 0.95)
			glow = 1.2
		&"crystal":
			tint_a = biome.glow_color.lerp(Color.WHITE, 0.3)
			tint_b = biome.glow_color
			glow = 3.0
			m.set_shader_parameter(&"metallic", 0.3)
			m.set_shader_parameter(&"facet", 1.0)
		&"mushroom":
			tint_a = Color(0.7, 0.75, 0.8)
			tint_b = Color(0.6, 0.65, 0.9)
			glow = 2.5
		&"spine":
			tint_a = Color(0.85, 0.82, 0.72)
			tint_b = Color(0.7, 0.68, 0.62)
		&"tubeworm":
			tint_a = Color(1, 1, 1)
			tint_b = Color(0.9, 0.85, 0.8)
			glow = 1.4
			m.set_shader_parameter(&"glow_color", Color(1.0, 0.25, 0.2))
		&"chimney":
			tint_a = Color(0.35, 0.3, 0.28)
			tint_b = Color(0.25, 0.22, 0.2)
			glow = 3.0
			m.set_shader_parameter(&"glow_color", Color(1.0, 0.45, 0.1))
	m.set_shader_parameter(&"tint_a", tint_a)
	m.set_shader_parameter(&"tint_b", tint_b)
	m.set_shader_parameter(&"glow_strength", glow)
	m.set_shader_parameter(&"glow_pulse", 0.3 if glow > 0.0 else 0.0)
	_materials[key] = m
	return m


# --- Mesh builders -------------------------------------------------------------

static func _mesh(id: StringName) -> Mesh:
	if _meshes.has(id):
		return _meshes[id]
	var mesh: Mesh
	match id:
		&"kelp": mesh = _kelp()
		&"rock": mesh = _rock()
		&"coral": mesh = _coral()
		&"anemone": mesh = _anemone()
		&"fan": mesh = _fan()
		&"crystal": mesh = _crystal()
		&"mushroom": mesh = _mushroom()
		&"spine": mesh = _spine()
		&"tubeworm": mesh = _tubeworm()
		&"chimney": mesh = _chimney()
	_meshes[id] = mesh
	return mesh


## Repaints a mesh's vertex colors: func(vertex: Vector3) -> Color.
static func _paint(mesh: ArrayMesh, painter: Callable) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors := PackedColorArray()
		colors.resize(verts.size())
		for i in verts.size():
			colors[i] = painter.call(verts[i])
		arrays[Mesh.ARRAY_COLOR] = colors
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Lathe standing along +Y instead of +X, base at y = 0.
static func _upright(profile: PackedVector2Array, h: float, sides: int, rings: int) -> ArrayMesh:
	var m := MeshKit.lathe(profile, h, sides, rings)
	return MeshKit.transformed(m, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, h * 0.5, 0)))


static func _kelp() -> ArrayMesh:
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for strand in 3:
		var h := rng.randf_range(4.0, 6.5)
		var stem := _upright(PackedVector2Array([Vector2(0, 0.05), Vector2(1, 0.02)]), h, 4, 10)
		var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		parts.append([stem, Transform3D(Basis(), off)])
		var y := 0.6
		while y < h:
			var leaf := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(0.35, 0.18), Vector2(0.75, 0.05),
					Vector2(0.35, -0.08)]), 0.01)
			var side := 1.0 if int(y * 3.0) % 2 == 0 else -1.0
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, side * 0.5), off + Vector3(0, y, 0))
			parts.append([leaf, xf])
			y += rng.randf_range(0.35, 0.6)
	return _paint(MeshKit.merge(parts), func(v: Vector3) -> Color:
		var t := clampf(v.y / 6.0, 0.0, 1.0)
		return Color(0.25 + t * 0.15, 0.32 + t * 0.12, 0.12, 0.0))


static func _rock_material(biome: BiomeDef) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROCK_SHADER
	m.set_shader_parameter(&"rock_albedo", TerrainRenderer.ROCK_ALBEDO)
	m.set_shader_parameter(&"rock_rough", TerrainRenderer.ROCK_ROUGH)
	m.set_shader_parameter(&"tint_a", biome.rock_tint)
	m.set_shader_parameter(&"tint_b", biome.rock_tint_deep)
	m.set_shader_parameter(&"sediment_tint", biome.sediment_tint)
	return m


static func _rock() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.6
	sphere.radial_segments = 18
	sphere.rings = 10
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.frequency = 0.9
	noise.fractal_octaves = 3
	for i in verts.size():
		var v := verts[i]
		v *= 1.0 + noise.get_noise_3dv(v * 1.3) * 0.45
		# Flatten the underside so boulders sit on the floor.
		v.y = maxf(v.y, -0.6)
		verts[i] = v
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	var mesh := st.commit()
	return _paint(mesh, func(v: Vector3) -> Color:
		var g := 0.75 + noise.get_noise_3dv(v * 3.0) * 0.2
		return Color(g, g, g * 1.02, 0.0))


static func _coral() -> ArrayMesh:
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var thick := _upright(PackedVector2Array([Vector2(0, 0.26), Vector2(0.7, 0.2), Vector2(1, 0.12)]), 0.7, 7, 4)
	var branch := _upright(PackedVector2Array([Vector2(0, 0.17), Vector2(0.75, 0.13), Vector2(1, 0.07)]), 0.65, 6, 3)
	var twig := _upright(PackedVector2Array([Vector2(0, 0.11), Vector2(1, 0.05)]), 0.4, 5, 2)
	parts.append([thick])
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf_range(-0.3, 0.3)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.BACK, rng.randf_range(0.45, 0.85))
		var base := Vector3(0, rng.randf_range(0.35, 0.6), 0)
		parts.append([branch, Transform3D(b, base)])
		var tip := base + b * Vector3(0, 0.6, 0)
		for k in 2:
			var b2 := b * Basis(Vector3.UP, k * PI + rng.randf_range(-0.4, 0.4)) * Basis(Vector3.BACK, rng.randf_range(0.3, 0.6))
			parts.append([twig, Transform3D(b2, tip)])
	# A rounded brain-coral lump at the base.
	var lump := MeshKit.ball(0.45, 0.0, 12, 8)
	parts.append([lump, Transform3D(Basis().scaled(Vector3(1.3, 0.7, 1.1)), Vector3(0.35, 0.1, 0.2))])
	return _paint(MeshKit.merge(parts), func(v: Vector3) -> Color:
		var tip := smoothstep(0.9, 1.35, v.length())
		return Color(0.9, 0.82, 0.8, tip))


static func _anemone() -> ArrayMesh:
	var parts := []
	parts.append([_upright(PackedVector2Array([Vector2(0, 0.28), Vector2(1, 0.22)]), 0.4, 10, 2)])
	for i in 22:
		var a := TAU * i / 22.0
		var ring := 0.12 + (i % 2) * 0.08
		var b := Basis(Vector3.UP, a) * Basis(Vector3.BACK, 0.5 + (i % 3) * 0.15)
		parts.append([_upright(PackedVector2Array([Vector2(0, 0.035), Vector2(1, 0.01)]), 0.55, 4, 2),
			Transform3D(b, Vector3(cos(a) * ring, 0.4, sin(a) * ring))])
	return _paint(MeshKit.merge(parts), func(v: Vector3) -> Color:
		return Color(0.9, 0.8, 0.85, smoothstep(0.55, 0.85, v.y)))


## Gorgonian sea fan: a flat lattice of forking branches facing the camera.
static func _fan() -> ArrayMesh:
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var seg := _upright(PackedVector2Array([Vector2(0, 1.0), Vector2(1, 0.75)]), 1.0, 4, 1)
	_fan_branch(parts, seg, rng, Vector3.ZERO, Vector3.UP, 0.42, 0.055, 0)
	return _paint(MeshKit.merge(parts), func(v: Vector3) -> Color:
		return Color(0.8, 0.75, 0.8, smoothstep(0.5, 1.4, v.y) * 0.8 + 0.1))


static func _fan_branch(parts: Array, seg: ArrayMesh, rng: RandomNumberGenerator, from: Vector3, dir: Vector3,
		length: float, radius: float, depth: int) -> void:
	var to := from + dir * length
	parts.append([seg, _segment_xform(from, to, radius)])
	if depth >= 4:
		return
	for side: float in [-1.0, 1.0]:
		var d := dir.rotated(Vector3.BACK, side * rng.randf_range(0.25, 0.55)).lerp(Vector3.UP, 0.15).normalized()
		_fan_branch(parts, seg, rng, to, d, length * rng.randf_range(0.7, 0.85), radius * 0.72, depth + 1)


## Places a unit-height upright mesh so it spans [param from] to [param to].
static func _segment_xform(from: Vector3, to: Vector3, radius: float) -> Transform3D:
	var d := to - from
	var axis := Vector3.UP.cross(d)
	var rot := Basis() if axis.length() < 0.0001 else Basis(axis.normalized(), Vector3.UP.angle_to(d))
	return Transform3D(rot * Basis().scaled(Vector3(radius, d.length(), radius)), from)


static func _crystal() -> ArrayMesh:
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for i in 5:
		var h := rng.randf_range(0.7, 1.6)
		var prism := _upright(PackedVector2Array([Vector2(0, 0.14), Vector2(0.8, 0.14), Vector2(1, 0.0)]), h, 6, 3)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.BACK, rng.randf_range(-0.6, 0.6))
		parts.append([prism, Transform3D(b, Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)))])
	return _paint(MeshKit.merge(parts), func(v: Vector3) -> Color:
		return Color(0.8, 0.85, 0.9, 0.35 + smoothstep(0.2, 1.2, v.y) * 0.65))


## Pale stalks with domed caps speckled with bioluminescent spots.
static func _mushroom() -> ArrayMesh:
	var stalk := _upright(PackedVector2Array([Vector2(0, 0.09), Vector2(0.6, 0.06), Vector2(1, 0.07)]), 0.7, 8, 3)
	var dome := PackedVector2Array([Vector2(0, 0.44), Vector2(0.25, 0.43), Vector2(0.55, 0.36), Vector2(0.8, 0.22),
		Vector2(1, 0.0)])
	var cap := _upright(dome, 0.34, 16, 6)
	var parts := [[stalk], [cap, Transform3D(Basis(), Vector3(0, 0.62, 0))]]
	parts.append([stalk, Transform3D(Basis(Vector3.BACK, 0.4).scaled(Vector3.ONE * 0.6), Vector3(0.3, 0, 0.1))])
	parts.append([cap, Transform3D(Basis().scaled(Vector3.ONE * 0.6), Vector3(0.45, 0.42, 0.1))])
	var spots := FastNoiseLite.new()
	spots.frequency = 2.6
	return _paint(MeshKit.merge(parts), func(v: Vector3) -> Color:
		var on_cap := smoothstep(0.38, 0.5, v.y)
		var spot := smoothstep(0.1, 0.45, spots.get_noise_3dv(v))
		return Color(0.75, 0.75, 0.8, on_cap * (0.15 + spot * 0.85)))


## Ribs of some enormous dead animal arching out of the rock.
static func _spine() -> ArrayMesh:
	var parts := []
	var rib := PackedVector2Array([Vector2(0, 0.32), Vector2(0.5, 0.24), Vector2(1, 0.06)])
	for r in 5:
		var x := r * 1.1
		var height := 3.2 - absf(r - 2.0) * 0.45
		for i in 5:
			var t := float(i) / 4.0
			var seg := _upright(PackedVector2Array([Vector2(0, lerpf(0.32, 0.12, t)), Vector2(1, lerpf(0.28, 0.07,
					t))]), height / 4.5, 6, 1)
			var bend := Basis(Vector3.BACK, -0.32 * i)
			var y := 0.0
			var off := Vector3.ZERO
			for k in i:
				off += Basis(Vector3.BACK, -0.32 * k) * Vector3(0, height / 4.5, 0)
			parts.append([seg, Transform3D(bend, Vector3(x, 0, 0) + off)])
	parts.append([_upright(rib, 5.0, 6, 3), Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-0.4, 0.15, 0))])
	return _paint(MeshKit.merge(parts), func(_v: Vector3) -> Color:
		return Color(0.86, 0.83, 0.76, 0.0))


static func _tubeworm() -> ArrayMesh:
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 7:
		var h := rng.randf_range(0.6, 1.3)
		var tube := _upright(PackedVector2Array([Vector2(0, 0.07), Vector2(1, 0.06)]), h, 6, 2)
		var plume := _upright(PackedVector2Array([Vector2(0, 0.06), Vector2(0.5, 0.14), Vector2(1, 0.03)]), 0.25, 6, 3)
		var off := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		var b := Basis(Vector3.BACK, rng.randf_range(-0.25, 0.25))
		parts.append([tube, Transform3D(b, off)])
		parts.append([plume, Transform3D(b, off + b * Vector3(0, h, 0))])
	return _paint(MeshKit.merge(parts), func(v: Vector3) -> Color:
		var plume := smoothstep(0.55, 0.75, v.y)
		return Color(0.85 + plume * 0.1, 0.82 - plume * 0.6, 0.78 - plume * 0.6, plume))


static func _chimney() -> ArrayMesh:
	var profile := PackedVector2Array()
	var noise := FastNoiseLite.new()
	noise.frequency = 3.0
	for i in 11:
		var t := i / 10.0
		profile.append(Vector2(t, lerpf(0.9, 0.35, t) * (1.0 + noise.get_noise_1d(t) * 0.25)))
	var body := _upright(profile, 5.0, 10, 10)
	return _paint(body, func(v: Vector3) -> Color:
		var hot := smoothstep(4.3, 5.0, v.y)
		var g := 0.35 + noise.get_noise_2d(v.x * 4.0, v.y * 2.0) * 0.1
		return Color(g, g * 0.92, g * 0.88, hot))
