extends Node3D
## The hangar: spend salvage on upgrades, research on new frames, browse the
## codex and recovered logs, pick a pressure level and start a dive.

enum Tab { UPGRADES, FRAMES, CODEX, LOGS }

var _backdrop: MenuBackdrop
var _content: VBoxContainer
var _currency: Label
var _tab := Tab.UPGRADES
var _tab_buttons: Array[Button] = []
var _pressure_label: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_backdrop = MenuBackdrop.new()
	add_child(_backdrop)
	Audio.play_music(&"title")
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.get_theme()
	layer.add_child(ui)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.0, 0.02, 0.04, 0.45)
	ui.add_child(shade)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_top = 40
	root.offset_right = -60
	root.offset_bottom = -40
	ui.add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(1040, 0)
	left.add_theme_constant_override(&"separation", 12)
	root.add_child(left)

	var header := HBoxContainer.new()
	left.add_child(header)
	header.add_child(UiUtil.label("HANGAR", &"TitleLabel", 60))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(fill)
	_currency = UiUtil.label("", &"HeaderLabel")
	_currency.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_currency)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 8)
	left.add_child(tabs)
	for t: Array in [[Tab.UPGRADES, "Upgrades"], [Tab.FRAMES, "Submarines"], [Tab.CODEX, "Codex"], [Tab.LOGS, "Signal logs"]]:
		var tab_id: Tab = t[0]
		var b := UiUtil.button(t[1], func() -> void: _show_tab(tab_id), 230)
		b.toggle_mode = true
		tabs.add_child(b)
		_tab_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 10)
	scroll.add_child(_content)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 14)
	left.add_child(footer)
	footer.add_child(UiUtil.button("Back", func() -> void: Router.go_to(Router.TITLE), 180))
	if Game.meta.pressure_unlocked > 0:
		footer.add_child(UiUtil.button("-", func() -> void: _change_pressure(-1), 60))
		_pressure_label = UiUtil.label("", &"MonoLabel")
		_pressure_label.custom_minimum_size = Vector2(300, 0)
		_pressure_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.add_child(_pressure_label)
		footer.add_child(UiUtil.button("+", func() -> void: _change_pressure(1), 60))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var dive := UiUtil.button("Begin dive", func() -> void:
		Game.start_run()
		Router.go_to(Router.DIVE), 300)
	footer.add_child(dive)

	_show_tab(Tab.UPGRADES)
	dive.grab_focus()


func _refresh_header() -> void:
	_currency.text = "%d SALVAGE    %d RESEARCH" % [Game.meta.salvage, Game.meta.research]
	if _pressure_label:
		var p := Game.meta.pressure_selected
		_pressure_label.text = "PRESSURE %d" % p if p > 0 else "PRESSURE 0 (standard)"
		_pressure_label.tooltip_text = "\n".join(Pressure.DESCRIPTIONS.slice(1, p + 1))


func _change_pressure(delta: int) -> void:
	Game.meta.pressure_selected = clampi(Game.meta.pressure_selected + delta, 0, Game.meta.pressure_unlocked)
	Game.save_game()
	_refresh_header()
	_show_tab(_tab)


func _show_tab(tab: Tab) -> void:
	_tab = tab
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = i == tab
	UiUtil.clear(_content)
	match tab:
		Tab.UPGRADES:
			_build_upgrades()
		Tab.FRAMES:
			_build_frames()
		Tab.CODEX:
			_build_codex()
		Tab.LOGS:
			_build_logs()
	_refresh_header()


func _row_panel() -> HBoxContainer:
	var panel := PanelContainer.new()
	_content.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	panel.add_child(row)
	return row


func _build_upgrades() -> void:
	if Game.meta.pressure_selected > 0:
		var notes := "Active pressure modifiers: " + ", ".join(Pressure.DESCRIPTIONS.slice(1, Game.meta.pressure_selected + 1))
		var l := UiUtil.label(notes, &"DimLabel", 18, UiTheme.WARN)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(l)
	for up in Catalog.upgrades():
		var row := _row_panel()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UiUtil.label(up.name, &"HeaderLabel", 26))
		info.add_child(UiUtil.label(up.description, &"DimLabel"))
		var level := Game.meta.upgrade_level(up.id)
		var pips := ""
		for i in up.max_level():
			pips += "[#] " if i < level else "[ ] "
		var pip_label := UiUtil.label(pips, &"MonoLabel", 22, UiTheme.ACCENT)
		pip_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pip_label)
		var b: Button
		if level >= up.max_level():
			b = UiUtil.button("Maxed", func() -> void: pass, 220)
			b.disabled = true
		else:
			var cost := up.costs[level]
			var id := up.id
			b = UiUtil.button("Upgrade  %d" % cost, func() -> void:
				if Game.meta.buy_upgrade(id):
					Audio.play_ui(&"purchase")
					Game.save_game()
				else:
					Audio.play_ui(&"denied")
				_show_tab(Tab.UPGRADES), 220)
			b.disabled = not Game.meta.can_afford(cost)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)


