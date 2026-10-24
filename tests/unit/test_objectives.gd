extends TestCase
## Zone objectives roll sensibly and pay out exactly once.


func _level(zone: int) -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var run := RunState.new()
	run.run_seed = 5
	run.rebuild_stats({})
	run.refill()
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), 21, zone)
	var level := Level.new()
	tree.root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, layout.start)
	level.player = sub
	return [level, sub, run]


func test_first_zone_has_none() -> void:
	var parts := _level(0)
	check(ZoneObjective.roll(parts[0], parts[1], 1) == null, "no objective in the tutorial zone")
	(parts[0] as Level).free()


func test_objectives_complete_once() -> void:
	var parts := _level(3)
	var level: Level = parts[0]
	var run: RunState = parts[2]
	for s in 30:
		var o := ZoneObjective.roll(level, parts[1], s)
		check(o != null, "zone 3 has an objective")
		check(o.describe() != "", "objective has a description")
		var before := run.salvage + run.research
		for i in o.target + 2:
			match o.kind:
				&"caches": Events.cache_opened.emit(Vector2.ZERO)
				&"bulbs": Events.bulb_harvested.emit(Vector2.ZERO)
				&"hunt": Events.creature_killed.emit(&"lancer", Vector2.ZERO)
				&"stalker": Events.creature_killed.emit(&"stalker", Vector2.ZERO)
				&"scan": Events.creature_scanned.emit(&"jelly", false)
				&"log": Events.log_found.emit(&"log_01")
				&"silent": level.exit_reached.emit()
		check(o.done, "%s completes" % o.kind)
		check(run.salvage + run.research == before + o.reward_salvage + o.reward_research, "%s pays once" % o.kind)
		o.release()
	level.free()
