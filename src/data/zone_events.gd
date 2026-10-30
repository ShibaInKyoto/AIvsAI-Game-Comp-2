class_name ZoneEvents
extends RefCounted
## Random conditions that change how a zone plays. Rolled per zone from the
## run seed; the first zone of a dive never has one. A daily dive instead has
## one condition of the day, applied to every zone after the first.

const NONE := &""
const EVENTS: Dictionary[StringName, Dictionary] = {
	&"currents": {"name": "Strong currents", "desc": "The water is moving. Fight it or ride it."},
	&"blackout": {"name": "Blackout", "desc": "Even the ambient glow has died. Bring your own light."},
	&"frenzy": {"name": "Feeding frenzy", "desc": "The zone is crowded with hungry things."},
	&"wrecks": {"name": "Wreck field", "desc": "An expedition died here. Their salvage didn't."},
	&"quiet": {"name": "Dead calm", "desc": "Sound carries twice as far in still water."},
	&"bloom": {"name": "Bioluminescent bloom", "desc": "Everything is glowing - and so are the glow bulbs."},
	&"whalefall": {"name": "Whale fall", "desc": "A whale sank here. Everything nearby has come to feed."},
	&"silt": {"name": "Silt storm",
		"desc": "Silt hangs in the water. You can see half as far, and so can everything hunting you."},
	&"magnetic": {"name": "Magnetic anomaly",
		"desc": "Iron in the rock bends your instruments: sonar reaches half as far and the compass wanders."},
	&"migration": {"name": "Migration",
		"desc": "Great schools are streaming through, and the hunters are busy following them."},
	&"tremors": {"name": "Tremors",
		"desc": "The rock is restless. Every half minute the zone shakes and loose stone comes down."},
	&"warm": {"name": "Warm layer",
		"desc": "Vent water has warmed the zone: your cells drain slower, but everything else moves faster."},
	&"jellies": {"name": "Jelly bloom", "desc": "Drifting stingers fill the open water. Each touch drains your cells."},
}
const CHANCE := 0.55


## The condition of [param zone] in [param run].
static func for_zone(run: RunState, zone: int) -> StringName:
	if run.daily:
		return NONE if zone == 0 or BiomeLibrary.is_final_zone(zone) else run.daily_event
	return roll(run.run_seed, zone)


## The daily dive's condition for a date key (YYYY-MM-DD).
static func daily(date: String) -> StringName:
	var keys := EVENTS.keys()
	return keys[absi(hash(date + "condition")) % keys.size()]


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
