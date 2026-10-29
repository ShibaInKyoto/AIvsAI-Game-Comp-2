extends TestCase
## With Reduce flashing on, bursts of light swell in gently and stay dim, and
## shockwave rings are fainter.


func _lights(parent: Node) -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for c in parent.get_children():
		if c is OmniLight3D:
			out.append(c)
	return out


func test_flashes_swell_instead_of_bursting() -> void:
	var was := Settings.reduce_flashing
	var stage := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(stage)
	Settings.reduce_flashing = false
	Fx.flash(stage, Vector2.ZERO, Color.WHITE, 10.0, 0.5)
	var sudden := _lights(stage)
	check(sudden.size() == 1 and sudden[0].light_energy >= 5.0, "normally a flash starts at full brightness")
	for l in sudden:
		l.free()
	Settings.reduce_flashing = true
	Fx.flash(stage, Vector2.ZERO, Color.WHITE, 10.0, 0.5)
	var gentle := _lights(stage)
	check(gentle.size() == 1 and gentle[0].light_energy == 0.0, "with it on, a flash starts dark and swells in")
	Settings.reduce_flashing = was
	stage.free()


func test_shockwaves_are_fainter() -> void:
	var was := Settings.reduce_flashing
	var stage := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(stage)
	var brightness := []
	for on: bool in [false, true]:
		Settings.reduce_flashing = on
		Fx.shockwave(stage, Vector2.ZERO, 5.0, Color(0.5, 0.5, 0.5))
		var ring := stage.get_child(stage.get_child_count() - 1) as MeshInstance3D
		brightness.append((ring.material_override as StandardMaterial3D).albedo_color.r)
	check(brightness[1] < brightness[0] * 0.5, "the ring is fainter (%.2f vs %.2f)" % [brightness[1], brightness[0]])
	Settings.reduce_flashing = was
	stage.free()
