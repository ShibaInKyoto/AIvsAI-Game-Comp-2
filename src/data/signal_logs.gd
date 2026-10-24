class_name SignalLogs
extends RefCounted
## The recovered logs of the Meridian Deep station, found one per zone in
## story order. Together they explain what is singing at the bottom.

const LOGS: Array[Dictionary] = [
	{"id": "log_01", "title": "Meridian Deep - Day 1", "author": "Cmdr. R. Hale",
		"text": "Meridian Deep is pressurised and operational at 10,912 metres. Four crew, ninety " +
			"days of supplies, and the quietest place on Earth. Okafor says the silence down " +
			"here is so complete she can hear her own pulse in the hull."},
	{"id": "log_02", "title": "Acoustic survey 03", "author": "Dr. L. Sato",
		"text": "There is a tone under the station. Fourteen hertz, steady, coming from below the " +
			"floor of the trench - which should be impossible, because there is no below. I " +
			"have logged it as a thermal artefact. I do not believe it is a thermal artefact."},
	{"id": "log_03", "title": "Ping test", "author": "Dr. L. Sato",
		"text": "We pinged the source. Eleven seconds later something pinged back. It was our own " +
			"signal, slowed down and stretched into something that sounded like a word. Hale " +
			"has asked me not to tell the others yet."},
	{"id": "log_04", "title": "Survey discrepancy", "author": "T. Vasquez",
		"text": "Ran the drone along yesterday's survey route and the route isn't there any more. " +
			"Tunnel B has sealed. There's a new chamber where solid rock was. Nothing " +
			"collapsed - the walls are smooth, like they grew. The trench is moving."},
	{"id": "log_05", "title": "Field notes", "author": "Dr. I. Okafor",
		"text": "The fauna gathers around the station at night. Lancers, jellies, things I have " +
			"no names for, all facing the floor, perfectly still. Like an audience. Every " +
			"time the tone changes pitch, they turn together."},
	{"id": "log_06", "title": "Resonance hypothesis", "author": "Dr. L. Sato",
		"text": "Rock has resonant frequencies. Sing the right note at a wine glass and it " +
			"shatters; sing the right chord at a cave and perhaps it flows. Whatever is down " +
			"there is not living in the trench. It is composing it. I have started calling it " +
			"the Choir."},
	{"id": "log_07", "title": "Standing order", "author": "Cmdr. R. Hale",
		"text": "Effective immediately: no active sonar. Engines at minimum. Lights off outside " +
			"the hull. Since we went quiet the walls have stopped moving. The thing below can " +
			"hear us, and I would like it to forget we are here."},
	{"id": "log_08", "title": "Unauthorised transmission", "author": "Dr. I. Okafor",
		"text": "I broke Hale's order tonight. I played it a melody through the hull speakers - " +
			"the first thing I could think of, a lullaby my mother sang. It sang it back. " +
			"Perfectly. And then it sang our voices. All four of us. Talking about it."},
	{"id": "log_09", "title": "Emergency log", "author": "Cmdr. R. Hale",
		"text": "The trench closed around the escape lock at 0300. Vasquez went out in the drone " +
			"to cut us a path. We heard him on comms for six minutes. Then the Choir sang, " +
			"and the tunnel he was in was simply not there any more."},
	{"id": "log_10", "title": "Last entry, Okafor", "author": "Dr. I. Okafor",
		"text": "Hale and Sato took the last pod up. I stayed. I don't think it is hostile. I " +
			"think it is lonely. It has been singing alone in the dark for longer than we " +
			"have had words, and we are the first thing that ever sang back."},
	{"id": "log_11", "title": "Beacon message", "author": "Dr. I. Okafor",
		"text": "If you are hearing this, the beacon is still pinging, and someone came down. Do " +
			"not come to rescue me. Come to listen. It will test you - it tests everything " +
			"that sings. Answer it. Keep answering."},
]


## Spoken by the Choir itself when the song ends. Not part of the found set.
const FINAL := {"id": "log_final", "title": "Unknown transmission", "author": "the Choir / I. Okafor",
	"text": "You answered. You kept answering. It has never been answered for that long. It " +
		"is not dying - it is listening now, and the trench is holding still. Go up. Tell " +
		"them the sea is not empty. Tell them it sings."}


static func get_log(id: StringName) -> Dictionary:
	if String(id) == FINAL.id:
		return FINAL
	for l in LOGS:
		if l.id == String(id):
			return l
	return {}


## Next log in story order the player has not found yet, or &"".
static func next_unfound(found: Array[String], _zone: int) -> StringName:
	for l in LOGS:
		if not found.has(l.id):
			return StringName(l.id)
	return &""


static func count() -> int:
	return LOGS.size()
