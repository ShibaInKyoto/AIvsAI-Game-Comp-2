extends TestCase
## Above the hadal floor the trench moves when the Choir sings: a stretch of
## tunnel behind the sub flows shut, a chamber opens ahead with a cache in it,
## and the way ahead is rerouted round a stretch that closes, three times a
## zone. The rock never closes on the sub, never buries anything and never
## cuts the sub off from the exit.

const DT := 1.0 / 20.0
const HADAL := BiomeLibrary.ZONES_PER_BIOME * (BiomeLibrary.BIOME_COUNT - 1)


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


func _shift(level: Level) -> TrenchShift:
	for e in level.entities:
		if e is TrenchShift:
			return e
	return null


## The sub, parked on the main path [param fraction] of the way to the exit.
func _sub_at(level: Level, run: RunState, fraction: float) -> Submarine:
	var path := level.layout.main_path
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, path[int(fraction * (path.size() - 1))])
	sub.input_enabled = false
	level.player = sub
	return sub


func _run_out(shift: TrenchShift, max_time := 20.0) -> void:
	var t := 0.0
	while shift.active() and t < max_time:
		shift.tick(DT)
		t += DT


func _seal(shift: TrenchShift) -> TrenchShift.Morph:
	for m in shift._morphs:
		if m.fill and m != shift._closing:
			return m
	return null


func _pocket(shift: TrenchShift) -> TrenchShift.Morph:
	return shift._pocket


func test_only_above_the_hadal_floor() -> void:
	for zone in [HADAL, HADAL + 1]:
		var parts := _zone_level(zone, 7)
		check(_shift(parts[0]) != null, "zone %d moves" % zone)
		(parts[0] as Level).free()
	for zone in [HADAL - 1, BiomeLibrary.TOTAL_ZONES - 1]:
		var parts := _zone_level(zone, 7)
		check(_shift(parts[0]) == null, "zone %d holds still" % zone)
		(parts[0] as Level).free()


func test_seals_behind_and_opens_ahead() -> void:
	var seals := 0
	var pockets := 0
	for run_seed in [7, 99, 1234, 55555]:
		var parts := _zone_level(HADAL + run_seed % 2, run_seed)
		var level: Level = parts[0]
		var shift := _shift(level)
		var sub := _sub_at(level, parts[1], TrenchShift.TRIGGERS[0] + 0.04)
		shift.tick(DT)
		check(shift.active(), "seed %d: the Choir sings as the sub presses on" % run_seed)
		var seal := _seal(shift)
		var pocket := _pocket(shift)
		_run_out(shift)
		check(not shift.active(), "seed %d: the rock settles" % run_seed)
		if seal:
			seals += 1
			var c := seal.centre()
			check(level.field.sample(c) < 0.0, "seed %d: the tunnel behind is rock now" % run_seed)
			check(sub.pos.distance_to(c) > 12.0, "seed %d: well behind the sub" % run_seed)
		if pocket:
			pockets += 1
			var c: Vector2 = pocket.shapes[0][0]
			check(level.field.sample(c) > 2.0, "seed %d: a chamber where there was rock" % run_seed)
			var cache := false
			for e in level.entities:
				if e is SalvageCache and e.pos.distance_to(c) < 1.0:
					cache = true
			check(cache, "seed %d: something waits in it" % run_seed)
		check(level.field.sample(sub.pos) >= Submarine.RADIUS - 0.05, "seed %d: the sub is in open water" % run_seed)
		check(not level.layout.find_path(sub.pos, level.layout.exit, 1.3).is_empty(),
			"seed %d: the way on is open" % run_seed)
		for e in level.entities:
			# (Bulbs the closing rock swallowed are gone.)
			if e.alive and not (e is Creature or e is Pickup or e is TrenchShift or e is ChoirEcho):
				var kind: String = e.get_script().get_global_name()
				check(level.field.sample(e.pos) > 0.0, "seed %d: nothing buried (%s)" % [run_seed, kind])
		level.free()
	check(seals >= 3, "the tunnel closes most times (%d of 4)" % seals)
	check(pockets >= 3, "a chamber opens most times (%d of 4)" % pockets)


func test_rock_waits_for_the_sub() -> void:
	var parts := _zone_level(HADAL, 99)
	var level: Level = parts[0]
	var shift := _shift(level)
	var sub := _sub_at(level, parts[1], TrenchShift.TRIGGERS[0] + 0.04)
	shift.tick(DT)
	var seal := _seal(shift)
	check(seal != null, "a seal to test with")
	if seal == null:
		level.free()
		return
	for i in int((TrenchShift.LEAD_IN + TrenchShift.MORPH_TIME * 0.3) / DT):
		shift.tick(DT)
	# The sub doubles back into the closing tunnel.
	sub.pos = seal.centre()
	var held := seal.progress
	for i in 60:
		shift.tick(DT)
	check_near(seal.progress, held, 0.001, "the rock waits while the sub is in the way")
	check(level.field.sample(sub.pos) >= Submarine.RADIUS - 0.05, "and never closes on it")
	# It swims on, and the tunnel closes behind it.
	sub.pos = level.layout.main_path[int(0.45 * (level.layout.main_path.size() - 1))]
	_run_out(shift)
	check(level.field.sample(seal.centre()) < 0.0, "once it has gone, the tunnel closes")
	level.free()


