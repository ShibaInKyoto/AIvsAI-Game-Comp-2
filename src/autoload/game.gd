extends Node
## Owns the persistent [MetaState], the current [RunState] and saving.

signal meta_changed

const SAVE_PATH := "user://save.json"

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
			meta.stalkers_killed += 1)


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
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
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
	f.store_string(JSON.stringify(meta.to_dict(), "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))
	meta_changed.emit()


func reset_progress() -> void:
	meta = MetaState.new()
	save_game()


## Starts a new dive with the selected frame. Daily dives use a date seed.
func start_run(daily := false) -> void:
	run = RunState.new()
	run.frame_id = StringName(meta.selected_frame)
	run.daily = daily
	run.pressure = meta.pressure_selected if not daily else 0
	if daily:
		var d := Time.get_date_dict_from_system()
		run.run_seed = hash("%04d-%02d-%02d" % [d.year, d.month, d.day]) & 0x7fffffff
	else:
		run.run_seed = randi() & 0x7fffffff
	run.rebuild_stats(meta.upgrades)
	run.refill()
	meta.dives += 1
	save_game()


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
	last_milestones = Milestones.check(meta, run)
	save_game()
	return kept
