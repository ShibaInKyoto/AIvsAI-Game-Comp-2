extends Node
## Debug helper: shows one UI panel over the menu backdrop and saves a PNG.
## Usage: xvfb-run godot --path . res://tools/debug/preview_ui.tscn -- <out.png> <panel> [zone]
## Panels: howto, settings, erase (armed), controls, stop, summary, records, credits,
## prologue, ending (every log found and the lullaby heard, epilogue shown at once), logs (the hangar's
## archive scrolled to its end: the recordings outside the Meridian set and the
## wonders witnessed; nothing is saved),
## hangar (its upgrades tab), specimen <id> (the hangar codex with that species in the viewport; nothing is saved),
## challenges [scroll px] (the hangar challenges, a few won and a skin worn; nothing is saved).
## (summary banks a fake dive into the local save).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://ui.png"
	var which := args[1] if args.size() > 1 else "howto"
	if which == "ending":
		for l in SignalLogs.LOGS:
			if not Game.meta.logs_found.has(l.id):
				Game.meta.logs_found.append(l.id)
		if not Game.meta.wonders.has("lullaby"):
			Game.meta.wonders.append("lullaby")
		var ending: Node = load(Router.ENDING).instantiate()
		ending.set(&"_fast", true)
		add_child(ending)
		await get_tree().create_timer(9.0).timeout
		get_viewport().get_texture().get_image().save_png(out)
		Router.quit()
		return
	if which == "logs":
		for id in ["log_01", "log_02", "log_03", "log_04", "log_drone", "log_final"]:
			if not Game.meta.logs_found.has(id):
				Game.meta.logs_found.append(id)
		for id in ["manta", "whale", "pearl", "grotto", "glass", "echo"]:
			if not Game.meta.wonders.has(id):
				Game.meta.wonders.append(id)
		var hangar: Node = load(Router.HANGAR).instantiate()
		add_child(hangar)
		await get_tree().process_frame
		hangar.call(&"_show_tab", 3)
		await get_tree().create_timer(1.5).timeout
		var scroll: ScrollContainer = hangar.find_children("*", "ScrollContainer", true, false)[0]
		# An optional third argument scrolls back up that many pixels from the end.
		var back := int(args[2]) if args.size() > 2 else 0
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value) - back
		await get_tree().create_timer(1.5).timeout
		get_viewport().get_texture().get_image().save_png(out)
		Router.quit()
		return
	if which == "challenges":
		# A few won, one skin worn, scrolled to the Lantern's skins (nothing is saved).
		Game.meta.challenges_won.assign(["first_descent", "twilight", "naturalist", "lantern_biolume"])
		Game.meta.challenge_best["lantern_survey"] = 4
		Game.meta.set_livery(&"lantern", "lantern_biolume")
		var hangar: Node = load(Router.HANGAR).instantiate()
		add_child(hangar)
		await get_tree().process_frame
		hangar.call(&"_show_tab", 4)
		await get_tree().create_timer(1.0).timeout
		var scroll: ScrollContainer = hangar.find_children("*", "ScrollContainer", true, false)[0]
		scroll.scroll_vertical = int(args[2]) if args.size() > 2 else 1650
		await get_tree().create_timer(2.0).timeout
		get_viewport().get_texture().get_image().save_png(out)
		Router.quit()
		return
	if which == "hangar":
		add_child(load(Router.HANGAR).instantiate())
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png(out)
		Router.quit()
		return
	if which == "specimen":
		var id := StringName(args[2]) if args.size() > 2 else &"manta"
		Game.meta.codex[String(id)] = 1
		var hangar: Node = load(Router.HANGAR).instantiate()
		add_child(hangar)
		await get_tree().process_frame
		hangar.call(&"_show_tab", 2)
		(hangar.get(&"_backdrop") as MenuBackdrop).preview_creature(id)
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png(out)
		Router.quit()
		return
	add_child(MenuBackdrop.new())
	match which:
		"settings":
			var panel := SettingsPanel.new()
			panel.allow_erase = true
			add_child(panel)
		"erase":
			var armed := SettingsPanel.new()
			armed.allow_erase = true
			add_child(armed)
			armed._on_erase()
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
			Game.run.wonders.assign(["manta", "whale"])
			add_child(RunSummary.new())
			(get_child(get_child_count() - 1) as RunSummary).show_result(Game.run, RunState.Outcome.IMPLODED)
		"stop":
			# The busiest stop: the Lamplighter ahead, a wreck to recover and an event forecast.
			var zone := int(args[2]) if args.size() > 2 else BiomeLibrary.ANGLER_ZONE
			Game.start_run()
			Game.run.zone = zone
			Game.run.daily = true
			Game.run.daily_event = &"blackout"
			Game.meta.record_wreck(zone, &"mako", 84)
			var stop := DecompressionStop.new()
			add_child(stop)
			stop.open(Game.run)
		_:
			add_child(HowToPlayPanel.new())
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(out)
	Router.quit()
