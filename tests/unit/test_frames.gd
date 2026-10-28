extends TestCase
## Every submarine frame builds its model and flies, fires and uses its tools.


func test_every_frame_flies() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(0), 555, 0)
	for f in Catalog.frames():
		var run := RunState.new()
		run.frame_id = f.id
		run.rebuild_stats({})
		run.refill()
		var level := Level.new()
		tree.root.add_child(level)
		level.build(layout, 0)
		var sub := Submarine.new()
		level.add_child(sub)
		sub.setup(level, run, layout.start)
		sub.input_enabled = false
		level.player = sub
		check(sub.model.get_child_count() > 2, "%s builds a model" % f.id)
		for i in 120:
			sub.external_move = Vector2(0.5, -1.0).normalized()
			sub.aim = Vector2.DOWN
			if i % 30 == 5:
				sub.tools.use(sub.aim)
				sub.tools.cycle()
			if i == 10:
				sub.harpoon.fire(sub.aim)
			if i == 40:
				sub.harpoon.release()
			sub.tick(1.0 / 30.0)
			level.tick(1.0 / 30.0)
		check(sub.alive and not is_nan(sub.pos.x), "%s survives a short flight" % f.id)
		level.free()
