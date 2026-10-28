extends Node
## Owns the persistent [MetaState], the current [RunState] and saving.

signal meta_changed

const SAVE_PATH := "user://save.json"
## The dive in progress, snapshotted at the start of each zone so quitting
## mid-dive is not the end of it.
const RUN_PATH := "user://run.json"

var meta := MetaState.new()
var run: RunState
## Salvage banked by the last victorious dive (shown by the ending).
var last_victory_banked := 0
## Milestones unlocked when the last run ended (shown by the summary).
var last_milestones: Array[Milestones.Milestone] = []


func _ready() -> void:
	load_game()
	Events.creature_killed.connect(func(id: StringName, _p: Vector2) -> void:
		if id == &"stalker":
			meta.stalkers_killed += 1
		elif id == &"mother":
			meta.mothers_killed += 1
			check_milestones())


## Hull color for a frame, honoring the chosen milestone paint.
func hull_color(frame_id: StringName) -> Color:
	var m := Milestones.find(meta.paint)
	if m:
		return m.paint
	var f := Catalog.frame(frame_id)
	return f.hull_color if f else Color(1.0, 0.6, 0.1)


## Awards newly met milestones and announces them. Returns them.
func check_milestones() -> Array[Milestones.Milestone]:
	var fresh := Milestones.check(meta, run)
	for m in fresh:
		Events.toast.emit("Milestone: %s  -  %s paint unlocked" % [m.name, m.paint_name], UiTheme.WARN)
		Audio.play(&"purchase", -2.0)
	if not fresh.is_empty():
		save_game()
	return fresh


func load_game() -> void:
	var path := SAVE_PATH
	# A crash between replacing the old save and moving the new one into
	# place leaves only the temp file; it is complete, so use it.
	if not FileAccess.file_exists(path) and FileAccess.file_exists(SAVE_PATH + ".tmp"):
		path = SAVE_PATH + ".tmp"
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		meta = MetaState.from_dict(parsed)
	else:
		push_warning("Save file unreadable; starting fresh.")


func save_game() -> void:
	# Write to a temp file first so a crash mid-write cannot corrupt the save.
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	var text := JSON.stringify(meta.to_dict(), "\t")
	f.store_string(text)
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		# Some file systems refuse to replace in place; write directly instead.
		var direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if direct:
			direct.store_string(text)
			direct.close()
	meta_changed.emit()


func reset_progress() -> void:
	meta = MetaState.new()
	save_game()


## Snapshots the current dive (called as each zone begins).
func save_run() -> void:
	if run == null or Autopilot.requested():
		return
	var f := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(run.to_dict()))
		f.close()


func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_PATH)


## The interrupted dive, or null if there is none (or it is unreadable).
func saved_run() -> RunState:
	if not has_saved_run():
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH))
	return RunState.from_dict(parsed, meta.upgrades) if parsed is Dictionary else null


## Continues the interrupted dive from the start of the zone it was in.
func resume_run() -> bool:
	var saved := saved_run()
	if saved == null:
		clear_saved_run()
		return false
	run = saved
	return true


func clear_saved_run() -> void:
	if has_saved_run():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


## Starts a new dive with the selected frame. Daily dives use a date seed.
## An interrupted dive that is not resumed counts as abandoned.
func start_run(daily := false) -> void:
	var interrupted := saved_run()
	if interrupted:
		run = interrupted
		end_run(RunState.Outcome.IMPLODED)
	run = RunState.new()
	run.frame_id = StringName(meta.selected_frame)
	run.daily = daily
	run.pressure = meta.pressure_selected if not daily else 0
	if daily:
		run.run_seed = hash(today()) & 0x7fffffff
		run.daily_event = ZoneEvents.daily(today())
		meta.begin_daily(today())
	else:
		run.run_seed = randi() & 0x7fffffff
	run.rebuild_stats(meta.upgrades)
	run.refill()
	meta.dives += 1
	save_game()


## Today's local date as YYYY-MM-DD (the daily dive key).
static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Guaranteed salvage for the depth reached, independent of the outcome.
static func expedition_pay(r: RunState) -> int:
	return r.zone * 8


## Ends the dive, banks currencies and records statistics.
## Returns the amount of salvage banked.
func end_run(outcome: RunState.Outcome) -> int:
	if run == null:
		return 0
	run.outcome = outcome
	var kept := run.salvage
	if outcome == RunState.Outcome.SURFACED:
		kept = int(run.salvage * Pressure.depth_bonus(run.zone))
	elif outcome == RunState.Outcome.IMPLODED:
		kept = int(run.salvage * clampf(run.stats.insurance, 0.0, 1.0))
	elif outcome == RunState.Outcome.VICTORY:
		kept = int(run.salvage * Pressure.depth_bonus(run.zone + 2))
		meta.wins += 1
		meta.best_pressure_win = maxi(meta.best_pressure_win, run.pressure)
		meta.pressure_unlocked = maxi(meta.pressure_unlocked, mini(run.pressure + 1, Pressure.MAX_LEVEL))
	# Expedition pay: every zone reached is worth something, even in defeat.
	kept += expedition_pay(run)
	meta.salvage += kept
	meta.total_salvage += kept
	meta.research += run.research
	meta.total_kills += run.kills
	meta.deepest_zone = maxi(meta.deepest_zone, run.zone)
	meta.deepest_depth = maxi(meta.deepest_depth, run.deepest_depth)
	if run.daily:
		meta.daily_best_depth = maxi(meta.daily_best_depth, run.deepest_depth)
		meta.daily_won = meta.daily_won or outcome == RunState.Outcome.VICTORY
	last_milestones = Milestones.check(meta, run)
	clear_saved_run()
	save_game()
	return kept
