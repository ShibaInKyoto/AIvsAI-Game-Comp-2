extends TestCase
## Every sound the code asks for by name exists on disk (a typo would just be
## silent at runtime), and every biome's music and ambience tracks are present.

const CALL := "Audio\\.(play|play_ui|play_at|play_music|play_ambience|get_stream)\\(&\"([a-z0-9_]+)\""


func test_referenced_sounds_exist() -> void:
	var re := RegEx.create_from_string(CALL)
	var names := {}
	for path in _scripts("res://src"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			names[m.get_string(2)] = path
	check(names.size() > 30, "found the sound references")
	for sound: String in names:
		check(_sound_exists(sound), "%s (used in %s) has no audio file" % [sound, names[sound]])


func test_biome_music_exists() -> void:
	for zone in BiomeLibrary.TOTAL_ZONES:
		var biome := BiomeLibrary.biome_for_zone(zone)
		check(_sound_exists(String(biome.music)), "music for %s" % biome.id)
		check(_sound_exists(String(biome.ambience)), "ambience for %s" % biome.id)


static func _sound_exists(sound: String) -> bool:
	return ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % sound) \
		or ResourceLoader.exists("res://assets/audio/music/%s.ogg" % sound)


static func _scripts(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		out.append_array(_scripts(dir_path.path_join(sub)))
	return out
