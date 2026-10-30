extends TestCase
## Creatures with a trick beyond biting: the unkillable lantern chain that
## stings hunters too, the jelly's dying discharge, the lancer that dashes
## itself senseless on rock.

const DT := 1.0 / 30.0


func _level() -> Level:
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(3), 99, 3)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	return level


## Open water with [param clearance] around it near the start.
func _open(level: Level, clearance: float) -> Vector2:
	var p := level.layout.random_open_point(level.rng, clearance)
	return p if p != Vector2.INF else level.layout.start


func test_the_lantern_chain_cannot_be_killed_but_stings_hunters() -> void:
	var level := _level()
	var chain: Creature = LevelPopulator.SPECIES[&"siphon"].new()
	chain.pos = _open(level, 4.0)
	level.add_entity(chain)
	check(not chain.targetable, "weapons find nothing to hold on to")
	chain.take_damage(10000.0, chain.pos)
	check(chain.alive and chain.hp == chain.max_hp, "no blow kills it")
	check(chain.scannable, "it can still be studied")
	var lancer: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	lancer.pos = (chain as Siphonophore).segments[4]
	level.add_entity(lancer)
	var hp := lancer.hp
	for i in 10:
		lancer.pos = (chain as Siphonophore).segments[4]
		chain.think()
	check(lancer.hp < hp, "a hunter brushing the chain is stung")
	level.free()


func test_a_dying_jelly_shocks_what_is_near() -> void:
	var level := _level()
	var at := _open(level, 4.0)
	var jelly: Creature = LevelPopulator.SPECIES[&"jelly"].new()
	jelly.pos = at
	level.add_entity(jelly)
	var near: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	near.pos = at + Vector2(2.5, 0.0)
	level.add_entity(near)
	var far: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	far.pos = at + Vector2(12.0, 0.0)
	level.add_entity(far)
	var hp_near := near.hp
	var hp_far := far.hp
	jelly.take_damage(1000.0, at)
	check(not jelly.alive, "the jelly dies")
	check(near.hp < hp_near and near.is_stunned(), "and its charge shocks and stuns what is close by")
	check_eq(far.hp, hp_far, "but not what is far off")
	level.free()


func test_a_lancer_that_dashes_into_rock_is_stunned() -> void:
	var level := _level()
	var lancer := LevelPopulator.SPECIES[&"lancer"].new() as Lancer
	# Somewhere with rock a few metres to the right.
	var at := level.layout.start
	for a in level.layout.anchors:
		if absf(a.normal.x) > 0.8 and level.field.sample(a.pos + a.normal * 5.0) > 1.5:
			at = a.pos + a.normal * 5.0
			break
	lancer.pos = at
	level.add_entity(lancer)
	var wall := level.field.normal(at) * -1.0
	lancer.set(&"_dash_dir", (Vector2(-signf(level.field.normal(at).x), 0.0)))
	lancer.state = Lancer.State.DASH
	lancer.set(&"_timer", 2.0)
	var stunned := false
	for i in int(1.5 / DT):
		lancer.tick(DT)
		if lancer.is_stunned():
			stunned = true
			break
	check(stunned, "it is left reeling (dash towards %s)" % wall)
	level.free()


func test_a_bloom_of_jellies_goes_off_in_a_chain() -> void:
	var level := _level()
	var at := _open(level, 6.0)
	var jellies: Array[Creature] = []
	for i in 4:
		var jelly: Creature = LevelPopulator.SPECIES[&"jelly"].new()
		jelly.pos = at + Vector2(i * 2.0, 0.0)
		level.add_entity(jelly)
		jelly.hp = 1.0
		jellies.append(jelly)
	jellies[0].take_damage(1000.0, at)
	check(jellies.all(func(j: Creature) -> bool: return not j.alive), "each discharge sets off the next, once")
	level.free()
