extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages the first Abyssal Vents zone and saves screenshots of
## the singing glass sealing its chamber, ringing higher with each ping, and
## shattering open on the third.
## Usage: xvfb-run godot --path . res://tools/debug/preview_glass.tscn -- <out_dir> [seed] [zoom] [clip step]

var _glass: SingingGlass
var _pings: Array[float] = [2.0, 4.8, 7.6]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var run_seed := int(args[1]) if args.size() > 1 else 17
	for k in 8:
		stage(SingingGlass.ZONE, run_seed + k)
		_glass = find_entity(func(e: Entity) -> bool: return e is SingingGlass)
		if _glass:
			break
		level.free()
	place_sub(_glass.wall - _glass.normal * 4.5, float(args[2]) if args.size() > 2 else 0.8)
	add_hud()
	shot_prefix = "glass"
	shot_times = [1.6, 2.5, 5.3, 6.6, 7.0, 8.1, 8.6, 11.0]
	# A fourth argument: a frame every that many seconds instead, for a clip.
	if args.size() > 3:
		shot_times.clear()
		var at := 1.4
		while at < 10.5:
			shot_times.append(at)
			at += float(args[3])


func direct(_dt: float) -> void:
	sub.run.hull = sub.stats.max_hull
	sub.run.battery = sub.stats.max_battery
	sub.vel = Vector2.ZERO
	sub.aim = _glass.normal
	sub.lamp_on = true
	if not _pings.is_empty() and t >= _pings[0]:
		_pings.pop_front()
		sub.sonar_cooldown = 0.0
		sub.try_ping()
