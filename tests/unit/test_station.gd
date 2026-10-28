extends TestCase
## The ruins of Meridian Deep stand on the floor of the final zone (and only
## there); the beacon keeps pinging, and coming near announces the station
## and pays the survey once.

const DT := 1.0 / 20.0


func _final_level(run_seed: int) -> Array:
	var zone := BiomeLibrary.TOTAL_ZONES - 1
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


func _station(level: Level) -> MeridianStation:
	for e in level.entities:
		if e is MeridianStation:
			return e
	return null


func test_station_stands_on_the_final_floor() -> void:
	for run_seed in [7, 99, 1234, 55555]:
		var parts := _final_level(run_seed)
		var level: Level = parts[0]
		var station := _station(level)
		check(station != null, "seed %d: the final zone has the station" % run_seed)
		if station:
			check(level.field.sample(station.pos + Vector2(0.0, 0.3)) < 1.0, "seed %d: it stands on the floor" % run_seed)
			check(level.field.sample(station.pos + Vector2(0.0, 4.0)) > 1.0, "seed %d: in open water" % run_seed)
			check(station.pos.distance_to(level.layout.exit) > 40.0, "seed %d: well above the arena" % run_seed)
		level.free()


func test_only_the_final_zone_has_it() -> void:
	var run := RunState.new()
	run.run_seed = 7
	run.rebuild_stats({})
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(9), run.zone_seed(9), 9)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	check(_station(level) == null, "no station above the hadal floor")
	level.free()


func test_beacon_pings_and_the_survey_pays_once() -> void:
	var parts := _final_level(7)
	var level: Level = parts[0]
	var run: RunState = parts[1]
	var station := _station(level)
	var pings: Array[Vector2] = []
	var on_ping := func(origin: Vector2, _r: float) -> void: pings.append(origin)
	Events.sonar_pinged.connect(on_ping)
	for i in int(MeridianStation.BEACON_PERIOD / DT) + 2:
		station.tick(DT)
	check(not pings.is_empty() and pings[0].distance_to(station.beacon_pos()) < 0.1, "the beacon pings")
	Events.sonar_pinged.disconnect(on_ping)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, station.pos + Vector2(0.0, 6.0))
	sub.input_enabled = false
	level.player = sub
	var research := run.research
	station.tick(DT)
	check(station.greeted, "coming near announces the station")
	check_eq(run.research, research + MeridianStation.SURVEY_RESEARCH, "the survey earns research")
	station.tick(DT)
	check_eq(run.research, research + MeridianStation.SURVEY_RESEARCH, "only once")
	level.free()
