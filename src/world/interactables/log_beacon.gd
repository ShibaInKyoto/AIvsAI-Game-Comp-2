class_name LogBeacon
extends Entity
## A black-box recorder from the Meridian Deep. Pings faintly on its own, so
## sonar and sharp ears can find it. Touch it to recover a signal log.

var log_id: StringName
var _t := 0.0
var _light: OmniLight3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _collected := false


func setup() -> void:
	radius = 0.8
	active_radius = 90.0
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.42
	cyl.height = 0.9
	cyl.radial_segments = 10
	body.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.4, 0.1)
	mat.metallic = 0.6
	mat.roughness = 0.4
	body.material_override = mat
	body.rotation.z = 0.3
	add_child(body)
	var lamp := MeshInstance3D.new()
	lamp.mesh = SubmarineModel._sphere(0.12)
	lamp.material_override = SubmarineModel._emissive(Color(0.4, 1.0, 0.6), 8.0)
	lamp.position = Vector3(-0.12, 0.5, 0.0)
	body.add_child(lamp)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 1.0, 0.6)
	_light.omni_range = 5.0
	_light.light_energy = 0.0
	_light.position = Vector3(0, 0.6, 1.0)
	add_child(_light)
	_ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	_ring.mesh = quad
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_texture = Fx.ring_texture()
	_ring_mat.albedo_color = Color(0.5, 1.5, 0.8, 0.0)
	_ring.material_override = _ring_mat
	_ring.position = Vector3(0, 0, 0.5)
	add_child(_ring)


func tick(delta: float) -> void:
	_t += delta
	var cycle := fmod(_t, 4.0)
	_light.light_energy = 2.0 * maxf(1.0 - cycle * 2.0, 0.0)
	_ring.scale = Vector3.ONE * (1.0 + cycle * 3.0)
	_ring_mat.albedo_color.a = maxf(1.0 - cycle / 1.5, 0.0) * 0.8
	if cycle < delta:
		Audio.play_at(&"beacon_ping", pos, -8.0)
	vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-2.0 * delta))
	move_and_collide_field(delta)
	var sub := level.player
	if not _collected and sub and sub.alive and sub.pos.distance_to(pos) < Submarine.RADIUS + radius + 0.5:
		_collect(sub)


func on_sonar(_origin: Vector2, _mark_time: float) -> void:
	_t = 3.5


func _collect(sub: Submarine) -> void:
	_collected = true
	sub.run.logs += 1
	sub.run.research += 5
	if not Game.meta.logs_found.has(String(log_id)):
		Game.meta.logs_found.append(String(log_id))
	Audio.play(&"log_found", -2.0)
	Fx.sparkle(level, pos, Color(0.4, 1.0, 0.6))
	Events.log_found.emit(log_id)
	despawn()
