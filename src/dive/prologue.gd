class_name Prologue
extends CanvasLayer
## The opening of a pilot's very first dive: a few lines over black while the
## first zone loads underneath, then a fade into the water. Any key skips it.

signal finished

const LINES: PackedStringArray = [
	"Forty days ago Meridian Deep, a research station on the floor of the deepest trench on Earth, went silent.",
	"Three weeks later its sonar beacon began to ping again.",
	"Something down there has been pinging back.",
	"The salvage contract is yours.",
]
## Sound cue played as each line appears (empty for none).
const CUES: Array[StringName] = [&"", &"beacon_ping", &"choir_call", &""]

var done := false
var _column: VBoxContainer
var _shade: ColorRect
var _tween: Tween


static func wanted() -> bool:
	return Game.meta.dives <= 1 and not Game.meta.tutorial_done and Game.run and Game.run.zone == 0 \
		and not Autopilot.requested()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	_shade = ColorRect.new()
	_shade.color = Color(0.0, 0.01, 0.02)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(1000, 0)
	_column.add_theme_constant_override(&"separation", 26)
	center.add_child(_column)
	var skip := UiUtil.label("Press any key to skip", &"DimLabel", 16)
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -300
	skip.offset_top = -48
	skip.offset_right = -28
	skip.offset_bottom = -20
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(skip)
	_play()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	var pressed: bool = event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed \
		or event is InputEventJoypadButton and event.pressed
	if pressed:
		get_viewport().set_input_as_handled()
		_finish()


func _play() -> void:
	for i in LINES.size():
		if done:
			return
		var l := UiUtil.label(LINES[i], &"", 30 if i < LINES.size() - 1 else 34,
				UiTheme.TEXT if i < LINES.size() - 1 else UiTheme.ACCENT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		_column.add_child(l)
		if CUES[i] != &"":
			Audio.play(CUES[i], -6.0 if i == 1 else -12.0)
		_tween = create_tween()
		_tween.tween_property(l, ^"modulate:a", 1.0, 1.4)
		_tween.tween_interval(2.2)
		await _tween.finished
	_finish()


func _finish() -> void:
	if done:
		return
	done = true
	if _tween and _tween.is_valid():
		_tween.kill()
	# Control returns as the water fades in.
	finished.emit()
	var fade := create_tween()
	fade.tween_property(_column, ^"modulate:a", 0.0, 0.6)
	fade.parallel().tween_property(_shade, ^"color:a", 0.0, 1.6)
	fade.tween_callback(queue_free)
