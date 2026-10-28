extends Node
## Debug helper: shows one UI panel over the menu backdrop and saves a PNG.
## Usage: xvfb-run godot --path . res://tools/debug/preview_ui.tscn -- <out.png> <howto|settings|stop|summary>
## (summary banks a fake dive into the local save).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://ui.png"
	var which := args[1] if args.size() > 1 else "howto"
	add_child(MenuBackdrop.new())
	match which:
		"settings":
			add_child(SettingsPanel.new())
		"summary":
			Game.start_run()
			Game.run.zone = 3
			Game.run.deepest_depth = 812
			Game.run.salvage = 64
			Game.run.hull = 0.0
			Game.run.last_hit_by = &"lancer"
			add_child(RunSummary.new())
			(get_child(get_child_count() - 1) as RunSummary).show_result(Game.run, RunState.Outcome.IMPLODED)
		"stop":
			Game.start_run()
			Game.run.zone = 3
			var stop := DecompressionStop.new()
			add_child(stop)
			stop.open(Game.run)
		_:
			add_child(HowToPlayPanel.new())
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(out)
	Router.quit()
