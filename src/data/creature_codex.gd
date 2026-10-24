class_name CreatureCodex
extends RefCounted
## Field notes for every species, shown in the codex once scanned.

class Entry:
	var id: StringName
	var name: String
	var latin: String
	var notes: String
	var threat: String

	func _init(i: StringName, n: String, l: String, t: String, d: String) -> void:
		id = i
		name = n
		latin = l
		threat = t
		notes = d


static var _entries: Array[Entry] = []


static func entries() -> Array[Entry]:
	if _entries.is_empty():
		_entries = [
			Entry.new(&"shoal", "Glimmer Shoal", "Lucens gregaria", "Harmless",
				"Schools of finger-length fish that flash in unison. They scatter from engines and are hunted by almost everything else down here."),
			Entry.new(&"jelly", "Drifter Jelly", "Medusa errans", "Low",
				"Drifts on the currents and drifts towards light. Its tentacles carry a charge that shorts batteries on contact."),
			Entry.new(&"lancer", "Lancer", "Sphyraena sonans", "Medium",
				"A needle-nosed hunter that strikes at sound. It winds up before every dash - cut your engines and it loses you."),
			Entry.new(&"lurelight", "Lurelight", "Melanocetus mendax", "High",
				"An ambush angler that hangs a living lantern in the dark. Whatever swims up to the light is swallowed. Sonar shows the body behind the bait."),
			Entry.new(&"gulper", "Gulper Eel", "Saccopharynx cavus", "High",
				"Lives in burrows in the cave wall and feels vibrations through the rock. Pass slowly and it may never notice you."),
			Entry.new(&"stalker", "Stalker", "Leviathanops auditor", "Extreme",
				"An apex predator the size of a bus. It hunts by sound and charges any light it sees. Flares distract it; torpedoes only make it angry."),
			Entry.new(&"isopod", "Vent Isopod", "Bathynomus ferrovorax", "Medium",
				"Armored scavengers that crawl the vent walls. They latch onto hulls and chew through power lines. A shock pulse or a burst of speed shakes them off."),
			Entry.new(&"choir", "The Choir", "-", "Unknown",
				"Whatever has been answering our pings. The station logs call it the Choir. It sings the trench into new shapes."),
		]
	return _entries


static func entry(id: StringName) -> Entry:
	for e in entries():
		if e.id == id:
			return e
	return null
