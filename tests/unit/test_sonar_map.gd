extends TestCase
## The sonar chart shows what the last ping found: loot where it lay when
## pinged (and where it lies now, once pinged again), mimics as the loot they
## pretend to be, and moved rock only once a ping reaches it.


func _stage() -> Array:
	var run := RunState.new()
	run.run_seed = 5
	run.rebuild_stats({})
	run.refill()
	run.zone = 4
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(4), run.zone_seed(4), 4)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, layout.start)
	sub.input_enabled = false
	level.player = sub
	var map := SonarMap.new()
	level.add_child(map)
	map.bind(level, sub)
	return [level, sub, map]


func _mark_pos(map: SonarMap, e: Entity) -> Vector2:
	for m: Dictionary in map.get(&"_marks"):
		if m.node == e:
			return m.pos
	return Vector2.INF


func test_a_fresh_ping_shows_where_loot_lies_now() -> void:
	var parts := _stage()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var map: SonarMap = parts[2]
	var cache := SalvageCache.new()
	cache.pos = sub.pos + Vector2(6.0, 0.0)
	level.add_entity(cache)
	level.ping(sub.pos, 40.0, 1.0)
	var first := _mark_pos(map, cache)
	check(first.distance_to(cache.pos) < 0.01, "pinged, the cache is charted")
	cache.pos += Vector2(0.0, -3.0)
	check(_mark_pos(map, cache).distance_to(first) < 0.01, "it sinks: the chart shows where it was")
	level.ping(sub.pos, 40.0, 1.0)
	check(_mark_pos(map, cache).distance_to(cache.pos) < 0.01, "pinged again, it shows where it lies now")
	level.free()


func test_a_mimic_answers_as_loot() -> void:
	var parts := _stage()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var map: SonarMap = parts[2]
	var mimic := Mimic.new()
	mimic.pos = sub.pos + Vector2(6.0, 0.0)
	level.add_entity(mimic)
	level.ping(sub.pos, 40.0, 1.0)
	check(_mark_pos(map, mimic) != Vector2.INF, "a sleeping mimic is charted like a cache")
	level.free()


func test_moved_rock_is_charted_only_once_pinged() -> void:
	var parts := _stage()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var map: SonarMap = parts[2]
	var img: Image = map.get(&"_terrain_img")
	var spot := sub.pos + Vector2(4.0, 0.0)
	var px := Vector2i(int(spot.x), int(-spot.y))
	var before := img.get_pixel(px.x, px.y).v
	# Fill the spot with rock in the field, and say so.
	var cells := level.field.cells_in(Rect2(spot - Vector2.ONE * 2.0, Vector2.ONE * 4.0))
	var values := level.field.read_cells(cells)
	values.fill(-2.0)
	level.field.write_cells(cells, values)
	Events.terrain_changed.emit(Rect2(spot - Vector2.ONE * 2.0, Vector2.ONE * 4.0))
	check_near(img.get_pixel(px.x, px.y).v, before, 0.01, "the chart still shows it as it was")
	level.ping(sub.pos, 40.0, 1.0)
	check(img.get_pixel(px.x, px.y).v < before - 0.2, "until a ping reaches it")
	level.free()
