class_name Milestones
extends RefCounted
## Long-term goals. Each one unlocks a hull paint for the hangar.
## Conditions are evaluated against the persistent [MetaState] (and the
## current [RunState] when one is in progress).

class Milestone:
	var id: String
	var name: String
	var description: String
	var paint_name: String
	var paint: Color
	var condition: Callable

	func _init(i: String, n: String, d: String, pn: String, p: Color, c: Callable) -> void:
		id = i
		name = n
		description = d
		paint_name = pn
		paint = p
		condition = c


static var _all: Array[Milestone] = []


static func all() -> Array[Milestone]:
	if _all.is_empty():
		_all = [
			Milestone.new("first_descent", "First Descent", "Clear the first zone of a dive.", "Signal Yellow",
				Color(1.0, 0.85, 0.15), func(m: MetaState, r: RunState) -> bool: return _depth_zone(m, r) >= 1),
			Milestone.new("twilight", "Into the Twilight", "Reach the Twilight Reef.", "Coral",
				Color(1.0, 0.45, 0.45), func(m: MetaState, r: RunState) -> bool: return _depth_zone(m, r) >= 2),
			Milestone.new("midnight", "Midnight", "Reach the Midnight Caverns.", "Abyss Blue",
				Color(0.15, 0.35, 0.85), func(m: MetaState, r: RunState) -> bool: return _depth_zone(m, r) >= 4),
			Milestone.new("vents", "Into the Fire", "Reach the Abyssal Vents.", "Magma",
				Color(0.95, 0.3, 0.05), func(m: MetaState, r: RunState) -> bool: return _depth_zone(m, r) >= 6),
			Milestone.new("hadal", "Hadal", "Reach the Hadal Trench.", "Pearl",
				Color(0.92, 0.9, 0.85), func(m: MetaState, r: RunState) -> bool: return _depth_zone(m, r) >= 8),
			Milestone.new("answer", "The Answer", "Silence the Choir.", "Choir Violet",
				Color(0.6, 0.3, 0.95), func(m: MetaState, _r: RunState) -> bool: return m.wins >= 1),
			Milestone.new("naturalist", "Naturalist", "Scan 5 different species.", "Kelp",
				Color(0.35, 0.6, 0.25), func(m: MetaState, _r: RunState) -> bool: return m.codex.size() >= 5),
			Milestone.new("codex", "Codex Complete", "Scan every species in the trench.", "Lumen Teal",
				Color(0.2, 0.9, 0.8), func(m: MetaState, _r: RunState) -> bool:
					return m.codex.size() >= CreatureCodex.entries().size()),
			Milestone.new("archivist", "Archivist", "Recover every signal log.", "Black Box Orange",
				Color(1.0, 0.5, 0.0), func(m: MetaState, _r: RunState) -> bool:
					return m.logs_found.size() >= SignalLogs.count()),
			Milestone.new("hunter", "Apex", "Kill a Stalker.", "Stalker Grey",
				Color(0.35, 0.37, 0.4), func(m: MetaState, _r: RunState) -> bool: return m.stalkers_killed >= 1),
			Milestone.new("hoarder", "Hoarder", "Bank 1,000 salvage in total.", "Gold",
				Color(0.95, 0.75, 0.25), func(m: MetaState, _r: RunState) -> bool: return m.total_salvage >= 1000),
			Milestone.new("fleet", "Fleet", "Unlock every submarine.", "Chrome",
				Color(0.8, 0.82, 0.85), func(m: MetaState, _r: RunState) -> bool:
					return m.unlocked_frames.size() >= Catalog.frames().size()),
			Milestone.new("pressure", "Crush Depth", "Silence the Choir at Pressure 3 or higher.", "Crimson",
				Color(0.75, 0.05, 0.12), func(m: MetaState, _r: RunState) -> bool: return m.best_pressure_win >= 3),
			Milestone.new("veteran", "Veteran", "Complete 15 dives.", "Navy",
				Color(0.12, 0.16, 0.35), func(m: MetaState, _r: RunState) -> bool: return m.dives >= 15),
		]
	return _all


static func find(id: String) -> Milestone:
	for m in all():
		if m.id == id:
			return m
	return null


static func _depth_zone(m: MetaState, r: RunState) -> int:
	return maxi(m.deepest_zone, r.zone if r else 0)


## Awards any newly met milestones. Returns the ones just unlocked.
static func check(meta: MetaState, run: RunState) -> Array[Milestone]:
	var fresh: Array[Milestone] = []
	for m in all():
		if not meta.milestones.has(m.id) and m.condition.call(meta, run):
			meta.milestones.append(m.id)
			fresh.append(m)
	return fresh
