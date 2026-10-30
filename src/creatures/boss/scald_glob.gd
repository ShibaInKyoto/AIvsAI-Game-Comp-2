class_name ScaldGlob
extends Entity
## A glob of scalding vent water the Ironclad spits at a sub out of its
## reach. It glows as it comes, slows and sinks as it cools, and bursts into
## steam on whatever it meets.

const DAMAGE := 14.0
const LIFETIME := 3.2
const COLOR := Color(1.0, 0.55, 0.18)

static var _mesh: Mesh
static var _material: StandardMaterial3D

## Whoever spat it (blamed for the damage).
var shooter: Node
var _age := 0.0
var _light: OmniLight3D


func setup() -> void:
	radius = 0.55
	active_radius = 120.0
	if _mesh == null:
		_mesh = MeshKit.sphere(0.55, 12, 8)
		_material = MeshKit.emissive_material(COLOR, 4.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 5.0
	_light.light_energy = 1.6
	add_child(_light)


func tick(delta: float) -> void:
	_age += delta
	# Water drags it to a stop as it cools; it sinks a little.
	vel = vel.lerp(Vector2(0.0, -1.0), 1.0 - exp(-0.5 * delta))
	pos += vel * delta
	scale = Vector3.ONE * (1.0 + 0.12 * sin(_age * 20.0))
	_light.light_energy = 1.6 * clampf(1.0 - _age / LIFETIME, 0.0, 1.0)
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < Submarine.RADIUS + radius:
		sub.take_damage(DAMAGE, pos, shooter if is_instance_valid(shooter) else null)
		_burst()
	elif level.field.sample(pos) < radius or _age > LIFETIME:
		_burst()


func _burst() -> void:
	Fx.bubble_burst(level, pos, 16, 0.8)
	Fx.silt(level, pos, 1.2, COLOR)
	Audio.play_at(&"vent_erupt", pos, -10.0, 0.05, 2.0)
	despawn()
