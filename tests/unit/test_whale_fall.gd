extends TestCase
## The whale fall event lays a skeleton along the floor with life gathered
## round it, and the first close look at it pays research once.


func _level(zone: int, run_seed: int) -> Array:
	var run := RunState.new()
	run.run_seed = run_seed
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0, 0, &"whalefall")
	LevelPopulator.populate(level, run)
	return [level, run]


func _fall(level: Level) -> WhaleFall:
	for e in level.entities:
		if e is WhaleFall:
			return e
	return null


func test_skeleton_lies_along_the_floor() -> void:
	var placed := 0
	for zone in [1, 3, 5, 7, 9]:
		var parts := _level(zone, 600 + zone)
		var level: Level = parts[0]
		var fall := _fall(level)
		if fall:
			placed += 1
			check(fall.spine.size() >= 10, "zone %d: a full spine (%d)" % [zone, fall.spine.size()])
			for p in fall.spine:
				if absf(level.field.sample(p)) > 0.6:
					check(false, "zone %d: bone at %s off the floor" % [zone, p])
					break
			var shoals := 0
			for e in level.entities:
				if e is Shoal and e.pos.distance_to(fall.pos) < 12.0:
					shoals += 1
			check(shoals >= 1, "zone %d: fish feed over it" % zone)
		level.free()
	check(placed >= 4, "most zones find room for it (%d of 5)" % placed)


func test_survey_pays_once() -> void:
	var parts := _level(3, 603)
	var level: Level = parts[0]
	var run: RunState = parts[1]
	var fall := _fall(level)
	check(fall != null, "the fall is placed")
	if fall:
		var sub := Submarine.new()
		level.add_child(sub)
		sub.setup(level, run, fall.pos + Vector2(0.0, 4.0))
		sub.input_enabled = false
		level.player = sub
		var research := run.research
		fall.tick(0.05)
		fall.tick(0.05)
		check(fall.surveyed, "a close look surveys it")
		check_eq(run.research, research + WhaleFall.SURVEY_RESEARCH, "once")
	level.free()
