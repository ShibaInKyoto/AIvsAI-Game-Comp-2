class_name Contracts
extends RefCounted
## Optional dive contracts, taken in the hangar for the next dive: a handicap
## that lasts the whole dive in exchange for a bigger score and payout.
## Daily dives never carry one, so their records stay comparable.

class Contract:
	var id: StringName
	var name: String
	var description: String
	var score_mult: float
	var salvage_mult: float
	var research_mult: float
	## Creature budget multiplier for every zone of the dive.
	var creature_mult: float
	## func(stats: SubStats) -> void, applied after the frame, upgrades and modules.
	var apply: Callable

	func _init(i: StringName, n: String, d: String, score: float, salvage: float, research: float,
			creatures: float, fx: Callable) -> void:
		id = i
		name = n
		description = d
		score_mult = score
		salvage_mult = salvage
		research_mult = research
		creature_mult = creatures
		apply = fx

	## "score x1.50, salvage x1.25" for the rewards that differ from 1.
	func rewards() -> String:
		var parts := PackedStringArray()
		for pair: Array in [["score", score_mult], ["salvage", salvage_mult], ["research", research_mult]]:
			if not is_equal_approx(pair[1], 1.0):
				parts.append("%s x%.2f" % pair)
		return ", ".join(parts)


static var _all: Array[Contract] = []


static func all() -> Array[Contract]:
	if _all.is_empty():
		_all = [
			Contract.new(&"glass_hull", "Glass Hull", "Maximum hull -40%.", 1.5, 1.25, 1.0, 1.0,
				func(s: SubStats) -> void: s.max_hull *= 0.6),
			Contract.new(&"silent_running", "Silent Running",
				"Sonar pings cost three times the battery and recharge half as fast.", 1.3, 1.0, 1.4, 1.0,
				func(s: SubStats) -> void:
					s.sonar_cost *= 3.0
					s.sonar_cooldown *= 2.0),
			Contract.new(&"failing_lamp", "Failing Lamp", "Lamp range -35%, and it drains twice as fast.",
				1.3, 1.0, 1.25, 1.0, func(s: SubStats) -> void:
					s.lamp_range *= 0.65
					s.lamp_drain *= 2.0),
			Contract.new(&"infested", "Infested Waters", "40% more creatures in every zone.", 1.4, 1.3, 1.0, 1.4,
				func(_s: SubStats) -> void: pass),
			Contract.new(&"uninsured", "No Insurance", "Implode and the insurers pay nothing.", 1.2, 1.5, 1.0, 1.0,
				func(s: SubStats) -> void: s.insurance = 0.0),
		]
	return _all


static func find(id: StringName) -> Contract:
	for c in all():
		if c.id == id:
			return c
	return null


static func score_mult(id: StringName) -> float:
	var c := find(id)
	return c.score_mult if c else 1.0


static func salvage_mult(id: StringName) -> float:
	var c := find(id)
	return c.salvage_mult if c else 1.0


static func research_mult(id: StringName) -> float:
	var c := find(id)
	return c.research_mult if c else 1.0


static func creature_mult(id: StringName) -> float:
	var c := find(id)
	return c.creature_mult if c else 1.0
