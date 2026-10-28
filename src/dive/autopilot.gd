class_name Autopilot
extends Node
## Debug/test driver that flies the submarine along the zone's main path,
## pings and fires at threats. Used by the smoke test and screenshot tooling.
##
## Enabled with user args:  -- --autopilot [--shots=<dir>] [--time=<seconds>]
## [--zone=<n>] [--frame=<id>]. Exits the game when time runs out and prints a summary.

var sub: Submarine
var level: Level
var shots_dir := ""
var time_limit := 60.0
var shot_interval := 4.0

## With --stops the decompression stop UI is shown (for screenshots).
var show_stops := false
## --event=<id> forces a zone event in every zone (for screenshots).
var force_event: StringName = &""
var ping_interval := 9.0
var _elapsed := 0.0
var _shot_timer := 1.5
var _path_index := 0
var _ping_timer := 0.0
var _tool_timer := 4.0
## Set while the Lamplighter fight has the lamp switched off.
var _ran_dark := false
var _guardian_seen := false
var _shots := 0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _zones_cleared := 0
var _route := PackedVector2Array()
var _force_exit_at := -1.0
var _max_draw_calls := 0
var _max_primitives := 0
var _max_frame_ms := 0.0
var _frame_ms_sum := 0.0
var _frames := 0
var _reported := false


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
	force_event = StringName(arg("event", ""))
	_force_exit_at = float(arg("force-exit", "-1"))
	ping_interval = float(arg("ping", "9"))
	var zone := int(arg("zone", "-1"))
	if zone >= 0 and Game.run:
		Game.run.zone = zone
	var frame := StringName(arg("frame", ""))
	if Catalog.frame(frame) and Game.run:
		Game.run.frame_id = frame
		Game.run.rebuild_stats(Game.meta.upgrades)
		Game.run.refill()
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(p_sub: Submarine, p_level: Level) -> void:
	if sub != null:
		_zones_cleared += 1
	sub = p_sub
	level = p_level
	sub.input_enabled = false
	_path_index = 0
	_last_pos = sub.pos
	_route = level.layout.find_path(sub.pos, level.layout.exit)
	if _route.is_empty():
		_route = level.layout.main_path


func drive(delta: float) -> void:
	if sub == null or not sub.alive:
		return
	if level.boss and level.boss.active:
		_fight_boss()
		return
	var guardian: Guardian = level.guardian if is_instance_valid(level.guardian) else null
	if guardian and guardian.active:
		if not _guardian_seen:
			_guardian_seen = true
			print("AUTOPILOT: %s woke at %.1f s, hull %.0f" % [guardian.title, _elapsed, sub.run.hull])
		if guardian is BlindMother:
			_fight_mother(guardian as BlindMother, delta)
		else:
			_fight_lamplighter(guardian as Lamplighter, delta)
		return
	if _ran_dark:
		_ran_dark = false
		sub.lamp_on = true
	var path := _route
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
	_use_tools(threat, move, delta)

	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = ping_interval
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


## Against the Blind Mother: hold station near the lair floor and ping to draw
## a lunge, sidestep the charge, then harpoon her while she is stuck.
func _fight_mother(mother: BlindMother, delta: float) -> void:
	var to := mother.pos - sub.pos
	sub.aim = to.normalized()
	sub.facing = 1.0 if sub.aim.x >= 0.0 else -1.0
	match mother.state:
		BlindMother.State.AIM, BlindMother.State.LUNGE:
			# Dodge across the line of the charge.
			sub.external_move = Vector2(-to.y, to.x).normalized()
		BlindMother.State.STUCK:
			sub.external_move = (to - to.normalized() * 7.0).limit_length(1.0)
			if sub.harpoon.state == Harpoon.State.IDLE and to.length() < sub.stats.harpoon_range:
				sub.harpoon.fire(sub.aim)
				sub.harpoon.release()
		_:
			var threat := _nearest_threat()
			if threat and threat != mother:
				sub.aim = (threat.pos - sub.pos).normalized()
				if sub.harpoon.state == Harpoon.State.IDLE and sub.pos.distance_to(threat.pos) < sub.stats.harpoon_range:
					sub.harpoon.fire(sub.aim)
					sub.harpoon.release()
			var station := mother.lair_center + Vector2(0.0, -mother.lair_radius.y * 0.55)
			sub.external_move = (station - sub.pos).limit_length(1.0) * 0.6
			_ping_timer -= delta
			if _ping_timer <= 0.0:
				_ping_timer = 3.0
				sub.try_ping()


