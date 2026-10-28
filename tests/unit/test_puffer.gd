extends TestCase
## Spined puffers swell when rushed and burst over their neighbours.


func _open_point(level: Level, near: Vector2) -> Vector2:
	for r in [0.0, 6.0, 12.0, 18.0]:
		for i in 16:
			var p: Vector2 = near + Vector2.from_angle(TAU * i / 16.0) * r
			if level.field.sample(p) > 7.0:
				return p
	return near


func test_puffer_swells_when_rushed_and_bursts_over_neighbours() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var run := RunState.new()
	run.rebuild_stats({})
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(0), 4040, 0)
	var level := Level.new()
	tree.root.add_child(level)
	level.build(layout, 0)
	var at := _open_point(level, layout.start + Vector2(0.0, -20.0))
	var puffer := Puffer.new()
	puffer.pos = at
	level.add_entity(puffer)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, at + Vector2(5.0, 0.0))
	sub.input_enabled = false
	level.player = sub
	sub.noise_radius = 3.0
	puffer.think()
	check(puffer.state == Puffer.State.CALM, "a quiet sub drifting past leaves it calm")
	sub.noise_radius = 14.0
	puffer.think()
	check(puffer.state == Puffer.State.PUFFED, "a rushing sub startles it")
	check(puffer.is_hostile(), "swollen, it is a threat")
	var lancer: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	lancer.pos = at + Vector2(-2.0, 0.0)
	level.add_entity(lancer)
	var hp := lancer.hp
	puffer.on_harpoon_hit(null, 5.0)
	check(not puffer.alive, "harpooned while swollen, it bursts")
	check(lancer.hp <= hp - Puffer.NOVA_DAMAGE + 0.01, "its spines hit the lancer beside it")
	level.free()
