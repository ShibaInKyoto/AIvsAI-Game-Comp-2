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


func test_only_the_first_blow_is_an_ambush() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(2), 77, 2)
	var level := Level.new()
	tree.root.add_child(level)
	level.build(layout, 0)
	var struck: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	struck.pos = layout.start + Vector2(4, 0)
	level.add_entity(struck)
	var kin: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	kin.pos = layout.start + Vector2(4, 5)
	level.add_entity(kin)
	var stranger: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	stranger.pos = layout.start + Vector2(4, 30)
	level.add_entity(stranger)
	struck.max_hp = 1000.0
	struck.hp = 1000.0
	struck.on_harpoon_hit(null, 5.0)
	check_near(1000.0 - struck.hp, 5.0 * Creature.AMBUSH_MULT, 0.01, "the first blow is an ambush")
	# Long after, it has not forgotten.
	level.time += Creature.AWARE_TIME * 10.0
	var hp := struck.hp
	struck.on_harpoon_hit(null, 5.0)
	check_near(hp - struck.hp, 5.0, 0.01, "the second is not, however long it has been")
	check(not kin.is_unaware(), "its kind close by heard it")
	check(stranger.is_unaware(), "those far off did not")
	level.free()
