extends Node
## Scene transitions with a fade to black.

const TITLE := "res://src/ui/title/title_screen.tscn"
const HANGAR := "res://src/ui/hangar/hangar.tscn"
const DIVE := "res://src/dive/dive.tscn"
const ENDING := "res://src/ui/ending/ending.tscn"

var _layer: CanvasLayer
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.01, 0.02, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fullscreen"):
		Settings.toggle_fullscreen()


func go_to(path: String, fade_time := 0.6) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, ^"color:a", 1.0, fade_time)
	await tween.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	# Let the new scene build (and any generation spikes settle) before fading in.
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_fade, ^"color:a", 0.0, fade_time)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Fades the screen to black and back while [param work] runs in between.
func fade_through(work: Callable, fade_time := 0.5) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, ^"color:a", 1.0, fade_time)
	await tween.finished
	await work.call()
	var back := create_tween()
	back.tween_property(_fade, ^"color:a", 0.0, fade_time)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
