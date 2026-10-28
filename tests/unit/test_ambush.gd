extends TestCase
## Harpooning a creature that has not noticed the sub deals double damage.


func test_ambush_doubles_harpoon_damage() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(2), 77, 2)
	var level := Level.new()
	tree.root.add_child(level)
	level.build(layout, 0)
	var unaware: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	unaware.pos = layout.start + Vector2(4, 0)
	level.add_entity(unaware)
	var aware: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	aware.pos = layout.start + Vector2(-4, 0)
	level.add_entity(aware)
	aware.alert()
	check(unaware.is_unaware() and not aware.is_unaware(), "awareness tracks noticing the sub")
	var hp_a := unaware.hp
	var hp_b := aware.hp
	unaware.on_harpoon_hit(null, 5.0)
	aware.on_harpoon_hit(null, 5.0)
	check_near(hp_a - unaware.hp, 5.0 * Creature.AMBUSH_MULT, 0.01, "ambush damage")
	check_near(hp_b - aware.hp, 5.0, 0.01, "normal damage once it has noticed")
	level.free()
