extends TestCase
## Every zone of the dive must generate a traversable cave.

const SEEDS := [1, 77, 4242]


func test_all_zones_are_traversable() -> void:
	for zone in BiomeLibrary.TOTAL_ZONES - 1:
		for s in SEEDS:
			var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), s, zone)
			var tag := "zone %d seed %d" % [zone, s]
			check(layout.is_reachable(layout.start), "%s: start reachable" % tag)
			check(layout.is_reachable(layout.exit), "%s: exit reachable" % tag)
			check(layout.field.sample(layout.start) > LevelGenerator.SUB_CLEARANCE, "%s: start has clearance" % tag)
			check(layout.anchors.size() > 50, "%s: enough wall anchors (%d)" % [tag, layout.anchors.size()])
			check(layout.chambers_of_kind(&"exit").size() == 1, "%s: one exit room" % tag)


func test_generation_is_deterministic() -> void:
	var a := LevelGenerator.new().generate(BiomeLibrary.get_biome(2), 99, 4)
	var b := LevelGenerator.new().generate(BiomeLibrary.get_biome(2), 99, 4)
	check_eq(a.field.data.size(), b.field.data.size())
	check(a.field.data == b.field.data, "same seed gives identical fields")
	check_eq(a.exit, b.exit)


func test_field_has_no_nan() -> void:
	var layout := LevelGenerator.new().generate(BiomeLibrary.get_biome(4), 5, 8)
	for v in layout.field.data:
		if is_nan(v) or is_inf(v):
			check(false, "field contains NaN/INF")
			return


func test_generation_is_fast() -> void:
	var t := Time.get_ticks_msec()
	LevelGenerator.new().generate(BiomeLibrary.get_biome(4), 3, 9)
	check(Time.get_ticks_msec() - t < 3000, "generation took %d ms" % (Time.get_ticks_msec() - t))
