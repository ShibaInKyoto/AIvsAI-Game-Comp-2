class_name SoundCues
extends Control
## Accessibility (Settings > Sound cues): shows where the sounds that matter
## come from. A threat heard near the sub flashes an arc on a ring around it,
## pointing at the source, with a word for what was heard; closer sources draw
## wider, bolder arcs. A Stalker on the hunt shows as a pulsing HEARTBEAT
## under the sub, as loud as the heartbeat it stands in for.

## Ring radius around the sub at 1080p, in pixels.
const RING := 150.0
## Seconds a cue stays up.
const LIFE := 1.8
## Sounds further away than this are not shown.
const RANGE := 48.0
const MAX_CUES := 10
## Sounds this close together share one cue.
const MERGE := 4.0
## Sound -> [word, colour]. Only sounds a pilot would act on are listed.
const CUES: Dictionary[StringName, Array] = {
	&"alert": ["NOTICED", UiTheme.WARN],
	&"lancer_windup": ["WIND-UP", UiTheme.DANGER],
	&"lancer_dash": ["DASH", UiTheme.DANGER],
	&"stalker_roar": ["ROAR", UiTheme.DANGER],
	&"stalker_bite": ["BITE", UiTheme.DANGER],
	&"gulper_strike": ["STRIKE", UiTheme.DANGER],
	&"lurelight_snap": ["SNAP", UiTheme.DANGER],
	&"isopod_leap": ["LEAP", UiTheme.DANGER],
	&"jelly_shock": ["STING", UiTheme.WARN],
	&"puffer_puff": ["SWELLING", UiTheme.WARN],
	&"puffer_burst": ["BURST", UiTheme.DANGER],
	&"vent_rumble": ["RUMBLE", UiTheme.WARN],
	&"vent_erupt": ["ERUPTION", UiTheme.DANGER],
	&"rock_loose": ["CRACKING", UiTheme.WARN],
	&"rock_shatter": ["ROCKFALL", UiTheme.WARN],
	&"explosion": ["BLAST", UiTheme.WARN],
	&"plate_step": ["FOOTSTEPS", UiTheme.WARN],
	&"trench_song": ["SINGING", UiTheme.ACCENT],
	&"rock_flow": ["ROCK MOVING", UiTheme.WARN],
	&"choir_echo": ["ECHO", UiTheme.ACCENT],
	&"choir_tone": ["THE TONE", UiTheme.ACCENT],
	&"glass_ring": ["RINGING", UiTheme.ACCENT],
	&"glass_shatter": ["SHATTER", UiTheme.ACCENT],
	&"decoy_ping": ["DECOY", UiTheme.ACCENT],
	&"beacon_ping": ["BEACON", UiTheme.GOOD],
}

var hud: Hud
## Live cues: {sound, word, color, pos, age}.
var cues: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Audio.sound_at.connect(_on_sound)


## Records a cue for [param sound] at [param pos] if it is one worth showing
## and close enough to the sub. A sound from about the same place as a live
## cue takes it over (a lancer's wind-up becomes its dash) rather than
## stacking a second word on top.
func _on_sound(sound: StringName, pos: Vector2) -> void:
	if not Settings.sound_cues or not CUES.has(sound) or hud == null or hud.sub == null:
		return
	if pos.distance_to(hud.sub.pos) > RANGE:
		return
	var cue: Dictionary = {}
	for c in cues:
		if (c.pos as Vector2).distance_to(pos) < MERGE:
			cue = c
	if cue.is_empty():
		if cues.size() >= MAX_CUES:
			cues.pop_front()
		cues.append(cue)
	cue.merge({"sound": sound, "word": CUES[sound][0], "color": CUES[sound][1], "pos": pos, "age": 0.0}, true)


func _process(delta: float) -> void:
	_t += delta
	for cue in cues:
		cue.age += delta
	cues = cues.filter(func(c: Dictionary) -> bool: return c.age < LIFE)
	visible = Settings.sound_cues
	if visible:
		queue_redraw()


func _draw() -> void:
	if hud == null or hud.sub == null or hud.camera == null or not hud.sub.alive:
		return
	var sub := hud.sub
	var cam := hud.camera
	var center := cam.unproject_position(Vector3(sub.pos.x, sub.pos.y, 0.0))
	var scale_px := size.y / 1080.0
	var ring := RING * scale_px
	var font := UiTheme.BOLD_FONT
	for cue in cues:
		var p: Vector2 = cue.pos
		var dir := cam.unproject_position(Vector3(p.x, p.y, 0.0)) - center
		dir = dir.normalized() if dir.length() > 2.0 else Vector2.UP
		var near := 1.0 - clampf(p.distance_to(sub.pos) / RANGE, 0.0, 1.0)
		var fade := 1.0 - smoothstep(LIFE * 0.55, LIFE, cue.age)
		var pop := 1.0 + 0.25 * (1.0 - smoothstep(0.0, 0.2, cue.age))
		var col: Color = cue.color
		var half := lerpf(0.16, 0.55, near)
		var angle := dir.angle()
		draw_arc(center, ring * pop, angle - half, angle + half, 24, Color(col, 0.9 * fade),
			lerpf(3.0, 8.0, near) * scale_px, true)
		var font_size := int(roundf(lerpf(20.0, 25.0, near) * scale_px))
		var at := center + dir * (ring * pop + font_size * 1.5)
		_word(font, at, cue.word, font_size, col.lightened(0.25), fade)
	var beat := hud.heartbeat.intensity() if hud.heartbeat else 0.0
	if beat > 0.05:
		# Two quick thumps a beat, quicker as it pounds harder.
		var phase := fmod(_t * (1.1 + beat * 0.8), 1.0)
		var thump := maxf(1.0 - absf(phase - 0.1) * 9.0, 0.0) + 0.7 * maxf(1.0 - absf(phase - 0.32) * 9.0, 0.0)
		var a := clampf(beat * 1.4, 0.25, 1.0) * (0.45 + 0.55 * thump)
		var font_size := int(roundf((21.0 + 6.0 * thump * beat) * scale_px))
		_word(font, center + Vector2(0.0, ring + 40.0 * scale_px), "HEARTBEAT", font_size,
			UiTheme.DANGER.lightened(0.3), a)


## [param text] centred on [param at], outlined so it reads on any water.
func _word(font: Font, at: Vector2, text: String, font_size: int, color: Color, alpha: float) -> void:
	var width := font_size * 12.0
	var base := at + Vector2(-width * 0.5, font_size * 0.35)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, maxi(font_size / 4, 3),
		Color(0.0, 0.0, 0.0, 0.85 * alpha))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(color, alpha))
