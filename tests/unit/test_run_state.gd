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
