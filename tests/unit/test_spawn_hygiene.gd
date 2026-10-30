extends TestCase
## Nothing that swims or drifts starts a zone inside the rock, on top of
## something else, or down the descent fissure out of reach.


func test_zones_settle_clean() -> void:
	for zone in range(0, BiomeLibrary.TOTAL_ZONES - 1):
		for run_seed in [5, 13]:
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
			var tag := "zone %d seed %d" % [zone, run_seed]
			var bodies: Array[Entity] = []
			for e in level.entities:
				var swimmer: bool = e is Creature and not (e is Guardian) and not (e is Shoal) \
					and not LevelPopulator.WALL_DWELLERS.has((e as Creature).species)
				if swimmer or e is SalvageCache or e is LogBeacon:
					bodies.append(e)
					check(level.field.sample(e.pos) >= e.radius * 0.9, "%s: %s clear of the rock" % [tag, e.name])
				if e is Pickup or e is SalvageCache or e is Creature:
					check(not LevelPopulator._past_exit(layout, e.pos), "%s: nothing down the descent" % tag)
			for i in bodies.size():
				for j in range(i + 1, bodies.size()):
					var a := bodies[i]
					var b := bodies[j]
					check(a.pos.distance_to(b.pos) >= a.radius + b.radius, "%s: no two on top of each other" % tag)
			level.free()
