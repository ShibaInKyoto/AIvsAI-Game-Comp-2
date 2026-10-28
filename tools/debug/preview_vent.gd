extends Node
## Debug helper: stages a thermal vent eruption beside the sub in a vent-field
## zone and saves screenshots of the warning and the eruption.
## Usage: xvfb-run godot --path . res://tools/debug/preview_vent.tscn -- <out_dir>

var _level: Level
var _sub: Submarine
var _vent: ThermalVent
var _camera: DiveCamera
var _t := 0.0
var _shots := [1.0, 2.6, 3.6]


func _ready() -> void:
	var run := RunState.new()
	run.run_seed = 31337
	run.rebuild_stats({})
	run.refill()
	run.zone = 6
	Game.run = run
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(6), run.zone_seed(6), 6)
	_level = Level.new()
	add_child(_level)
	_level.build(layout, 2)
	LevelPopulator.populate(_level, run)
	_vent = _level.entities.filter(func(e: Entity) -> bool: return e is ThermalVent)[0]
	_sub = Submarine.new()
	_level.add_child(_sub)
	_sub.setup(_level, run, _vent.pos + _vent.normal * 4.0 + _vent.normal.orthogonal() * 6.0)
	_sub.input_enabled = false
	_level.player = _sub
	_camera = DiveCamera.new()
	add_child(_camera)
	_camera.target = _sub
	_camera.level_size = layout.size()
	_sub.set_camera(_camera)
	_camera.snap()
	_vent.erupt_soon()


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0)
	_t += dt
	_sub.external_move = Vector2.ZERO
	_sub.aim = (_vent.pos - _sub.pos).normalized()
	_sub.tick(dt)
	_level.tick(dt)
	_camera.tick(dt)
	if not _shots.is_empty() and _t >= _shots[0]:
		var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
		get_viewport().get_texture().get_image().save_png(out.path_join("vent_%d.png" % (3 - _shots.size())))
		_shots.pop_front()
		if _shots.is_empty():
			get_tree().quit()
