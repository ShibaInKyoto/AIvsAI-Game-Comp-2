extends Node3D
## Runs a dive: generates each zone on a worker thread, owns the level,
## submarine, camera and HUD, and handles zone exits, death and surfacing.

enum State { LOADING, PLAYING, STOPPED, DEAD }

var level: Level
var sub: Submarine
var camera: DiveCamera
var hud: Hud
var state := State.LOADING
var autopilot: Autopilot

var _pause_menu: PauseMenu
var _layout_result: LevelLayout


func _ready() -> void:
	if Game.run == null:
		Game.start_run()
	camera = DiveCamera.new()
	add_child(camera)
	hud = Hud.new()
	add_child(hud)
	add_child(LogReader.new())
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.surface_requested.connect(_on_abandon)
	Settings.changed.connect(_on_settings_changed)
	if Autopilot.requested():
		autopilot = Autopilot.new()
		add_child(autopilot)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	await load_zone(Game.run.zone)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func load_zone(zone: int) -> void:
	state = State.LOADING
	var run := Game.run
	var biome := BiomeLibrary.biome_for_zone(zone)
	var layout := await _generate(biome, run.zone_seed(zone), zone)
	if level:
		level.queue_free()
		level = null
	level = Level.new()
	add_child(level)
	var event := ZoneEvents.roll(run.run_seed, zone)
	level.build(layout, Settings.quality, run.pressure, event)
	LevelPopulator.populate(level, run)
	level.exit_reached.connect(_on_exit_reached)
	if level.boss:
		level.boss.defeated.connect(_on_victory)

	sub = Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, layout.start)
	sub.set_camera(camera)
	level.player = sub
	sub.died.connect(_on_player_died)

	camera.target = sub
	camera.level_size = layout.size()
	camera.snap()
	var water := WaterFx.new()
	level.add_child(water)
	water.setup(biome, layout.size(), camera, Settings.quality, level.current)
	hud.bind(sub, level, camera)
	if autopilot:
		autopilot.bind(sub, level)
	if Tutorial.wanted():
		var tutorial := Tutorial.new()
		level.add_child(tutorial)
		tutorial.bind(sub, level)

	Audio.play_music(biome.music)
	Audio.play_ambience(&"ambience")
	var depth := BiomeLibrary.zone_depth_range(zone)
	if BiomeLibrary.is_final_zone(zone):
		Events.banner.emit("THE HADAL FLOOR", "%d m  -  the signal is close" % int(depth.x))
	elif event != ZoneEvents.NONE:
		Events.banner.emit(biome.display_name.to_upper(), "%d - %d m   -   %s: %s" % [int(depth.x), int(depth.y),
			ZoneEvents.display_name(event).to_upper(), ZoneEvents.description(event)])
	else:
		Events.banner.emit(biome.display_name.to_upper(), "%s   %d - %d m" % [biome.tagline, int(depth.x), int(depth.y)])
	state = State.PLAYING


## Generates the layout on a worker thread so the frame keeps ticking.
func _generate(biome: BiomeDef, zone_seed: int, zone: int) -> LevelLayout:
	_layout_result = null
	var task := WorkerThreadPool.add_task(func() -> void:
		_layout_result = LevelGenerator.new().generate(biome, zone_seed, zone))
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return _layout_result


func _physics_process(delta: float) -> void:
	if state != State.PLAYING and state != State.DEAD:
		return
	Game.run.time += delta
	if autopilot:
		autopilot.drive(delta)
	sub.tick(delta)
	level.tick(delta)
	camera.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and state == State.PLAYING:
		_pause_menu.open()
		get_viewport().set_input_as_handled()


func _on_settings_changed() -> void:
	if level and level.environment_rig:
		level.environment_rig.apply_quality(Settings.quality)


func _on_exit_reached() -> void:
	if state != State.PLAYING:
		return
	state = State.STOPPED
	sub.input_enabled = false
	Audio.play(&"zone_exit", -2.0)
	var run := Game.run
	if BiomeLibrary.is_final_zone(run.zone):
		return
	if not Game.meta.tutorial_done:
		Game.meta.tutorial_done = true
		Game.save_game()
	run.zone += 1
	if autopilot:
		_continue_after_stop()
		return
	var stop := DecompressionStop.new()
	add_child(stop)
	stop.open(run)
	var choice: StringName = await stop.finished
	if choice == &"surface":
		_finish(RunState.Outcome.SURFACED)
	else:
		_continue_after_stop()


func _continue_after_stop() -> void:
	Router.fade_through(func() -> void:
		await load_zone(Game.run.zone))


func _on_victory() -> void:
	if state == State.DEAD:
		return
	state = State.STOPPED
	sub.input_enabled = false
	Game.last_victory_banked = Game.end_run(RunState.Outcome.VICTORY)
	Router.go_to(Router.ENDING, 2.5)


func _on_player_died() -> void:
	state = State.DEAD
	_finish(RunState.Outcome.IMPLODED)


func _on_abandon() -> void:
	_finish(RunState.Outcome.IMPLODED if state == State.PLAYING else RunState.Outcome.SURFACED)


func _finish(outcome: RunState.Outcome) -> void:
	state = State.STOPPED
	get_tree().paused = false
	var summary := RunSummary.new()
	add_child(summary)
	summary.show_result(Game.run, outcome)
