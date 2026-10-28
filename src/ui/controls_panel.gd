class_name ControlsPanel
extends CanvasLayer
## Keyboard and mouse rebinding. Pick an action, then press the key or mouse
## button for it; a key another action was using swaps over. Gamepad
## controls, the arrow keys and pause stay as they are.

const NAMES: Dictionary[StringName, String] = {
	&"move_up": "Thrust up", &"move_left": "Thrust left", &"move_down": "Thrust down",
	&"move_right": "Thrust right", &"fire": "Harpoon", &"tool": "Use tool", &"cycle_tool": "Cycle tool",
	&"ping": "Sonar ping", &"boost": "Boost", &"lamp": "Toggle lamp", &"map": "Sonar chart",
}

var _buttons: Dictionary[StringName, Button] = {}
var _waiting: StringName = &""


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := UiUtil.modal(self, 0.8, 980)
	column.add_child(UiUtil.label("CONTROLS", &"TitleLabel"))
	var panel := PanelContainer.new()
	column.add_child(panel)
	# Two actions per row: label, key, label, key.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override(&"h_separation", 28)
	grid.add_theme_constant_override(&"v_separation", 8)
	panel.add_child(grid)
	for action in Settings.REBINDABLE:
		grid.add_child(UiUtil.label(NAMES.get(action, String(action))))
		var b := UiUtil.button("", func() -> void: _listen(action), 190)
		grid.add_child(b)
		_buttons[action] = b
	column.add_child(UiUtil.label("Pick an action, then press its new key or mouse button (Esc cancels). " +
		"Arrow keys and gamepads always work.", &"DimLabel", 17))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 20)
	column.add_child(row)
	row.add_child(UiUtil.button("Reset to defaults", func() -> void:
		Settings.reset_bindings()
		_refresh(), 280))
	var close := UiUtil.button("Back", queue_free, 200)
	row.add_child(close)
	_refresh()
	_buttons[Settings.REBINDABLE[0]].grab_focus()


func _listen(action: StringName) -> void:
	_waiting = action
	_refresh()
	_buttons[action].text = "Press a key..."


func _input(event: InputEvent) -> void:
	if _waiting == &"":
		return
	var chosen: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode != KEY_ESCAPE:
			chosen = event
	elif event is InputEventMouseButton and event.pressed:
		var button := (event as InputEventMouseButton).button_index
		if button < MOUSE_BUTTON_WHEEL_UP or button > MOUSE_BUTTON_WHEEL_RIGHT:
			chosen = event
		else:
			return
	else:
		return
	if chosen:
		Settings.rebind(_waiting, chosen)
		Audio.play_ui(&"ui_click")
	_waiting = &""
	_refresh()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting == &"" and event.is_action_pressed(&"ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for action in _buttons:
		_buttons[action].text = Settings.binding_name(action)
