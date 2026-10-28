class_name Heartbeat
extends AudioStreamPlayer
## A muffled heartbeat that rises under a nearby Stalker: louder and faster as
## it investigates, hunts and closes in. Silent the rest of the time.

const NEAR := 10.0
const FAR := 45.0

var _intensity := 0.0


func _ready() -> void:
	bus = &"SFX"
	stream = Audio.get_stream(&"heartbeat_loop")
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	volume_db = -60.0


func tick(level: Level, sub: Submarine, delta: float) -> void:
	var want := 0.0
	if sub and sub.alive:
		for e in level.entities:
			if e is Stalker:
				var near := 1.0 - smoothstep(NEAR, FAR, e.pos.distance_to(sub.pos))
				want = maxf(want, (e as Stalker).menace() * near)
	# Swell in quickly, fade out slowly once the danger has passed.
	_intensity = lerpf(_intensity, want, 1.0 - exp(-(2.5 if want > _intensity else 0.6) * delta))
	if _intensity < 0.02:
		if playing:
			stop()
		return
	if not playing and stream:
		play()
	volume_db = linear_to_db(_intensity) - 4.0
	pitch_scale = 1.0 + _intensity * 0.5
