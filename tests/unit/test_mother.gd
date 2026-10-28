extends TestCase
## The Blind Mother guards the lair zone: the way down is sealed while she
## lives, noise beside a wall makes her lunge into the rock and stick, only
## a stuck Mother takes full damage, and killing her opens the exit.

const DT := 1.0 / 30.0


func _lair_level(run: RunState) -> Level:
	var zone := BiomeLibrary.LAIR_ZONE
	run.run_seed = 2024
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	return level


func test_lair_is_sealed_and_guarded() -> void:
	var run := RunState.new()
	var level := _lair_level(run)
	var lair: LevelLayout.Chamber = level.layout.chambers_of_kind(&"exit")[0]
	check(lair.radius.x >= 20.0, "the lair is a big room")
	check(is_instance_valid(level.guardian), "the Blind Mother is there")
	check(level.exit_sealed, "the way down is sealed")
	level.free()


func test_noise_by_a_wall_makes_her_stick_and_open_up() -> void:
	var run := RunState.new()
	var level := _lair_level(run)
	var mother := level.guardian
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, level.layout.start)
	sub.input_enabled = false
	level.player = sub
	mother.take_damage(1.0, mother.pos)
	check(mother.active, "a hit wakes her")
	# A loud sound right against the lair wall.
	var wall := mother.lair_center + Vector2(mother.lair_radius.x * 0.95, 0.0)
	var water := level.layout.field.resolve_circle(wall, 2.0)
	var stuck := false
	for i in 300:
		if i % 15 == 0:
			level.emit_noise(water, 60.0)
		level.tick(DT)
		if mother.state == BlindMother.State.STUCK:
			stuck = true
			break
	check(stuck, "she lunges at the sound and wedges herself in the rock")
	var before := mother.hp
	mother.take_damage(20.0, mother.pos)
	check_near(before - mother.hp, 20.0, 0.01, "stuck, her gills take the full blow")
	mother.state = BlindMother.State.PROWL
	before = mother.hp
	mother.take_damage(20.0, mother.pos)
	check(before - mother.hp < 3.0, "free, her hide turns most of it")
	var opened := [false]
	mother.defeated.connect(func() -> void: opened[0] = true)
	mother.state = BlindMother.State.STUCK
	mother.take_damage(10000.0, mother.pos)
	check(opened[0], "she dies")
	check(not level.exit_sealed, "the way down opens")
	level.free()
