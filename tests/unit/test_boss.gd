extends TestCase
## The final encounter must be winnable by answering every wave and striking
## the organs while they are open, and lost waves must hurt.

const DT := 1.0 / 60.0


func _setup() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var zone := BiomeLibrary.TOTAL_ZONES - 1
	var run := RunState.new()
	run.run_seed = 7
	run.rebuild_stats({"harpoon": 3})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	tree.root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	var sub := Submarine.new()
	level.add_child(sub)
	var arena: LevelLayout.Chamber = layout.chambers_of_kind(&"arena")[0]
	sub.setup(level, run, arena.center + Vector2(0, -8))
	sub.input_enabled = false
	level.player = sub
	return [level, sub, run]


func test_arena_has_boss_and_organs() -> void:
	var parts := _setup()
	var level: Level = parts[0]
	check(level.boss != null, "final zone spawns the Choir")
	check_eq(level.boss.organs.size(), 4, "four voice organs")
	for o in level.boss.organs:
		check(level.field.sample(o.pos) > 0.0, "organ placed in open water")
	level.free()


func test_boss_is_winnable() -> void:
	var parts := _setup()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var run: RunState = parts[2]
	var won := [false]
	level.boss.defeated.connect(func() -> void: won[0] = true)
	var answered_any := false
	for i in 60 * 240:
		run.hull = sub.stats.max_hull
		var boss := level.boss
		if boss.active and boss.next_arrival(sub.pos) < 0.1:
			sub.try_ping()
		if boss.vulnerable > 0.0:
			answered_any = true
			for o in boss.organs:
				o.take_damage(5.0, sub.pos)
				break
		sub.tick(DT)
		level.tick(DT)
		if boss.organs.is_empty():
			break
	check(answered_any, "pings answer the waves")
	check(level.boss.organs.is_empty(), "all organs destroyed")
	level.free()


func test_missed_waves_hurt() -> void:
	var parts := _setup()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var run: RunState = parts[2]
	var start_hull := run.hull
	for i in 60 * 12:
		sub.tick(DT)
		level.tick(DT)
	check(level.boss.active, "fight starts when the sub is in the arena")
	check(run.hull < start_hull, "unanswered waves damage the hull")
	level.free()


func test_answered_waves_cost_no_battery() -> void:
	var parts := _setup()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var run: RunState = parts[2]
	var answered := 0
	var before := 0.0
	for i in 60 * 30:
		var boss := level.boss
		if boss.active and boss.next_arrival(sub.pos) < 0.1 and sub.sonar_cooldown <= 0.0:
			before = run.battery
			sub.try_ping()
		var was := boss.vulnerable
		sub.lamp_on = false
		sub.tick(DT)
		level.tick(DT)
		if boss.vulnerable > was + 1.0:
			answered += 1
	check(answered >= 3, "waves answered (%d)" % answered)
	check(run.battery > sub.stats.max_battery - 3.0, "answers refund their pings (battery %.0f)" % run.battery)
	check(before >= 0.0, "pinged")
	level.free()


func test_no_hazards_in_the_arena() -> void:
	var parts := _setup()
	var level: Level = parts[0]
	var arena: LevelLayout.Chamber = level.layout.chambers_of_kind(&"arena")[0]
	for e in level.entities:
		if e is ThermalVent or e is Stalactite:
			check(e.pos.distance_to(arena.center) > arena.radius.x, "%s clear of the arena" % e.get_class())
	level.free()
