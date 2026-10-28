class_name Torpedo
extends Entity
## Self-propelled explosive. Accelerates, homes gently on the nearest creature
## ahead of it and detonates on contact with rock or a creature.

const MAX_SPEED := 30.0
const ACCEL := 40.0
const LIFETIME := 3.2
const BLAST_RADIUS := 6.5

var damage := 70.0
var owner_sub: Submarine
var _age := 0.0
var _trail: GPUParticles3D


func setup() -> void:
	radius = 0.35
	active_radius = 200.0
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.16
	capsule.height = 0.9
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.35)
	mat.metallic = 0.8
	mat.roughness = 0.3
	body.material_override = mat
	body.rotation_degrees = Vector3(0, 0, -90)
	add_child(body)
	var glow := MeshInstance3D.new()
	glow.mesh = MeshKit.sphere(0.1)
	glow.material_override = MeshKit.emissive_material(Color(1.0, 0.25, 0.15), 8.0)
	glow.position = Vector3(-0.45, 0, 0)
	add_child(glow)
	_trail = Fx.bubble_emitter()
	_trail.position = Vector3(-0.5, 0, 0)
	add_child(_trail)
	_trail.emitting = true


func tick(delta: float) -> void:
	_age += delta
	var dir := vel.normalized()
	var target := _find_target(dir)
	if target:
		var want := (target.pos - pos).normalized()
		dir = dir.slerp(want, 1.0 - exp(-3.5 * delta)).normalized()
	var speed := minf(vel.length() + ACCEL * delta, MAX_SPEED)
	vel = dir * speed
	rotation.z = dir.angle()
	var next := pos + vel * delta
	var hit := level.first_target_on_segment(pos, next, radius)
	if hit or level.field.cast(pos, next, radius) < 1.0 or _age > LIFETIME:
		explode()
		return
	pos = next


func _find_target(dir: Vector2) -> Entity:
	var best: Entity = null
	var best_score := INF
	for e in level.targets_in_radius(pos, 28.0):
		if not e is Creature:
			continue
		var to := e.pos - pos
		if absf(dir.angle_to(to)) > deg_to_rad(35.0):
			continue
		var score := to.length() - (12.0 if (e as Creature).is_marked() else 0.0)
		if score < best_score:
			best_score = score
			best = e
	return best


func explode() -> void:
	if not alive:
		return
	Fx.explosion(level, pos, BLAST_RADIUS)
	Audio.play_at(&"explosion", pos, 2.0)
	Events.shake_requested.emit(0.8)
	level.emit_noise(pos, 70.0, owner_sub)
	for e in level.targets_in_radius(pos, BLAST_RADIUS):
		if e is Creature:
			var falloff := 1.0 - clampf(e.pos.distance_to(pos) / (BLAST_RADIUS + e.radius), 0.0, 0.7)
			(e as Creature).take_damage(damage * falloff, pos, &"torpedo")
	if owner_sub and owner_sub.alive and owner_sub.pos.distance_to(pos) < BLAST_RADIUS * 0.6:
		owner_sub.take_damage(8.0, pos, self)
	despawn()
