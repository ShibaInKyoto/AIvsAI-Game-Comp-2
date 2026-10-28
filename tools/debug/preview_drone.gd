extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages the last Hadal Trench zone and saves screenshots of
## the sub coming alongside Vasquez's drone in its wall.
## Usage: xvfb-run godot --path . res://tools/debug/preview_drone.tscn -- <out_dir> [seed] [zoom]

var _drone: VasquezDrone


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	stage(VasquezDrone.ZONE, int(args[1]) if args.size() > 1 else 99, &"lantern", true)
	LevelPopulator.populate(level, run)
	_drone = find_entity(func(e: Entity) -> bool: return e is VasquezDrone)
	place_sub(_drone.pos + _drone.normal * 8.0 + Vector2(0.0, 5.5), float(args[2]) if args.size() > 2 else 1.0)
	add_hud()
	shot_prefix = "drone"
	shot_times = [1.5, 7.0]


func direct(_dt: float) -> void:
	sub.aim = (_drone.pos - sub.pos).normalized()
	if t > 3.0 and t < 4.5:
		sub.external_move = (_drone.pos - sub.pos).normalized() * 0.5
