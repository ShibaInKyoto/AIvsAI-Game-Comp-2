extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages the first Midnight Caverns zone and saves screenshots
## of its glow-worm grotto lit in the quiet, going dark around a loud noise,
## and lighting up again.
## Usage: xvfb-run godot --path . res://tools/debug/preview_grotto.tscn -- <out_dir> [seed] [zoom]

var _grotto: GlowwormGrotto
var _noisy := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var run_seed := int(args[1]) if args.size() > 1 else 17
	for k in 8:
		stage(4, run_seed + k)
		_grotto = find_entity(func(e: Entity) -> bool: return e is GlowwormGrotto)
		if _grotto:
			break
		level.free()
	var at := level.field.resolve_circle(_grotto.room.center + Vector2(0.0, _grotto.room.radius.y * 0.15), 1.6)
	place_sub(at, float(args[2]) if args.size() > 2 else 1.5)
	add_hud()
	shot_prefix = "grotto"
	shot_times = [2.0, 3.8, 5.5, 14.0]


func direct(_dt: float) -> void:
	sub.run.hull = sub.stats.max_hull
	sub.lamp_on = false
	# Hold station, so the camera keeps the grotto in shot.
	sub.vel = Vector2.ZERO
	if t > 2.3 and not _noisy:
		_noisy = true
		level.emit_noise(sub.pos, 26.0, sub)
