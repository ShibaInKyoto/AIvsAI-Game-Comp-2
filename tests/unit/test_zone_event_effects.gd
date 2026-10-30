extends TestCase
## Each zone event changes how the zone plays, not just its name.

const DT := 1.0 / 20.0


func _stage(event: StringName, zone := 3) -> Array:
	var run := RunState.new()
	run.run_seed = 4242
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0, 0, event)
	LevelPopulator.populate(level, run)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, layout.start)
	sub.input_enabled = false
	level.player = sub
	return [level, sub, run]


func _count(level: Level, script: Script) -> int:
	return level.entities.filter(func(e: Entity) -> bool: return e.alive and e.get_script() == script).size()


func test_silt_shortens_sight() -> void:
	var parts := _stage(&"silt")
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var lancer: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	lancer.pos = sub.pos + Vector2(4.0, 0.0)
	level.add_entity(lancer)
	sub.lamp_on = true
	check(lancer.can_see_player(10.0), "close by, still seen")
	lancer.pos = sub.pos + Vector2(7.0, 0.0)
	if level.field.line_of_sight(lancer.pos, sub.pos):
		check(not lancer.can_see_player(10.0), "but sight is halved in the silt")
	level.free()


func test_a_magnetic_anomaly_shortens_pings() -> void:
	var parts := _stage(&"magnetic")
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var reach := [0.0]
	Events.sonar_pinged.connect(func(_p: Vector2, r: float) -> void: reach[0] = r, CONNECT_ONE_SHOT)
	sub.run.battery = sub.stats.max_battery
	check(sub.try_ping(), "it pings")
	check_near(reach[0], sub.stats.sonar_range * level.sonar_scale, 0.01, "the ping reaches only so far")
	check(level.sonar_scale < 0.6, "about half as far")
	level.free()


func test_warm_water_spares_the_cells_and_quickens_the_rest() -> void:
	var drains: Array[float] = []
	for event: StringName in [&"", &"warm"]:
		var parts := _stage(event)
		var level: Level = parts[0]
		var sub: Submarine = parts[1]
		var run: RunState = parts[2]
		sub.lamp_on = true
		for i in 60:
			sub.tick(DT)
		drains.append(run.stats.max_battery - run.battery)
		if event == &"warm":
			check(level.creature_pace > 1.0, "creatures move faster")
		level.free()
	check(drains[1] < drains[0] * 0.7, "the cells drain slower (%.2f against %.2f)" % [drains[1], drains[0]])


func test_a_migration_streams_along_the_main_path() -> void:
	var parts := _stage(&"migration")
	var level: Level = parts[0]
	var migrants: Array[Shoal] = []
	for e in level.entities:
		if e is Shoal and not (e as Shoal).route.is_empty():
			migrants.append(e)
	check(migrants.size() >= 4, "schools on the move (%d)" % migrants.size())
	var legs := migrants.map(func(s: Shoal) -> int: return s.leg)
	level.player.pos = migrants[0].pos
	for i in 400:
		level.tick(DT)
	check(migrants.map(func(s: Shoal) -> int: return s.leg) != legs, "and they move on along it")
	level.free()


func test_a_jelly_bloom_fills_the_water() -> void:
	var calm: Level = _stage(&"")[0]
	var plain := _count(calm, LevelPopulator.SPECIES[&"jelly"])
	calm.free()
	var parts := _stage(&"jellies")
	var level: Level = parts[0]
	var bloom := _count(level, LevelPopulator.SPECIES[&"jelly"])
	check(bloom >= plain + 10, "a bloom (%d jellies against %d)" % [bloom, plain])
	level.free()


func test_tremors_bring_rock_down() -> void:
	var parts := _stage(&"tremors")
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	sub.invulnerable = true
	var tremors: Tremors
	for e in level.entities:
		if e is Tremors:
			tremors = e
	check(tremors != null, "the zone is restless")
	var falling := [0]
	for i in int((Tremors.FIRST + 2.0) / DT):
		sub.tick(DT)
		level.tick(DT)
		for e in level.entities:
			var rock := e as Stalactite
			if rock and rock.state != Stalactite.State.HANGING:
				falling[0] += 1
	check_eq(tremors.quakes, 1, "it shakes")
	check(falling[0] > 0, "and rock comes loose")
	level.free()