## Against the Lamplighter: run dark and ping to break the lure's pull, keep
## clear of the lure, then light her eyes up close (or feed her a flare) and
## harpoon her while she is dazzled.
func _fight_lamplighter(angler: Lamplighter, delta: float) -> void:
	_ran_dark = true
	var head := angler.head_pos()
	var to := head - sub.pos
	var d := to.length()
	sub.aim = to.normalized()
	sub.facing = 1.0 if sub.aim.x >= 0.0 else -1.0
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = 3.0
		sub.try_ping()
	var away_from_lure := (sub.pos - angler.lure_pos()).normalized()
	match angler.state:
		Lamplighter.State.WINDUP, Lamplighter.State.CHARGE:
			sub.lamp_on = false
			sub.external_move = Vector2(-to.y, to.x).normalized()
		Lamplighter.State.DAZZLED:
			sub.lamp_on = false
			sub.external_move = (to - to.normalized() * 8.0).limit_length(1.0) * 0.6
			if sub.harpoon.state == Harpoon.State.IDLE and d < sub.stats.harpoon_range:
				sub.harpoon.fire(sub.aim)
				sub.harpoon.release()
		Lamplighter.State.STALK:
			if sub.tools.current() == &"flare" and sub.run.flares > 0 and d < 20.0:
				_tool_timer -= delta
				if _tool_timer <= 0.0:
					_tool_timer = 6.0
					sub.tools.use(sub.aim)
			# Close in to dazzling range, never onto the lure itself.
			var want := (to - to.normalized() * 10.0).limit_length(1.0)
			if sub.pos.distance_to(angler.lure_pos()) < Lamplighter.SNAP_REACH + 2.5:
				want = away_from_lure
			sub.external_move = want * 0.8
			sub.lamp_on = d < Lamplighter.DAZZLE_RANGE - 2.0
		_:
			sub.lamp_on = false
			sub.external_move = away_from_lure * 0.7


## Every few seconds near a threat, uses the current tool and cycles to the
## next: weapons at the threat, lures (flares, decoys) back along the route.
func _use_tools(threat: Creature, move: Vector2, delta: float) -> void:
	_tool_timer -= delta
	if threat == null or _tool_timer > 0.0:
		return
	_tool_timer = 8.0
	var tool := sub.tools.current()
	sub.tools.use(sub.aim if tool == &"torpedo" or tool == &"shock" else -move)
	sub.tools.cycle()


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
	# The clock starts once the first zone has loaded, so loading time (long in
	# frames when running headless at a fixed frame rate) never eats the budget.
	if sub == null:
		return
	_elapsed += delta
	_frames += 1
	_frame_ms_sum += delta * 1000.0
	if _elapsed > 2.0:
		_max_frame_ms = maxf(_max_frame_ms, delta * 1000.0)
	_max_draw_calls = maxi(_max_draw_calls,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_max_primitives = maxi(_max_primitives,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if shots_dir != "":
		_shot_timer -= delta
		if _shot_timer <= 0.0:
			_shot_timer = shot_interval
			var img := get_viewport().get_texture().get_image()
			img.save_png(shots_dir.path_join("shot_%03d.png" % _shots))
			_shots += 1
	if _force_exit_at > 0.0 and _elapsed >= _force_exit_at and level:
		_force_exit_at = -1.0
		level.exit_reached.emit()
	if _elapsed >= time_limit and not _reported:
		_reported = true
		_report_and_quit()


func _report_and_quit() -> void:
	var run := Game.run
	print("AUTOPILOT: time=%.1f zone=%d zones_cleared=%d hull=%.0f battery=%.0f salvage=%d kills=%d fps=%d" % [
		_elapsed, run.zone if run else -1, _zones_cleared, run.hull if run else 0.0, run.battery if run else 0.0,
		run.salvage if run else 0, run.kills if run else 0, Engine.get_frames_per_second()])
	print("RENDER: max_draw_calls=%d max_primitives=%d avg_frame=%.1fms worst_frame=%.1fms entities=%d" % [
		_max_draw_calls, _max_primitives, _frame_ms_sum / maxi(_frames, 1), _max_frame_ms,
		level.entities.size() if level else 0])
	Router.quit()
