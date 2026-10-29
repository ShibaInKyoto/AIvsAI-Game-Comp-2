extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages the hadal floor and saves screenshots of the Choir's
## song waves rolling out across its arena, the sub answering them with
## pings and the voice organs opening.
## Usage: xvfb-run godot --path . res://tools/debug/preview_choir.tscn -- <out_dir> [seed] [zoom]

var _choir: ChoirBoss
var _ping_at := 3.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	stage(BiomeLibrary.TOTAL_ZONES - 1, int(args[1]) if args.size() > 1 else 7)
	_choir = level.boss
	# Inside the arena, a little off the heart, in open water.
	var at := _choir.center + Vector2(-22.0, 2.0)
	for k in 16:
		var p := _choir.center + Vector2.from_angle(PI + TAU * k / 16.0) * 22.0
		if level.field.sample(p) > 3.0:
			at = p
			break
	place_sub(at, float(args[2]) if args.size() > 2 else 0.9)
	add_hud()
	shot_prefix = "choir"
	shot_times = [4.0, 6.5, 8.8, 10.2, 12.5]


func direct(_dt: float) -> void:
	sub.run.hull = sub.stats.max_hull
	sub.run.battery = sub.stats.max_battery
	sub.vel = Vector2.ZERO
	sub.lamp_on = true
	var organ: Entity = null
	for o in _choir.organs:
		if not is_instance_valid(o) or not o.alive:
			continue
		if organ == null or o.pos.distance_to(sub.pos) < organ.pos.distance_to(sub.pos):
			organ = o
	if organ:
		sub.aim = (organ.pos - sub.pos).normalized()
	if t >= _ping_at:
		_ping_at += 2.6
		sub.sonar_cooldown = 0.0
		sub.try_ping()
