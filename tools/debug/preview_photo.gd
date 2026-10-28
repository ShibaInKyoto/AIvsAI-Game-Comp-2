extends "res://tools/debug/preview_stage.gd"
## Debug helper: opens photo mode in the Abyssal Vents and swings the camera
## round, to check the orbit shows the relief of the walls.
## Usage: xvfb-run godot --path . res://tools/debug/preview_photo.tscn -- <out_dir>

var _photo: PhotoMode


func _ready() -> void:
	stage(6, 31337)
	place_sub(level.layout.start + Vector2(0.0, -12.0))
	shot_prefix = "photo"
	shot_times = [0.8, 1.6]


func direct(_dt: float) -> void:
	if _photo == null and t > 0.5:
		_photo = PhotoMode.new()
		add_child(_photo)
		_photo.open(camera)
		_photo.call(&"_turn", Vector2(-0.55, 0.3))
