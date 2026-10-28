class_name RecordsPanel
extends CanvasLayer
## The pilot's five best dives by score (see [DiveScore]).


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := UiUtil.modal(self, 0.85, 1000)
	column.add_child(UiUtil.label("RECORDS", &"TitleLabel"))
	var records := Game.meta.records
	if records.is_empty():
		column.add_child(UiUtil.label("No dives on record yet. Depth, kills, scans, logs and salvage all score.",
				&"DimLabel", 20))
	else:
		var panel := PanelContainer.new()
		column.add_child(panel)
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override(&"h_separation", 34)
		grid.add_theme_constant_override(&"v_separation", 10)
		panel.add_child(grid)
		for h in ["", "SCORE", "SUB", "DEPTH", "RESULT", "DATE"]:
			grid.add_child(UiUtil.label(h, &"DimLabel", 16))
		for i in records.size():
			var r := records[i]
			var color := UiTheme.WARN if i == 0 else UiTheme.TEXT
			var frame := Catalog.frame(StringName(r.frame))
			var result: String = r.outcome
			if int(r.pressure) > 0:
				result += "  (P%d)" % int(r.pressure)
			if r.daily:
				result += "  daily"
			var terms := Contracts.find(StringName(r.get("contract", "")))
			if terms:
				result += "  " + terms.name
			for cell: String in ["#%d" % (i + 1), UiUtil.thousands(int(r.score)), frame.name if frame else "?",
					"%s m" % UiUtil.thousands(int(r.depth)), result, r.date]:
				grid.add_child(UiUtil.label(cell, &"MonoLabel", 22, color))
	var rules := UiUtil.label(("Score: metres descended, +%d per kill, +%d per ambush, +%d per scan, +%d per log, " +
			"plus the salvage you recovered. Surfacing and silencing the Choir add bonuses; pressure multiplies " +
			"it all.") % [DiveScore.PER_KILL, DiveScore.PER_AMBUSH, DiveScore.PER_SCAN, DiveScore.PER_LOG],
			&"DimLabel", 17)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(rules)
	var close := UiUtil.button("Back", queue_free)
	column.add_child(close)
	close.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
