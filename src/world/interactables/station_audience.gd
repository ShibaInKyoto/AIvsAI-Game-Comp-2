class_name StationAudience
extends Entity
## "The fauna gathers around the station at night. Lancers, jellies, things I
## have no names for, all facing the floor, perfectly still. Like an
## audience. Every time the tone changes pitch, they turn together." (log_05)
## Over the ruins of Meridian Deep hangs a gathering of hunters held by the
## Choir's tone: deaf to sonar and engines, biting nothing. Each time the
## tone shifts they turn as one. Hurt or bump one, and every member near it
## wakes and turns on the sub.

const MEMBERS: Array[StringName] = [&"lancer", &"lancer", &"lancer", &"ghostfin", &"ghostfin", &"jelly", &"jelly"]
## Seconds between changes of the tone.
const TONE_PERIOD := Vector2(7.0, 11.0)
## A member that wakes wakes the rest within this range.
const WAKE_RADIUS := 10.0
const HEARING := 60.0
const NOTICE_RANGE := 28.0

## Shown once per session, the first time the sub comes near.
static var _explained := false

var members: Array[Creature] = []
var turns := 0
var _tone_in := 3.0
var _side := 1.0
## While the lullaby is sung back, they hold still, facing the station.
var _listening := 0.0


## Gathers the audience in the water over [param station]; returns it.
static func gather(level: Level, station: MeridianStation) -> StationAudience:
	var audience := StationAudience.new()
	audience.pos = station.pos + Vector2(0.0, 7.0)
	level.add_entity(audience)
	var rng := level.rng
	var placed := PackedVector2Array()
	for id in MEMBERS:
		for _attempt in 14:
			var p := station.pos + Vector2(rng.randf_range(-11.0, 11.0), rng.randf_range(4.0, 10.0))
			if level.field.sample(p) < 2.0 or not _clear_of(p, placed, 2.6):
				continue
			var c: Creature = LevelPopulator.SPECIES[id].new()
			c.pos = p
			c.entranced = true
			level.add_entity(c)
			audience.members.append(c)
			placed.append(p)
			break
	return audience


static func _clear_of(p: Vector2, points: PackedVector2Array, dist: float) -> bool:
	for q in points:
		if q.distance_squared_to(p) < dist * dist:
			return false
	return true


func setup() -> void:
	radius = 0.0
	active_radius = 1.0e6


func tick(delta: float) -> void:
	# Killed members are freed: check before touching them (a typed lambda
	# would choke on the freed instance).
	var still: Array[Creature] = []
	for m: Variant in members:
		if is_instance_valid(m) and (m as Creature).alive:
			still.append(m)
	members = still
	# One that has left the trance (hurt, bumped) brings the rest with it.
	for m in members:
		if not m.entranced:
			_wake_near(m.pos)
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < NOTICE_RANGE \
			and members.any(func(m: Creature) -> bool: return m.entranced):
		Wonders.witness("audience")
	if not _explained and sub and sub.alive and sub.pos.distance_to(pos) < NOTICE_RANGE \
			and members.any(func(m: Creature) -> bool: return m.entranced):
		_explained = true
		Events.toast.emit("Hunters hang over the station, facing the floor, perfectly still. Do not wake them.",
			UiTheme.WARN)
	# Once the Choir is singing to the sub, the tone is its own.
	if level.boss and level.boss.active:
		return
	_listening = maxf(_listening - delta, 0.0)
	if _listening > 0.0:
		return
	_tone_in -= delta
	if _tone_in <= 0.0:
		_tone_in = level.rng.randf_range(TONE_PERIOD.x, TONE_PERIOD.y)
		_shift_tone()


## The lullaby sung back from below: they turn to face the station's speakers.
func listen() -> void:
	_listening = 26.0
	for m in members:
		if m.entranced:
			m.entranced_facing = (pos + Vector2(0.0, -2.0) - m.pos).normalized()


func _wake_near(p: Vector2) -> void:
	for m in members:
		if m.entranced and m.pos.distance_to(p) < WAKE_RADIUS:
			m.entranced = false
			m.alert()


## The tone changes pitch, and the audience turns together.
func _shift_tone() -> void:
	_side = -_side
	turns += 1
	var heading := Vector2(0.45 * _side, -1.0).normalized()
	for m in members:
		if m.entranced:
			m.entranced_facing = heading
	var sub := level.player
	if sub and sub.pos.distance_to(pos) < HEARING:
		Audio.play_at(&"choir_tone", pos + Vector2(0.0, -8.0), -6.0, 0.0, 1.0 if _side > 0.0 else 0.84)
