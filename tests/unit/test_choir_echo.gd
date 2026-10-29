extends TestCase
## Above the hadal floor something answers the sub's sonar eleven seconds
## later, from far below; the first ping in a zone always, then sometimes,
## and never its own answer or anyone else's ping.

const DT := 1.0 / 20.0
const HADAL := BiomeLibrary.ZONES_PER_BIOME * (BiomeLibrary.BIOME_COUNT - 1)


func _zone_level(zone: int, run_seed := 7) -> Array:
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


func _echo(level: Level) -> ChoirEcho:
	for e in level.entities:
		if e is ChoirEcho:
			return e
	return null


func test_only_above_the_hadal_floor() -> void:
	for zone in [HADAL, HADAL + 1]:
		var parts := _zone_level(zone)
		check(_echo(parts[0]) != null, "zone %d answers" % zone)
		(parts[0] as Level).free()
	for zone in [HADAL - 1, BiomeLibrary.TOTAL_ZONES - 1]:
		var parts := _zone_level(zone)
		check(_echo(parts[0]) == null, "zone %d is silent" % zone)
		(parts[0] as Level).free()


func test_a_ping_comes_back_from_below() -> void:
	var parts := _zone_level(HADAL)
	var level: Level = parts[0]
	var run: RunState = parts[1]
	var echo := _echo(level)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, level.layout.start)
	sub.input_enabled = false
	level.player = sub
	var pings: Array[Vector2] = []
	var on_ping := func(origin: Vector2, _r: float) -> void: pings.append(origin)
	Events.sonar_pinged.connect(on_ping)
	# Someone else's ping (a beacon, say) is not answered.
	level.ping(sub.pos + Vector2(20.0, 0.0), 20.0, 2.0)
	check(not echo.pending(), "only the sub's own pings")
	check(sub.try_ping(), "the sub pings")
	check(echo.pending(), "something will answer the first ping")
	pings.clear()
	for i in int((ChoirEcho.DELAY - 1.0) / DT):
		echo.tick(DT)
	check(pings.is_empty(), "not straight away")
	for i in int(2.0 / DT):
		echo.tick(DT)
	check_eq(pings.size(), 1, "eleven seconds later it answers")
	if not pings.is_empty():
		check(pings[0].y < sub.pos.y - 10.0, "from far below")
	check_eq(echo.answers, 1, "once")
	# Its own answer is not answered, and it rests for a while after.
	check(not echo.pending(), "an answer is not answered")
	sub.sonar_cooldown = 0.0
	sub.try_ping()
	check(not echo.pending(), "it rests after answering")
	Events.sonar_pinged.disconnect(on_ping)
	level.free()
