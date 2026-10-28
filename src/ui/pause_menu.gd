class_name PauseMenu
extends CanvasLayer
## In-dive pause menu with controls reference and settings.

signal surface_requested

var _root: Control
var _settings: SettingsPanel


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open() -> void:
	if visible:
		return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_build()


func close() -> void:
	visible = false
	if _root:
		_root.queue_free()
		_root = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		if _settings and is_instance_valid(_settings):
			_settings.queue_free()
			_settings = null
		else:
			close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var column := UiUtil.modal(self, 0.7, 640)
	_root = column.get_parent().get_parent()
	column.add_child(UiUtil.label("PAUSED", &"TitleLabel"))
	var resume := UiUtil.button("Resume", close)
	column.add_child(resume)
	column.add_child(UiUtil.button("Settings", _open_settings))
	# Abandoning mid-zone counts as losing the sub: only insurance pays out.
	var abandon := "Abandon dive"
	if Game.run:
		abandon += "  (keep %d%% of salvage)" % int(Game.run.stats.insurance * 100)
	column.add_child(UiUtil.button(abandon, func() -> void:
		close()
		surface_requested.emit()))
	column.add_child(UiUtil.spacer(10))
	column.add_child(UiUtil.label("CONTROLS", &"HeaderLabel"))
	column.add_child(Prompt.controls_grid())
	resume.grab_focus()


func _open_settings() -> void:
	_settings = SettingsPanel.new()
	add_child(_settings)
