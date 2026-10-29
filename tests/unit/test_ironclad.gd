extends TestCase
## The Ironclad guards the last Abyssal Vents zone: its lair floor is a vent
## field, it walks towards sound (but never towards an eruption), its shell
## turns blows until a vent's heat cracks it, and killing it opens the exit.

const DT := 1.0 / 30.0


func _lair_level(run: RunState, run_seed := 2024) -> Level:
	var zone := BiomeLibrary.FURNACE_ZONE
	run.run_seed = run_seed
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	return level


func _with_sub(level: Level, run: RunState) -> Submarine:
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, level.layout.start)
	sub.input_enabled = false
	level.player = sub
	return sub


func _lair_vents(level: Level) -> Array[ThermalVent]:
	var out: Array[ThermalVent] = []
	for e in level.entities:
		if e is ThermalVent and (e as ThermalVent).in_lair:
			out.append(e)
	return out


func test_lair_is_a_sealed_vent_field() -> void:
	for run_seed in [2024, 77, 31337]:
		var run := RunState.new()
		var level := _lair_level(run, run_seed)
		var boss := level.guardian as Ironclad
		check(boss != null, "seed %d: the Ironclad guards the lair" % run_seed)
		check(level.exit_sealed, "seed %d: the way down is sealed" % run_seed)
		if boss:
			check(_lair_vents(level).size() >= 3, "seed %d: vents on the lair floor (%d)" % [run_seed,
				_lair_vents(level).size()])
			check(level.field.sample(boss.pos) > 1.0, "seed %d: it waits in open water" % run_seed)
			var bulbs := 0
			for e in level.entities:
				if e is GlowBulb and boss.in_lair(e.pos, 1.6):
					bulbs += 1
			check(bulbs >= 2, "seed %d: glow mats to recharge by (%d)" % [run_seed, bulbs])
			# It never climbs down into the fissure, even chasing a sound there.
			_with_sub(level, run)
			boss.take_damage(1.0, boss.pos)
			var floor_y := boss.pos.y
			for i in 240:
				if i % 10 == 0:
					level.emit_noise(level.layout.exit + Vector2(0.0, -4.0), 40.0)
				level.tick(DT)
			check(boss.pos.y > floor_y - 4.0, "seed %d: it bridges the fissure (%.1f below)" % [run_seed,
				floor_y - boss.pos.y])
		level.free()


func test_walks_to_sound_but_not_to_eruptions() -> void:
	var run := RunState.new()
	var level := _lair_level(run)
	var boss := level.guardian as Ironclad
	_with_sub(level, run)
	boss.take_damage(1.0, boss.pos)
	check(boss.active, "a hit wakes it")
	var vent := _lair_vents(level)[0]
	var side := -signf(boss.pos.x - boss.lair_center.x)
	var goal := boss.lair_center + Vector2(side * boss.lair_radius.x * 0.6, 0.0)
	var start_x := boss.pos.x
	for i in 150:
		if i % 10 == 0:
			level.emit_noise(goal, 40.0)
		level.tick(DT)
	check(absf(boss.pos.x - goal.x) < absf(start_x - goal.x) - 4.0, "it walks towards the sound")
	# An eruption's roar alone does not draw it.
	var before := boss.pos.x
	var far_vent: ThermalVent = vent
	for v in _lair_vents(level):
		if absf(v.pos.x - boss.pos.x) > absf(far_vent.pos.x - boss.pos.x):
			far_vent = v
	boss.state = Ironclad.State.CRAWL
	for i in 60:
		level.emit_noise(far_vent.pos, 40.0, far_vent)
		boss.think()
	check(not boss.get(&"_chasing") or absf(boss.get(&"_goal_x") - far_vent.pos.x) > 3.0,
		"a vent's roar is not a sound worth hunting (moved %.1f)" % absf(boss.pos.x - before))
	level.free()


func test_only_heat_cracks_the_shell() -> void:
	var run := RunState.new()
	var level := _lair_level(run)
	var boss := level.guardian as Ironclad
	_with_sub(level, run)
	boss.take_damage(1.0, boss.pos)
	var before := boss.hp
	boss.take_damage(20.0, boss.pos, &"harpoon")
	check(before - boss.hp < 3.0, "plates turn a harpoon")
	boss.take_damage(14.0, boss.pos, &"vent")
	check(boss.exposed > 0.0, "a vent's scald cracks the shell")
	before = boss.hp
	boss.take_damage(20.0, boss.pos, &"harpoon")
	check_near(before - boss.hp, 20.0, 0.01, "cracked, it takes the full blow")
	for i in 200:
		boss.tick(DT)
	check(boss.exposed <= 0.0, "the shell closes again")
	var opened := [false]
	boss.defeated.connect(func() -> void: opened[0] = true)
	boss.exposed = 1.0
	boss.take_damage(10000.0, boss.pos, &"harpoon")
	check(opened[0], "it dies")
	check(not level.exit_sealed, "the way down opens")
	level.free()


func test_an_eruption_under_it_cracks_it() -> void:
	var run := RunState.new()
	var level := _lair_level(run)
	var boss := level.guardian as Ironclad
	_with_sub(level, run)
	boss.take_damage(1.0, boss.pos)
	var vent := _lair_vents(level)[0]
	boss.pos = vent.pos + vent.normal * Ironclad.RIDE
	boss.state = Ironclad.State.SCALDED
	vent.erupt_soon()
	var cracked := false
	for i in 120:
		vent.tick(DT)
		if boss.exposed > 0.0:
			cracked = true
			break
	check(cracked, "standing in the column, the heat splits its plates")
	level.free()


func test_climbs_out_of_the_fissure() -> void:
	# Seed 77's lair has a bowl deeper at the edge than at the fissure's lip,
	# so a slam could knock it down into the fissure, walled in either side.
	var run := RunState.new()
	var level := _lair_level(run, 77)
	var boss := level.guardian as Ironclad
	var sub := _with_sub(level, run)
	boss.take_damage(1.0, boss.pos)
	boss.pos = Vector2(44.57, -259.29)
	boss.state = Ironclad.State.CRAWL
	var goal := boss.lair_center + Vector2(boss.lair_radius.x * 0.5, 0.0)
	sub.pos = goal + Vector2(0.0, 6.0)
	for i in 240:
		if i % 10 == 0:
			level.emit_noise(goal, 40.0)
		level.tick(DT)
	check(boss.pos.y > -257.5, "it climbs out of the fissure (%s)" % boss.pos)
	check(absf(boss.pos.x - goal.x) < absf(44.57 - goal.x) - 4.0, "and walks on towards the sound")
	level.free()
