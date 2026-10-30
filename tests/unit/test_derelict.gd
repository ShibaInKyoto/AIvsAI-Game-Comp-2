extends TestCase
## A sub not yet in the hangar waits as a derelict in its zone; holding
## alongside it copies its schematics, at a cost in battery, and unlocks it.

const DT := 1.0 / 20.0


func test_holding_alongside_unlocks_the_frame() -> void:
	var meta_before := MetaState.from_dict(Game.meta.to_dict())
	Game.meta = MetaState.new()
	var zone := Catalog.frame(&"mako").found_in
	var run := RunState.new()
	run.run_seed = 77
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	var wreck: DerelictFrame
	for e in level.entities:
		if e is DerelictFrame:
			wreck = e
	check(wreck != null and wreck.frame_id == &"mako", "the Mako prototype lies in its zone")
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, wreck.pos + Vector2(0.0, 2.0))
	sub.input_enabled = false
	sub.external_move = Vector2.ZERO
	level.player = sub
	var battery := run.battery
	for i in int((DerelictFrame.COPY_TIME + 0.5) / DT):
		sub.pos = wreck.pos + Vector2(0.0, 2.0)
		sub.vel = Vector2.ZERO
		level.tick(DT)
	check(wreck.recovered, "the schematics are copied")
	check(Game.meta.is_frame_unlocked(&"mako"), "and the Mako joins the hangar")
	check(run.battery < battery - DerelictFrame.COPY_DRAIN * DerelictFrame.COPY_TIME * 0.8,
		"its memory core ran on our battery")
	level.free()
	# Found, it is not laid down again.
	var again := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(again)
	again.build(layout, 0)
	LevelPopulator.populate(again, run)
	check(not again.entities.any(func(e: Entity) -> bool: return e is DerelictFrame), "only until it is found")
	again.free()
	Game.meta = meta_before
	Game.save_game()
