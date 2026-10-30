class_name MetaState
extends RefCounted
## Progress that persists between dives: banked currencies, hangar upgrades,
## unlocked frames, codex and statistics. Serialized to JSON by [SaveSystem].

const VERSION := 1
const MAX_RECORDS := 5

var salvage := 0
var research := 0
## Upgrade id (String) -> purchased level.
var upgrades: Dictionary = {}
var unlocked_frames: Array[String] = ["lantern"]
var selected_frame := "lantern"
## Creature id (String) -> number of times scanned.
var codex: Dictionary = {}
var logs_found: Array[String] = []
## Ids of the [Wonders] witnessed.
var wonders: Array[String] = []
var deepest_zone := 0
var deepest_depth := 0
var dives := 0
var wins := 0
var pressure_unlocked := 0
var pressure_selected := 0
var tutorial_done := false
var total_salvage := 0
var total_kills := 0
var stalkers_killed := 0
var mothers_killed := 0
var anglers_killed := 0
var best_pressure_win := -1
## Ids of achieved [Milestones].
var milestones: Array[String] = []
## Milestone id whose paint is applied to the hull ("" = the frame's own colors).
var paint := ""
## Daily dive record for [member daily_date] (YYYY-MM-DD).
var daily_date := ""
var daily_best_depth := 0
var daily_attempts := 0
var daily_won := false
## Best dives, highest score first (see [method DiveScore.record]).
var records: Array[Dictionary] = []
## The wreck of the last sub to implode: its zone (-1 = none), frame and the
## cargo insurance did not cover, waiting to be recovered (see [LostWreck]).
var wreck_zone := -1
var wreck_frame := ""
var wreck_cargo := 0
## How it was lost: "implosion" (crushed) or "power" (dark but whole).
var wreck_kind := ""
## Contract taken in the hangar for the next dive ("" = none); used up when it starts.
var contract_selected := ""


func upgrade_level(id: StringName) -> int:
	return upgrades.get(String(id), 0)


func can_afford(cost: int) -> bool:
	return salvage >= cost


## Buys the next level of an upgrade. Returns false if maxed or unaffordable.
func buy_upgrade(id: StringName) -> bool:
	var def := Catalog.upgrade(id)
	if def == null:
		return false
	var level := upgrade_level(id)
	if level >= def.max_level():
		return false
	var cost := def.costs[level]
	if salvage < cost:
		return false
	salvage -= cost
	upgrades[String(id)] = level + 1
	return true


## Files a finished dive. Returns its place in the records (0 = new best),
## or -1 if it did not make the table.
func record_dive(entry: Dictionary) -> int:
	if int(entry.get("score", 0)) <= 0:
		return -1
	var rank := records.size()
	for i in records.size():
		if int(entry.score) > int(records[i].score):
			rank = i
			break
	if rank >= MAX_RECORDS:
		return -1
	records.insert(rank, entry)
	if records.size() > MAX_RECORDS:
		records.resize(MAX_RECORDS)
	return rank


func record_wreck(zone: int, frame: StringName, cargo: int, kind := "implosion") -> void:
	wreck_zone = zone
	wreck_frame = String(frame)
	wreck_cargo = cargo
	wreck_kind = kind


func clear_wreck() -> void:
	wreck_zone = -1
	wreck_frame = ""
	wreck_cargo = 0
	wreck_kind = ""


func has_wreck() -> bool:
	return wreck_zone >= 0 and wreck_cargo > 0


func best_score() -> int:
	return int(records[0].score) if not records.is_empty() else 0


func is_frame_unlocked(id: StringName) -> bool:
	return unlocked_frames.has(String(id))


func unlock_frame(id: StringName) -> bool:
	var def := Catalog.frame(id)
	if def == null or is_frame_unlocked(id) or research < def.research_cost:
		return false
	research -= def.research_cost
	unlocked_frames.append(String(id))
	return true


func record_scan(id: StringName) -> bool:
	var key := String(id)
	var first := not codex.has(key)
	codex[key] = codex.get(key, 0) + 1
	return first


## Starts a daily attempt, resetting the record when the day has changed.
func begin_daily(date: String) -> void:
	if daily_date != date:
		daily_date = date
		daily_best_depth = 0
		daily_attempts = 0
		daily_won = false
	daily_attempts += 1


