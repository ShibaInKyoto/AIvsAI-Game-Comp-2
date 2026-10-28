class_name Prompt
extends RefCounted
## Human-readable button names for the active input device.

const KEYBOARD: Dictionary[StringName, String] = {
	&"move": "WASD", &"aim": "Mouse", &"fire": "LMB", &"tool": "RMB", &"cycle_tool": "Q",
	&"ping": "Space", &"boost": "Shift", &"lamp": "F", &"map": "Tab", &"pause": "Esc",
}
const GAMEPAD: Dictionary[StringName, String] = {
	&"move": "L-Stick", &"aim": "R-Stick", &"fire": "RT", &"tool": "RB", &"cycle_tool": "LB",
	&"ping": "A", &"boost": "LT", &"lamp": "Y", &"map": "Back", &"pause": "Start",
}


## Rows of [description, keyboard, gamepad] for the controls reference.
const CONTROLS := [
	["Move", "WASD", "Left stick"],
	["Aim lamp and tools", "Mouse", "Right stick"],
	["Harpoon (hold to winch)", "Left mouse", "RT"],
	["Use tool", "Right mouse", "RB"],
	["Cycle tool", "Q", "LB"],
	["Sonar ping", "Space", "A"],
	["Boost", "Shift", "LT"],
	["Toggle lamp", "F", "Y"],
	["Sonar chart", "Tab", "Back"],
	["Pick a module at stops", "1 / 2 / 3", "D-pad + A"],
	["Pause", "Esc", "Start"],
	["Fullscreen", "F11", "-"],
]


## A grid listing every control for keyboard and gamepad.
static func controls_grid(font_size := 20) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 30)
	for row: Array in CONTROLS:
		grid.add_child(UiUtil.label(row[0], &"DimLabel", font_size))
		grid.add_child(UiUtil.label(row[1], &"MonoLabel", font_size))
		grid.add_child(UiUtil.label(row[2], &"MonoLabel", font_size))
	return grid


static func key(action: StringName) -> String:
	var table := GAMEPAD if Settings.using_gamepad else KEYBOARD
	return "[%s]" % table.get(action, String(action))
