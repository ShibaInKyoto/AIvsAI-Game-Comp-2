extends TestCase
## Loose stalactites hang over open water and fall on loud noises.


func _caverns() -> Level:
	var tree := Engine.get_main_loop() as SceneTree
	var run := RunState.new()
	run.run_seed = 5150
	run.rebuild_stats({})
	var zone := 4
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	tree.root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	return level


func _stalactites(level: Level) -> Array[Stalactite]:
	var out: Array[Stalactite] = []
	for e in level.entities:
		if e is Stalactite:
			out.append(e)
	return out


func test_stalactites_hang_over_open_water() -> void:
	var level := _caverns()
	var all := _stalactites(level)
	check(all.size() >= 3, "the caverns have loose rock (%d)" % all.size())
	for s in all:
		check(level.field.sample(s.tip()) > 0.0, "the tip hangs in open water")
		check(level.field.sample(s.base() + Vector2(0.0, 0.6)) < 0.5, "the base is set in the ceiling")
	level.free()


func test_loud_noise_drops_rock_on_whatever_is_below() -> void:
	var level := _caverns()
	var s := _stalactites(level)[0]
	s.active_radius = 100000.0
	level.emit_noise(s.pos, 8.0)
	for i in 10:
		level.tick(0.05)
	check(s.state == Stalactite.State.HANGING, "a quiet noise does nothing")
	var lancer: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	lancer.pos = s.tip() - Vector2(0.0, 1.5)
	level.add_entity(lancer)
	lancer.stun(5.0)
	var hp := lancer.hp
	level.emit_noise(s.pos + Vector2(6.0, 0.0), 35.0)
	for i in 80:
		level.tick(0.05)
	check(not s.alive, "a ping brings it down and it shatters")
	check(not lancer.alive or lancer.hp < hp, "the lancer below is skewered")
	level.free()
