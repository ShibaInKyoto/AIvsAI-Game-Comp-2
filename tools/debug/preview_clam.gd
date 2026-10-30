extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages a Twilight Reef zone and saves screenshots of a giant
## clam shut in the lamp's light, gaping once the lamp is off, and the pearl
## harpooned out of it.
## Usage: xvfb-run godot --path . res://tools/debug/preview_clam.tscn -- <out_dir> [seed] [zoom]

var _clam: GiantClam
var _fired := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var run_seed := int(args[1]) if args.size() > 1 else 21
	for k in 8:
		stage(2, run_seed + k)
		_clam = find_entity(func(e: Entity) -> bool: return e is GiantClam)
		if _clam:
			break
		level.free()
	var at := _clam.pos + Vector2(-6.0, 3.0)
	for k in 12:
		var p := _clam.pos + Vector2.from_angle(PI * 0.15 + PI * 0.7 * k / 11.0) * 6.5
		if level.field.sample(p) > 2.5:
			at = p
			break
	place_sub(at, float(args[2]) if args.size() > 2 else 0.8)
	add_hud()
	shot_prefix = "clam"
	shot_times = [1.2, 6.8, 8.2]


func direct(_dt: float) -> void:
	sub.run.hull = sub.stats.max_hull
	sub.aim = (_clam.pos + Vector2(0.3, 0.3) - sub.pos).normalized()
	sub.lamp_on = t < 1.5
	if t > 7.0 and not _fired:
		_fired = true
		sub.harpoon.throw(sub.aim)
