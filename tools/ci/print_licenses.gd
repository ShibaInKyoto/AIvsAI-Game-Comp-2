extends SceneTree
## Prints the engine and third-party licenses the game ships under, for the
## release archive.  Usage: godot --headless --path . -s res://tools/ci/print_licenses.gd


func _initialize() -> void:
	print(CreditsPanel.license_text())
	quit()
