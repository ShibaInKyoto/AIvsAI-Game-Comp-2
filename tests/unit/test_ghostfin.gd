extends TestCase
## Ghostfins hunt the lamp: a lit sub draws them in to circle, going dark
## sends them off, and the hadal floor spawns them in packs.


## Somewhere with at least 5 m of open water all round, searching outwards.
func _open_point(level: Level, near: Vector2) -> Vector2:
	for r in range(0, 60, 3):
		for i in 24:
			var p: Vector2 = near + Vector2.from_angle(TAU * i / 24.0) * r
			if level.field.sample(p) > 5.0:
				return p
	return near


func test_ghostfins_circle_a_lit_lamp_and_lose_interest_in_the_dark() -> void:
	var zone := 8
	var run := RunState.new()
	run.rebuild_stats({})
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), 3030, zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	var at := _open_point(level, layout.start)
	var fin := Ghostfin.new()
	fin.pos = at
	level.add_entity(fin)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, at + Vector2(4.0, 0.0))
	sub.input_enabled = false
	level.player = sub
	sub.lamp_on = true
	for i in 20:
		level.tick(0.05)
	check(fin.state != Ghostfin.State.DRIFT, "a lit lamp draws it in")
	sub.lamp_on = false
	for i in 120:
		level.tick(0.05)
	check(fin.state == Ghostfin.State.DRIFT, "in the dark it loses interest")
	level.free()


func test_ghostfins_come_in_packs() -> void:
	var zone := 8
	var run := RunState.new()
	run.run_seed = 99
	run.rebuild_stats({})
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	var count := 0
	for e in level.entities:
		if e is Ghostfin:
			count += 1
	check(count > 0 and count % 3 == 0, "ghostfins spawn in threes (%d)" % count)
	level.free()
