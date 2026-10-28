extends "res://tools/debug/preview_stage.gd"
## Debug helper: a Whisper launches a sonar decoy in a reef zone; screenshots
## catch it sinking and pinging.
## Usage: xvfb-run godot --path . res://tools/debug/preview_decoy.tscn -- <out_dir>

var _launched := false


func _ready() -> void:
	stage(2, 4242, &"whisper", true)
	place_sub(level.layout.start)
	shot_prefix = "decoy"
	shot_times = [1.35, 3.85, 6.0]


func direct(_dt: float) -> void:
	sub.aim = Vector2(0.6, -0.8)
	if not _launched and t > 0.3:
		_launched = true
		sub.tools.use(sub.aim)
