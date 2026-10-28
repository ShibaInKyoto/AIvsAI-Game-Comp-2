extends TestCase
## The Lamplighter guards the reef's way down: she charges a lamp seen from
## afar, a lamp held in her eyes up close dazzles her, only a dazzled
## Lamplighter takes full damage, a flare also dazzles her, and killing her
## opens the exit.

const DT := 1.0 / 30.0


func _lair(run: RunState) -> Array:
	var zone := BiomeLibrary.ANGLER_ZONE
	run.run_seed = 77
	run.rebuild_stats({})
	run.refill()
	run.zone = zone
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(zone), run.zone_seed(zone), zone)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	LevelPopulator.populate(level, run)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, layout.start)
	sub.input_enabled = false
	level.player = sub
	return [level, sub, level.guardian as Lamplighter]


## Holds the sub [param dist] in front of her face with the lamp on her eyes.
func _face(sub: Submarine, angler: Lamplighter, dist: float) -> void:
	sub.pos = angler.head_pos() + angler.facing * dist
	sub.vel = Vector2.ZERO
	sub.aim = (angler.head_pos() - sub.pos).normalized()


func test_reef_lair_is_sealed_by_the_lamplighter() -> void:
	var parts := _lair(RunState.new())
	var level: Level = parts[0]
	check(parts[2] != null, "the Lamplighter guards the reef's exit")
	check(level.exit_sealed, "the way down is sealed")
	level.free()


func test_light_draws_a_charge_and_dazzles_up_close() -> void:
	var parts := _lair(RunState.new())
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var angler: Lamplighter = parts[2]
	sub.lamp_on = false
	angler.take_damage(1.0, angler.pos)
	check(angler.active, "a hit wakes her")
	# A lamp seen from across the lair, not shone in her eyes.
	var far := level.layout.field.resolve_circle(angler.lair_center - Vector2(angler.lair_radius.x * 0.7, 0.0), 2.0)
	var charged := false
	for i in 150:
		sub.pos = far
		sub.vel = Vector2.ZERO
		sub.aim = (sub.pos - angler.head_pos()).normalized()
		sub.lamp_on = true
		level.tick(DT)
		if angler.state == Lamplighter.State.WINDUP or angler.state == Lamplighter.State.CHARGE:
			charged = true
			break
	check(charged, "a lamp seen from afar draws a charge")
	angler.state = Lamplighter.State.STALK
	var dazzled := false
	for i in 90:
		_face(sub, angler, 9.0)
		sub.lamp_on = true
		level.tick(DT)
		if angler.state == Lamplighter.State.DAZZLED:
			dazzled = true
			break
	check(dazzled, "a lamp held in her eyes up close dazzles her")
	var before := angler.hp
	angler.take_damage(20.0, angler.pos)
	check_near(before - angler.hp, 20.0, 0.01, "dazzled, she takes the full blow")
	angler.state = Lamplighter.State.STALK
	before = angler.hp
	angler.take_damage(20.0, angler.pos)
	check(before - angler.hp < 3.0, "otherwise her scales turn most of it")
	var opened := [false]
	angler.defeated.connect(func() -> void: opened[0] = true)
	angler.state = Lamplighter.State.DAZZLED
	angler.take_damage(10000.0, angler.pos)
	check(opened[0], "she dies")
	check(not level.exit_sealed, "the way down opens")
	level.free()


func test_a_flare_in_the_lair_is_swallowed_and_dazzles_her() -> void:
	var parts := _lair(RunState.new())
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var angler: Lamplighter = parts[2]
	sub.lamp_on = false
	sub.pos = level.layout.start
	angler.take_damage(1.0, angler.pos)
	var flare := Flare.new()
	flare.pos = angler.head_pos() + angler.facing * 5.0
	level.add_entity(flare)
	var dazzled := false
	for i in 240:
		level.tick(DT)
		if angler.state == Lamplighter.State.DAZZLED:
			dazzled = true
			break
	check(dazzled, "she goes for the flare and it dazzles her")
	check(not flare.alive, "the flare is swallowed")
	level.free()
