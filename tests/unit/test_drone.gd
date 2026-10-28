extends TestCase
## Vasquez's drone is sealed into a wall of the last zone above the hadal
## floor (and only there); coming alongside plays its recorder once, tops up
## the battery and keeps the recording in the archive without counting it
## among the Meridian logs.

const DT := 1.0 / 20.0


func _zone_level(zone: int, run_seed: int) -> Array:
	var run := RunState.new()
	run.run_seed = run_seed
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	return [level, run]


func _drone(level: Level) -> VasquezDrone:
	for e in level.entities:
		if e is VasquezDrone:
			return e
	return null


func test_sealed_into_a_wall_of_the_last_hadal_zone() -> void:
	for run_seed in [7, 99, 1234, 55555]:
		var parts := _zone_level(VasquezDrone.ZONE, run_seed)
		var level: Level = parts[0]
		var drone := _drone(level)
		check(drone != null, "seed %d: the drone lies in zone %d" % [run_seed, VasquezDrone.ZONE])
		if drone:
			check(absf(level.field.sample(drone.wall)) < 0.6, "seed %d: against the rock" % run_seed)
			check(absf(drone.normal.x) >= 0.75, "seed %d: in a wall, not the floor" % run_seed)
			check(level.field.sample(drone.pos) > 0.5, "seed %d: open water in front of it" % run_seed)
			check(level.layout.is_reachable(drone.wall + drone.normal * 3.0), "seed %d: reachable" % run_seed)
			check(drone.pos.distance_to(level.layout.start) > 25.0, "seed %d: away from the entrance" % run_seed)
		level.free()
	for zone in [VasquezDrone.ZONE - 1, BiomeLibrary.TOTAL_ZONES - 1]:
		var parts := _zone_level(zone, 7)
		check(_drone(parts[0]) == null, "no drone in zone %d" % zone)
		(parts[0] as Level).free()


func test_recorder_plays_once_and_drains_the_cells() -> void:
	var found := Game.meta.logs_found.duplicate()
	Game.meta.logs_found.clear()
	var parts := _zone_level(VasquezDrone.ZONE, 99)
	var level: Level = parts[0]
	var run: RunState = parts[1]
	var drone := _drone(level)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, drone.pos + drone.normal * 20.0)
	sub.input_enabled = false
	level.player = sub
	run.battery = 40.0
	var heard: Array[StringName] = []
	var on_log := func(id: StringName) -> void: heard.append(id)
	Events.log_found.connect(on_log)
	for i in 40:
		drone.tick(DT)
	check(not drone.surveyed, "nothing plays from across the tunnel")
	sub.pos = drone.pos + drone.normal * 3.0
	var research := run.research
	drone.tick(DT)
	check(drone.surveyed, "coming alongside plays the recorder")
	check_eq(heard, [VasquezDrone.LOG_ID] as Array[StringName], "the drone's own recording")
	check_eq(run.research, research + VasquezDrone.SURVEY_RESEARCH, "the survey earns research")
	check_near(run.battery, 40.0 + VasquezDrone.CELL_CHARGE, 0.01, "its cells top up the battery")
	drone.tick(DT)
	check_eq(heard.size(), 1, "only once")
	check(Game.meta.logs_found.has(String(VasquezDrone.LOG_ID)), "kept in the archive")
	check_eq(SignalLogs.found_count(Game.meta.logs_found), 0, "but not counted as a Meridian log")
	Events.log_found.disconnect(on_log)
	Game.meta.logs_found = found
	level.free()


func test_full_battery_stays_full() -> void:
	var found := Game.meta.logs_found.duplicate()
	var parts := _zone_level(VasquezDrone.ZONE, 1234)
	var level: Level = parts[0]
	var run: RunState = parts[1]
	var drone := _drone(level)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, drone.pos)
	sub.input_enabled = false
	level.player = sub
	drone.survey(sub)
	check_near(run.battery, sub.stats.max_battery, 0.01, "never above the cap")
	Game.meta.logs_found = found
	level.free()


func test_extras_stay_out_of_the_count() -> void:
	var all: Array[String] = []
	for l in SignalLogs.LOGS:
		all.append(l.id)
	check_eq(SignalLogs.found_count(all), SignalLogs.count(), "every Meridian log counts")
	all.append(String(VasquezDrone.LOG_ID))
	all.append(String(SignalLogs.FINAL.id))
	check_eq(SignalLogs.found_count(all), SignalLogs.count(), "extras do not")
	check_eq(SignalLogs.get_log(VasquezDrone.LOG_ID).author, "T. Vasquez", "the recorder can be read")
	check_eq(SignalLogs.get_log(&"log_final").id, "log_final", "and so can the Choir's message")
