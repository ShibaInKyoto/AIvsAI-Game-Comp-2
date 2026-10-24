class_name Flare
extends Entity
## A burning flare. Bounces off rock, then settles and glows. Creatures that
## hunt by light are drawn to it, which makes it a decoy as well as a lamp.

const BURN_TIME := 14.0

var light: OmniLight3D
var _age := 0.0
var _core: MeshInstance3D
var _sparks: GPUParticles3D


func setup() -> void:
	radius = 0.25
	active_radius = 200.0
	level.flares.append(self)
	_core = MeshInstance3D.new()
	_core.mesh = MeshKit.sphere(0.14)
	_core.material_override = MeshKit.emissive_material(Color(1.0, 0.35, 0.2), 9.0)
	add_child(_core)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.35, 0.22)
	light.omni_range = 15.0
	light.light_energy = 3.0
	light.light_volumetric_fog_energy = 2.0
	light.position = Vector3(0, 0, 0.6)
	add_child(light)
	_sparks = Fx.bubble_emitter()
	_sparks.amount = 16
	add_child(_sparks)
	_sparks.emitting = true


func tick(delta: float) -> void:
	_age += delta
	vel.y -= 2.5 * delta
	vel *= exp(-1.2 * delta)
	var n := move_and_collide_field(delta, 0.35)
	if n != Vector2.ZERO and vel.length() < 2.0:
		vel = Vector2.ZERO
	var life := 1.0 - _age / BURN_TIME
	light.light_energy = (2.6 + sin(_age * 23.0) * 0.4 + sin(_age * 7.0) * 0.3) * clampf(life * 4.0, 0.0, 1.0)
	if _age >= BURN_TIME:
		despawn()


## Strength of the light lure at a point, 0 if out of reach.
func lure_strength(p: Vector2) -> float:
	var d := p.distance_to(pos)
	return clampf(1.0 - d / 30.0, 0.0, 1.0) * clampf((BURN_TIME - _age) / 2.0, 0.0, 1.0)
