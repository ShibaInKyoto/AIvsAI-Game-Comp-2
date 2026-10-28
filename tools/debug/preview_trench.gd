extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages a Hadal Trench zone, sets the Choir singing and saves
## screenshots of the tunnel behind the sub flowing shut.
## Usage: xvfb-run godot --path . res://tools/debug/preview_trench.tscn -- <out_dir> [seed] [zoom] [pocket]
## (pocket: frame the chamber opening ahead instead.)

var _shift: TrenchShift
var _watch := Vector2.ZERO
var _pocket_view := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := BiomeLibrary.ZONES_PER_BIOME * (BiomeLibrary.BIOME_COUNT - 1)
	stage(zone, int(args[1]) if args.size() > 1 else 99, &"lantern", true)
	LevelPopulator.populate(level, run)
	_pocket_view = args.size() > 3 and args[3] == "pocket"
	_shift = find_entity(func(e: Entity) -> bool: return e is TrenchShift)
	var path := level.layout.main_path
	place_sub(path[int((TrenchShift.TRIGGERS[0] + 0.03) * (path.size() - 1))],
		float(args[2]) if args.size() > 2 else 1.6)
	add_hud()
	_shift.tick(0.0)
	for m in _shift._morphs:
		if m.fill != _pocket_view:
			_watch = m.centre()
			if _pocket_view:
				# Across the tunnel from the chamber's neck.
				var mouth: Vector2 = m.shapes[1][0]
				_watch = m.shapes[0][0]
				sub.pos = mouth + (mouth - _watch).normalized() * 5.0
	if not _pocket_view:
		# Hang back a little way from it, so it is in shot but the rock need not wait.
		sub.pos = _watch + (sub.pos - _watch).normalized() * 16.0
	sub.pos = level.field.resolve_circle(sub.pos, Submarine.RADIUS + 0.5)
	camera.snap()
	shot_prefix = "pocket" if _pocket_view else "seal"
	shot_times = [0.8, 3.5, 5.0, 8.5]


func direct(_dt: float) -> void:
	sub.aim = (_watch - sub.pos).normalized()
	sub.run.hull = sub.stats.max_hull
