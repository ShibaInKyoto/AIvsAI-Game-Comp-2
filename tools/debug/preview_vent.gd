extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages a thermal vent eruption beside the sub in a vent-field
## zone and saves screenshots of the warning and the eruption.
## Usage: xvfb-run godot --path . res://tools/debug/preview_vent.tscn -- <out_dir>

var _vent: ThermalVent


func _ready() -> void:
	stage(6, 31337)
	_vent = find_entity(func(e: Entity) -> bool: return e is ThermalVent)
	place_sub(_vent.pos + _vent.normal * 4.0 + _vent.normal.orthogonal() * 6.0)
	shot_prefix = "vent"
	shot_times = [1.0, 2.6, 3.6]
	_vent.erupt_soon()


func direct(_dt: float) -> void:
	sub.aim = (_vent.pos - sub.pos).normalized()
