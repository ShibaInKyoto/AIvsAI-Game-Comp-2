extends TestCase
## Erasing progress is offered only from the title (never mid-dive) and takes
## two presses: the first only arms the button, and it disarms on its own.
## (The second press is not exercised: it would wipe the local save.)


func _panel(allow: bool) -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel.allow_erase = allow
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	return panel


func test_erase_is_only_offered_when_allowed() -> void:
	var panel := _panel(false)
	check(panel._erase == null, "no erase button mid-dive")
	panel.free()


func test_first_press_only_arms() -> void:
	var meta := Game.meta
	var panel := _panel(true)
	check(panel._erase != null, "the title's settings offer it")
	panel._on_erase()
	check(Game.meta == meta, "one press erases nothing")
	check(panel._erase.text.contains("again"), "it asks for a second press")
	panel._process(SettingsPanel.ERASE_ARM_TIME + 0.1)
	check_eq(panel._erase.text, "Erase progress...", "and disarms after a few seconds")
	panel.free()
