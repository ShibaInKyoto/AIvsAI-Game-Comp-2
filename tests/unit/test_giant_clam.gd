extends TestCase
## Giant clams sit on the Twilight Reef floor: shut in the lamp's light or at
## a loud noise, open after a few seconds of dark and quiet, the pearl only
## to be had while they gape, and a bite for whatever swims into one.

const DT := 1.0 / 20.0


func _zone_level(zone: int, run_seed: int) -> Array:
	var run := RunState.new()
	run.run_seed = run_seed
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	return [level, run]


func _clams(level: Level) -> Array[GiantClam]:
	var out: Array[GiantClam] = []
	for e in level.entities:
		if e is GiantClam:
			out.append(e)
	return out


## The sub parked a few metres off [param clam], up in open water.
func _with_sub(level: Level, run: RunState, clam: GiantClam) -> Submarine:
	var sub := Submarine.new()
	level.add_child(sub)
	var at := clam.pos + Vector2(0.0, 5.0)
	for k in 12:
		var p := clam.pos + Vector2.from_angle(PI * 0.15 + PI * 0.7 * k / 11.0) * 6.0
		if level.field.sample(p) > 2.0:
			at = p
			break
	sub.setup(level, run, at)
	sub.input_enabled = false
	level.player = sub
	return sub


func _run(clam: GiantClam, seconds: float) -> void:
	for i in int(seconds / DT):
		clam.level.time += DT
		clam.tick(DT)


func test_on_the_reef_floor_only() -> void:
	var total := 0
	for run_seed in [5, 21, 64, 300]:
		for zone in [2, 3]:
			var parts := _zone_level(zone, run_seed)
			var level: Level = parts[0]
			for c in _clams(level):
				total += 1
				# Measured straight down (the field's distances are loose near carved lairs).
				var floor_y := MeridianStation.floor_below(level.field, c.pos + Vector2(0.0, 0.6), 3.0)
				check(floor_y != -INF and c.pos.y - floor_y < 1.3, "resting on the floor")
				check(not LevelPopulator.in_guarded_room(level, c.pos), "not in the lair")
			level.free()
	check(total >= 6, "the reef has its clams (%d in 8 zones)" % total)
	for zone in [0, 4]:
		var parts := _zone_level(zone, 5)
		check(_clams(parts[0]).is_empty(), "none in zone %d" % zone)
		(parts[0] as Level).free()


func test_light_shuts_it_and_the_dark_opens_it() -> void:
	var level: Level = null
	var run: RunState = null
	var clam: GiantClam = null
	for run_seed in [5, 21, 64, 300]:
		var parts := _zone_level(2, run_seed)
		var found := _clams(parts[0])
		if not found.is_empty():
			level = parts[0]
			run = parts[1]
			clam = found[0]
			break
		(parts[0] as Level).free()
	check(clam != null, "a clam to watch")
	if clam == null:
		return
	var sub := _with_sub(level, run, clam)
	sub.lamp_on = true
	sub.aim = (clam.pos - sub.pos).normalized()
	_run(clam, 6.0)
	check(clam.openness == 0.0, "lit, it stays shut")
	# A harpoon on the shut shell gets nothing.
	var research := run.research
	clam.on_harpoon_hit(null, 10.0)
	check(clam.has_pearl and run.research == research, "the pearl cannot be had through the shell")
	sub.lamp_on = false
	_run(clam, GiantClam.CALM_TIME + GiantClam.OPEN_TIME + 0.5)
	check(clam.state == GiantClam.State.OPEN, "dark and quiet, it gapes")
	# A loud noise close by and it snaps shut.
	level.emit_noise(clam.pos + Vector2(2.0, 1.0), 14.0)
	_run(clam, 0.5)
	check(clam.openness < 0.2, "a loud noise shuts it")
	level.noises.clear()
	_run(clam, GiantClam.CALM_TIME + GiantClam.OPEN_TIME + 0.5)
	clam.on_harpoon_hit(null, 10.0)
	check(not clam.has_pearl, "harpooned while it gapes, the pearl comes out")
	check_eq(run.research, research + GiantClam.PEARL_RESEARCH, "and earns research")
	clam.on_harpoon_hit(null, 10.0)
	check_eq(run.research, research + GiantClam.PEARL_RESEARCH, "only once")
	level.free()


func test_it_bites_what_swims_in() -> void:
	var parts := _zone_level(2, 21)
	var level: Level = parts[0]
	var found := _clams(level)
	if found.is_empty():
		level.free()
		return
	var clam := found[0]
	var sub := _with_sub(level, parts[1], clam)
	sub.lamp_on = false
	_run(clam, GiantClam.CALM_TIME + GiantClam.OPEN_TIME + 0.5)
	var hull := sub.run.hull
	sub.pos = clam.pos + Vector2(0.8, 0.6)
	_run(clam, 0.2)
	check(sub.run.hull < hull, "it bites")
	check(clam.state == GiantClam.State.CLOSING or clam.state == GiantClam.State.CLOSED, "and clamps shut")
	level.free()
