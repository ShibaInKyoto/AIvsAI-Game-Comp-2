extends "res://tools/debug/preview_stage.gd"
## Debug helper: hangs back from the audience over Meridian Deep and saves
## screenshots as the Choir's tone shifts and they turn together.
## Usage: xvfb-run godot --path . res://tools/debug/preview_audience.tscn -- <out_dir> [seed] [zoom]

var _audience: StationAudience


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	stage(BiomeLibrary.TOTAL_ZONES - 1, int(args[1]) if args.size() > 1 else 7)
	_audience = find_entity(func(e: Entity) -> bool: return e is StationAudience)
	var centre := Vector2.ZERO
	for m in _audience.members:
		centre += m.pos / _audience.members.size()
	# Off to one side of the crowd, clear of every member.
	var at := centre + Vector2(16.0, 0.0)
	for k in 24:
		var p := centre + Vector2.from_angle(TAU * k / 24.0) * 15.0
		var clear := level.field.sample(p) > 2.0
		for m in _audience.members:
			clear = clear and m.pos.distance_to(p) > 5.0
		if clear:
			at = p
			break
	place_sub(at, float(args[2]) if args.size() > 2 else 1.25)
	add_hud()
	_audience.set(&"_tone_in", 2.5)
	shot_prefix = "audience"
	shot_times = [2.0, 5.5, 9.0]


func direct(_dt: float) -> void:
	sub.run.hull = sub.stats.max_hull
	var centre := Vector2.ZERO
	for m in _audience.members:
		centre += m.pos / maxi(_audience.members.size(), 1)
	sub.aim = (centre - sub.pos).normalized()
