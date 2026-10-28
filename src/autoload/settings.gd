extends Node
## Player preferences (persisted to user://settings.cfg) and the input map.
##
## Input actions are registered in code rather than in project.godot so the
## defaults live next to the code that reads them.

signal changed

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

const PATH := "user://settings.cfg"
const QUALITY_NAMES: PackedStringArray = ["Low", "Medium", "High", "Ultra"]

var master_volume := 0.8
var music_volume := 0.65
var sfx_volume := 0.9
var quality := Quality.HIGH
var fullscreen := true
var vsync := true
var screen_shake := 1.0
var show_fps := false
## Assist mode: the submarine takes much less damage.
var assist := false
## Gamepad rumble on impacts.
var rumble := true
## Last input device used; prompts and aiming adapt to it.
var using_gamepad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_inputs()
	load_settings()
	apply()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		using_gamepad = true
	elif event is InputEventMouseMotion or event is InputEventKey or event is InputEventMouseButton:
		using_gamepad = false


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	master_volume = cfg.get_value("audio", "master", master_volume)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	quality = clampi(cfg.get_value("video", "quality", quality), Quality.LOW, Quality.ULTRA) as Quality
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	vsync = cfg.get_value("video", "vsync", vsync)
	show_fps = cfg.get_value("video", "show_fps", show_fps)
	screen_shake = cfg.get_value("game", "screen_shake", screen_shake)
	assist = cfg.get_value("game", "assist", assist)
	rumble = cfg.get_value("game", "rumble", rumble)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "vsync", vsync)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("game", "screen_shake", screen_shake)
	cfg.set_value("game", "assist", assist)
	cfg.set_value("game", "rumble", rumble)
	cfg.save(PATH)


## Applies window and viewport settings and notifies listeners (audio buses,
## level environments) so they can apply theirs.
func apply() -> void:
	if not DisplayServer.get_name() == "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport()
	match quality:
		Quality.LOW:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.67
		Quality.MEDIUM:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			vp.scaling_3d_scale = 0.85
		Quality.HIGH:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
		Quality.ULTRA:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
	changed.emit()


## Damage multiplier applied to the player's submarine.
func damage_taken_mult() -> float:
	return 0.6 if assist else 1.0


## Short gamepad rumble scaled by [param strength] (0..1).
func rumble_pulse(strength: float, duration := 0.2) -> void:
	if rumble and using_gamepad:
		for pad in Input.get_connected_joypads():
			Input.start_joy_vibration(pad, clampf(strength, 0.0, 1.0) * 0.6, clampf(strength, 0.0, 1.0), duration)


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	save_settings()


# --- Input map ---------------------------------------------------------------

func _register_inputs() -> void:
	_action(&"move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_action(&"move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_action(&"move_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_action(&"move_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_action(&"aim_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_action(&"aim_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_action(&"aim_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_action(&"aim_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_action(&"fire", [_mouse(MOUSE_BUTTON_LEFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action(&"tool", [_mouse(MOUSE_BUTTON_RIGHT), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_action(&"cycle_tool", [_key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER)])
	_action(&"ping", [_key(KEY_SPACE), _joy(JOY_BUTTON_A)])
	_action(&"boost", [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action(&"lamp", [_key(KEY_F), _joy(JOY_BUTTON_Y)])
	_action(&"interact", [_key(KEY_E), _joy(JOY_BUTTON_X)])
	_action(&"map", [_key(KEY_TAB), _joy(JOY_BUTTON_BACK)])
	_action(&"pause", [_key(KEY_ESCAPE), _key(KEY_P), _joy(JOY_BUTTON_START)])
	_action(&"fullscreen", [_key(KEY_F11)])
	_action(&"pick_1", [_key(KEY_1)])
	_action(&"pick_2", [_key(KEY_2)])
	_action(&"pick_3", [_key(KEY_3)])


func _action(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for e: InputEvent in events:
		InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e
