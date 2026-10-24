class_name MetaState
extends RefCounted
## Progress that persists between dives: banked currencies, hangar upgrades,
## unlocked frames, codex and statistics. Serialized to JSON by [SaveSystem].

const VERSION := 1

var salvage := 0
var research := 0
## Upgrade id (String) -> purchased level.
var upgrades: Dictionary = {}
var unlocked_frames: Array[String] = ["lantern"]
var selected_frame := "lantern"
## Creature id (String) -> number of times scanned.
var codex: Dictionary = {}
var logs_found: Array[String] = []
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
var best_pressure_win := -1
## Ids of achieved [Milestones].
var milestones: Array[String] = []
## Milestone id whose paint is applied to the hull ("" = the frame's own colors).
var paint := ""


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
		"best_pressure_win": best_pressure_win,
		"milestones": milestones,
		"paint": paint,
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
	m.best_pressure_win = int(d.get("best_pressure_win", -1))
	for id in d.get("milestones", []):
		m.milestones.append(String(id))
	m.paint = String(d.get("paint", ""))
	if not m.milestones.has(m.paint):
		m.paint = ""
	return m
