extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages any zone with its usual content and saves
## screenshots of the sub a third of the way along the main path, lamp on,
## pinging once.
## Usage: xvfb-run godot --path . res://tools/debug/preview_dive.tscn -- <out_dir> [zone] [seed] [along] [zoom]
## [zone event]. [along] may be "derelict" to start beside the zone's derelict sub.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# "derelict" for [along] lays the zone's derelict sub (nothing is saved) and starts beside it.
	var derelict := args.size() > 3 and args[3] == "derelict"
	if derelict:
		Game.meta.unlocked_frames.assign(["lantern"])
	stage(int(args[1]) if args.size() > 1 else 2, int(args[2]) if args.size() > 2 else 23, &"lantern", false,
		StringName(args[5]) if args.size() > 5 else &"")
	var path := level.layout.main_path
	var at := path[int((path.size() - 1) * (float(args[3]) if args.size() > 3 and not derelict else 0.33))]
	if derelict:
		for e in level.entities:
			if e is DerelictFrame:
				at = e.pos + Vector2(-5.0, 1.5)
	place_sub(at, float(args[4]) if args.size() > 4 else 0.85)
	add_hud()
	shot_prefix = "dive"
	shot_times = [1.5, 2.6, 4.0, 6.0]


func direct(_dt: float) -> void:
	sub.vel *= 0.9
	sub.lamp_on = true
	if t >= 1.2 and t < 1.2 + STEP:
		sub.try_ping()
