class_name Autopilot
extends Node
## Debug/test driver that flies the submarine along the zone's main path,
## pings and fires at threats. Used by the smoke test and screenshot tooling.
##
## Enabled with user args:  -- --autopilot [--shots=<dir>] [--time=<seconds>]
## [--zone=<n>]. Exits the game when time runs out and prints a summary.

var sub: Submarine
var level: Level
var shots_dir := ""
var time_limit := 60.0
var shot_interval := 4.0

var _elapsed := 0.0
var _shot_timer := 1.5
var _path_index := 0
var _ping_timer := 0.0
var _shots := 0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _zones_cleared := 0
## With --stops the decompression stop UI is shown (for screenshots).
var show_stops := false


static func requested() -> bool:
	return OS.get_cmdline_user_args().has("--autopilot")


static func arg(name: String, default: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.split("=", true, 1)[1]
	return default


func _ready() -> void:
	shots_dir = arg("shots", "")
	time_limit = float(arg("time", "60"))
	shot_interval = float(arg("interval", "4"))
	show_stops = OS.get_cmdline_user_args().has("--stops")
	var zone := int(arg("zone", "-1"))
	if zone >= 0 and Game.run:
		Game.run.zone = zone
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(p_sub: Submarine, p_level: Level) -> void:
	if sub != null:
		_zones_cleared += 1
	sub = p_sub
	level = p_level
	sub.input_enabled = false
	_path_index = 0
	_last_pos = sub.pos


func drive(delta: float) -> void:
	if sub == null or not sub.alive:
		return
	if level.boss and level.boss.active:
		_fight_boss()
		return
	var path := level.layout.main_path
	# Advance along the path once we are close to the current waypoint.
	while _path_index < path.size() - 1 and sub.pos.distance_to(path[_path_index]) < 6.0:
		_path_index += 1
	var target := path[mini(_path_index + 1, path.size() - 1)]
	if _path_index >= path.size() - 2:
		target = level.layout.exit
	var to := target - sub.pos
	var move := to.normalized()
	var threat := _nearest_threat()
	if threat:
		sub.aim = (threat.pos - sub.pos).normalized()
		if sub.harpoon.state == Harpoon.State.IDLE and sub.pos.distance_to(threat.pos) < sub.stats.harpoon_range:
			sub.harpoon.fire(sub.aim)
			sub.harpoon.release()
	else:
		sub.aim = sub.aim.slerp(move, 0.1).normalized()
	sub.facing = 1.0 if sub.aim.x >= 0.0 else -1.0
	sub.external_move = move

	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = 5.0
		sub.try_ping()

	# Unstick: if we have not moved for a while, skip ahead on the path.
	_stuck_timer += delta
	if _stuck_timer > 3.0:
		if sub.pos.distance_to(_last_pos) < 3.0:
			_path_index = mini(_path_index + 3, path.size() - 1)
		_stuck_timer = 0.0
		_last_pos = sub.pos


## Holds position near an organ, answers every wave and strikes open organs.
func _fight_boss() -> void:
	var boss := level.boss
	var eta := boss.next_arrival(sub.pos)
	if eta < 0.12:
		sub.try_ping()
	var organ: ChoirOrgan = null
	for o in boss.organs:
		if organ == null or o.pos.distance_to(sub.pos) < organ.pos.distance_to(sub.pos):
			organ = o
	if organ == null:
		sub.external_move = Vector2.ZERO
		return
	var to := organ.pos - sub.pos
	var want := organ.pos - to.normalized() * 9.0
	sub.external_move = (want - sub.pos).limit_length(1.0)
	sub.aim = to.normalized()
	sub.facing = 1.0 if sub.aim.x >= 0.0 else -1.0
	if boss.vulnerable > 0.3 and sub.harpoon.state == Harpoon.State.IDLE and to.length() < sub.stats.harpoon_range:
		sub.harpoon.fire(sub.aim)
		sub.harpoon.release()


func _nearest_threat() -> Creature:
	var best: Creature = null
	var best_d := 14.0
	for e in level.targets_in_radius(sub.pos, 14.0):
		var c := e as Creature
		if c and c.is_hostile():
			var d := c.pos.distance_to(sub.pos)
			if d < best_d and level.field.line_of_sight(sub.pos, c.pos):
				best = c
				best_d = d
	return best


func _process(delta: float) -> void:
	_elapsed += delta
	if shots_dir != "":
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = shot_interval
			var img := get_viewport().get_texture().get_image()
			img.save_png(shots_dir.path_join("shot_%03d.png" % _shots))
			_shots += 1
	if _elapsed >= time_limit:
		_report_and_quit()


func _report_and_quit() -> void:
	var run := Game.run
	print("AUTOPILOT: time=%.1f zone=%d zones_cleared=%d hull=%.0f battery=%.0f salvage=%d kills=%d fps=%d" % [
		_elapsed, run.zone if run else -1, _zones_cleared, run.hull if run else 0.0, run.battery if run else 0.0,
		run.salvage if run else 0, run.kills if run else 0, Engine.get_frames_per_second()])
	get_tree().quit()
