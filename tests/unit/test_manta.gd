extends TestCase
## Shelf mantas glide through the open water of the Sunlit Shelf: harmless,
## never stuck in the rock, banking away from a sub that crowds them, and
## there to scan for the codex.

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


func _manta(level: Level) -> Manta:
	for e in level.entities:
		if e is Manta:
			return e
	return null


func _with_sub(level: Level, run: RunState, at: Vector2) -> Submarine:
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, at)
	sub.input_enabled = false
	level.player = sub
	return sub


func test_found_on_the_shelf_only() -> void:
	var found := 0
	for run_seed in [3, 17, 42, 99, 2024, 31337]:
		for zone in [0, 1]:
			var parts := _zone_level(zone, run_seed)
			if _manta(parts[0]):
				found += 1
			(parts[0] as Level).free()
	check(found >= 6, "most shelf zones have one (%d of 12)" % found)
	for zone in [2, 4, 8]:
		var parts := _zone_level(zone, 17)
		check(_manta(parts[0]) == null, "none in zone %d" % zone)
		(parts[0] as Level).free()


func test_glides_harmlessly_and_keeps_its_distance() -> void:
	var level: Level = null
	var run: RunState = null
	var manta: Manta = null
	for run_seed in [3, 17, 42, 99]:
		var parts := _zone_level(0, run_seed)
		manta = _manta(parts[0])
		if manta:
			level = parts[0]
			run = parts[1]
			break
		(parts[0] as Level).free()
	check(manta != null, "a manta to watch")
	if manta == null:
		return
	check(not manta.is_hostile() and manta.scannable, "harmless, and there to scan")
	check(CreatureCodex.entry(&"manta") != null, "it has a codex entry")
	# Touching it does no harm.
	var sub := _with_sub(level, run, manta.pos + Vector2(manta.radius + 0.6, 0.0))
	var hull := sub.run.hull
	for i in 10:
		manta.tick(DT)
	check_eq(sub.run.hull, hull, "bumping it does no damage")
	# Crowded, it banks away.
	sub.pos = manta.pos + Vector2(3.0, 0.0)
	var close := manta.pos.distance_to(sub.pos)
	for i in int(3.0 / DT):
		manta.tick(DT)
	check(manta.pos.distance_to(sub.pos) > close + 1.0, "it moves off from a sub that crowds it")
	# Left alone, it glides on through open water.
	sub.pos = level.layout.start + Vector2(0.0, 400.0)
	var start := manta.pos
	var travelled := 0.0
	var furthest := 0.0
	var last := manta.pos
	var in_rock := 0
	for i in int(40.0 / DT):
		manta.tick(DT)
		travelled += manta.pos.distance_to(last)
		furthest = maxf(furthest, manta.pos.distance_to(start))
		last = manta.pos
		if level.field.sample(manta.pos) < manta.radius * 0.5:
			in_rock += 1
	check(travelled > 40.0, "it keeps gliding (%.0f m in 40 s)" % travelled)
	check(furthest > 12.0, "and roams (%.0f m out at most)" % furthest)
	check_eq(in_rock, 0, "never into the rock")
	level.free()


func test_a_school_shelters_under_it() -> void:
	for run_seed in [3, 17, 42, 99]:
		var parts := _zone_level(0, run_seed)
		var level: Level = parts[0]
		var manta := _manta(level)
		if manta == null:
			level.free()
			continue
		var escort: Shoal = null
		for e in level.entities:
			if e is Shoal and (e as Shoal).follow == manta:
				escort = e
		check(escort != null, "seed %d: a school comes with it" % run_seed)
		if escort:
			var worst := 0.0
			for i in int(30.0 / DT):
				manta.tick(DT)
				escort.tick(DT)
				if i > int(5.0 / DT):
					worst = maxf(worst, escort.pos.distance_to(manta.pos))
			check(worst < 10.0, "seed %d: and keeps under it (strays %.1f m at most)" % [run_seed, worst])
		level.free()
		return
