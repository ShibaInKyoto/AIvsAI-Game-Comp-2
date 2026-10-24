class_name ZoneEvents
extends RefCounted
## Random conditions that change how a zone plays. Rolled per zone from the
## run seed; the first zone of a dive never has one.

const NONE := &""
const EVENTS: Dictionary[StringName, Dictionary] = {
	&"currents": {"name": "Strong currents", "desc": "The water is moving. Fight it or ride it."},
	&"blackout": {"name": "Blackout", "desc": "Even the ambient glow has died. Bring your own light."},
	&"frenzy": {"name": "Feeding frenzy", "desc": "The zone is crowded with hungry things."},
	&"wrecks": {"name": "Wreck field", "desc": "An expedition died here. Their salvage didn't."},
	&"quiet": {"name": "Dead calm", "desc": "Sound carries twice as far in still water."},
	&"bloom": {"name": "Bioluminescent bloom", "desc": "Everything is glowing - and so are the glow bulbs."},
}
const CHANCE := 0.45


static func roll(run_seed: int, zone: int) -> StringName:
	if zone == 0 or BiomeLibrary.is_final_zone(zone):
		return NONE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, zone, "event"])
	if rng.randf() > CHANCE:
		return NONE
	var keys := EVENTS.keys()
	return keys[rng.randi() % keys.size()]


static func display_name(id: StringName) -> String:
	return EVENTS[id].name if EVENTS.has(id) else ""


static func description(id: StringName) -> String:
	return EVENTS[id].desc if EVENTS.has(id) else ""
