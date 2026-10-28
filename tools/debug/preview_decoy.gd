extends Node
## Debug helper: a Whisper launches a sonar decoy in a reef zone; screenshots
## catch it sinking and pinging.
## Usage: xvfb-run godot --path . res://tools/debug/preview_decoy.tscn -- <out_dir>

var _level: Level
var _sub: Submarine
var _camera: DiveCamera
var _t := 0.0
var _launched := false
var _shots := [1.35, 3.85, 6.0]


func _ready() -> void:
	var run := RunState.new()
	run.run_seed = 4242
	run.frame_id = &"whisper"
	run.rebuild_stats({})
	run.refill()
	run.zone = 2
	Game.run = run
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(2), run.zone_seed(2), 2)
	_level = Level.new()
	add_child(_level)
	_level.build(layout, 2)
	_sub = Submarine.new()
	_level.add_child(_sub)
	_sub.setup(_level, run, layout.start)
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
	_sub.aim = Vector2(0.6, -0.8)
	if not _launched and _t > 0.3:
		_launched = true
		_sub.tools.use(_sub.aim)
	_sub.tick(dt)
	_level.tick(dt)
	_camera.tick(dt)
	if not _shots.is_empty() and _t >= _shots[0]:
		var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
		get_viewport().get_texture().get_image().save_png(out.path_join("decoy_%d.png" % (3 - _shots.size())))
		_shots.pop_front()
		if _shots.is_empty():
			get_tree().quit()
