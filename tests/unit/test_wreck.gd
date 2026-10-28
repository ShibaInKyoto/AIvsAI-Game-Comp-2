extends TestCase
## The cargo insurance does not cover waits in the wreck of the last sub, in
## the zone where it imploded, until a later dive recovers it.


func test_the_wreck_waits_in_its_zone_and_gives_back_the_cargo() -> void:
	var meta := Game.meta
	var saved := [meta.wreck_zone, meta.wreck_frame, meta.wreck_cargo]
	meta.record_wreck(1, &"mako", 75)
	var run := RunState.new()
	run.run_seed = 99
	run.rebuild_stats({})
	run.refill()
	run.zone = 1
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(1), run.zone_seed(1), 1)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	var wreck: LostWreck = null
	for e in level.entities:
		if e is LostWreck:
			wreck = e
	check(wreck != null, "the wreck lies in the zone where it sank")
	if wreck:
		check_eq(wreck.frame_id, &"mako", "it is the sub that was lost")
		check_eq(wreck.cargo, 75, "with the uninsured cargo aboard")
		check(level.field.sample(wreck.pos) > 1.0, "in open water the sub can reach")
		var sub := Submarine.new()
		level.add_child(sub)
		sub.setup(level, run, layout.start)
		level.player = sub
		wreck.recover(sub)
		var spilled := 0
		for e in level.entities:
			if e is Pickup and (e as Pickup).kind == &"salvage" and e.alive:
				spilled += (e as Pickup).amount
		check(spilled >= 75, "the cargo spills out to be collected (%d)" % spilled)
		check(not meta.has_wreck(), "recovered, the wreck is gone for good")
	level.free()
	meta.record_wreck(saved[0], StringName(saved[1]), saved[2])


func test_the_wreck_survives_a_save() -> void:
	var m := MetaState.new()
	check(not m.has_wreck(), "no wreck to start with")
	m.record_wreck(4, &"whisper", 120)
	var copy := MetaState.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(copy.has_wreck() and copy.wreck_zone == 4 and copy.wreck_cargo == 120, "it survives a save")
	var d := m.to_dict()
	d.wreck_frame = "no_such_sub"
	check(not MetaState.from_dict(d).has_wreck(), "a wreck of an unknown sub is dropped")
