class_name QualityProbe
extends Node
## First launch only: watches the frame rate on the title screen (which renders
## a full cave backdrop) and steps the graphics preset down if this machine
## cannot hold a smooth frame rate at the default one.

signal adjusted(quality_name: String)

const WARMUP := 3.0
const WINDOW := 4.0
const MEDIUM_BELOW_FPS := 42.0
const LOW_BELOW_FPS := 24.0

var _time := 0.0
var _frames := 0
var _measured := 0.0


## Only on a real first launch: never headless, and never for debug runs
## (screenshots, autopilot), which would otherwise tune for the CI renderer.
static func wanted() -> bool:
	return not Settings.quality_probed and DisplayServer.get_name() != "headless" \
		and OS.get_cmdline_user_args().is_empty()


func _process(delta: float) -> void:
	_time += delta
	if _time < WARMUP:
		return
	_frames += 1
	_measured += delta
	if _measured < WINDOW:
		return
	var fps := _frames / _measured
	var target := Settings.quality
	if fps < LOW_BELOW_FPS:
		target = Settings.Quality.LOW
	elif fps < MEDIUM_BELOW_FPS:
		target = mini(Settings.quality, Settings.Quality.MEDIUM) as Settings.Quality
	Settings.quality_probed = true
	if target < Settings.quality:
		Settings.quality = target
		Settings.apply()
		adjusted.emit(Settings.QUALITY_NAMES[target])
	Settings.save_settings()
	queue_free()