func _build_frames() -> void:
	for f in Catalog.frames():
		var row := _row_panel()
		var swatch := ColorRect.new()
		swatch.color = f.hull_color
		swatch.custom_minimum_size = Vector2(14, 80)
		row.add_child(swatch)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UiUtil.label(f.name, &"HeaderLabel", 28))
		var desc := UiUtil.label(f.description, &"DimLabel")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
		var stats := SubStats.build(f.id, {}, [])
		var tools := ", ".join(stats.tools.map(func(t: StringName) -> String: return Catalog.TOOL_NAMES.get(t, String(t))))
		info.add_child(UiUtil.label("Hull %d   Battery %d   Speed %.1f   Tools: %s" % [
			stats.max_hull, stats.max_battery, stats.max_speed, tools if tools != "" else "harpoon only"], &"MonoLabel", 18))
		var id := f.id
		var b: Button
		if Game.meta.selected_frame == String(id):
			b = UiUtil.button("Selected", func() -> void: pass, 220)
			b.disabled = true
		elif Game.meta.is_frame_unlocked(id):
			b = UiUtil.button("Select", func() -> void:
				Game.meta.selected_frame = String(id)
				Game.save_game()
				_backdrop.refresh_sub()
				_show_tab(Tab.FRAMES), 220)
		else:
			b = UiUtil.button("Unlock  %d research" % f.research_cost, func() -> void:
				if Game.meta.unlock_frame(id):
					Audio.play_ui(&"purchase")
					Game.meta.selected_frame = String(id)
					Game.save_game()
					_backdrop.refresh_sub()
				else:
					Audio.play_ui(&"denied")
				_show_tab(Tab.FRAMES), 300)
			b.disabled = Game.meta.research < f.research_cost
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	_content.add_child(UiUtil.label("Research comes from scanning creatures with your lamp and recovering signal logs.", &"DimLabel"))


func _build_codex() -> void:
	var known := 0
	for e in CreatureCodex.entries():
		var scanned := Game.meta.codex.has(String(e.id))
		known += 1 if scanned else 0
		var row := _row_panel()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		if scanned:
			info.add_child(UiUtil.label("%s   %s" % [e.name, e.latin], &"HeaderLabel", 26))
			var notes := UiUtil.label(e.notes)
			notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(notes)
			info.add_child(UiUtil.label("Threat: %s   -   Scanned %d times" % [e.threat, Game.meta.codex[String(e.id)]], &"DimLabel"))
		else:
			info.add_child(UiUtil.label("? ? ?", &"HeaderLabel", 26, UiTheme.TEXT_DIM))
			info.add_child(UiUtil.label("Not yet scanned. Hold your lamp on a creature to scan it.", &"DimLabel"))
	var head := UiUtil.label("%d / %d species catalogued" % [known, CreatureCodex.entries().size()], &"MonoLabel")
	_content.add_child(head)
	_content.move_child(head, 0)


func _build_logs() -> void:
	var found := Game.meta.logs_found
	_content.add_child(UiUtil.label("%d / %d logs recovered" % [found.size(), SignalLogs.count()], &"MonoLabel"))
	for l in SignalLogs.LOGS:
		var row := _row_panel()
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		if found.has(l.id):
			info.add_child(UiUtil.label("%s  -  %s" % [l.title, l.author], &"HeaderLabel", 24))
			var text := UiUtil.label(l.text)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(text)
		else:
			info.add_child(UiUtil.label("[ encrypted ]", &"HeaderLabel", 24, UiTheme.TEXT_DIM))
			info.add_child(UiUtil.label("Recover this log from a black-box beacon in the trench.", &"DimLabel"))
