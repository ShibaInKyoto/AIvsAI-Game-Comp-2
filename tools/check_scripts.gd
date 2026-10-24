extends SceneTree
## Loads every script and shader under res://src so parse errors surface in CI.
## Usage: godot --headless --path . -s res://tools/check_scripts.gd

var _failures := 0


func _initialize() -> void:
	_scan("res://src")
	print("check_scripts: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path.path_join(sub))
	for file in dir.get_files():
		if file.ends_with(".gd") or file.ends_with(".gdshader"):
			var path := dir_path.path_join(file)
			var res := load(path)
			if res == null or (res is GDScript and not (res as GDScript).can_instantiate()):
				printerr("FAILED: ", path)
				_failures += 1
