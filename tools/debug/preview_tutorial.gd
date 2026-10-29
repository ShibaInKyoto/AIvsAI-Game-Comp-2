extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages the first zone with the first-dive tutorial on and
## saves screenshots of its first hints (move, then sonar once the sub has moved).
## Usage: xvfb-run godot --path . res://tools/debug/preview_tutorial.tscn -- <out_dir> [seed]

var _tutorial: Tutorial


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	stage(0, int(args[1]) if args.size() > 1 else 4242)
	place_sub(level.layout.start, 1.0)
	add_hud()
	_tutorial = Tutorial.new()
	add_child(_tutorial)
	_tutorial.bind(sub, level)
	shot_prefix = "tutorial"
	shot_times = [2.0, 6.5]


func direct(_dt: float) -> void:
	# Drift on along the way down after the first shot, so the next hint shows.
	if t > 2.5:
		var path := level.layout.main_path
		sub.external_move = (path[mini(12, path.size() - 1)] - sub.pos).limit_length(1.0)
