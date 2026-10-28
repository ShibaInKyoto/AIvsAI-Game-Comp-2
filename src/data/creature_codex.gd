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
				"Schools of finger-length fish that flash in unison. They scatter from engines " +
					"and are hunted by almost everything else down here."),
			Entry.new(&"puffer", "Spined Puffer", "Diodon tumescens", "Low",
				"A slow, curious reef fish that gulps water and swells into a ball of spines when anything " +
					"rushes past. Drift by gently. Harpooned while swollen, it bursts and sprays spines at " +
					"everything nearby."),
			Entry.new(&"jelly", "Drifter Jelly", "Medusa errans", "Low",
				"Drifts on the currents and drifts towards light. Its tentacles carry a charge that shorts batteries on contact."),
			Entry.new(&"lancer", "Lancer", "Sphyraena sonans", "Medium",
				"A needle-nosed hunter that strikes at sound. It winds up before every dash - cut your engines and it loses you."),
			Entry.new(&"lurelight", "Lurelight", "Melanocetus mendax", "High",
				"An ambush angler that hangs a living lantern in the dark. Whatever swims up to " +
					"the light is swallowed. Sonar shows the body behind the bait."),
			Entry.new(&"gulper", "Gulper Eel", "Saccopharynx cavus", "High",
				"Lives in burrows in the cave wall and feels vibrations through the rock. Pass " +
					"slowly and it may never notice you."),
			Entry.new(&"stalker", "Stalker", "Leviathanops auditor", "Extreme",
				"An apex predator the size of a bus. It hunts by sound and charges any light it " +
					"sees. Flares distract it; torpedoes only make it angry."),
			Entry.new(&"isopod", "Vent Isopod", "Bathynomus ferrovorax", "Medium",
				"Armored scavengers that crawl the vent walls. They latch onto hulls and chew " +
					"through power lines. A shock pulse or a burst of speed shakes them off."),
			Entry.new(&"siphon", "Lantern Chain", "Praya catenata", "Low",
				"Not one animal but thousands, strung into a living chain longer than a bus. " +
					"Every bell can sting. Drift around it, not through it."),
			Entry.new(&"mimic", "Mimic", "Cista mendax", "High",
				"It wears the shape of an expedition crate. Sonar marks it as alive - that is the only warning you get."),
			Entry.new(&"ghostfin", "Ghostfin", "Phantasmichthys gregarius", "Medium",
				"Finger-thin, nearly transparent pack hunters of the hadal floor: you see the eyes before the fish. " +
					"A lit lamp draws a whole pack to circle it and dart in by turns. Go dark and they drift off; " +
					"a flare holds their attention instead."),
			Entry.new(&"lamplighter", "The Lamplighter", "Ceratias regina", "Extreme",
				"A matriarch angler as long as a whale, guarding the way out of the reef. She sees only light: " +
					"a lamp seen from afar draws a charge, and her lure pulls swimmers in until a ping breaks " +
					"its spell. A lamp in her eyes up close, or a flare fed to her, dazzles her."),
			Entry.new(&"mother", "The Blind Mother", "Mater caeca", "Extreme",
				"Thirty metres of eyeless eel coiled at the bottom of the Midnight Caverns. She hears a sub drift past " +
					"from across her lair and strikes at the sound - straight through anything in the way. A strike " +
					"that ends in rock wedges her head there and lays her glowing gills open."),
			Entry.new(&"ironclad", "The Ironclad", "Bathynomus ferreus", "Extreme",
				"An isopod the size of a bus, walking the floor of the hottest vent field in the trench. Its plates " +
					"turn harpoons and torpedoes, but not the vents: caught in an eruption, the shell splits and glows. " +
					"It hunts by sound, and while it hunts it forgets to step around the heat."),
			Entry.new(&"choir", "The Choir", "-", "Unknown",
				"Whatever has been answering our pings. The station logs call it the Choir. It sings the trench into new shapes."),
		]
	return _entries


static func entry(id: StringName) -> Entry:
	for e in entries():
		if e.id == id:
			return e
	return null
