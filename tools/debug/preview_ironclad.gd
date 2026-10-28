extends "res://tools/debug/preview_stage.gd"
## Debug helper: wakes the Ironclad in its vent-field lair and saves
## screenshots of it walking, then cracked open by a vent erupting under it.
## Usage: xvfb-run godot --path . res://tools/debug/preview_ironclad.tscn -- <out_dir> [seed]

var _boss: Ironclad
var _vent: ThermalVent


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	stage(BiomeLibrary.FURNACE_ZONE, int(args[1]) if args.size() > 1 else 9102)
	_boss = level.guardian as Ironclad
	for e in level.entities:
		var v := e as ThermalVent
		if v and v.in_lair and (_vent == null or v.pos.distance_to(_boss.pos) < _vent.pos.distance_to(_boss.pos)):
			_vent = v
	place_sub(level.field.resolve_circle(_boss.pos + Vector2(-6.0, 11.0), 2.0), 1.35)
	add_hud()
	shot_prefix = "ironclad"
	_boss.take_damage(0.1, _boss.pos)


func direct(_dt: float) -> void:
	sub.aim = (_boss.pos - sub.pos).normalized()
	sub.run.hull = sub.stats.max_hull
	# Call it onto the vent, then set the vent off under it.
	if t < 3.0 and int(t * 10.0) % 10 == 0:
		level.emit_noise(_vent.pos + Vector2(0.0, 3.0), 60.0)
	if t > 2.2 and _vent.state == ThermalVent.State.DORMANT and _boss.exposed <= 0.0:
		_vent.erupt_soon()
	var n := shots_taken()
	if (n == 0 and t >= 1.2) or (n == 1 and _boss.exposed > 0.0 and _boss.exposed < 3.6):
		shoot()
	if shots_taken() >= 2 or t > 25.0:
		get_tree().quit()
