extends "res://tools/debug/preview_stage.gd"
## Debug helper: flies the sub up to the Meridian Deep station in the final
## zone and saves screenshots before and after its beacon pings.
## Usage: xvfb-run godot --path . res://tools/debug/preview_station.tscn -- <out_dir> [seed]

var _station: MeridianStation


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	stage(BiomeLibrary.TOTAL_ZONES - 1, int(args[1]) if args.size() > 1 else 7)
	_station = find_entity(func(e: Entity) -> bool: return e is MeridianStation)
	place_sub(_station.pos + Vector2(-7.0, 5.0), 1.15)
	add_hud()
	shot_prefix = "station"
	shot_times = [2.6, 4.0]


func direct(_dt: float) -> void:
	sub.aim = Vector2(1.0, -0.25).normalized()
	sub.external_move = Vector2(0.25, 0.0)
