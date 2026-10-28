class_name DeathTips
extends RefCounted
## What sank the submarine, and one piece of advice about it, for the
## end-of-dive report.

const TIPS: Dictionary[StringName, String] = {
	&"stalker": "The Stalker hunts by sound. Drift slowly, kill the lamp, and fire a flare to send it elsewhere.",
	&"lancer": "Lancers glow before they dash. Sidestep the charge, then harpoon them while they recover.",
	&"jelly": "Drifter jellies are drawn to light. Swing the lamp away, or switch it off, as you pass.",
	&"lurelight": "A lone light in the dark is usually a lure. Ping first: the sonar shows what is holding it.",
	&"gulper": "Gulper eels feel fast movement through the rock. Pass their burrows slowly.",
	&"isopod": "A latched isopod drains hull and battery. Boost or fire a shock pulse to throw it off.",
	&"siphon": "Lantern chains sting along their whole length. Go around the colony, never through it.",
	&"mimic": "Deep caches sometimes bite. Hook one with the harpoon from a distance before you ram it.",
	&"choir": "Answer each wave with a ping just as it reaches you. The ring around your sub shows when.",
	&"rock": "Ramming rock at speed cracks the hull. Ease off the boost in tight tunnels.",
	&"torpedo": "Torpedoes do not care who fired them. Keep your distance from the blast.",
	&"vent": "Thermal vents rumble and glow before they erupt. Wait it out beside the column, not in it.",
}
const FALLBACK := "Hangar upgrades carry over between dives, and Settings has an Assist mode."


## The cause id for damage from [param source] (null means a collision).
static func cause_of(source: Node) -> StringName:
	if source is Creature:
		return (source as Creature).species
	if source is ChoirBoss:
		return &"choir"
	if source is Torpedo:
		return &"torpedo"
	if source is ThermalVent:
		return &"vent"
	return &"rock"


## A short "sunk by" phrase for a cause id.
static func describe(cause: StringName) -> String:
	match cause:
		&"rock":
			return "the rock itself"
		&"torpedo":
			return "your own torpedo"
		&"choir":
			return "the Choir's song"
		&"stalker":
			return "the Stalker"
		&"vent":
			return "a thermal vent"
	var entry := CreatureCodex.entry(cause)
	return "a " + entry.name if entry else "something in the dark"


static func tip(cause: StringName) -> String:
	return TIPS.get(cause, FALLBACK)
