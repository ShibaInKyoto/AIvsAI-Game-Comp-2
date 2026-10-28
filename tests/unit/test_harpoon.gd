extends TestCase
## The harpoon drags small creatures in, and lets go of one snagged on rock
## rather than staying hooked (and useless) for good.

const DT := 1.0 / 60.0


## Somewhere with at least 5 m of open water all round, searching outwards.
func _open_point(level: Level, near: Vector2) -> Vector2:
	for r in range(0, 60, 3):
		for i in 24:
			var p: Vector2 = near + Vector2.from_angle(TAU * i / 24.0) * r
			if level.field.sample(p) > 5.0:
				return p
	return near


## A level with the sub in open water and a tough lancer 6 m to its right,
## already hooked.
func _hooked() -> Array:
	var run := RunState.new()
	run.rebuild_stats({})
	var layout := LevelGenerator.new().generate(BiomeLibrary.biome_for_zone(2), 4242, 2)
	var level := Level.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(level)
	level.build(layout, 0)
	var at := _open_point(level, layout.start)
	var sub := Submarine.new()
	level.add_child(sub)
	sub.setup(level, run, at - Vector2(3.0, 0.0))
	sub.input_enabled = false
	level.player = sub
	var fish := Lancer.new()
	fish.pos = at + Vector2(3.0, 0.0)
	level.add_entity(fish)
	fish.max_hp = 1000.0
	fish.hp = 1000.0
	fish.stun(10.0)
	sub.aim = Vector2.RIGHT
	sub.harpoon.fire(Vector2.RIGHT)
	sub.harpoon.release()
	for i in 30:
		sub.harpoon.tick(DT)
		if sub.harpoon.state != Harpoon.State.FLYING:
			break
	return [level, sub, fish]


func test_drags_a_creature_in() -> void:
	var parts := _hooked()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var fish: Lancer = parts[2]
	check_eq(sub.harpoon.state, Harpoon.State.ATTACHED, "the harpoon hooks the lancer")
	var start := fish.pos.distance_to(sub.pos)
	for i in 60:
		sub.harpoon.tick(DT)
		fish.tick(DT)
		if sub.harpoon.state != Harpoon.State.ATTACHED:
			break
	check(fish.pos.distance_to(sub.pos) < start - 2.0, "the catch is reeled towards the sub")
	level.free()


func test_lets_go_of_a_snagged_catch() -> void:
	var parts := _hooked()
	var level: Level = parts[0]
	var sub: Submarine = parts[1]
	var fish: Lancer = parts[2]
	var pinned := fish.pos
	var held := 0.0
	while held < 5.0 and sub.harpoon.state == Harpoon.State.ATTACHED:
		sub.harpoon.tick(DT)
		# Snagged: the reel cannot move it.
		fish.pos = pinned
		fish.vel = Vector2.ZERO
		held += DT
	check(sub.harpoon.state != Harpoon.State.ATTACHED, "a catch that will not come is let go")
	check(held < Harpoon.DRAG_STALL + 0.5, "soon after it stops coming (held %.1f s)" % held)
	level.free()
