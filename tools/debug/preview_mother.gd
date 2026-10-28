extends Node
## Debug helper: wakes the Blind Mother in her lair, draws a lunge into the
## wall with a noise and saves screenshots of her prowling, lunging and stuck.
## Usage: xvfb-run godot --path . res://tools/debug/preview_mother.tscn -- <out_dir>

var _level: Level
var _sub: Submarine
var _mother: BlindMother
var _camera: DiveCamera
var _t := 0.0
var _shot := 0
var _out := "user://"


func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
	var run := RunState.new()
	run.run_seed = 2024
	run.rebuild_stats({})
	run.refill()
	run.zone = BiomeLibrary.LAIR_ZONE
	Game.run = run
	var zone := BiomeLibrary.LAIR_ZONE
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	_level = Level.new()
	add_child(_level)
	_level.build(layout, 2)
	LevelPopulator.populate(_level, run)
	_mother = _level.guardian
	_sub = Submarine.new()
	_level.add_child(_sub)
	_sub.setup(_level, run, _level.layout.field.resolve_circle(_mother.lair_center + Vector2(-8.0, 2.0), 2.0))
	_sub.input_enabled = false
	_level.player = _sub
	_camera = DiveCamera.new()
	add_child(_camera)
	_camera.target = _sub
	_camera.level_size = layout.size()
	_camera.zoom = 1.3
	_sub.set_camera(_camera)
	_camera.snap()
	_mother.take_damage(0.1, _mother.pos)


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0)
	_t += dt
	_sub.external_move = Vector2.ZERO
	_sub.aim = (_mother.pos - _sub.pos).normalized()
	_sub.run.hull = _sub.stats.max_hull
	if _mother.state == BlindMother.State.PROWL and _t > 1.5:
		var wall := _mother.lair_center + Vector2(_mother.lair_radius.x * 0.95, -_mother.lair_radius.y * 0.3)
		_level.emit_noise(_level.layout.field.resolve_circle(wall, 2.0), 60.0)
	_sub.tick(dt)
	_level.tick(dt)
	_camera.tick(dt)
	var want := [1.0, -1.0, -1.0]
	var capture := (_shot == 0 and _t >= want[0]) or (_shot == 1 and _mother.state == BlindMother.State.LUNGE) \
		or (_shot == 2 and _mother.state == BlindMother.State.STUCK)
	if capture:
		get_viewport().get_texture().get_image().save_png(_out.path_join("mother_%d.png" % _shot))
		_shot += 1
	if _shot >= 3 or _t > 20.0:
		get_tree().quit()
