extends "res://tools/debug/preview_stage.gd"
## Debug helper: wakes the Lamplighter in the reef lair and saves screenshots
## of her lure in the dark, the lure going dark before a charge, and her
## dazzled by the lamp.
## Usage: xvfb-run godot --path . res://tools/debug/preview_lamplighter.tscn -- <out_dir>

var _angler: Lamplighter
var _far := Vector2.ZERO


func _ready() -> void:
	stage(BiomeLibrary.ANGLER_ZONE, 77)
	_angler = level.guardian as Lamplighter
	_far = level.layout.field.resolve_circle(_angler.lair_center - Vector2(_angler.lair_radius.x * 0.45, 0.0), 2.0)
	place_sub(_far, 1.3)
	sub.lamp_on = false
	add_hud()
	shot_prefix = "angler"
	_angler.take_damage(0.1, _angler.pos)


func direct(_dt: float) -> void:
	sub.run.hull = sub.stats.max_hull
	var n := shots_taken()
	if n < 2:
		sub.pos = _far
		sub.vel = Vector2.ZERO
		sub.aim = (_angler.head_pos() - sub.pos).normalized()
		sub.lamp_on = n == 1
	elif _angler.state == Lamplighter.State.STALK:
		sub.pos = _angler.head_pos() + _angler.facing * 9.0
		sub.vel = Vector2.ZERO
		sub.aim = (_angler.head_pos() - sub.pos).normalized()
		sub.lamp_on = true
	if (n == 0 and t >= 1.2) or (n == 1 and _angler.state == Lamplighter.State.WINDUP and t > 3.0) \
			or (n == 2 and _angler.state == Lamplighter.State.DAZZLED):
		shoot()
	if shots_taken() >= 3 or t > 30.0:
		get_tree().quit()
