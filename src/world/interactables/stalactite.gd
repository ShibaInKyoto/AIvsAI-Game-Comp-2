class_name Stalactite
extends Entity
## A loose spike of rock hanging from a cavern ceiling. A very loud noise
## nearby (a ping, a boost, an explosion), a harpoon strike or a bump shakes
## it loose: it trembles for a moment, then falls, skewering whatever is
## below, and shatters with a crack loud enough to bring down its neighbours.

enum State { HANGING, SHAKING, FALLING }

const LENGTH := 3.6
## Only noises at least this loud shake rock loose (cruising never does) ...
const LOUD := 16.0
## ... and only within this fraction of their reach.
const REACH := 0.6
const SHAKE_TIME := 0.9
const GRAVITY := 30.0
const SUB_DAMAGE := 20.0
const CREATURE_DAMAGE := 55.0
const SHATTER_NOISE := 18.0

static var _mesh: Mesh
static var _materials: Dictionary[StringName, StandardMaterial3D] = {}
## The first one a pilot sees come loose explains itself, once per session.
static var _explained := false

var state := State.HANGING
var size := 1.0
var _timer := 0.0
var _model: MeshInstance3D
var _drip_mat: StandardMaterial3D
var _struck: Array[Node] = []


func setup() -> void:
	radius = 0.9 * size
	active_radius = 90.0
	targetable = true
	if _mesh == null:
		_mesh = _build_mesh()
	_model = MeshInstance3D.new()
	_model.mesh = _mesh
	_model.material_override = _material(level.biome)
	_model.scale = Vector3.ONE * size
	_model.rotation.y = level.rng.randf() * TAU
	add_child(_model)
	# A bead of mineral water glowing at the tip marks it in the dark.
	var drip := MeshInstance3D.new()
	drip.mesh = MeshKit.sphere(0.09)
	_drip_mat = MeshKit.emissive_material(level.biome.glow_color, 2.5)
	drip.material_override = _drip_mat
	drip.position = Vector3(0.0, -LENGTH * 0.5, 0.0)
	_model.add_child(drip)


## Upper and lower ends of the spike (it hangs centred on [member pos]).
func base() -> Vector2:
	return pos + Vector2(0.0, LENGTH * 0.5 * size)


func tip() -> Vector2:
	return pos - Vector2(0.0, LENGTH * 0.5 * size)


func tick(delta: float) -> void:
	match state:
		State.HANGING:
			if _heard_loud_noise():
				shake_loose()
			_bump_sub()
		State.SHAKING:
			_timer -= delta
			_model.position = Vector3(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3), 0.0) * 0.07 * size
			_drip_mat.emission_energy_multiplier = randf_range(2.0, 9.0)
			_bump_sub()
			if _timer <= 0.0:
				state = State.FALLING
				_model.position = Vector3.ZERO
		State.FALLING:
			vel.y -= GRAVITY * delta
			pos += vel * delta
			_strike()
			if level.field.sample(tip()) < 0.15:
				_shatter()


## Starts the tremble that ends in a fall (no effect once it is already loose).
func shake_loose(time := SHAKE_TIME) -> void:
	if state != State.HANGING:
		return
	state = State.SHAKING
	_timer = time
	Audio.play_at(&"rock_loose", pos, -2.0)
	Fx.ichor(level, base(), level.biome.sediment_tint, 8)
	_explain()


func on_harpoon_hit(_harpoon: Node, _damage: float) -> HarpoonReaction:
	Audio.play_at(&"harpoon_wall", pos, -4.0)
	shake_loose(0.3)
	return HarpoonReaction.IGNORE


func _heard_loud_noise() -> bool:
	for n in level.noises:
		if n.source != self and n.radius >= LOUD and pos.distance_to(n.pos) < n.radius * REACH:
			return true
	return false


func _segment_distance(p: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, base(), tip()))


## Brushing past a hanging spike knocks it loose and nudges the sub away.
func _bump_sub() -> void:
	var sub := level.player
	if sub == null or not sub.alive:
		return
	var reach := Submarine.RADIUS + 0.3 * size
	if _segment_distance(sub.pos) < reach:
		var away := sub.pos - Geometry2D.get_closest_point_to_segment(sub.pos, base(), tip())
		sub.vel += away.normalized() * 4.0
		shake_loose(0.5)


## Damages everything the falling spike passes through, once each.
func _strike() -> void:
	var sub := level.player
	if sub and sub.alive and not _struck.has(sub) and _segment_distance(sub.pos) < Submarine.RADIUS + 0.3 * size:
		_struck.append(sub)
		sub.take_damage(SUB_DAMAGE * size, tip() + Vector2(0.0, 2.0), self)
	var victims: Array[Entity] = level.targets_in_radius(pos, LENGTH * 0.5 * size + 1.0)
	if is_instance_valid(level.guardian) and level.guardian.alive:
		victims.append(level.guardian)
	for e in victims:
		var c := e as Creature
		if c and not _struck.has(c) and _segment_distance(c.pos) < c.radius + 0.3 * size:
			_struck.append(c)
			c.take_damage(CREATURE_DAMAGE * size, base(), &"rock")


func _shatter() -> void:
	var at := tip()
	Audio.play_at(&"rock_shatter", at, 0.0)
	Fx.ichor(level, at, level.biome.sediment_tint, 26)
	Fx.bubble_burst(level, at, 14, 1.2)
	Fx.rubble(level, at, _mesh, _model.material_override, 7)
	Events.shake_requested.emit(0.3)
	level.emit_noise(at, SHATTER_NOISE, self)
	despawn()


func _explain() -> void:
	var sub := level.player
	if _explained or sub == null or sub.pos.distance_to(pos) > 30.0:
		return
	_explained = true
	Events.toast.emit("Loose rock! Loud noises bring stalactites down - on you, or on whatever is below.",
		UiTheme.WARN)


## Pale dripstone in the biome's rock tint, rim-lit so it stands out against the walls.
static func _material(biome: BiomeDef) -> StandardMaterial3D:
	if not _materials.has(biome.id):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = biome.rock_tint.lerp(Color(0.85, 0.82, 0.76), 0.55)
		m.roughness = 0.75
		m.rim_enabled = true
		m.rim = 0.5
		m.rim_tint = 0.3
		_materials[biome.id] = m
	return _materials[biome.id]


## A lumpy cone, base up, tip down, centred on the origin.
static func _build_mesh() -> Mesh:
	var profile := PackedVector2Array([Vector2(0.0, 0.85), Vector2(0.18, 0.72), Vector2(0.4, 0.5),
		Vector2(0.62, 0.3), Vector2(0.85, 0.12), Vector2(1.0, 0.02)])
	var cone := MeshKit.lathe(profile, LENGTH, 9, 8)
	var noise := FastNoiseLite.new()
	noise.frequency = 1.4
	var arrays := cone.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		var bump := 1.0 + noise.get_noise_3dv(v * 1.7) * 0.35
		verts[i] = Vector3(v.x, v.y * bump, v.z * bump)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	# Lathe runs tail (base) -> head (tip) along +X; turn it so the tip hangs down.
	var mesh := MeshKit.transformed(st.commit(), Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3.ZERO))
	return MeshKit.painted(mesh, func(v: Vector3) -> Color:
		var g := 0.7 + noise.get_noise_3dv(v * 3.0) * 0.2
		return Color(g, g, g * 1.03, 0.0))
