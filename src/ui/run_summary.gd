class_name RunSummary
extends CanvasLayer
## End-of-dive report. Banks the run through [method Game.end_run] and offers
## a way back to the hangar or straight into another dive.


func show_result(run: RunState, outcome: RunState.Outcome) -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var run_salvage := run.salvage
	var banked := Game.end_run(outcome)
	var column := UiUtil.modal(self, 0.85, 900)
	var title := ""
	var subtitle := ""
	var color := UiTheme.TEXT
	match outcome:
		RunState.Outcome.IMPLODED:
			title = "SIGNAL LOST"
			subtitle = "The Lantern imploded at %d m." % run.deepest_depth
			color = UiTheme.DANGER
			Audio.play_music(&"loss", 1.0)
		RunState.Outcome.SURFACED:
			title = "SURFACED"
			subtitle = "You made it back up from %d m." % run.deepest_depth
			color = UiTheme.GOOD
		RunState.Outcome.VICTORY:
			title = "THE CHOIR IS SILENT"
			subtitle = "You reached the bottom of the world."
			color = UiTheme.ACCENT
	column.add_child(UiUtil.label(title, &"TitleLabel", 72, color))
	column.add_child(UiUtil.label(subtitle, &"HeaderLabel"))
	var panel := PanelContainer.new()
	column.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 60)
	grid.add_theme_constant_override(&"v_separation", 8)
	panel.add_child(grid)
	var rows: Array = [
		["Deepest point", "%d m" % run.deepest_depth],
		["Zones cleared", "%d" % run.zone],
		["Dive time", UiUtil.format_time(run.time)],
		["Creatures defeated", "%d" % run.kills],
		["Species scanned", "%d" % run.scans],
		["Signal logs", "%d" % run.logs],
		["Salvage recovered", "%d" % run_salvage],
		["Expedition pay", "%d" % Game.expedition_pay(run)],
		["Salvage banked", "%d" % banked],
		["Research gained", "%d" % run.research],
	]
	for r: Array in rows:
		grid.add_child(UiUtil.label(r[0], &"DimLabel", 22))
		grid.add_child(UiUtil.label(r[1], &"MonoLabel", 24))
	for m in Game.last_milestones:
		column.add_child(UiUtil.label("Milestone: %s  -  %s paint unlocked in the hangar" % [m.name, m.paint_name],
				&"", 22, UiTheme.WARN))
	if outcome == RunState.Outcome.IMPLODED:
		column.add_child(UiUtil.label("Insurance recovered %d%% of your salvage." % int(run.stats.insurance * 100),
				&"DimLabel"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 20)
	column.add_child(row)
	var hangar := UiUtil.button("Return to hangar", func() -> void: Router.go_to(Router.HANGAR), 320)
	row.add_child(hangar)
	row.add_child(UiUtil.button("Dive again", func() -> void:
		Game.start_run()
		Router.go_to(Router.DIVE), 260))
	hangar.grab_focus()
	if Autopilot.requested():
		get_tree().create_timer(1.0).timeout.connect(get_tree().quit)
