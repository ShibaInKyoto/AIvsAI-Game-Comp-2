extends Node
## Debug helper: shows the title screen as a fresh save sees it (the Sunlit
## Shelf behind the menu) and saves screenshots as it plays, by frame count
## so slow software rendering still sees the backdrop at the same moments.
## Usage: xvfb-run godot --path . res://tools/debug/preview_title.tscn -- <out_dir> [frames between shots]

var _out := "user://"
var _every := 80
var _frame := 0
var _shots := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_every = int(args[1])
	Game.meta.deepest_zone = 0
	add_child(load(Router.TITLE).instantiate())


func _process(_delta: float) -> void:
	_frame += 1
	if _frame % _every == 0:
		get_viewport().get_texture().get_image().save_png(_out.path_join("title_%d.png" % _shots))
		_shots += 1
		if _shots >= 6:
			Router.quit()
