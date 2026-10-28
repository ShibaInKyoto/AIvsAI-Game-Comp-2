extends Node
## Debug helper: wakes the Lamplighter in the reef lair and saves screenshots
## of her lure in the dark, the lure going dark before a charge, and her
## dazzled by the lamp.
## Usage: xvfb-run godot --path . res://tools/debug/preview_lamplighter.tscn -- <out_dir>

var _level: Level
var _sub: Submarine
var _angler: Lamplighter
var _camera: DiveCamera
var _t := 0.0
var _shot := 0
var _out := "user://"
var _far := Vector2.ZERO


func _ready() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
	var run := RunState.new()
	run.run_seed = 77
	run.rebuild_stats({})
	run.refill()
	var zone := BiomeLibrary.ANGLER_ZONE
	run.zone = zone
	Game.run = run
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	_level = Level.new()
	add_child(_level)
	_level.build(layout, 2)
	LevelPopulator.populate(_level, run)
	_angler = _level.guardian as Lamplighter
	_far = layout.field.resolve_circle(_angler.lair_center - Vector2(_angler.lair_radius.x * 0.45, 0.0), 2.0)
	_sub = Submarine.new()
	_level.add_child(_sub)
	_sub.setup(_level, run, _far)
	_sub.input_enabled = false
	_sub.lamp_on = false
	_level.player = _sub
	_camera = DiveCamera.new()
	add_child(_camera)
	_camera.target = _sub
	_camera.level_size = layout.size()
	_camera.zoom = 1.3
	_sub.set_camera(_camera)
	_camera.snap()
	var hud := Hud.new()
	add_child(hud)
	hud.bind(_sub, _level, _camera)
	add_child(PostFx.new())
	_angler.take_damage(0.1, _angler.pos)


func _process(delta: float) -> void:
	var dt := minf(delta, 1.0 / 20.0)
	_t += dt
	_sub.external_move = Vector2.ZERO
	_sub.run.hull = _sub.stats.max_hull
	if _shot < 2:
		_sub.pos = _far
		_sub.vel = Vector2.ZERO
		_sub.aim = (_angler.head_pos() - _sub.pos).normalized()
		_sub.lamp_on = _shot == 1
	elif _angler.state == Lamplighter.State.STALK:
		_sub.pos = _angler.head_pos() + _angler.facing * 9.0
		_sub.vel = Vector2.ZERO
		_sub.aim = (_angler.head_pos() - _sub.pos).normalized()
		_sub.lamp_on = true
	_sub.tick(dt)
	_level.tick(dt)
	_camera.tick(dt)
	var capture: bool = (_shot == 0 and _t >= 1.2) or (_shot == 1 and _angler.state == Lamplighter.State.WINDUP
		and _t > 3.0) or (_shot == 2 and _angler.state == Lamplighter.State.DAZZLED)
	if capture:
		get_viewport().get_texture().get_image().save_png(_out.path_join("angler_%d.png" % _shot))
		_shot += 1
	if _shot >= 3 or _t > 30.0:
		get_tree().quit()
