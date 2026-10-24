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


static func key(action: StringName) -> String:
	var table := GAMEPAD if Settings.using_gamepad else KEYBOARD
	return "[%s]" % table.get(action, String(action))
