extends Node
## Debug helper: knocks a loose stalactite down in the Midnight Caverns and
## saves screenshots of it hanging, falling and shattering.
## Usage: xvfb-run godot --path . res://tools/debug/preview_stalactite.tscn -- <out_dir>

var _level: Level
var _sub: Submarine
var _rock: Stalactite
var _camera: DiveCamera
var _t := 0.0
var _dropped := false
var _shots := [0.45, 1.5, 1.7, 2.1]


func _ready() -> void:
	var run := RunState.new()
	run.run_seed = 5150
	run.rebuild_stats({})
	run.refill()
	run.zone = 4
	Game.run = run
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(4), run.zone_seed(4), 4)
	_level = Level.new()
	add_child(_level)
	_level.build(layout, 2)
	LevelPopulator.populate(_level, run)
	_rock = _level.entities.filter(func(e: Entity) -> bool: return e is Stalactite)[0]
	_sub = Submarine.new()
	_level.add_child(_sub)
	_sub.setup(_level, run, _rock.tip() + Vector2(-9.0, 0.5))
	_sub.input_enabled = false
	_level.player = _sub
	_camera = DiveCamera.new()
	add_child(_camera)
	_camera.target = _sub
	_camera.level_size = layout.size()
	_sub.set_camera(_camera)
	_camera.snap()


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0)
	_t += dt
	_sub.external_move = Vector2.ZERO
	_sub.aim = (_rock.pos - _sub.pos).normalized() if is_instance_valid(_rock) else Vector2.RIGHT
	if not _dropped and _t > 0.5:
		_dropped = true
		_rock.shake_loose()
	_sub.tick(dt)
	_level.tick(dt)
	_camera.tick(dt)
	if not _shots.is_empty() and _t >= _shots[0]:
		var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
		get_viewport().get_texture().get_image().save_png(out.path_join("rock_%d.png" % (4 - _shots.size())))
		_shots.pop_front()
		if _shots.is_empty():
			get_tree().quit()
