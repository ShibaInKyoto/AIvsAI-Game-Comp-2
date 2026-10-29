class_name Wonders
extends RefCounted
## The sights of the trench a pilot has witnessed, kept between dives and
## listed in the hangar archive beside the logs that told of them. One not
## yet witnessed says where to look.

const ALL: Array[Dictionary] = [
	{"id": "manta", "name": "A shelf manta", "where": "in the Sunlit Shelf",
		"text": "Seven metres of wing gliding through the shallows, a school of fish sheltering under it."},
	{"id": "whale", "name": "A sperm whale", "where": "in the Sunlit Shelf",
		"text": "Eleven metres of whale passing in the blue, its clicks lighting the cave on your sonar."},
	{"id": "pearl", "name": "A giant clam's pearl", "where": "in the Twilight Reef",
		"text": "Taken in the dark by its own glow, while the clam gaped."},
	{"id": "whale_fall", "name": "A whale fall", "where": "in the Twilight Reef, now and then",
		"text": "A whale's bones on the floor, feeding the deep for a century."},
	{"id": "grotto", "name": "The glow-worm grotto", "where": "in the Midnight Caverns",
		"text": "A ceiling of cold lights that go dark at a sound, and light the way for the quiet."},
	{"id": "glass", "name": "Singing glass", "where": "in the Abyssal Vents", "log": "log_06",
		"text": "Three notes rang it to pieces. Sing the right chord at the rock and it gives way."},
	{"id": "echo", "name": "The echo", "where": "in the Hadal Trench", "log": "log_03",
		"text": "Eleven seconds after your ping, something far below pinged back."},
	{"id": "trench", "name": "The moving trench", "where": "in the Hadal Trench", "log": "log_04",
		"text": "The rock flowed shut behind you and opened into a chamber that had not been there."},
	{"id": "drone", "name": "MD-02", "where": "in the Hadal Trench", "log": "log_09",
		"text": "Vasquez's drone, swallowed by the rock it was cutting through."},
	{"id": "audience", "name": "The audience", "where": "on the hadal floor", "log": "log_05",
		"text": "They hung over the station facing the floor, and turned together when the tone changed."},
	{"id": "lullaby", "name": "Okafor's lullaby", "where": "on the hadal floor", "log": "log_08",
		"text": "The station's speakers still play it, and something far below still sings it back."},
]


static func get_wonder(id: String) -> Dictionary:
	for w in ALL:
		if w.id == id:
			return w
	return {}


## Records [param id] as witnessed (kept with the rest of the progress when
## the dive ends) and says so the first time.
static func witness(id: String) -> void:
	var meta := Game.meta
	if meta == null or meta.wonders.has(id) or get_wonder(id).is_empty():
		return
	meta.wonders.append(id)
	Audio.play(&"wonder_chime", -6.0)
	Events.toast.emit("Witnessed: %s  (%d / %d)" % [get_wonder(id).name, found_count(meta.wonders), ALL.size()],
		UiTheme.GOOD)


## How many of [param seen] are wonders (saves may hold ids no longer listed).
static func found_count(seen: Array[String]) -> int:
	var n := 0
	for w in ALL:
		if seen.has(w.id):
			n += 1
	return n
