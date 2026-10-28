extends "res://tools/debug/preview_stage.gd"
## Debug helper: a few spined puffers beside the sub in the Sunlit Shelf,
## photographed calm, swollen and bursting.
## Usage: xvfb-run godot --path . res://tools/debug/preview_puffer.tscn -- <out_dir>

var _puffers: Array[Puffer] = []
var _step := 0


func _ready() -> void:
	stage(0, 4040, &"lantern", true)
	var at := level.layout.start + Vector2(7.0, -6.0)
	for offset: Vector2 in [Vector2.ZERO, Vector2(2.6, 1.6), Vector2(1.2, -2.2)]:
		var p := Puffer.new()
		p.pos = at + offset
		level.add_entity(p)
		_puffers.append(p)
	place_sub(at + Vector2(-6.5, 0.5))
	shot_prefix = "puffer"
	shot_times = [0.8, 1.9, 2.3]


func direct(_dt: float) -> void:
	sub.aim = Vector2.RIGHT
	if _step == 0 and t > 1.0:
		_step = 1
		for p in _puffers:
			p.puff()
	elif _step == 1 and t > 2.1:
		_step = 2
		_puffers[0].on_harpoon_hit(null, 5.0)
