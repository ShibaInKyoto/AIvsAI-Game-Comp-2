class_name Decoy
extends Entity
## A sonar decoy buoy. Sinks, anchors itself to the first rock it touches and
## then pings loudly every few seconds, so whatever hunts by sound goes to it
## instead of the sub. Hunters drawn in this way have not noticed the sub, so
## they can be ambushed.

const ARM_TIME := 0.9
const PING_INTERVAL := 2.4
const PINGS := 7
## Noise radius of each ping, about as loud as the sub's own sonar.
const NOISE := 34.0
const COLOR := Color(0.35, 1.0, 0.72)

var anchored := false
var pings_left := PINGS
var _age := 0.0
var _next_ping := ARM_TIME
var _blink := 0.0
var _beacon_mat: StandardMaterial3D
var _light: OmniLight3D


func setup() -> void:
	radius = 0.4
	# Keeps pinging when the sub has moved far away from it.
	active_radius = 400.0
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.26
	capsule.height = 0.95
	capsule.radial_segments = 10
	capsule.rings = 2
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.55, 0.12)
	mat.metallic = 0.6
	mat.roughness = 0.35
	body.material_override = mat
	add_child(body)
	var beacon := MeshInstance3D.new()
	beacon.mesh = MeshKit.sphere(0.14)
	_beacon_mat = MeshKit.emissive_material(COLOR, 2.0)
	beacon.material_override = _beacon_mat
	beacon.position = Vector3(0, 0.55, 0)
	add_child(beacon)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 11.0
	_light.light_energy = 0.4
	_light.position = Vector3(0, 0.7, 0.6)
	add_child(_light)


func tick(delta: float) -> void:
	_age += delta
	if not anchored:
		vel.y -= 3.0 * delta
		vel *= exp(-1.4 * delta)
		var n := move_and_collide_field(delta, 0.25)
		if n != Vector2.ZERO and vel.length() < 3.0:
			_anchor(n)
	_blink = maxf(_blink - delta * 2.5, 0.0)
	_light.light_energy = 0.4 + _blink * _blink * 7.0
	_beacon_mat.emission_energy_multiplier = 2.0 + _blink * 10.0
	if _age >= _next_ping:
		if pings_left > 0:
			_ping()
		else:
			despawn()


func _anchor(normal: Vector2) -> void:
	anchored = true
	vel = Vector2.ZERO
	# Stand upright on the rock, beacon away from it.
	rotation.z = normal.angle() - PI * 0.5
	Audio.play_at(&"harpoon_wall", pos, -10.0, 0.08, 1.3)


func _ping() -> void:
	pings_left -= 1
	_next_ping = _age + (PING_INTERVAL if pings_left > 0 else 1.2)
	_blink = 1.0
	level.emit_noise(pos, NOISE, self)
	Fx.shockwave(level, pos, 7.0, COLOR * 0.22, 1.0)
	Audio.play_at(&"decoy_ping", pos, 0.0, 0.03)
