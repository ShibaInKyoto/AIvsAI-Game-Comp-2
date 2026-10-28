extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages a whale fall zone and saves screenshots of the sub
## hovering over the skeleton.
## Usage: xvfb-run godot --path . res://tools/debug/preview_whale.tscn -- <out_dir> [zone] [seed]

var _fall: WhaleFall


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := int(args[1]) if args.size() > 1 else 3
	stage(zone, int(args[2]) if args.size() > 2 else 603, &"lantern", true)
	level.event = &"whalefall"
	LevelPopulator.populate(level, run)
	_fall = find_entity(func(e: Entity) -> bool: return e is WhaleFall)
	place_sub(_fall.pos + Vector2(-5.0, 6.0), 1.2)
	add_hud()
	shot_prefix = "whale"
	shot_times = [1.5, 3.0]


func direct(_dt: float) -> void:
	sub.aim = Vector2(0.8, -0.6).normalized()
