extends TestCase
## Mid-dive, a pilot can see which modules are installed: the pause menu's
## panel lists each with what it does, and the stop names them in a line.


func _run_with(ids: Array[StringName]) -> RunState:
	var run := RunState.new()
	run.rebuild_stats({})
	for id in ids:
		run.add_module(id, {})
	return run


func test_the_installed_modules_are_listed() -> void:
	var mods := Catalog.modules()
	var a: StringName = mods[0].id
	var b: StringName = mods[1].id
	var run := _run_with([a, b, a])
	var line := DecompressionStop.installed_text(run)
	check(line.contains(Catalog.module(a).name + " x2"), "stacked modules show their count")
	check(line.contains(Catalog.module(b).name), "each module is named")
	var panel := ModulesPanel.new()
	panel.run = run
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	var texts: Array[String] = []
	for l in panel.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	var joined := "\n".join(texts)
	check(joined.contains(Catalog.module(b).description), "the panel says what each does")
	panel.free()
