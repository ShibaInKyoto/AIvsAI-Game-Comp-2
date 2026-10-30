class_name LevelEnvironment
extends Node3D
## Water, fog, light and post-processing for a zone. Colors drift from the
## biome's shallow palette to its deep palette as the submarine descends.

var environment: Environment
var sun: DirectionalLight3D
var fog_volume: FogVolume

## Multiplier on ambient light (zone events darken or brighten a zone).
var ambient_scale := 1.0
## Multiplier on how far you can see through the water (a silt storm thickens it).
var fog_scale := 1.0
var _biome: BiomeDef
var _fog_material: FogMaterial


func setup(biome: BiomeDef, level_size: Vector2) -> void:
	_biome = biome
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# There is no sky; without this the (near black) background would replace
	# the ambient color entirely.
	environment.ambient_light_sky_contribution = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 1.6

	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.9
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.set_glow_level(0, 0.0)
	environment.set_glow_level(1, 1.0)
	environment.set_glow_level(2, 1.0)
	environment.set_glow_level(3, 0.8)
	environment.set_glow_level(4, 0.5)

	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 24.0 * fog_scale
	environment.fog_depth_end = 75.0 * fog_scale
	environment.fog_depth_curve = 1.2
	environment.fog_density = 0.65
	environment.fog_sky_affect = 0.0

	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_anisotropy = 0.55
	environment.volumetric_fog_length = 80.0
	environment.volumetric_fog_detail_spread = 1.5
	environment.volumetric_fog_ambient_inject = 0.35
	environment.volumetric_fog_sky_affect = 0.0
	environment.volumetric_fog_temporal_reprojection_enabled = true

	environment.ssao_enabled = true
	environment.ssao_radius = 2.5
	environment.ssao_intensity = 1.6
	environment.ssao_power = 1.4

	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.12

	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)

	# A slab of scattering water around the playable plane. Keeping the fog
	# out of the space between camera and cave keeps the scene crisp while
	# lamp beams still glow.
	_fog_material = FogMaterial.new()
	_fog_material.density = biome.fog_density / fog_scale
	_fog_material.edge_fade = 0.3
	fog_volume = FogVolume.new()
	fog_volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fog_volume.material = _fog_material
	fog_volume.size = Vector3(level_size.x + 80.0, level_size.y + 80.0, 22.0)
	fog_volume.position = Vector3(level_size.x * 0.5, -level_size.y * 0.5, -3.0)
	add_child(fog_volume)

	if biome.sun_energy > 0.0:
		sun = DirectionalLight3D.new()
		sun.light_energy = biome.sun_energy * 0.8
		sun.light_color = Color(0.75, 0.95, 1.0)
		sun.light_volumetric_fog_energy = 0.6
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 80.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.rotation_degrees = Vector3(-62.0, 12.0, 0.0)
		add_child(sun)

	update_depth(0.0)


## [param t] is 0 at the top of the biome's first zone and 1 at its bottom.
func update_depth(t: float) -> void:
	var water := _biome.water_color.lerp(_biome.water_color_deep, clampf(t, 0.0, 1.0))
	environment.background_color = water * 0.6
	environment.fog_light_color = water
	environment.ambient_light_color = _biome.ambient_color
	environment.ambient_light_energy = _biome.ambient_energy * lerpf(1.0, 0.6, t) * ambient_scale
	_fog_material.albedo = water.lightened(0.35)
	_fog_material.emission = water * 0.25
	if sun:
		sun.light_energy = _biome.sun_energy * lerpf(0.9, 0.35, t)


func apply_quality(quality: int) -> void:
	environment.volumetric_fog_enabled = quality >= 1
	environment.ssao_enabled = quality >= 2
	if sun:
		sun.shadow_enabled = quality >= 1
