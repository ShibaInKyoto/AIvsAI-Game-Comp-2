class_name DecompressionStop
extends CanvasLayer
## Between zones: the sub docks at a relay buoy. Battery recharges, one
## module is drafted from three, the hull can be repaired for salvage, and
## the player decides whether to go deeper or surface and bank everything.

signal finished(choice: StringName)

const REPAIR_AMOUNT := 40.0

var _run: RunState
var _column: VBoxContainer
var _cards: HBoxContainer
var _picked := false
var _descend: Button
var _repair: Button
var _status: Label


func open(run: RunState) -> void:
	_run = run
	layer = 40
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Docking restores power and some ammunition.
	run.battery = run.stats.max_battery
	run.torpedoes = mini(run.torpedoes + 1, run.stats.torpedo_capacity)
	run.flares = mini(run.flares + 2, run.stats.flare_capacity)
	Audio.play(&"dock", -2.0)
	_build()


func _repair_cost() -> int:
	return 12 + _run.zone * 6


func _build() -> void:
	_column = UiUtil.modal(self, 0.82, 1280)
	_column.add_child(UiUtil.label("DECOMPRESSION STOP", &"TitleLabel"))
	var next := BiomeLibrary.biome_for_zone(_run.zone)
	var depth := BiomeLibrary.zone_depth_range(_run.zone)
	var next_text := "Next: %s, %d - %d m" % [next.display_name, int(depth.x), int(depth.y)]
	if BiomeLibrary.is_final_zone(_run.zone):
		next_text = "Next: the hadal floor. The signal is directly below you."
	_column.add_child(UiUtil.label(next_text, &"HeaderLabel"))
	if _run.zone == BiomeLibrary.LAIR_ZONE:
		_column.add_child(UiUtil.label("Sonar returns from the bottom of the next zone are wrong. Something enormous " +
			"is coiled down there, and it is listening.", &"", 22, UiTheme.DANGER))
	var event := ZoneEvents.for_zone(_run, _run.zone)
	if event != ZoneEvents.NONE:
		_column.add_child(UiUtil.label("Sensor forecast: %s - %s" % [ZoneEvents.display_name(event),
				ZoneEvents.description(event)],
			&"", 22, UiTheme.WARN))
	_status = UiUtil.label("", &"MonoLabel")
	_column.add_child(_status)
	_column.add_child(UiUtil.spacer(6))
	_column.add_child(UiUtil.label("Install one module from the relay's salvage locker:"))

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 18)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_child(_cards)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_run.run_seed, _run.zone, "draft"])
	var first: Button
	for mod in Catalog.draft(rng, _run.modules, _run.stats, 3):
		var card := _module_card(mod)
		_cards.add_child(card)
		if first == null:
			first = card

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_child(UiUtil.spacer(8))
	_column.add_child(row)
	_repair = UiUtil.button("", _on_repair, 330)
	row.add_child(_repair)
	_descend = UiUtil.button("Descend", func() -> void: _finish(&"descend"), 300)
	row.add_child(_descend)
	var bonus := Pressure.depth_bonus(_run.zone)
	var surface := UiUtil.button("Surface  (bank %d salvage)" % int(_run.salvage * bonus),
			func() -> void: _finish(&"surface"), 420)
	row.add_child(surface)
	var terms := "Surfacing now banks all salvage with a x%.1f depth bonus. Implode and you keep only %d%%."
	_column.add_child(UiUtil.label(terms % [bonus, int(_run.stats.insurance * 100)], &"DimLabel"))
	_refresh()
	if first:
		first.grab_focus()
	else:
		_descend.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _picked or _cards == null:
		return
	for i in mini(_cards.get_child_count(), 3):
		if event.is_action_pressed(StringName("pick_%d" % (i + 1))):
			(_cards.get_child(i) as Button).pressed.emit()
			get_viewport().set_input_as_handled()
			return


func _module_card(mod: Catalog.ModuleDef) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, 230)
	b.text = ""
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 16
	box.offset_bottom = -16
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var hotkey := "[%d]  " % (_cards.get_child_count() + 1) if not Settings.using_gamepad else ""
	var rarity := UiUtil.label(hotkey + Catalog.RARITY_NAMES[mod.rarity].to_upper(), &"DimLabel", 16,
			Catalog.RARITY_COLORS[mod.rarity])
	box.add_child(rarity)
	var title := UiUtil.label(mod.name, &"HeaderLabel", 28, mod.color)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var desc := UiUtil.label(mod.description)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	var owned := _run.modules.count(mod.id)
	if owned > 0:
		box.add_child(UiUtil.label("Installed: %d / %d" % [owned, mod.max_stacks], &"DimLabel"))
	for c in box.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := UiTheme.panel_style(Color(0.02, 0.09, 0.13, 0.92), Color(Catalog.RARITY_COLORS[mod.rarity], 0.5), 2, 6)
	b.add_theme_stylebox_override(&"normal", border)
	var hover := border.duplicate() as StyleBoxFlat
	hover.border_color = Catalog.RARITY_COLORS[mod.rarity]
	hover.bg_color = Color(0.05, 0.18, 0.24, 0.96)
	b.add_theme_stylebox_override(&"hover", hover)
	b.add_theme_stylebox_override(&"focus", hover)
	b.mouse_entered.connect(func() -> void: Audio.play_ui(&"ui_hover", -10.0))
	b.pressed.connect(func() -> void: _pick(mod, b))
	return b


func _pick(mod: Catalog.ModuleDef, card: Button) -> void:
	if _picked:
		return
	_picked = true
	_run.add_module(mod.id, Game.meta.upgrades)
	Audio.play_ui(&"module_install")
	for c in _cards.get_children():
		var other := c as Button
		other.disabled = other != card
		if other != card:
			other.modulate = Color(1, 1, 1, 0.35)
	_refresh()
	_descend.grab_focus()


func _on_repair() -> void:
	var cost := _repair_cost()
	if _run.salvage < cost or _run.hull >= _run.stats.max_hull:
		Audio.play_ui(&"denied")
		return
	_run.salvage -= cost
	_run.hull = minf(_run.hull + REPAIR_AMOUNT, _run.stats.max_hull)
	Audio.play_ui(&"repair")
	_refresh()


func _refresh() -> void:
	_status.text = "HULL %d/%d    BATTERY %d/%d    SALVAGE %d    MODULES %d" % [
		ceili(_run.hull), int(_run.stats.max_hull), int(_run.battery), int(_run.stats.max_battery),
		_run.salvage, _run.modules.size()]
	var cost := _repair_cost()
	_repair.text = "Repair hull +%d  (%d salvage)" % [int(REPAIR_AMOUNT), cost]
	_repair.disabled = _run.salvage < cost or _run.hull >= _run.stats.max_hull
	_descend.text = "Descend" if _picked else "Descend without a module"


func _finish(choice: StringName) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	finished.emit(choice)
	queue_free()
