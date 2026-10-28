extends "res://tools/debug/preview_stage.gd"
## Debug helper: wakes the Blind Mother in her lair, draws a lunge into the
## wall with a noise and saves screenshots of her prowling, lunging and stuck.
## Usage: xvfb-run godot --path . res://tools/debug/preview_mother.tscn -- <out_dir>

var _mother: BlindMother


func _ready() -> void:
	stage(BiomeLibrary.LAIR_ZONE, 2024)
	_mother = level.guardian as BlindMother
	place_sub(level.layout.field.resolve_circle(_mother.lair_center + Vector2(-8.0, 2.0), 2.0), 1.3)
	add_hud()
	shot_prefix = "mother"
	_mother.take_damage(0.1, _mother.pos)


func direct(_dt: float) -> void:
	sub.aim = (_mother.pos - sub.pos).normalized()
	sub.run.hull = sub.stats.max_hull
	if _mother.state == BlindMother.State.PROWL and t > 1.5:
		var wall := _mother.lair_center + Vector2(_mother.lair_radius.x * 0.95, -_mother.lair_radius.y * 0.3)
		level.emit_noise(level.layout.field.resolve_circle(wall, 2.0), 60.0)
	var n := shots_taken()
	if (n == 0 and t >= 1.0) or (n == 1 and _mother.state == BlindMother.State.LUNGE) \
			or (n == 2 and _mother.state == BlindMother.State.STUCK):
		shoot()
	if shots_taken() >= 3 or t > 20.0:
		get_tree().quit()
