extends Node
## Debug helper: a few spined puffers beside the sub in the Sunlit Shelf,
## photographed calm, swollen and bursting.
## Usage: xvfb-run godot --path . res://tools/debug/preview_puffer.tscn -- <out_dir>

var _level: Level
var _sub: Submarine
var _camera: DiveCamera
var _puffers: Array[Puffer] = []
var _t := 0.0
var _step := 0
var _shots := [0.8, 1.9, 2.3]


func _ready() -> void:
	var run := RunState.new()
	run.run_seed = 4040
	run.rebuild_stats({})
	run.refill()
	Game.run = run
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(0), run.zone_seed(0), 0)
	_level = Level.new()
	add_child(_level)
	_level.build(layout, 2)
	var at := layout.start + Vector2(7.0, -6.0)
	for offset: Vector2 in [Vector2.ZERO, Vector2(2.6, 1.6), Vector2(1.2, -2.2)]:
		var p := Puffer.new()
		p.pos = at + offset
		_level.add_entity(p)
		_puffers.append(p)
	_sub = Submarine.new()
	_level.add_child(_sub)
	_sub.setup(_level, run, at + Vector2(-6.5, 0.5))
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
	_sub.aim = Vector2.RIGHT
	if _step == 0 and _t > 1.0:
		_step = 1
		for p in _puffers:
			p.puff()
	elif _step == 1 and _t > 2.1:
		_step = 2
		_puffers[0].on_harpoon_hit(null, 5.0)
	_sub.tick(dt)
	_level.tick(dt)
	_camera.tick(dt)
	if not _shots.is_empty() and _t >= _shots[0]:
		var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
		get_viewport().get_texture().get_image().save_png(out.path_join("puffer_%d.png" % (3 - _shots.size())))
		_shots.pop_front()
		if _shots.is_empty():
			get_tree().quit()
