extends TestCase
## The first Abyssal Vents zone has a chamber sealed with singing glass: shut
## to the sub until three sonar pings in a row ring it to shattering, a
## ping too late starting the chord again.

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


func _glass(level: Level) -> SingingGlass:
	for e in level.entities:
		if e is SingingGlass:
			return e
	return null


func _run(level: Level, glass: SingingGlass, seconds: float) -> void:
	for i in int(seconds / DT):
		level.time += DT
		glass.tick(DT)


## A sub parked in the tunnel in front of the seam.
func _with_sub(level: Level, run: RunState, glass: SingingGlass) -> Submarine:
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, glass.wall - glass.normal * 3.0)
	sub.input_enabled = false
	level.player = sub
	return sub


func _ping(level: Level, sub: Submarine) -> void:
	sub.sonar_cooldown = 0.0
	sub.run.battery = sub.stats.max_battery
	check(sub.try_ping(), "the sub pings")
	level.noises.clear()


func test_seals_a_chamber_in_the_first_vents_zone() -> void:
	var found := 0
	for run_seed in [3, 17, 42, 99, 2024, 777]:
		var parts := _zone_level(SingingGlass.ZONE, run_seed)
		var level: Level = parts[0]
		var glass := _glass(level)
		if glass:
			found += 1
			var layout := level.layout
			check(level.field.sample(glass.chamber) > glass.pocket_radius - 0.6,
				"seed %d: a chamber hollowed out behind it" % run_seed)
			check(layout.find_path(layout.start, glass.chamber, 1.3).is_empty(), "seed %d: and sealed" % run_seed)
			check(not layout.find_path(layout.start, layout.exit, 1.3).is_empty(), "seed %d: the way on is open" % run_seed)
			var caches := 0
			for e in level.entities:
				if e is SalvageCache and e.pos.distance_to(glass.chamber) < glass.pocket_radius + 1.0:
					caches += 1
			check_eq(caches, 1, "seed %d: a cache waits inside" % run_seed)
		level.free()
	check(found >= 5, "the first vents zone has one (%d of 6)" % found)
	for zone in [0, 4, SingingGlass.ZONE + 1]:
		var parts := _zone_level(zone, 17)
		check(_glass(parts[0]) == null, "none in zone %d" % zone)
		(parts[0] as Level).free()


func test_three_pings_in_a_row_shatter_it() -> void:
	var level: Level = null
	var run: RunState = null
	var glass: SingingGlass = null
	for run_seed in [3, 17, 42, 99]:
		var parts := _zone_level(SingingGlass.ZONE, run_seed)
		glass = _glass(parts[0])
		if glass:
			level = parts[0]
			run = parts[1]
			break
		(parts[0] as Level).free()
	if glass == null:
		check(false, "a seam to ring")
		return
	var sub := _with_sub(level, run, glass)
	_ping(level, sub)
	_run(level, glass, 1.0)
	check_eq(glass.rings, 1, "a ping rings it")
	# Too late: it fell silent, and the chord starts again.
	_run(level, glass, SingingGlass.RING_TIME + 0.5)
	check_eq(glass.rings, 0, "silent again")
	_ping(level, sub)
	_run(level, glass, 2.6)
	_ping(level, sub)
	_run(level, glass, 1.0)
	check_eq(glass.rings, 2, "pinged while it rings, it rings higher")
	check(not glass.shattered, "still whole")
	var research := run.research
	_ping(level, sub)
	_run(level, glass, 0.5)
	check(glass.shattered, "the third note shatters it")
	check_eq(run.research, research + SingingGlass.RESEARCH, "and earns research")
	_run(level, glass, SingingGlass.OPEN_TIME + 0.5)
	var layout := level.layout
	check(not layout.find_path(sub.pos, glass.chamber, 1.3).is_empty(), "the chamber lies open")
	level.free()
