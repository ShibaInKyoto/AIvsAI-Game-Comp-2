extends Node
## Debug helper: renders a zone from a few camera positions to PNG files.
## Usage: xvfb-run godot --path . res://tools/debug/preview_terrain.tscn -- <out_dir> [zone] [seed]

var _frames := 0
var _shots: Array[Vector2] = []
var _cam: Camera3D
var _lamp: SpotLight3D
var _out := ""
var _zone := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://"
	_zone = int(args[1]) if args.size() > 1 else 0
	var zone_seed := int(args[2]) if args.size() > 2 else 1234
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(_zone), zone_seed, _zone)
	var root3d := Node3D.new()
	add_child(root3d)
	var env := LevelEnvironment.new()
	root3d.add_child(env)
	env.setup(layout.biome, layout.size())
	if OS.get_environment("NOSHADOW") != "" and env.sun:
		env.sun.shadow_enabled = false
	if OS.get_environment("FOGD") != "":
		(env.fog_volume.material as FogMaterial).density = float(OS.get_environment("FOGD"))
	if OS.get_environment("GFOG") != "":
		env.environment.volumetric_fog_density = float(OS.get_environment("GFOG"))
	if OS.get_environment("SKYC") != "":
		env.environment.ambient_light_sky_contribution = float(OS.get_environment("SKYC"))
	if OS.get_environment("NOSSAO") != "":
		env.environment.ssao_enabled = false
	if OS.get_environment("NOVFOG") != "":
		env.environment.volumetric_fog_enabled = false
	if OS.get_environment("NOFOG") != "":
		env.environment.fog_enabled = false
	if OS.get_environment("AMB") != "":
		layout.biome.ambient_energy = float(OS.get_environment("AMB"))
		env.update_depth(0.0)
	var terrain := TerrainRenderer.new()
	root3d.add_child(terrain)
	terrain.build(layout)
	var only := OS.get_environment("PROPS")
	if only != "":
		var level := Level.new()
		root3d.add_child(level)
		level.layout = layout
		level.field = layout.field
		level.biome = layout.biome.duplicate()
		level.biome.props = {StringName(only): 3.0}
		PropScatter.scatter(level)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.far = 150.0
	root3d.add_child(_cam)
	_lamp = SpotLight3D.new()
	_lamp.light_energy = 12.0
	_lamp.spot_range = 30.0
	_lamp.spot_angle = 28.0
	_lamp.shadow_enabled = true
	_lamp.light_volumetric_fog_energy = float(OS.get_environment("VFOGE")) if OS.get_environment("VFOGE") != "" else 8.0
	_lamp.light_color = Color(1.0, 0.95, 0.85)
	root3d.add_child(_lamp)
	_shots.append(layout.start)
	for c in layout.chambers:
		if c.kind == &"main":
			_shots.append(c.center)
			break
	_shots.append(layout.chambers.back().center)


func _process(_delta: float) -> void:
	_frames += 1
	@warning_ignore("integer_division")
	var idx := _frames / 20
	if idx >= _shots.size():
		get_tree().quit()
		return
	var p := _shots[idx]
	_cam.position = Vector3(p.x, p.y, float(OS.get_environment("CAMZ")) if OS.get_environment("CAMZ") != "" else 30.0)
	_lamp.position = Vector3(p.x, p.y, 0.5)
	_lamp.look_at(Vector3(p.x + 10.0, p.y - 4.0, 0.0))
	RenderingServer.global_shader_parameter_set(&"sonar_time", _frames / 60.0)
	if _frames % 20 == 19:
		get_viewport().get_texture().get_image().save_png(_out.path_join("terrain_%d_%d.png" % [_zone, idx]))
