class_name SettingsPanel
extends CanvasLayer
## Audio, video and gameplay settings. Changes apply immediately and are
## saved when the panel closes.

## Seconds the erase button stays armed after the first press.
const ERASE_ARM_TIME := 4.0

## Offer to erase all progress (only from the title screen, never mid-dive).
var allow_erase := false
var _erase_armed := 0.0
var _erase: Button


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := UiUtil.modal(self, 0.75, 760)
	column.add_child(UiUtil.label("SETTINGS", &"TitleLabel"))

	var panel := PanelContainer.new()
	column.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 40)
	grid.add_theme_constant_override(&"v_separation", 14)
	panel.add_child(grid)

	_slider(grid, "Master volume", Settings.master_volume, func(v: float) -> void: Settings.master_volume = v)
	_slider(grid, "Music volume", Settings.music_volume, func(v: float) -> void: Settings.music_volume = v)
	_slider(grid, "Effects volume", Settings.sfx_volume, func(v: float) -> void: Settings.sfx_volume = v)
	_slider(grid, "Screen shake", Settings.screen_shake, func(v: float) -> void: Settings.screen_shake = v)

	grid.add_child(UiUtil.label("Graphics quality"))
	var quality := OptionButton.new()
	for q in Settings.QUALITY_NAMES:
		quality.add_item(q)
	quality.selected = Settings.quality
	quality.item_selected.connect(func(i: int) -> void:
		Settings.quality = i as Settings.Quality
		Settings.apply())
	grid.add_child(quality)

	_check(grid, "Fullscreen", Settings.fullscreen, func(on: bool) -> void: Settings.fullscreen = on)
	_check(grid, "V-Sync", Settings.vsync, func(on: bool) -> void: Settings.vsync = on)
	_check(grid, "Show FPS", Settings.show_fps, func(on: bool) -> void: Settings.show_fps = on)
	_check(grid, "Assist mode (40% less damage, wider timing)", Settings.assist,
		func(on: bool) -> void: Settings.assist = on)
	_check(grid, "Gamepad rumble", Settings.rumble, func(on: bool) -> void: Settings.rumble = on)
	_check(grid, "Sound cues (show where threat sounds come from)", Settings.sound_cues,
		func(on: bool) -> void: Settings.sound_cues = on)
	_check(grid, "Reduce flashing (softer bursts of light)", Settings.reduce_flashing,
		func(on: bool) -> void: Settings.reduce_flashing = on)

	column.add_child(UiUtil.label("Quality changes to terrain detail apply from the next zone.", &"DimLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	column.add_child(row)
	var controls := UiUtil.button("Controls...", func() -> void: add_child(ControlsPanel.new()))
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(controls)
	if allow_erase:
		_erase = UiUtil.button("Erase progress...", _on_erase)
		_erase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_erase.clip_text = true
		row.add_child(_erase)
	var close := UiUtil.button("Back", _close)
	column.add_child(close)
	close.grab_focus()


func _process(delta: float) -> void:
	if _erase_armed > 0.0:
		_erase_armed -= delta
		if _erase_armed <= 0.0:
			_disarm()


## First press arms the button; a second within a few seconds erases every
## upgrade, frame, record and log (settings and key bindings are kept).
func _on_erase() -> void:
	if _erase_armed <= 0.0:
		_erase_armed = ERASE_ARM_TIME
		_erase.text = "Press again to erase ALL progress"
		_erase.tooltip_text = "Upgrades, frames, records, logs and milestones. Settings are kept."
		_erase.add_theme_color_override(&"font_color", UiTheme.DANGER)
		_erase.add_theme_color_override(&"font_focus_color", UiTheme.DANGER)
		_erase.add_theme_color_override(&"font_hover_color", UiTheme.DANGER)
		return
	Game.clear_saved_run()
	Game.reset_progress()
	Settings.save_settings()
	Router.go_to(Router.TITLE)
	queue_free()


func _disarm() -> void:
	_erase_armed = 0.0
	_erase.text = "Erase progress..."
	for c: StringName in [&"font_color", &"font_focus_color", &"font_hover_color"]:
		_erase.remove_theme_color_override(c)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _close() -> void:
	Settings.save_settings()
	queue_free()


func _slider(grid: GridContainer, title: String, value: float, setter: Callable) -> void:
	grid.add_child(UiUtil.label(title))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(320, 30)
	s.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		Settings.apply())
	grid.add_child(s)


func _check(grid: GridContainer, title: String, value: bool, setter: Callable) -> void:
	grid.add_child(UiUtil.label(title))
	var c := CheckBox.new()
	c.button_pressed = value
	c.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		Settings.apply())
	grid.add_child(c)
