class_name ModulesPanel
extends CanvasLayer
## The modules installed on this dive, each with what it does (from the pause
## menu: a pilot can forget what they drafted three stops ago).

var run: RunState


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var column := UiUtil.modal(self, 0.8, 900)
	column.add_child(UiUtil.label("INSTALLED MODULES", &"TitleLabel"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 8)
	scroll.add_child(list)
	var seen: Array[StringName] = []
	for id in run.modules if run else []:
		if seen.has(id):
			continue
		seen.append(id)
		var mod := Catalog.module(id)
		if mod == null:
			continue
		var panel := PanelContainer.new()
		list.add_child(panel)
		var info := VBoxContainer.new()
		panel.add_child(info)
		var count := run.modules.count(id)
		var title := mod.name + ("   x%d" % count if count > 1 else "")
		info.add_child(UiUtil.label(title, &"HeaderLabel", 24, mod.color))
		var desc := UiUtil.label(mod.description)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
	if seen.is_empty():
		list.add_child(UiUtil.label("None yet. Every decompression stop offers one.", &"DimLabel"))
	var close := UiUtil.button("Back", queue_free)
	column.add_child(close)
	close.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		queue_free()
		get_viewport().set_input_as_handled()
