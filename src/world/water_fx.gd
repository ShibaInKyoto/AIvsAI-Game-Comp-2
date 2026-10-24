class_name WaterFx
extends Node3D
## Ambient water effects: drifting marine snow that follows the camera and,
## in shallow biomes, shimmering shafts of sunlight from above.

const SHAFT_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.6, 0.9, 1.0, 1.0);
uniform float strength = 0.25;
varying float phase;
void vertex() {
	phase = MODEL_MATRIX[3].x * 0.37;
}
void fragment() {
	float across = sin(UV.x * 3.14159);
	float along = smoothstep(1.0, 0.0, UV.y) * smoothstep(0.0, 0.08, UV.y);
	float shimmer = 0.7 + 0.3 * sin(TIME * 0.7 + phase + UV.y * 3.0);
	ALBEDO = tint.rgb;
	ALPHA = across * across * along * strength * shimmer;
}
"""

var _snow: GPUParticles3D
var _camera: Camera3D


func setup(biome: BiomeDef, level_size: Vector2, camera: Camera3D, quality: int) -> void:
	_camera = camera
	_build_snow(biome, quality)
	if biome.sun_energy > 0.0:
		_build_shafts(biome, level_size)


func _process(_delta: float) -> void:
	if _camera and _snow:
		_snow.global_position = Vector3(_camera.global_position.x, _camera.global_position.y, -2.0)


func _build_snow(biome: BiomeDef, quality: int) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 19, 9)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0.02, -0.12, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.3
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.25
	pm.turbulence_noise_scale = 6.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	pm.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Fx.soft_texture()
	mat.albedo_color = Color(0.85, 0.9, 0.85, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.32, 0.35)
	mat.roughness = 1.0
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	quad.material = mat
	_snow = GPUParticles3D.new()
	_snow.amount = int([250, 500, 900, 1300][clampi(quality, 0, 3)] * biome.snow_amount)
	_snow.lifetime = 14.0
	_snow.preprocess = 14.0
	_snow.process_material = pm
	_snow.draw_pass_1 = quad
	_snow.local_coords = false
	_snow.visibility_aabb = AABB(Vector3(-40, -30, -15), Vector3(80, 60, 30))
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_snow)


func _build_shafts(biome: BiomeDef, level_size: Vector2) -> void:
	var shader := Shader.new()
	shader.code = SHAFT_SHADER
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level_size.x * 13.0 + level_size.y)
	var count := 14
	for i in count:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(&"strength", rng.randf_range(0.08, 0.2) * biome.sun_energy)
		mat.set_shader_parameter(&"tint", Color(0.55, 0.85, 1.0))
		var mi := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var length := rng.randf_range(35.0, 70.0)
		quad.size = Vector2(rng.randf_range(2.5, 7.0), length)
		# UV.y runs 0 (top) to 1 (bottom); shift so the quad hangs down from its origin.
		quad.center_offset = Vector3(0, -length * 0.5, 0)
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(0.0, level_size.x), rng.randf_range(4.0, -level_size.y * 0.25), rng.randf_range(-7.0, 3.0))
		mi.rotation = Vector3(0, rng.randf_range(-0.3, 0.3), rng.randf_range(-0.35, -0.15))
		add_child(mi)
