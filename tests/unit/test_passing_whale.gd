extends TestCase
## A sperm whale passes behind the playfield in the second Sunlit Shelf zone:
## it waits until the sub comes near, swims past it along a stretch of open
## water, charts the cave with its clicks, and is gone at the far end.

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


func _whale(level: Level) -> PassingWhale:
	for e in level.entities:
		if e is PassingWhale:
			return e
	return null


func test_waits_in_the_second_shelf_zone() -> void:
	var found := 0
	for run_seed in [3, 17, 42, 99, 2024]:
		var parts := _zone_level(PassingWhale.ZONE, run_seed)
		var whale := _whale(parts[0])
		if whale:
			found += 1
			var field := (parts[0] as Level).field
			check(whale.to.x - whale.from.x >= PassingWhale.MIN_RUN, "seed %d: a long way to swim" % run_seed)
			var x := whale.from.x
			while x <= whale.to.x:
				check(field.sample(Vector2(x, whale.from.y)) > PassingWhale.CLEARANCE - 0.01,
					"seed %d: open water all along it" % run_seed)
				x += 2.0
			check_eq(whale.state, PassingWhale.State.WAITING, "seed %d: waiting for the sub" % run_seed)
		(parts[0] as Level).free()
	check(found >= 4, "the second shelf zone has one (%d of 5)" % found)
	for zone in [0, 2, 4]:
		var parts := _zone_level(zone, 17)
		check(_whale(parts[0]) == null, "none in zone %d" % zone)
		(parts[0] as Level).free()


func test_passes_the_sub_clicking() -> void:
	var level: Level = null
	var run: RunState = null
	var whale: PassingWhale = null
	for run_seed in [3, 17, 42, 99]:
		var parts := _zone_level(PassingWhale.ZONE, run_seed)
		whale = _whale(parts[0])
		if whale:
			level = parts[0]
			run = parts[1]
			break
		(parts[0] as Level).free()
	if whale == null:
		check(false, "a whale to watch")
		return
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, whale.pos + Vector2(0.0, 2.5))
	sub.input_enabled = false
	level.player = sub
	var pings := [0]
	var on_ping := func(_p: Vector2, _r: float) -> void: pings[0] += 1
	Events.sonar_pinged.connect(on_ping)
	var research := run.research
	var steps := int((whale.to.x - whale.from.x) / PassingWhale.SPEED / DT) + 40
	var closest := INF
	for i in steps:
		level.time += DT
		sub.pos = whale.pos + Vector2(0.0, 2.5)
		whale.tick(DT)
		if whale.state == PassingWhale.State.PASSING:
			closest = minf(closest, whale.whale_pos().distance_to(sub.pos))
	Events.sonar_pinged.disconnect(on_ping)
	check(closest < 4.0, "it swims right past the sub (%.1f m)" % closest)
	check(pings[0] >= 3, "its clicks chart the cave (%d)" % pings[0])
	check(whale.witnessed and run.research == research + PassingWhale.RESEARCH, "witnessed, for research")
	check(Game.meta.wonders.has("whale"), "a wonder")
	check_eq(whale.state, PassingWhale.State.GONE, "and gone at the far end")
	level.free()
