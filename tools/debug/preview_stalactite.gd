extends "res://tools/debug/preview_stage.gd"
## Debug helper: knocks a loose stalactite down in the Midnight Caverns and
## saves screenshots of it hanging, falling and shattering.
## Usage: xvfb-run godot --path . res://tools/debug/preview_stalactite.tscn -- <out_dir>

var _rock: Stalactite
var _dropped := false


func _ready() -> void:
	stage(4, 5150)
	_rock = find_entity(func(e: Entity) -> bool: return e is Stalactite)
	place_sub(_rock.tip() + Vector2(-9.0, 0.5))
	shot_prefix = "rock"
	shot_times = [0.45, 1.5, 1.7, 2.1]


func direct(_dt: float) -> void:
	sub.aim = (_rock.pos - sub.pos).normalized() if is_instance_valid(_rock) else Vector2.RIGHT
	if not _dropped and t > 0.5:
		_dropped = true
		_rock.shake_loose()
