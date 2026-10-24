class_name SalvageCache
extends Entity
## A sealed salvage crate from a lost expedition. Ram it, or hook it with the
## harpoon to drag it in; it bursts open into salvage and supplies.

static var _mesh: Mesh
static var _mat: StandardMaterial3D
static var _trim_mat: StandardMaterial3D

## Base salvage inside; scaled by depth when populated.
var salvage := 10
var rich := false
var _opened := false
var _beacon: MeshInstance3D
var _t := 0.0


func setup() -> void:
	radius = 1.0
	active_radius = 70.0
	targetable = true
	if _mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(1.6, 1.1, 1.1)
		_mesh = box
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.85, 0.6, 0.15)
		_mat.metallic = 0.6
		_mat.roughness = 0.45
		_trim_mat = StandardMaterial3D.new()
		_trim_mat.albedo_color = Color(0.15, 0.15, 0.17)
		_trim_mat.metallic = 0.8
		_trim_mat.roughness = 0.35
	var body := MeshInstance3D.new()
	body.mesh = _mesh
	body.material_override = _mat
	body.rotation.z = level.rng.randf_range(-0.4, 0.4)
	add_child(body)
	for x: float in [-0.55, 0.55]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 1.18, 1.18)
		band.mesh = bm
		band.material_override = _trim_mat
		band.position = Vector3(x, 0, 0)
		body.add_child(band)
	_beacon = MeshInstance3D.new()
	_beacon.mesh = MeshKit.sphere(0.1)
	_beacon.material_override = MeshKit.emissive_material(Color(1.0, 0.75, 0.2) if not rich else Color(0.4, 1.0, 0.5), 8.0)
	_beacon.position = Vector3(0, 0.62, 0.3)
	body.add_child(_beacon)


func tick(delta: float) -> void:
	_t += delta
	_beacon.visible = fmod(_t, 1.2) < 0.6
	vel = vel.lerp(Vector2(0, -0.6), 1.0 - exp(-1.2 * delta))
	move_and_collide_field(delta, 0.1)
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < Submarine.RADIUS + radius + 0.3:
		open(sub)


func on_harpoon_hit(_harpoon: Node, _damage: float) -> HarpoonReaction:
	return HarpoonReaction.DRAG


func on_reeled_in(sub: Submarine) -> void:
	open(sub)


func on_sonar(_origin: Vector2, _mark_time: float) -> void:
	_t = 0.0


func open(sub: Submarine) -> void:
	if _opened:
		return
	_opened = true
	Events.cache_opened.emit(pos)
	Audio.play_at(&"cache_open", pos, 0.0)
	Fx.sparkle(level, pos, Color(1.0, 0.8, 0.3))
	Fx.bubble_burst(level, pos, 24, 1.0)
	Pickup.scatter(level, pos, &"salvage", salvage, 1.4)
	var extras := 1 + sub.stats.cache_bonus + (1 if rich else 0)
	for i in extras:
		var roll := level.rng.randf()
		if roll < 0.4:
			Pickup.scatter(level, pos, &"repair", 20, 1.0)
		elif roll < 0.75:
			Pickup.scatter(level, pos, &"power", 25, 1.0)
		else:
			_resupply(sub)
	despawn()


func _resupply(sub: Submarine) -> void:
	var run := sub.run
	if run.stats.torpedo_capacity > run.torpedoes or run.stats.flare_capacity > run.flares:
		run.torpedoes = mini(run.torpedoes + 2, run.stats.torpedo_capacity)
		run.flares = mini(run.flares + 2, run.stats.flare_capacity)
		Events.toast.emit("Ammunition resupplied", UiTheme.WARN)
	else:
		Pickup.scatter(level, pos, &"salvage", int(salvage * 0.5), 1.2)
