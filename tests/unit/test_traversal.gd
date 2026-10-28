extends TestCase
## Flies an invulnerable submarine through every zone of a run along a grid
## path to the exit, with real collision, to prove each zone can be
## physically crossed (not just flood-filled).

const DT := 1.0 / 30.0
const MAX_SECONDS := 150.0


func test_every_zone_is_crossable() -> void:
	for zone in BiomeLibrary.TOTAL_ZONES - 1:
		_cross(4321, zone)


## A zone whose tightest route hugs a wall round a sharp corner: the roomy
## route a pilot (or the autopilot) would take still gets through.
func test_a_zone_with_a_tight_corner_is_crossable() -> void:
	_cross(1453234075, 0)


func _cross(run_seed: int, zone: int) -> void:
	var run := RunState.new()
	run.run_seed = run_seed
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var route := layout.find_path(layout.start, layout.exit, 1.7)
	if route.is_empty():
		route = layout.find_path(layout.start, layout.exit)
	check(not route.is_empty(), "zone %d has a route to the exit" % zone)
	if route.is_empty():
		return
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, layout.start)
	sub.input_enabled = false
	level.player = sub
	var reached := [false]
	level.exit_reached.connect(func() -> void: reached[0] = true)
	var idx := 0
	var t := 0.0
	while t < MAX_SECONDS and not reached[0]:
		while idx < route.size() - 1 and sub.pos.distance_to(route[idx]) < 2.5:
			idx += 1
		sub.external_move = (route[mini(idx + 1, route.size() - 1)] - sub.pos).normalized()
		run.hull = sub.stats.max_hull
		run.battery = sub.stats.max_battery
		sub.tick(DT)
		level.tick(DT)
		t += DT
	check(reached[0], "zone %d (seed %d) crossed (stopped %.0f m from the exit after %.0f s)" % [
		zone, run_seed, sub.pos.distance_to(layout.exit), t])
	level.free()


## The way to the exit is never a tight squeeze: some route keeps well over
## a sub radius (1.15 m) of water around it in every zone.
func test_route_is_never_a_squeeze() -> void:
	for zone in BiomeLibrary.TOTAL_ZONES - 1:
		for s in 3:
			var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), 1000 + s * 17 + zone, zone)
			check(not layout.find_path(layout.start, layout.exit, 1.6).is_empty(),
				"zone %d seed %d has a route with 1.6 m clearance" % [zone, s])
