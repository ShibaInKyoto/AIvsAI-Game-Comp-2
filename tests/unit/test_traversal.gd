extends TestCase
## Flies an invulnerable submarine through every zone of a run along the
## grid path to the exit, with real collision, to prove each zone can be
## physically crossed (not just flood-filled).

const DT := 1.0 / 30.0
const MAX_SECONDS := 150.0


func test_every_zone_is_crossable() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for zone in BiomeLibrary.TOTAL_ZONES - 1:
		var run := RunState.new()
		run.run_seed = 4321
		run.rebuild_stats({})
		run.refill()
		run.zone = zone
		var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
		var route := layout.find_path(layout.start, layout.exit)
		check(not route.is_empty(), "zone %d has a route to the exit" % zone)
		if route.is_empty():
			continue
		var level := Level.new()
		tree.root.add_child(level)
		level.build(layout, 0)
		var sub := Submarine.new()
		level.add_child(sub)
		sub.setup(level, run, layout.start)
		sub.input_enabled = false
		level.player = sub
		var reached := [false]
		level.exit_reached.connect(func() -> void: reached[0] = true)
		var idx := 0
		var t := 0.0
		while t < MAX_SECONDS and not reached[0]:
			while idx < route.size() - 1 and sub.pos.distance_to(route[idx]) < 2.5:
				idx += 1
			sub.external_move = (route[mini(idx + 1, route.size() - 1)] - sub.pos).normalized()
			run.hull = sub.stats.max_hull
			run.battery = sub.stats.max_battery
			sub.tick(DT)
			level.tick(DT)
			t += DT
		check(reached[0], "zone %d crossed (stopped %.0f m from the exit after %.0f s)" % [
			zone, sub.pos.distance_to(layout.exit), t])
		level.free()
