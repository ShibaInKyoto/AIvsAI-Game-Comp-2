extends Node
## End-to-end smoke test of the real scenes and menus, driven by code:
## title -> dive -> decompression stop -> next zone -> pause & settings ->
## implosion -> run summary -> hangar (buy, tabs) -> title.
## Run headless:  godot --headless --path . res://tests/flow_test.tscn
## Exits with code 1 if a step times out.

const STEP_TIMEOUT := 20.0

## The copy that actually runs lives under the root window, because the
## scene this node starts in gets replaced by the first scene change.
var runner := false


func _ready() -> void:
	if not runner:
		var copy: Node = get_script().new()
		copy.runner = true
		get_tree().root.add_child.call_deferred(copy)
		return
	Game.meta = MetaState.new()
	Game.meta.salvage = 500
	_run.call_deferred()


func _run() -> void:
	Router.go_to(Router.TITLE, 0.05)
	var title: Node = await _wait_scene("title_screen")
	title.call("_on_dive")
	var dive: Node = await _wait_scene("Dive")
	await _wait(func() -> bool: return dive.get("state") == 1)
	print("FLOW: dive loaded, zone ", Game.run.zone)

	dive.call("_on_exit_reached")
	var stop: DecompressionStop = await _wait_node(func() -> Node: return _find(dive, "DecompressionStop"))
	var cards: HBoxContainer = stop.get("_cards")
	(cards.get_child(0) as Button).pressed.emit()
	check(Game.run.modules.size() == 1, "module installed")
	stop.call("_finish", &"descend")
	await _wait(func() -> bool: return dive.get("state") == 1 and Game.run.zone == 1)
	print("FLOW: zone 2 loaded")

	var pause: PauseMenu = dive.get("_pause_menu")
	pause.open()
	pause.call("_open_settings")
	await get_tree().process_frame
	var settings: SettingsPanel = pause.get("_settings")
	settings.call("_close")
	pause.close()
	print("FLOW: pause and settings ok")

	var sub: Submarine = dive.get("sub")
	sub.take_damage(9999.0, sub.pos)
	var summary: RunSummary = await _wait_node(func() -> Node: return _find(dive, "RunSummary"))
	check(is_instance_valid(summary), "run summary shown")
	check(Game.run.outcome == RunState.Outcome.IMPLODED, "run recorded as imploded")
	print("FLOW: summary shown, salvage banked total ", Game.meta.salvage)
	Router.go_to(Router.HANGAR, 0.05)
	var hangar: Node = await _wait_scene("hangar")
	for tab in 5:
		hangar.call("_show_tab", tab)
		await get_tree().process_frame
	var before := Game.meta.salvage
	check(Game.meta.buy_upgrade(&"hull"), "buy hull upgrade")
	check(Game.meta.salvage < before, "salvage spent")
	print("FLOW: hangar ok")

	Router.go_to(Router.ENDING, 0.05)
	await _wait_scene("Ending")
	await get_tree().create_timer(1.0).timeout
	Router.go_to(Router.TITLE, 0.05)
	await _wait_scene("title_screen")
	print("FLOW: PASSED")
	Router.quit(0)


func check(ok: bool, what: String) -> void:
	if not ok:
		printerr("FLOW: FAILED ", what)
		get_tree().quit(1)
		# Stop this coroutine here; quit() takes effect at the end of the frame.
		await get_tree().create_timer(3600.0).timeout


func _find(root: Node, cls: String) -> Node:
	for c in root.get_children():
		if c.get_script() and c.get_script().get_global_name() == cls:
			return c
	return null


func _wait(cond: Callable) -> void:
	var t := 0.0
	while not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > STEP_TIMEOUT:
			printerr("FLOW: FAILED timeout")
			get_tree().quit(1)
			return


func _wait_node(getter: Callable) -> Node:
	# Lambdas capture locals by value, so the result travels in an array.
	var found: Array[Node] = [null]
	await _wait(func() -> bool:
		found[0] = getter.call()
		return found[0] != null)
	return found[0]


func _wait_scene(scene_name: String) -> Node:
	await _wait(func() -> bool:
		var cs := get_tree().current_scene
		return cs != null and cs.name == scene_name and cs.is_node_ready())
	await get_tree().process_frame
	return get_tree().current_scene
