extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages a Sunlit Shelf zone and saves screenshots of a manta
## gliding past the sub.
## Usage: xvfb-run godot --path . res://tools/debug/preview_manta.tscn -- <out_dir> [seed] [zoom]

var _manta: Manta


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var run_seed := int(args[1]) if args.size() > 1 else 3
	for k in 8:
		stage(0, run_seed + k)
		_manta = find_entity(func(e: Entity) -> bool: return e is Manta)
		if _manta:
			break
		level.free()
	var at := _manta.pos + Vector2(-9.0, 2.0)
	for k in 16:
		var p := _manta.pos + Vector2.from_angle(TAU * k / 16.0) * 9.0
		if level.field.sample(p) > 2.5:
			at = p
			break
	place_sub(at, float(args[2]) if args.size() > 2 else 1.0)
	add_hud()
	shot_prefix = "manta"
	shot_times = [1.5, 4.0, 7.0]


func direct(_dt: float) -> void:
	sub.aim = (_manta.pos - sub.pos).normalized()
	# Keep pace a little way off, so it stays in shot without being crowded.
	var off := sub.pos - _manta.pos
	if off.length() > 11.0:
		sub.external_move = -off.normalized() * 0.6
