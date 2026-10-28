extends TestCase
## Run bookkeeping: stat rebuilds, modules and seeds.


func _run() -> RunState:
	var r := RunState.new()
	r.run_seed = 1234
	r.rebuild_stats({})
	r.refill()
	return r


func test_module_grants_new_capacity() -> void:
	var r := _run()
	r.hull = 50.0
	r.add_module(&"plating", {})
	check_near(r.hull, 75.0, 0.01, "plating adds its bonus to current hull")
	check_near(r.stats.max_hull, 125.0, 0.01)


func test_glass_cannon_clamps_hull() -> void:
	var r := _run()
	r.add_module(&"glass_cannon", {})
	check(r.hull <= r.stats.max_hull)


func test_zone_seeds_differ() -> void:
	var r := _run()
	check(r.zone_seed(0) != r.zone_seed(1))
	check_eq(r.zone_seed(3), r.zone_seed(3))


func test_snapshot_round_trip() -> void:
	var r := RunState.new()
	r.run_seed = 777
	r.frame_id = &"mako"
	r.zone = 5
	r.modules = [&"torpedo_rack", &"warhead"]
	r.rebuild_stats({})
	r.refill()
	r.hull = 33.0
	r.salvage = 120
	r.daily = true
	r.daily_event = &"blackout"
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())), {})
	check_eq(back.run_seed, 777)
	check_eq(back.frame_id, &"mako")
	check_eq(back.zone, 5)
	check_eq(back.modules.size(), 2)
	check_near(back.hull, 33.0, 0.01)
	check_eq(back.salvage, 120)
	check_eq(back.daily_event, &"blackout")
	check_eq(back.stats.torpedo_capacity, r.stats.torpedo_capacity)


func test_snapshot_rejects_garbage() -> void:
	var back := RunState.from_dict({"frame_id": "nope", "zone": 999, "modules": ["fake"], "hull": -5}, {})
	check_eq(back.frame_id, &"lantern")
	check_eq(back.zone, BiomeLibrary.TOTAL_ZONES - 1)
	check(back.modules.is_empty(), "unknown modules dropped")
	check(back.hull >= 1.0, "hull clamped to a living sub")
