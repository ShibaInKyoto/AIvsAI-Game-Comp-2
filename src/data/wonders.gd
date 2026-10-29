class_name Wonders
extends RefCounted
## The sights of the trench a pilot has witnessed, kept between dives and
## listed in the hangar archive beside the logs that told of them. One not
## yet witnessed says where to look. The moment each was first witnessed is
## kept as a small snapshot beside it.

const SNAPSHOT_DIR := "user://wonders"
const SNAPSHOT_WIDTH := 320

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
	if Game.run:
		Game.run.wonders.append(id)
	_snapshot(id)
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


static func snapshot_path(id: String) -> String:
	return SNAPSHOT_DIR.path_join(id + ".png")


## The snapshot kept of [param id], or null if there is none.
static func snapshot(id: String) -> Texture2D:
	var path := snapshot_path(id)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	return ImageTexture.create_from_image(img) if img and not img.is_empty() else null


## Forgets every snapshot (with the rest of the progress).
static func clear_snapshots() -> void:
	if not DirAccess.dir_exists_absolute(SNAPSHOT_DIR):
		return
	for f in DirAccess.get_files_at(SNAPSHOT_DIR):
		DirAccess.remove_absolute(SNAPSHOT_DIR.path_join(f))


## Keeps the last frame drawn, small, for the archive (not in headless or
## autopilot runs).
static func _snapshot(id: String) -> void:
	if DisplayServer.get_name() == "headless" or Autopilot.requested():
		return
	var tree := Engine.get_main_loop() as SceneTree
	var tex := tree.root.get_texture() if tree else null
	var img := tex.get_image() if tex else null
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(SNAPSHOT_DIR)
	var path := snapshot_path(id)
	# Shrink and write it off the main thread, so the moment does not hitch.
	WorkerThreadPool.add_task(func() -> void:
		img.resize(SNAPSHOT_WIDTH, maxi(1, SNAPSHOT_WIDTH * img.get_height() / img.get_width()),
			Image.INTERPOLATE_BILINEAR)
		img.save_png(path))
