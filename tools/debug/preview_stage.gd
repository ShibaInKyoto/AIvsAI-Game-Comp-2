extends Node
## Shared rig for the scripted debug previews: builds a zone, a sub and the
## dive camera, steps everything at a fixed rate (so slow software rendering
## still sees a smooth simulation) and saves numbered screenshots into the
## directory passed after `--`. Previews extend this script and direct the
## scene from [method direct].

const STEP := 1.0 / 20.0

var level: Level
var sub: Submarine
var camera: DiveCamera
var run: RunState
## Simulated seconds since the stage was built.
var t := 0.0
## Simulated times at which to take the next screenshots; the preview quits
## after the last one.
var shot_times: Array[float] = []
var shot_prefix := "shot"
var _out := "user://"
var _shots := 0


## Builds [param zone] from [param run_seed] for a [param frame] sub,
## populated with the zone's usual content unless [param bare].
func stage(zone: int, run_seed: int, frame := &"lantern", bare := false) -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
	run = RunState.new()
	run.run_seed = run_seed
	run.frame_id = frame
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	Game.run = run
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	level = Level.new()
	add_child(level)
	level.build(layout, 2)
	if not bare:
		LevelPopulator.populate(level, run)


## Adds the sub at [param at] with the dive camera following it.
func place_sub(at: Vector2, zoom := 1.0) -> void:
	sub = Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, at)
	sub.input_enabled = false
	level.player = sub
	camera = DiveCamera.new()
	add_child(camera)
	camera.target = sub
	camera.level_size = level.layout.size()
	camera.zoom = zoom
	sub.set_camera(camera)
	camera.snap()


## Adds the dive HUD and post-processing, for shots that should look in-game.
func add_hud() -> void:
	var hud := Hud.new()
	add_child(hud)
	hud.bind(sub, level, camera)
	add_child(PostFx.new())


## The first entity in the level for which [param match] returns true.
func find_entity(match: Callable) -> Entity:
	for e in level.entities:
		if match.call(e):
			return e
	return null


## Saves the next numbered screenshot.
func shoot() -> void:
	get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%d.png" % [shot_prefix, _shots]))
	_shots += 1


func shots_taken() -> int:
	return _shots


## Override: directs the scene every step (aim, triggers, event-driven shots).
func direct(_dt: float) -> void:
	pass


func _process(delta: float) -> void:
	if sub == null:
		return
	var dt := minf(delta, STEP)
	t += dt
	sub.external_move = Vector2.ZERO
	direct(dt)
	sub.tick(dt)
	level.tick(dt)
	camera.tick(dt)
	if not shot_times.is_empty() and t >= shot_times[0]:
		shot_times.pop_front()
		shoot()
		if shot_times.is_empty():
			get_tree().quit()
