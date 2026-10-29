extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages a Hadal Trench zone, pings once and saves screenshots
## of the answer rising from below eleven seconds later.
## Usage: xvfb-run godot --path . res://tools/debug/preview_echo.tscn -- <out_dir> [seed]

var _pinged := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := BiomeLibrary.ZONES_PER_BIOME * (BiomeLibrary.BIOME_COUNT - 1)
	stage(zone, int(args[1]) if args.size() > 1 else 99, &"lantern", true)
	LevelPopulator.populate(level, run)
	var path := level.layout.main_path
	place_sub(path[int(0.2 * (path.size() - 1))], 1.3)
	add_hud()
	shot_prefix = "echo"
	shot_times = [2.0, 11.9, 12.4, 13.2]


func direct(_dt: float) -> void:
	sub.run.hull = sub.stats.max_hull
	if not _pinged and t > 0.5:
		_pinged = sub.try_ping()
