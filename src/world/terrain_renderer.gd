class_name TerrainRenderer
extends Node3D
## Renders a [TerrainField] as chunked relief meshes. Every chunk shares one
## flat grid mesh; the terrain shader displaces it on the GPU using the field
## uploaded as a float texture, so building a zone costs almost nothing on the
## CPU.

const CHUNK := 32.0
## Extra chunks rendered around the field so shafts appear to continue.
const OVERSCAN := 1
const ROCK_HEIGHT := 4.5
const BACK_DEPTH := 10.0

const SHADER := preload("res://src/fx/shaders/terrain.gdshader")
const ROCK_ALBEDO := preload("res://assets/textures/cliff_side_diff.jpg")
const ROCK_NORMAL := preload("res://assets/textures/cliff_side_nor.jpg")
const ROCK_ROUGH := preload("res://assets/textures/cliff_side_rough.jpg")
const SAND_ALBEDO := preload("res://assets/textures/sand_diff.jpg")
const SAND_NORMAL := preload("res://assets/textures/sand_nor.jpg")

static var _shared_noise: NoiseTexture2D

var material: ShaderMaterial
var _sdf_tex: ImageTexture


## Grid spacing in meters; lower quality settings use a coarser grid.
static func grid_step_for_quality(quality: int) -> float:
	return [0.75, 0.5, 0.4, 0.33][clampi(quality, 0, 3)]


func build(layout: LevelLayout, quality := 2) -> void:
	var field := layout.field
	var biome := layout.biome
	_sdf_tex = ImageTexture.create_from_image(field.to_image())

	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter(&"sdf_tex", _sdf_tex)
	material.set_shader_parameter(&"field_size", field.world_size())
	material.set_shader_parameter(&"texel_count", Vector2(field.width, field.height))
	material.set_shader_parameter(&"rock_height", ROCK_HEIGHT)
	material.set_shader_parameter(&"back_depth", BACK_DEPTH)
	material.set_shader_parameter(&"detail_noise", detail_noise())
	material.set_shader_parameter(&"rock_albedo", ROCK_ALBEDO)
	material.set_shader_parameter(&"rock_normal", ROCK_NORMAL)
	material.set_shader_parameter(&"rock_rough", ROCK_ROUGH)
	material.set_shader_parameter(&"sand_albedo", SAND_ALBEDO)
	material.set_shader_parameter(&"sand_normal", SAND_NORMAL)
	material.set_shader_parameter(&"rock_tint", biome.rock_tint)
	material.set_shader_parameter(&"rock_tint_deep", biome.rock_tint_deep)
	material.set_shader_parameter(&"sediment_tint", biome.sediment_tint)
	material.set_shader_parameter(&"vein_color", biome.vein_color)
	material.set_shader_parameter(&"vein_strength", biome.vein_strength)
	material.set_shader_parameter(&"caustics", biome.caustics)

	var step := grid_step_for_quality(quality)
	material.set_shader_parameter(&"grid_step", step)
	var mesh := _build_chunk_mesh(step)
	var size := field.world_size()
	var nx := ceili(size.x / CHUNK)
	var ny := ceili(size.y / CHUNK)
	for cy in range(-OVERSCAN, ny + OVERSCAN):
		for cx in range(-OVERSCAN, nx + OVERSCAN):
			var chunk := MeshInstance3D.new()
			chunk.mesh = mesh
			chunk.material_override = material
			chunk.position = Vector3(cx * CHUNK, -cy * CHUNK, 0.0)
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(chunk)


## Re-uploads [param field] after the rock has moved (same size as built).
func refresh(field: TerrainField) -> void:
	if _sdf_tex:
		_sdf_tex.update(field.to_image())


## Lights up to two regions of moving rock (centre xy, radius, strength 0..1).
func set_shift_glow(zones: Array[Vector4]) -> void:
	var packed := PackedVector4Array()
	for i in 2:
		packed.append(zones[i] if i < zones.size() else Vector4.ZERO)
	material.set_shader_parameter(&"shift_zones", packed)


## Seamless tiling noise shared by terrain and props.
static func detail_noise() -> NoiseTexture2D:
	if _shared_noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		_shared_noise = NoiseTexture2D.new()
		_shared_noise.width = 512
		_shared_noise.height = 512
		_shared_noise.seamless = true
		_shared_noise.generate_mipmaps = true
		_shared_noise.noise = noise
	return _shared_noise


## A flat grid in the XY plane spanning one chunk, from (0, 0) to (CHUNK, -CHUNK).
static func _build_chunk_mesh(step: float) -> ArrayMesh:
	var n := int(CHUNK / step)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize((n + 1) * (n + 1))
	normals.resize(verts.size())
	for y in n + 1:
		for x in n + 1:
			var i := y * (n + 1) + x
			verts[i] = Vector3(x * CHUNK / n, -y * CHUNK / n, 0.0)
			normals[i] = Vector3.BACK
	indices.resize(n * n * 6)
	var k := 0
	for y in n:
		for x in n:
			var i := y * (n + 1) + x
			# Clockwise winding as seen from +Z (Godot's front face).
			indices[k] = i
			indices[k + 1] = i + 1
			indices[k + 2] = i + n + 1
			indices[k + 3] = i + 1
			indices[k + 4] = i + n + 2
			indices[k + 5] = i + n + 1
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-2.0, -CHUNK - 2.0, -BACK_DEPTH - 12.0),
		Vector3(CHUNK + 4.0, CHUNK + 4.0, BACK_DEPTH + ROCK_HEIGHT + 18.0))
	return mesh
