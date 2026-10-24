class_name LogReader
extends CanvasLayer
## Shows a recovered signal log as a transmission that types itself out,
## without pausing the game. Fades after a while.

const CHARS_PER_SECOND := 70.0
const HOLD_TIME := 9.0

var _panel: PanelContainer
var _title: Label
var _body: Label
var _t := 0.0
var _total := 0
var _active := false


func _ready() -> void:
	layer = 11
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_panel.offset_left = 40
	_panel.offset_right = 640
	_panel.offset_top = -40
	_panel.offset_bottom = 220
	_panel.add_theme_stylebox_override(&"panel", UiTheme.panel_style(Color(0.01, 0.05, 0.04, 0.88), Color(UiTheme.GOOD, 0.6), 1, 6))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	root.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_title = UiUtil.label("", &"HeaderLabel", 24, UiTheme.GOOD)
	box.add_child(_title)
	_body = UiUtil.label("", &"MonoLabel", 19)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(560, 0)
	box.add_child(_body)
	Events.log_found.connect(show_log)


func show_log(id: StringName) -> void:
	var entry := SignalLogs.get_log(id)
	if entry.is_empty():
		return
	_title.text = "SIGNAL LOG  -  %s  /  %s" % [entry.title, entry.author]
	_body.text = entry.text
	_body.visible_characters = 0
	_total = entry.text.length()
	_t = 0.0
	_active = true


func _process(delta: float) -> void:
	if not _active:
		_panel.modulate.a = move_toward(_panel.modulate.a, 0.0, delta * 2.0)
		return
	_t += delta
	_panel.modulate.a = move_toward(_panel.modulate.a, 1.0, delta * 4.0)
	_body.visible_characters = mini(int(_t * CHARS_PER_SECOND), _total)
	if _t > _total / CHARS_PER_SECOND + HOLD_TIME:
		_active = false
