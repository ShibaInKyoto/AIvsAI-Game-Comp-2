extends TestCase
## Left alone, lancers hunt shoals: they dash in, catch fish and feed, and
## none of that counts as noticing the sub.


func _open_point(level: Level, near: Vector2) -> Vector2:
	for r in [0.0, 6.0, 12.0, 18.0, 24.0]:
		for i in 16:
			var p: Vector2 = near + Vector2.from_angle(TAU * i / 16.0) * r
			if level.field.sample(p) > 8.0:
				return p
	return near


func test_lancers_pick_fish_off_shoals() -> void:
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(0), 5555, 0)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	var at := _open_point(level, layout.start + Vector2(0.0, -25.0))
	var shoal := Shoal.new()
	shoal.pos = at
	level.add_entity(shoal)
	var lancer: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	lancer.pos = level.field.resolve_circle(at + Vector2(7.0, 0.0), 1.0)
	level.add_entity(lancer)
	var fish := shoal.fish_pos.size()
	for i in 800:
		level.tick(0.05)
		if not shoal.alive or shoal.fish_pos.size() < fish:
			break
	check(not shoal.alive or shoal.fish_pos.size() < fish, "the lancer caught a fish")
	check(lancer.is_unaware(), "hunting is not noticing the sub")
	level.free()
