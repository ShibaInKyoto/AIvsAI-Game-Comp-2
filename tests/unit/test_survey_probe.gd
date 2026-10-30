extends TestCase
## Meridian's lost survey probes lie in the side rooms of the zones below the
## first; hooked and reeled in (or bumped into) they are worth research.


func _level(zone: int, run_seed: int) -> Array:
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


func _probes(level: Level) -> Array[SurveyProbe]:
	var out: Array[SurveyProbe] = []
	for e in level.entities:
		if e is SurveyProbe:
			out.append(e)
	return out


func test_probes_wait_in_the_side_rooms() -> void:
	var found := 0
	for run_seed in [3, 30, 300]:
		var parts := _level(2, run_seed)
		var level: Level = parts[0]
		for p in _probes(level):
			found += 1
			check(level.field.sample(p.pos) > 0.3, "in open water")
			# Settled on a floor, it is reached from the water just above.
			check(level.layout.is_reachable(p.pos) or level.layout.is_reachable(p.pos + Vector2(0.0, 1.0)),
				"where the sub can reach it")
			check(p.pos.distance_to(level.layout.start) > 25.0, "away from the way in")
		level.free()
	check(found >= 3, "a probe or two in each zone (%d in three)" % found)
	var first: Level = _level(0, 3)[0]
	check(_probes(first).is_empty(), "none in the first zone")
	first.free()


func test_reeling_one_in_pays_research() -> void:
	var meta_before := MetaState.from_dict(Game.meta.to_dict())
	Game.meta = MetaState.new()
	var parts := _level(4, 30)
	var level: Level = parts[0]
	var run: RunState = parts[1]
	var probe := _probes(level)[0]
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, probe.pos + Vector2(6.0, 0.0))
	sub.input_enabled = false
	level.player = sub
	check_eq(probe.on_harpoon_hit(null, 10.0), Entity.HarpoonReaction.DRAG, "the harpoon hooks it")
	var research := run.research
	probe.on_reeled_in(sub)
	check_eq(run.research, research + probe.research(), "reeled in, its logs pay research")
	check(probe.research() > SurveyProbe.RESEARCH_BASE, "more the deeper it lay")
	check_eq(run.probes, 1)
	check_eq(Game.meta.probes_recovered, 1, "and count towards the Surveyor")
	probe.on_reeled_in(sub)
	check_eq(run.probes, 1, "only once")
	level.free()
	Game.meta = meta_before
	Game.save_game()
