extends "res://tools/debug/preview_stage.gd"
## Debug helper: a pack of ghostfins finds the sub's lamp in the Hadal Trench
## and circles it.
## Usage: xvfb-run godot --path . res://tools/debug/preview_ghostfin.tscn -- <out_dir>


func _ready() -> void:
	stage(8, 3030, &"lantern", true)
	var at := level.layout.start
	for r in range(0, 60, 3):
		var p := level.layout.start + Vector2(r, -r * 0.5)
		if level.field.sample(p) > 6.0:
			at = p
			break
	for i in 3:
		var fin := Ghostfin.new()
		fin.pos = at + Vector2.from_angle(TAU * i / 3.0) * 3.0
		level.add_entity(fin)
	place_sub(at + Vector2(-5.0, 0.0))
	sub.lamp_on = true
	shot_prefix = "ghost"
	shot_times = [1.5, 2.6, 3.6]


func direct(_dt: float) -> void:
	sub.aim = Vector2.RIGHT
	sub.run.hull = sub.stats.max_hull
