extends Node
## Boot scene: installs the UI theme and hands over to the title screen
## (or straight into a dive when the autopilot test harness is requested).


func _ready() -> void:
	get_tree().root.theme = UiTheme.get_theme()
	var target := Router.TITLE
	if Autopilot.requested():
		Game.start_run()
		target = Router.DIVE
	get_tree().change_scene_to_file.call_deferred(target)
