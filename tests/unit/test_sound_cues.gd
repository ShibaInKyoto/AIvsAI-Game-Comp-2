extends TestCase
## The sound-cue overlay picks up threat sounds near the sub (and only those),
## merges repeats from the same place, fades them out and stays quiet when
## the setting is off.


func _cues() -> Array:
	var hud := Hud.new()
	var sub := Submarine.new()
	sub.pos = Vector2(5.0, -20.0)
	hud.sub = sub
	var cues := SoundCues.new()
	cues.hud = hud
	(Engine.get_main_loop() as SceneTree).root.add_child(cues)
	return [cues, hud, sub]


func _free(parts: Array) -> void:
	(parts[0] as Node).free()
	(parts[1] as Node).free()
	(parts[2] as Node).free()


func test_threat_sounds_near_the_sub_show_up() -> void:
	var was := Settings.sound_cues
	Settings.sound_cues = true
	var parts := _cues()
	var cues: SoundCues = parts[0]
	var sub: Submarine = parts[2]
	Audio.play_at(&"lancer_windup", sub.pos + Vector2(10.0, 0.0))
	check_eq(cues.cues.size(), 1, "a played threat sound is heard")
	if cues.cues.size() == 1:
		check_eq(cues.cues[0].word, "WIND-UP", "named for what it means")
	cues._on_sound(&"lancer_dash", sub.pos + Vector2(11.0, 0.0))
	check_eq(cues.cues.size(), 1, "a sound from the same place takes over its cue")
	if cues.cues.size() == 1:
		check_eq(cues.cues[0].word, "DASH", "showing the latest sound")
	cues._on_sound(&"harpoon_wall", sub.pos + Vector2(3.0, 0.0))
	check_eq(cues.cues.size(), 1, "the sub's own clatter is not a cue")
	cues._on_sound(&"stalker_roar", sub.pos + Vector2(SoundCues.RANGE + 5.0, 0.0))
	check_eq(cues.cues.size(), 1, "sounds out of range are left out")
	cues._on_sound(&"vent_rumble", sub.pos + Vector2(0.0, -6.0))
	check_eq(cues.cues.size(), 2, "different sources get their own cue")
	cues._process(SoundCues.LIFE + 0.1)
	check_eq(cues.cues.size(), 0, "cues fade out")
	Settings.sound_cues = false
	cues._on_sound(&"stalker_bite", sub.pos + Vector2(4.0, 0.0))
	check_eq(cues.cues.size(), 0, "nothing shows with the setting off")
	Settings.sound_cues = was
	_free(parts)


func test_every_cue_names_a_real_sound() -> void:
	for sound: StringName in SoundCues.CUES:
		check(ResourceLoader.exists(Audio.SFX_DIR + String(sound) + ".ogg"), "%s has a sound file" % sound)