func test_a_sub_cut_off_gets_its_way_back() -> void:
	var parts := _zone_level(HADAL, 99)
	var level: Level = parts[0]
	var shift := _shift(level)
	var sub := _sub_at(level, parts[1], TrenchShift.TRIGGERS[0] + 0.04)
	shift.tick(DT)
	var seal := _seal(shift)
	if seal == null:
		check(false, "a seal to test with")
		level.free()
		return
	for i in int((TrenchShift.LEAD_IN + TrenchShift.MORPH_TIME * 0.3) / DT):
		shift.tick(DT)
	sub.pos = seal.centre()
	shift.tick(DT)
	# Then slips through to the entrance side before the rock shuts.
	sub.pos = level.layout.start
	_run_out(shift)
	check(level.field.sample(seal.centre()) > 1.0, "the rock gives way again")
	check(not level.layout.find_path(sub.pos, level.layout.exit, 1.3).is_empty(), "the sub can still reach the exit")
	level.free()


func test_twice_a_zone() -> void:
	var parts := _zone_level(HADAL, 1234)
	var level: Level = parts[0]
	var shift := _shift(level)
	var sub := _sub_at(level, parts[1], 0.1)
	shift.tick(DT)
	check(not shift.active(), "quiet near the entrance")
	var path := level.layout.main_path
	for fraction: float in [0.35, 0.7, 0.9]:
		sub.pos = path[int(fraction * (path.size() - 1))]
		shift.tick(DT)
		_run_out(shift)
	check_eq(shift.shifts, TrenchShift.TRIGGERS.size(), "the Choir sings twice")
	level.free()


func test_field_cells_round_trip() -> void:
	var field := TerrainField.new(40, 30, 0.5)
	for i in field.data.size():
		field.data[i] = float(i)
	var cells := field.cells_in(Rect2(Vector2(2.0, -6.0), Vector2(3.0, 2.0)))
	check(cells.position.x == 4 and cells.position.y == 8, "the rectangle maps onto the grid (%s)" % cells)
	var values := field.read_cells(cells)
	check_eq(values[0], float(8 * 40 + 4), "values read row by row")
	for i in values.size():
		values[i] = -1.0
	field.write_cells(cells, values)
	check_eq(field.at(4, 8), -1.0, "and written back in place")
	check_eq(field.at(3, 8), float(8 * 40 + 3), "leaving the rest alone")
	check(field.cell_pos(4, 8).is_equal_approx(Vector2(2.0, -4.0)), "cell positions are world positions")


func test_the_way_ahead_is_rerouted() -> void:
	var detours := 0
	for run_seed in [7, 99, 1234, 55555, 31337, 4242]:
		var parts := _zone_level(HADAL + run_seed % 2, run_seed)
		var level: Level = parts[0]
		var shift := _shift(level)
		# The second song of a zone is the one that moves the way ahead.
		shift.shifts = 1
		var sub := _sub_at(level, parts[1], TrenchShift.TRIGGERS[1] + 0.03)
		shift.tick(DT)
		var block: Array = shift._detour_block
		var passage := shift._detour_open
		var route := shift._detour_route
		_run_out(shift, 40.0)
		if not block.is_empty():
			check(passage.progress >= 1.0, "seed %d: the new passage opens" % run_seed)
		# The stretch closes only if that leaves the sub a way on.
		if not block.is_empty() and level.field.sample((block[0] + block[1]) * 0.5) < 0.0:
			detours += 1
			var mid := route[route.size() / 2]
			check(level.field.sample(mid) > TrenchShift.DETOUR_RADIUS - 0.8,
				"seed %d: and a passage bends open round it" % run_seed)
			check(passage.progress >= 1.0, "seed %d: fully open" % run_seed)
			var on_route := false
			for p in level.layout.main_path:
				on_route = on_route or p.distance_to(mid) < 1.0
			check(on_route, "seed %d: the way on runs through it" % run_seed)
		check(not level.layout.find_path(sub.pos, level.layout.exit, 1.3).is_empty(),
			"seed %d: the way on is open" % run_seed)
		level.free()
	check(detours >= 3, "the way ahead moves most times (%d of 6)" % detours)
