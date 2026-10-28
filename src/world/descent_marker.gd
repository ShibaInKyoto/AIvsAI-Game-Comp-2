class_name DescentMarker
extends Node3D
## The way down: a glowing fissure with water streaming into it. Placed at the
## zone exit so it reads from a distance even before sonar finds it.

const COLOR := Color(0.35, 1.0, 0.75)
## While a guardian lives the way down glows a warning red and stops flowing.
const SEALED_COLOR := Color(1.0, 0.25, 0.2)

var _light: OmniLight3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _stream: GPUParticles3D
var _color := COLOR
var _t := 0.0


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 16.0
	_light.light_energy = 2.0
	_light.light_volumetric_fog_energy = 1.5
	_light.position = Vector3(0, 0, 1.5)
	add_child(_light)

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(5.0, 1.0, 2.0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(COLOR, 0.0), Color(COLOR, 0.8), Color(COLOR, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	pm.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	quad.material = Fx.particle_material(Fx.soft_texture(), true, 2.5)
	var stream := GPUParticles3D.new()
	_stream = stream
	stream.amount = 70
	stream.lifetime = 2.6
	stream.process_material = pm
	stream.draw_pass_1 = quad
	stream.position = Vector3(0, 8.0, 0)
	stream.visibility_aabb = AABB(Vector3(-8, -20, -6), Vector3(16, 30, 12))
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)

	_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	_ring.mesh = q
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_texture = Fx.ring_texture()
	_ring_mat.albedo_color = Color(_color.r * 1.5, _color.g * 1.5, _color.b * 1.5, 0.6)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position = Vector3(0, 0, 0.3)
	add_child(_ring)


func set_sealed(sealed: bool) -> void:
	_color = SEALED_COLOR if sealed else COLOR
	if _light:
		_light.light_color = _color
		_ring_mat.albedo_color = Color(_color.r * 1.5, _color.g * 1.5, _color.b * 1.5, _ring_mat.albedo_color.a)
		_stream.emitting = not sealed


func _process(delta: float) -> void:
	_t += delta
	var cycle := fmod(_t, 2.0) / 2.0
	_ring.scale = Vector3.ONE * lerpf(6.0, 1.0, cycle)
	_ring_mat.albedo_color.a = sin(cycle * PI) * 0.6
	_light.light_energy = 1.8 + sin(_t * 2.0) * 0.4