## Today's daily record, or an empty string if there is none yet.
func daily_summary(date: String) -> String:
	if daily_date != date or daily_attempts == 0:
		return ""
	var best := "Choir silenced" if daily_won else "best %s m" % UiUtil.thousands(daily_best_depth)
	return "%s, %d attempt%s" % [best, daily_attempts, "" if daily_attempts == 1 else "s"]


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"salvage": salvage,
		"research": research,
		"upgrades": upgrades,
		"unlocked_frames": unlocked_frames,
		"selected_frame": selected_frame,
		"codex": codex,
		"logs_found": logs_found,
		"wonders": wonders,
		"deepest_zone": deepest_zone,
		"deepest_depth": deepest_depth,
		"dives": dives,
		"wins": wins,
		"pressure_unlocked": pressure_unlocked,
		"pressure_selected": pressure_selected,
		"tutorial_done": tutorial_done,
		"total_salvage": total_salvage,
		"total_kills": total_kills,
		"stalkers_killed": stalkers_killed,
		"mothers_killed": mothers_killed,
		"anglers_killed": anglers_killed,
		"best_pressure_win": best_pressure_win,
		"milestones": milestones,
		"paint": paint,
		"daily_date": daily_date,
		"daily_best_depth": daily_best_depth,
		"daily_attempts": daily_attempts,
		"daily_won": daily_won,
		"records": records,
		"wreck_zone": wreck_zone,
		"wreck_frame": wreck_frame,
		"wreck_cargo": wreck_cargo,
		"wreck_kind": wreck_kind,
		"contract_selected": contract_selected,
	}


static func from_dict(d: Dictionary) -> MetaState:
	var m := MetaState.new()
	m.salvage = int(d.get("salvage", 0))
	m.research = int(d.get("research", 0))
	var ups: Dictionary = d.get("upgrades", {})
	for k in ups:
		m.upgrades[String(k)] = int(ups[k])
	m.unlocked_frames.clear()
	for f in d.get("unlocked_frames", ["lantern"]):
		m.unlocked_frames.append(String(f))
	if not m.unlocked_frames.has("lantern"):
		m.unlocked_frames.append("lantern")
	m.selected_frame = String(d.get("selected_frame", "lantern"))
	if not m.unlocked_frames.has(m.selected_frame):
		m.selected_frame = "lantern"
	var codex: Dictionary = d.get("codex", {})
	for k in codex:
		m.codex[String(k)] = int(codex[k])
	for l in d.get("logs_found", []):
		m.logs_found.append(String(l))
	for w in d.get("wonders", []):
		m.wonders.append(String(w))
	m.deepest_zone = int(d.get("deepest_zone", 0))
	m.deepest_depth = int(d.get("deepest_depth", 0))
	m.dives = int(d.get("dives", 0))
	m.wins = int(d.get("wins", 0))
	m.pressure_unlocked = int(d.get("pressure_unlocked", 0))
	m.pressure_selected = clampi(int(d.get("pressure_selected", 0)), 0, m.pressure_unlocked)
	m.tutorial_done = bool(d.get("tutorial_done", false))
	m.total_salvage = int(d.get("total_salvage", 0))
	m.total_kills = int(d.get("total_kills", 0))
	m.stalkers_killed = int(d.get("stalkers_killed", 0))
	m.mothers_killed = int(d.get("mothers_killed", 0))
	m.anglers_killed = int(d.get("anglers_killed", 0))
	m.best_pressure_win = int(d.get("best_pressure_win", -1))
	for id in d.get("milestones", []):
		m.milestones.append(String(id))
	m.paint = String(d.get("paint", ""))
	if not m.milestones.has(m.paint):
		m.paint = ""
	m.daily_date = String(d.get("daily_date", ""))
	m.daily_best_depth = int(d.get("daily_best_depth", 0))
	m.daily_attempts = int(d.get("daily_attempts", 0))
	m.daily_won = bool(d.get("daily_won", false))
	for r: Variant in d.get("records", []):
		if r is Dictionary:
			m.records.append(_clean_record(r))
	m.wreck_zone = clampi(int(d.get("wreck_zone", -1)), -1, BiomeLibrary.TOTAL_ZONES - 1)
	m.wreck_frame = String(d.get("wreck_frame", ""))
	m.wreck_cargo = maxi(int(d.get("wreck_cargo", 0)), 0)
	m.wreck_kind = String(d.get("wreck_kind", "implosion"))
	m.contract_selected = String(d.get("contract_selected", ""))
	if Contracts.find(StringName(m.contract_selected)) == null:
		m.contract_selected = ""
	if Catalog.frame(StringName(m.wreck_frame)) == null:
		m.clear_wreck()
	m.records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
	if m.records.size() > MAX_RECORDS:
		m.records.resize(MAX_RECORDS)
	return m


## A records entry with every field present and of the right type.
static func _clean_record(r: Dictionary) -> Dictionary:
	return {
		"score": int(r.get("score", 0)), "frame": String(r.get("frame", "lantern")),
		"depth": int(r.get("depth", 0)), "zone": int(r.get("zone", 0)), "outcome": String(r.get("outcome", "")),
		"pressure": int(r.get("pressure", 0)), "daily": bool(r.get("daily", false)),
		"date": String(r.get("date", "")), "contract": String(r.get("contract", "")),
	}
