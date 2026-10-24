extends Node3D
## Debug helper: lines up every species in a lit tank and saves a picture.
## Usage: xvfb-run godot --path . res://tools/debug/preview_creatures.tscn -- <out.png>

var _frames := 0
var _level: Level


func _ready() -> void:
	var layout := LevelGenerator.new().generate(BiomeLibrary.get_biome(1), 5, 2)
	_level = Level.new()
	add_child(_level)
	_level.build(layout, 1)
	_level.environment_rig.environment.ambient_light_energy = 2.5
	var origin := Vector2(layout.size().x * 0.5, -60)
	var species: Array = [Lancer, Jelly, Lurelight, Gulper, Stalker, Isopod, Siphonophore, Mimic, Shoal]
	for i in species.size():
		var c: Creature = species[i].new()
		c.pos = origin + Vector2((i % 3) * 14.0 - 14.0, -int(i / 3.0) * 10.0)
		c.set(&"wall_normal", Vector2.UP)
		_level.add_entity(c)
		c.vel = Vector2(2, 0)
		c.facing = Vector2.RIGHT
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 20, 0)
	light.light_energy = 1.4
	add_child(light)
	var cam := Camera3D.new()
	cam.position = Vector3(origin.x, origin.y - 10, 34)
	cam.fov = 45
	cam.far = 200
	add_child(cam)
	cam.current = true


func _process(delta: float) -> void:
	_frames += 1
	for e in _level.entities:
		e.sync_transform()
		if e is Creature:
			(e as Creature)._update_visuals(delta)
	if _frames == 12:
		var args := OS.get_cmdline_user_args()
		get_viewport().get_texture().get_image().save_png(args[0] if args.size() > 0 else "user://creatures.png")
		get_tree().quit()
