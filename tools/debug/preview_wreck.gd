extends "res://tools/debug/preview_stage.gd"
## Debug helper: lays the wreck of a lost Mako beside the sub in the Twilight
## Reef and photographs it before and as its cargo is recovered.
## Usage: xvfb-run godot --path . res://tools/debug/preview_wreck.tscn -- <out_dir>

var _wreck: LostWreck


func _ready() -> void:
	stage(2, 6060, &"lantern", true)
	_wreck = LostWreck.new()
	_wreck.frame_id = &"mako"
	_wreck.cargo = 84
	_wreck.pos = level.layout.field.resolve_circle(level.layout.start + Vector2(7.0, -5.0), 2.0)
	level.add_entity(_wreck)
	place_sub(_wreck.pos + Vector2(-7.0, 1.5))
	shot_prefix = "wreck"
	shot_times = [1.5, 2.6]


func direct(_dt: float) -> void:
	sub.aim = (_wreck.pos - sub.pos).normalized() if is_instance_valid(_wreck) else Vector2.RIGHT
	if t > 2.0 and is_instance_valid(_wreck):
		_wreck.recover(sub)
