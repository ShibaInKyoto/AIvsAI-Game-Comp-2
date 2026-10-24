extends SceneTree
## Headless test runner. Loads every tests/unit/test_*.gd suite after the
## autoloads are up and exits non-zero if anything fails.
## Usage: godot --headless --path . -s res://tests/run_tests.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Wait one frame so the root window is inside the tree for node-based tests.
	await process_frame
	var total_pass := 0
	var total_fail := 0
	var dir := DirAccess.open("res://tests/unit")
	var files := dir.get_files()
	files.sort()
	for file in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/unit/" + file)
		var suite: RefCounted = script.new()
		var t := Time.get_ticks_msec()
		var result: Dictionary = suite.call("run_all")
		total_pass += result.passed
		total_fail += result.failed
		print("%-34s %3d passed  %3d failed  (%d ms)" % [file, result.passed, result.failed, Time.get_ticks_msec() - t])
		for f: String in suite.get("failures"):
			printerr("    FAIL ", f)
	print("TOTAL: %d passed, %d failed" % [total_pass, total_fail])
	quit(1 if total_fail > 0 else 0)
