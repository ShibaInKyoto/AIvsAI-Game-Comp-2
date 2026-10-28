class_name SettingsPanel
extends CanvasLayer
## Audio, video and gameplay settings. Changes apply immediately and are
## saved when the panel closes.


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

	column.add_child(UiUtil.label("Quality changes to terrain detail apply from the next zone.", &"DimLabel"))
	var close := UiUtil.button("Back", _close)
	column.add_child(close)
	close.grab_focus()


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
