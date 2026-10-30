extends TestCase
## Builds, populates and simulates a zone under every zone event, so each
## event's special cases (wrecks, blackout lighting, currents...) run.

const STEPS := 240
const DT := 1.0 / 30.0


func test_every_event_builds_and_simulates() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for event: StringName in ZoneEvents.EVENTS:
		var zone := 3
		var run := RunState.new()
		run.run_seed = 4242
		run.rebuild_stats({})
		run.refill()
		run.zone = zone
		var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
		var level := Level.new()
		tree.root.add_child(level)
		level.build(layout, 0, 0, event)
		check_eq(level.event, event)
		LevelPopulator.populate(level, run)
		var sub := Submarine.new()
		level.add_child(sub)
		sub.setup(level, run, layout.start)
		sub.input_enabled = false
		level.player = sub
		for i in STEPS:
			sub.external_move = Vector2(0.3, -1.0).normalized()
			sub.tick(DT)
			level.tick(DT)
		check(not is_nan(sub.pos.x) and level.field.sample(sub.pos) > 0.0, "%s: sub stays in open water" % event)
		level.free()


func test_daily_dive_has_one_condition() -> void:
	var run := RunState.new()
	run.daily = true
	run.daily_event = ZoneEvents.daily("2026-10-28")
	check(ZoneEvents.EVENTS.has(run.daily_event), "a real condition")
	check_eq(ZoneEvents.daily("2026-10-28"), run.daily_event, "stable for the day")
	check_eq(ZoneEvents.for_zone(run, 0), ZoneEvents.NONE, "first zone is calm")
	check_eq(ZoneEvents.for_zone(run, BiomeLibrary.TOTAL_ZONES - 1), ZoneEvents.NONE, "no event in the arena")
	for zone in range(1, BiomeLibrary.TOTAL_ZONES - 1):
		check_eq(ZoneEvents.for_zone(run, zone), run.daily_event)
