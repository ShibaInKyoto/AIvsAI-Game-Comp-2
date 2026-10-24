class_name Pickup
extends Entity
## Small collectible: salvage, battery charge or a hull repair. Drifts, is
## pulled towards the submarine inside its magnet radius and collected on touch.

const KINDS: Dictionary[StringName, Dictionary] = {
	&"salvage": {"color": Color(1.0, 0.75, 0.25), "size": 0.22},
	&"power": {"color": Color(0.35, 0.95, 1.0), "size": 0.28},
	&"repair": {"color": Color(1.0, 0.45, 0.3), "size": 0.3},
}

static var _meshes: Dictionary[StringName, Mesh] = {}
static var _mats: Dictionary[StringName, Material] = {}

var kind: StringName = &"salvage"
var amount := 1
var _age := 0.0
var _spin := Vector3.ZERO
var _mesh_instance: MeshInstance3D


## Spawns [param count] salvage-style pickups bursting out of [param at].
static func scatter(level: Level, at: Vector2, pickup_kind: StringName, count: int, spread := 1.0) -> void:
	if count <= 0:
		return
	var pieces := mini(count, 6)
	@warning_ignore("integer_division")
	var each := count / pieces
	var extra := count - each * pieces
	for i in pieces:
		var p := Pickup.new()
		p.kind = pickup_kind
		p.amount = each + (1 if i < extra else 0)
		p.pos = at
		var a := level.rng.randf() * TAU
		p.vel = Vector2(cos(a), sin(a)) * level.rng.randf_range(2.0, 5.0) * spread
		level.add_entity(p)


func setup() -> void:
	radius = 0.35
	active_radius = 50.0
	_spin = Vector3(level.rng.randf_range(-2, 2), level.rng.randf_range(-3, 3), level.rng.randf_range(-2, 2))
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh_for(kind)
	_mesh_instance.material_override = _material_for(kind)
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)


func tick(delta: float) -> void:
	_age += delta
	_mesh_instance.rotation += _spin * delta
	var sub := level.player
	var pulled := false
	if sub and sub.alive:
		var to := sub.pos - pos
		var d := to.length()
		if d < Submarine.RADIUS + 0.6:
			_collect(sub)
			return
		if d < sub.stats.pickup_radius and _age > 0.4:
			pulled = true
			vel = vel.lerp(to / d * (6.0 + (sub.stats.pickup_radius - d) * 3.0), 1.0 - exp(-6.0 * delta))
	if not pulled:
		vel = vel.lerp(Vector2(0, -0.3), 1.0 - exp(-1.5 * delta))
	move_and_collide_field(delta, 0.3)
	_mesh_instance.position.y = sin(_age * 2.0) * 0.08


func _collect(sub: Submarine) -> void:
	match kind:
		&"salvage":
			var gained := ceili(amount * sub.stats.salvage_mult * Pressure.salvage(sub.run.pressure))
			sub.run.salvage += gained
			Audio.play(&"pickup_salvage", -6.0, randf_range(0.95, 1.15))
		&"power":
			sub.add_battery(amount * sub.stats.bulb_mult)
			Audio.play(&"pickup_power", -4.0)
		&"repair":
			sub.heal(amount)
			Audio.play(&"pickup_repair", -4.0)
			Events.toast.emit("Hull repaired +%d" % amount, UiTheme.GOOD)
	Events.pickup_collected.emit(kind, amount)
	Fx.sparkle(level, pos, KINDS[kind].color)
	despawn()


static func _mesh_for(k: StringName) -> Mesh:
	if not _meshes.has(k):
		var size: float = KINDS[k].size
		var m: Mesh
		if k == &"salvage":
			var prism := PrismMesh.new()
			prism.size = Vector3(size * 1.6, size * 1.6, size)
			m = prism
		elif k == &"repair":
			var box := BoxMesh.new()
			box.size = Vector3(size * 1.4, size * 1.4, size * 1.4)
			m = box
		else:
			var s := SphereMesh.new()
			s.radius = size
			s.height = size * 2.0
			s.radial_segments = 10
			s.rings = 6
			m = s
		_meshes[k] = m
	return _meshes[k]


static func _material_for(k: StringName) -> Material:
	if not _mats.has(k):
		var c: Color = KINDS[k].color
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.metallic = 0.6
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.2
		_mats[k] = mat
	return _mats[k]
