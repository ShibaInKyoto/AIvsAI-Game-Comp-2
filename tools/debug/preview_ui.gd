extends Node
## Debug helper: shows one UI panel over the menu backdrop and saves a PNG.
## Usage: xvfb-run godot --path . res://tools/debug/preview_ui.tscn -- <out.png> <panel>
## Panels: howto, settings, controls, stop, summary, records, credits, prologue.
## (summary banks a fake dive into the local save).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://ui.png"
	var which := args[1] if args.size() > 1 else "howto"
	add_child(MenuBackdrop.new())
	match which:
		"settings":
			add_child(SettingsPanel.new())
		"credits":
			add_child(CreditsPanel.new())
		"records":
			add_child(RecordsPanel.new())
		"controls":
			add_child(ControlsPanel.new())
		"prologue":
			add_child(Prologue.new())
			await get_tree().create_timer(9.0).timeout
		"summary":
			Game.start_run()
			Game.run.zone = 3
			Game.run.deepest_depth = 812
			Game.run.salvage = 64
			Game.run.kills = 5
			Game.run.ambushes = 2
			Game.run.scans = 3
			Game.run.hull = 0.0
			Game.run.last_hit_by = &"lancer"
			add_child(RunSummary.new())
			(get_child(get_child_count() - 1) as RunSummary).show_result(Game.run, RunState.Outcome.IMPLODED)
		"stop":
			# The busiest stop: the Lamplighter ahead, a wreck to recover and an event forecast.
			Game.start_run()
			Game.run.zone = BiomeLibrary.ANGLER_ZONE
			Game.run.daily = true
			Game.run.daily_event = &"blackout"
			Game.meta.record_wreck(BiomeLibrary.ANGLER_ZONE, &"mako", 84)
			var stop := DecompressionStop.new()
			add_child(stop)
			stop.open(Game.run)
		_:
			add_child(HowToPlayPanel.new())
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(out)
	Router.quit()
