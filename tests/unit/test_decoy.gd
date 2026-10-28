extends TestCase
## Sonar decoys ping, draw hunters that hear them and burn out.


func _level() -> Level:
	var tree := Engine.get_main_loop() as SceneTree
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(2), 91, 2)
	var level := Level.new()
	tree.root.add_child(level)
	level.build(layout, 0)
	return level


## Open water about [param dist] from [param from], in line of sight of it.
func _open_point_near(level: Level, from: Vector2, dist: float) -> Vector2:
	for i in 64:
		var p := from + Vector2.from_angle(TAU * i / 64.0) * dist
		if level.field.sample(p) > 2.0 and level.field.line_of_sight(from, p):
			return p
	return from + Vector2(dist, 0.0)


func test_decoy_draws_hunters_then_burns_out() -> void:
	var level := _level()
	var decoy := Decoy.new()
	decoy.pos = level.layout.start
	level.add_entity(decoy)
	var lancer: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	lancer.pos = _open_point_near(level, decoy.pos, 11.0)
	level.add_entity(lancer)
	var start_d := lancer.pos.distance_to(decoy.pos)
	for i in 20:
		level.tick(0.05)
	check(decoy.pings_left < Decoy.PINGS, "the decoy pings once armed")
	check(lancer.heard_noise().distance_to(decoy.pos) < 4.0, "a lancer hears the decoy")
	for i in 40:
		level.tick(0.05)
	check(lancer.pos.distance_to(decoy.pos) < start_d - 2.0, "the lancer swims to it")
	check(lancer.is_unaware(), "investigating a decoy is not noticing the sub")
	for i in 400:
		level.tick(0.05)
	check(decoy.anchored, "the decoy settled on rock")
	check(not decoy.alive and not level.entities.has(decoy), "the decoy burns out")
	level.free()


func test_whisper_carries_decoys_and_saves_them() -> void:
	var run := RunState.new()
	run.frame_id = &"whisper"
	run.rebuild_stats({})
	run.refill()
	check(run.stats.has_tool(&"decoy") and run.decoys == 3, "the Whisper launches decoys")
	run.decoys = 1
	var copy := RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), {})
	check_eq(copy.decoys, 1, "decoys survive a resumed dive")
	run.add_module(&"decoy_rack", {})
	check_eq(run.decoys, 3, "a decoy rack adds two decoys at once")
