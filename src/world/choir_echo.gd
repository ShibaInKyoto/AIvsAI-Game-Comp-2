class_name ChoirEcho
extends Entity
## In the Hadal Trench something answers the sub's sonar the way it answered
## Meridian's (log_03): eleven seconds after a ping, the ping comes back up
## from far below, slowed down and stretched into something like a word. The
## returning wave charts the cave around the sub again, and makes no sound a
## hunter can follow. The first ping in a zone is always answered; after
## that, only sometimes.

const DELAY := 11.0
const CHANCE := 0.35
const COOLDOWN := 40.0
## How far below the sub the answer rises from.
const DEPTH := 30.0

## Shown once per session, the first time something answers.
static var _explained := false

var answers := 0
var _wait := -1.0
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	radius = 0.0
	active_radius = 1.0e6
	_rng.seed = level.layout.zone_seed + 11
	Events.sonar_pinged.connect(_on_ping)


func _exit_tree() -> void:
	if Events.sonar_pinged.is_connected(_on_ping):
		Events.sonar_pinged.disconnect(_on_ping)


## Whether an answer is on its way.
func pending() -> bool:
	return _wait >= 0.0


func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _wait < 0.0:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = -1.0
		_answer()


func _on_ping(origin: Vector2, _range: float) -> void:
	# Only the sub's own pings (not the answer itself, which rises from below).
	var sub := level.player
	if sub == null or not sub.alive or origin.distance_to(sub.pos) > 1.5:
		return
	if pending() or _cooldown > 0.0:
		return
	if answers > 0 and _rng.randf() >= CHANCE:
		return
	_wait = DELAY
	_cooldown = COOLDOWN


func _answer() -> void:
	var sub := level.player
	if sub == null or not sub.alive:
		return
	answers += 1
	Wonders.witness("echo")
	var from := sub.pos + Vector2(0.0, -DEPTH)
	Audio.play(&"choir_echo", -3.0)
	# For the sound cues: it comes up from below.
	Audio.sound_at.emit(&"choir_echo", from)
	level.ping(from, DEPTH + sub.stats.sonar_range, sub.stats.sonar_mark_time)
	if not _explained:
		_explained = true
		Events.toast.emit("Eleven seconds later, something far below pinged back.", UiTheme.ACCENT)
