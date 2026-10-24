extends TestCase
## Spawns each species next to the submarine so its aggressive states run,
## and checks it behaves physically (finite, out of rock, harmful if hostile).

const DT := 1.0 / 60.0


func test_each_species_engages() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scripts: Dictionary = LevelPopulator.SPECIES.duplicate()
	scripts[&"mimic"] = Mimic
	for id: StringName in scripts:
		var zone := 4
		var run := RunState.new()
		run.run_seed = 3
		run.rebuild_stats({})
		run.refill()
		var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), 11, zone)
		var level := Level.new()
		tree.root.add_child(level)
		level.build(layout, 0)
		var sub := Submarine.new()
		level.add_child(sub)
		var room: LevelLayout.Chamber = layout.chambers_of_kind(&"main")[0] if not layout.chambers_of_kind(&"main").is_empty() else layout.chambers[0]
		sub.setup(level, run, room.center)
		sub.input_enabled = false
		level.player = sub
		var c: Creature = scripts[id].new()
		var anchor := _nearest_anchor(layout, room.center)
		c.pos = anchor.pos + anchor.normal * 0.6
		c.set(&"wall_normal", anchor.normal)
		level.add_entity(c)
		var start_hull := run.hull
		for i in 600:
			# Wiggle towards the creature loudly to provoke it.
			sub.external_move = (c.pos - sub.pos).normalized() * (1.0 if i % 120 < 80 else -1.0)
			sub.tick(DT)
			level.tick(DT)
			if not c.alive:
				break
			if i % 200 == 0:
				sub.try_ping()
		check(not is_nan(c.pos.x) and not is_nan(c.pos.y), "%s position finite" % id)
		if c.alive and id != &"gulper":
			check(level.field.sample(c.pos) > -0.5, "%s stays out of rock (%.2f)" % [id, level.field.sample(c.pos)])
		if c.is_hostile() and id != &"stalker":
			check(run.hull < start_hull, "%s managed to hurt the sub" % id)
		level.free()


func _nearest_anchor(layout: LevelLayout, p: Vector2) -> LevelLayout.Anchor:
	var best: LevelLayout.Anchor = layout.anchors[0]
	for a in layout.anchors:
		if a.pos.distance_to(p) < best.pos.distance_to(p) and a.pos.distance_to(p) > 6.0:
			best = a
	return best
