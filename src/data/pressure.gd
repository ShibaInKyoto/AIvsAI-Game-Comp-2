class_name Pressure
extends RefCounted
## Escalating difficulty levels unlocked by completing the dive. Each level
## keeps every modifier of the levels below it.

const MAX_LEVEL := 6
const DESCRIPTIONS: PackedStringArray = [
	"Standard dive.",
	"Creatures have 30% more health.",
	"More creatures in every zone.",
	"Battery drains 25% faster.",
	"Creatures hit 30% harder.",
	"Caches hold less salvage.",
	"Hunters hear twice as far.",
]


static func creature_health(level: int) -> float:
	return 1.3 if level >= 1 else 1.0


static func creature_budget(level: int) -> float:
	return 1.35 if level >= 2 else 1.0


static func battery_drain(level: int) -> float:
	return 1.25 if level >= 3 else 1.0


static func creature_damage(level: int) -> float:
	return 1.3 if level >= 4 else 1.0


static func salvage(level: int) -> float:
	return 0.75 if level >= 5 else 1.0


static func hearing(level: int) -> float:
	return 2.0 if level >= 6 else 1.0


## Salvage multiplier for surfacing deeper (reward for pushing your luck).
static func depth_bonus(zone: int) -> float:
	return 1.0 + 0.1 * zone
