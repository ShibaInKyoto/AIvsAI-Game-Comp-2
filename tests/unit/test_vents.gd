extends TestCase
## Thermal vents spawn in the vent fields, and an eruption shoves and scalds
## a submarine caught in its column.


func test_vents_spawn_and_erupt() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var zone := 6
	var run := RunState.new()
	run.run_seed = 31337
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	tree.root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	var vents := level.entities.filter(func(e: Entity) -> bool: return e is ThermalVent)
	check(vents.size() >= 2, "the vent fields have erupting vents (%d)" % vents.size())
	if vents.is_empty():
		level.free()
		return
	var vent: ThermalVent = vents[0]
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, vent.pos + vent.normal * 3.0)
	sub.input_enabled = false
	sub.external_move = Vector2.ZERO
	level.player = sub
	check(vent.column_strength(sub.pos, Submarine.RADIUS) > 0.0, "the sub starts inside the column")
	var start := sub.pos
	var hull := run.hull
	vent.erupt_soon()
	for i in 90:
		sub.tick(1.0 / 30.0)
		level.tick(1.0 / 30.0)
	check((sub.pos - start).dot(vent.normal) > 1.5, "the eruption shoves the sub up the column")
	check(run.hull < hull, "the eruption scalds the hull")
	check_eq(run.last_hit_by, &"vent")
	level.free()
