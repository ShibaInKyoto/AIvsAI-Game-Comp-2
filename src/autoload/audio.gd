extends Node
## Mixer setup, pooled sound effects and music/ambience crossfades.
##
## Sounds are referenced by name and loaded lazily from
## res://assets/audio/{sfx,music}/<name>.ogg (synthesized by tools/audio).
## Missing sounds are ignored so gameplay never depends on audio assets.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_2D := 16
const POOL_3D := 32

var _streams: Dictionary[String, AudioStream] = {}
var _missing: Dictionary[String, bool] = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _next_2d := 0
var _next_3d := 0
var _music: Array[AudioStreamPlayer] = []
var _music_index := 0
var _current_music := &""
var _ambience: AudioStreamPlayer
var _current_ambience := &""
var _sfx_lowpass: AudioEffectLowPassFilter
## Rate limiting so a swarm of events cannot stack the same sound 20 times.
var _last_played: Dictionary[StringName, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 14.0
		p.max_distance = 90.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.8
		add_child(p)
		_pool3d.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		add_child(m)
		_music.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = &"Ambience"
	add_child(_ambience)
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()


## Stops every playback and drops cached streams (used when quitting so
## nothing outlives the audio server).
func stop_all() -> void:
	for p in _pool:
		p.stop()
	for p in _pool3d:
		p.stop()
	for m in _music:
		m.stop()
	_ambience.stop()
	_current_music = &""
	_current_ambience = &""
	_streams.clear()


func _setup_buses() -> void:
	for bus_name: StringName in [&"Music", &"SFX", &"UI", &"Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")
	var sfx := AudioServer.get_bus_index(&"SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		_sfx_lowpass = AudioEffectLowPassFilter.new()
		_sfx_lowpass.cutoff_hz = 9000.0
		AudioServer.add_bus_effect(sfx, _sfx_lowpass)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.7
		reverb.damping = 0.6
		reverb.wet = 0.18
		reverb.dry = 1.0
		AudioServer.add_bus_effect(sfx, reverb)
	var master := AudioServer.get_bus_index(&"Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, limiter)


func _apply_volumes() -> void:
	_set_bus_volume(&"Master", Settings.master_volume)
	_set_bus_volume(&"Music", Settings.music_volume)
	_set_bus_volume(&"SFX", Settings.sfx_volume)
	_set_bus_volume(&"Ambience", Settings.sfx_volume)
	_set_bus_volume(&"UI", Settings.sfx_volume)


static func _set_bus_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


## Muffles effects (e.g. while the hull is critically damaged). 0 = clear.
func set_muffle(amount: float) -> void:
	if _sfx_lowpass:
		_sfx_lowpass.cutoff_hz = lerpf(9000.0, 900.0, clampf(amount, 0.0, 1.0))


func get_stream(sound: StringName, dir := SFX_DIR) -> AudioStream:
	var path := dir + String(sound) + ".ogg"
	if _streams.has(path):
		return _streams[path]
	if _missing.has(path):
		return null
	if not ResourceLoader.exists(path):
		_missing[path] = true
		return null
	var stream: AudioStream = load(path)
	_streams[path] = stream
	return stream


func _rate_limited(sound: StringName, min_gap_ms: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_played.get(sound, -100000) < min_gap_ms:
		return true
	_last_played[sound] = now
	return false


## Non-positional sound (UI, the player's own cockpit sounds).
func play(sound: StringName, volume_db := 0.0, pitch := 1.0, bus := &"SFX") -> void:
	var stream := get_stream(sound)
	if stream == null or _rate_limited(sound, 35):
		return
	var p := _pool[_next_2d]
	_next_2d = (_next_2d + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func play_ui(sound: StringName, volume_db := 0.0) -> void:
	play(sound, volume_db, randf_range(0.97, 1.03), &"UI")


## Positional sound on the gameplay plane.
func play_at(sound: StringName, pos: Vector2, volume_db := 0.0, pitch_variance := 0.08, pitch := 1.0) -> void:
	var stream := get_stream(sound)
	if stream == null or _rate_limited(sound, 25):
		return
	var p := _pool3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool3d.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_variance, pitch_variance))
	p.global_position = Vector3(pos.x, pos.y, 0.0)
	p.play()


## Crossfades to [param track]; [param gain_db] trims tracks mastered quieter.
func play_music(track: StringName, fade := 2.5, gain_db := 0.0) -> void:
	if track == _current_music:
		return
	_current_music = track
	var stream := get_stream(track, MUSIC_DIR)
	var old := _music[_music_index]
	_music_index = (_music_index + 1) % 2
	var new := _music[_music_index]
	if old.playing:
		var tween := create_tween()
		tween.tween_property(old, ^"volume_db", -60.0, fade)
		tween.tween_callback(old.stop)
	if stream:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		new.stream = stream
		new.volume_db = -60.0
		new.play()
		create_tween().tween_property(new, ^"volume_db", gain_db, fade)


func stop_music(fade := 2.0) -> void:
	_current_music = &""
	for m in _music:
		if m.playing:
			var tween := create_tween()
			tween.tween_property(m, ^"volume_db", -60.0, fade)
			tween.tween_callback(m.stop)


func play_ambience(track: StringName) -> void:
	if track == _current_ambience:
		return
	_current_ambience = track
	var stream := get_stream(track, MUSIC_DIR)
	_ambience.stop()
	if stream:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_ambience.stream = stream
		_ambience.volume_db = -6.0
		_ambience.play()
