extends Node
## Debug helper: the menu backdrop showing codex specimens in place of the
## submarine, one screenshot per species.
## Usage: xvfb-run godot --path . res://tools/debug/preview_specimen.tscn -- <out_dir> [ids...]

var _backdrop: MenuBackdrop
var _ids: PackedStringArray = ["lancer", "puffer", "ghostfin", "lamplighter"]
var _out := "user://"
var _t := 0.0
var _index := -1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_ids = args.slice(1)
	_backdrop = MenuBackdrop.new()
	_backdrop.force_zone = 2
	add_child(_backdrop)


func _process(delta: float) -> void:
	_t += minf(delta, 0.05)
	var step := int(_t / 1.5)
	if step != _index and step <= _ids.size():
		if _index >= 0:
			get_viewport().get_texture().get_image().save_png(_out.path_join("specimen_%s.png" % _ids[_index]))
		_index = step
		if _index >= _ids.size():
			get_tree().quit()
			return
		_backdrop.preview_creature(StringName(_ids[_index]))
