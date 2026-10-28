extends TestCase
## The wreck-field event lays hulls on the floor with reachable salvage spots.


func test_wrecks_have_reachable_spots() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	for zone in [1, 3, 5, 7, 9]:
		var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), 77 + zone, zone)
		var level := Level.new()
		level.layout = layout
		level.field = layout.field
		level.biome = layout.biome
		tree.root.add_child(level)
		var rng := RandomNumberGenerator.new()
		rng.seed = zone
		var spots := Wrecks.scatter(level, rng, PackedVector2Array())
		check(spots.size() > 0, "zone %d has room for a wreck" % zone)
		for s in spots:
			check(layout.is_reachable(s), "wreck spot reachable in zone %d" % zone)
		level.free()
