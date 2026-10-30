extends TestCase
## The battery is life support: it drains with the motors as well as the lamp
## and the sonar, and once it is empty a short reserve is all that keeps the
## pilot alive. A sub lost to an empty battery sinks whole with all its cargo;
## a crushed one spills half. Without insurance a lost sub banks nothing, but
## research is kept.

const DT := 1.0 / 20.0


func _stage() -> Array:
	var run := RunState.new()
	run.run_seed = 3
	run.rebuild_stats({})
	run.refill()
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(0), run.zone_seed(0), 0)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, layout.start)
	sub.input_enabled = false
	sub.lamp_on = false
	level.player = sub
	return [level, sub, run]


func test_the_motors_draw_on_the_battery() -> void:
	var parts := _stage()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var run: RunState = parts[2]
	sub.external_move = Vector2.ZERO
	for i in 100:
		sub.tick(DT)
	var idle := run.stats.max_battery - run.battery
	check(idle > 0.0, "life support draws a little even at rest (%.2f)" % idle)
	run.battery = run.stats.max_battery
	sub.external_move = Vector2(1.0, 0.0)
	for i in 100:
		sub.tick(DT)
	var moving := run.stats.max_battery - run.battery
	check(moving > idle * 2.0, "thrust draws more (%.2f against %.2f)" % [moving, idle])
	level.free()


func test_an_empty_battery_is_a_countdown() -> void:
	var parts := _stage()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var run: RunState = parts[2]
	var died := [false]
	sub.died.connect(func() -> void: died[0] = true)
	run.battery = 0.0
	for i in int(Submarine.POWER_GRACE * 0.5 / DT):
		sub.tick(DT)
	check(sub.alive and sub.power_failing > 0.0, "on reserve, the clock is running")
	# A glow bulb's charge resets it.
	sub.add_battery(20.0)
	sub.tick(DT)
	check_eq(sub.power_failing, 0.0, "recharged, the reserve is restored")
	run.battery = 0.0
	for i in int((Submarine.POWER_GRACE + 1.0) / DT):
		sub.tick(DT)
	check(not sub.alive, "the reserve spent, life support fails")
	check(run.lost_power(), "lost to the empty battery")
	level.free()


func test_a_lost_sub_banks_nothing_without_insurance() -> void:
	var meta_before := MetaState.from_dict(Game.meta.to_dict())
	var run_before := Game.run
	for kind in ["power", "implosion"]:
		Game.meta = MetaState.new()
		var run := RunState.new()
		run.rebuild_stats({})
		run.refill()
		run.zone = 3
		run.salvage = 200
		run.research = 30
		if kind == "power":
			run.last_hit_by = &"power"
		else:
			run.hull = 0.0
			run.last_hit_by = &"lancer"
		Game.run = run
		var banked := Game.end_run(RunState.Outcome.IMPLODED)
		check_eq(banked, 0, "%s: no salvage banked, no expedition pay" % kind)
		check_eq(Game.meta.research, 30, "%s: research was transmitted as it was found" % kind)
		check_eq(Game.meta.wreck_kind, kind, "%s: its wreck waits" % kind)
		check_eq(Game.meta.wreck_cargo, 200 if kind == "power" else 100,
			"%s: whole, it keeps all its cargo; crushed, half" % kind)
	Game.meta = meta_before
	Game.run = run_before
	Game.save_game()
