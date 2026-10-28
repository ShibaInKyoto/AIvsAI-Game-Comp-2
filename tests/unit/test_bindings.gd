extends TestCase
## Rebinding a control: the new key takes over, a key in use swaps over,
## gamepad bindings stay, prompts follow along and a reset restores it all.


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _has_joypad(action: StringName) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			return true
	return false


func test_rebind_swap_and_reset() -> void:
	Settings.reset_bindings()
	check_eq((Settings.primary_event(&"ping") as InputEventKey).physical_keycode, KEY_SPACE, "ping starts on Space")
	Settings.rebind(&"ping", _key(KEY_E))
	check_eq((Settings.primary_event(&"ping") as InputEventKey).physical_keycode, KEY_E, "ping moves to E")
	check(_has_joypad(&"ping"), "the gamepad button still pings")
	check(Prompt.keyboard_name(&"ping") != "Space", "prompts show the new key")
	# Lamp takes E: ping gets the lamp's old key rather than being left unbound.
	Settings.rebind(&"lamp", _key(KEY_E))
	check_eq((Settings.primary_event(&"lamp") as InputEventKey).physical_keycode, KEY_E, "the lamp moves to E")
	check_eq((Settings.primary_event(&"ping") as InputEventKey).physical_keycode, KEY_F, "ping swaps onto F")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	Settings.rebind(&"boost", mouse)
	check_eq(Settings.binding_name(&"boost"), "MMB", "a mouse button can be bound")
	check(Settings.bindings.has("lamp") and Settings.bindings.has("ping"), "rebinds are remembered for saving")
	Settings.reset_bindings()
	check(Settings.bindings.is_empty(), "a reset forgets every rebind")
	check_eq((Settings.primary_event(&"ping") as InputEventKey).physical_keycode, KEY_SPACE, "ping is back on Space")
	check_eq(Settings.primary_event(&"boost").get_class(), "InputEventKey", "boost is back on its key")
	check_eq(InputMap.action_get_events(&"move_up").size(), 3, "no duplicated events after a reset")


func test_saved_rebinds_are_applied_and_bad_ones_dropped() -> void:
	Settings.reset_bindings()
	Settings.bindings = {"map": {"key": KEY_M}, "pause": {"key": KEY_X}, "lamp": "garbage"}
	Settings.call(&"_apply_bindings")
	check_eq((Settings.primary_event(&"map") as InputEventKey).physical_keycode, KEY_M, "a saved rebind applies")
	check(not Settings.bindings.has("pause"), "fixed actions cannot be rebound")
	check(not Settings.bindings.has("lamp"), "malformed entries are dropped")
	Settings.reset_bindings()
