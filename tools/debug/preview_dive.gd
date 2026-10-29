extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages any zone with its usual content and saves
## screenshots of the sub a third of the way along the main path, lamp on,
## pinging once.
## Usage: xvfb-run godot --path . res://tools/debug/preview_dive.tscn -- <out_dir> [zone] [seed] [along] [zoom]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	stage(int(args[1]) if args.size() > 1 else 2, int(args[2]) if args.size() > 2 else 23)
	var path := level.layout.main_path
	var along := float(args[3]) if args.size() > 3 else 0.33
	place_sub(path[int((path.size() - 1) * along)], float(args[4]) if args.size() > 4 else 0.85)
	add_hud()
	shot_prefix = "dive"
	shot_times = [1.5, 2.6, 4.0, 6.0]


func direct(_dt: float) -> void:
	sub.vel *= 0.9
	sub.lamp_on = true
	if t >= 1.2 and t < 1.2 + STEP:
		sub.try_ping()
