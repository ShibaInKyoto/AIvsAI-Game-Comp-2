class_name Tremors
extends Entity
## The "tremors" zone event: every half minute or so the rock shakes. A low
## groan gives a moment's warning, then the zone lurches: the sub is knocked
## about, silt pours from the ceilings, every loose stalactite near the sub
## comes down and new rock breaks away overhead.

## Seconds of groaning before the quake proper.
const WARNING := 2.4
const FIRST := 18.0
const GAP := Vector2(26.0, 40.0)
## Loose rock this close to the sub is shaken down.
const REACH := 34.0
## Fresh rock breaks away from ceilings within this far of the sub, sideways.
const DROP_SPREAD := 13.0
const DROPS := 2
const KNOCK := 3.5

## Shown once per session, the first time the zone shakes.
static var _explained := false

var quakes := 0
var _timer := FIRST
var _warned := false


func setup() -> void:
	active_radius = INF


func tick(delta: float) -> void:
	var sub := level.player
	if sub == null or not sub.alive:
		return
	_timer -= delta
	if not _warned and _timer <= WARNING:
		_warned = true
		Audio.play(&"vent_rumble", -4.0, 0.6)
		Audio.play(&"creak", -6.0, 0.7)
		Events.shake_requested.emit(0.12)
	if _timer <= 0.0:
		_quake(sub)
		_timer = level.rng.randf_range(GAP.x, GAP.y)
		_warned = false


func _quake(sub: Submarine) -> void:
	quakes += 1
	Audio.play(&"rock_flow", 0.0, 0.7)
	Audio.play(&"impact_rock", -2.0, 0.6)
	Events.shake_requested.emit(0.8)
	sub.vel += Vector2.from_angle(level.rng.randf() * TAU) * KNOCK
	if not _explained:
		_explained = true
		Events.toast.emit("TREMOR! Get clear of the ceiling - the rock is coming down.", UiTheme.WARN)
	var rng := level.rng
	for e in level.entities:
		var rock := e as Stalactite
		if rock and rock.alive and rock.pos.distance_to(sub.pos) < REACH:
			rock.shake_loose(rng.randf_range(0.4, 1.8))
	var overhead: Array[LevelLayout.Anchor] = []
	var ceilings: Array[LevelLayout.Anchor] = []
	for a in level.layout.anchors:
		if a.normal.y > -0.5 or a.pos.distance_to(sub.pos) > REACH:
			continue
		ceilings.append(a)
		if a.normal.y < -0.8 and absf(a.pos.x - sub.pos.x) < DROP_SPREAD and a.pos.y > sub.pos.y:
			overhead.append(a)
	overhead.shuffle()
	var dropped: Array[Vector2] = []
	for a in overhead:
		if dropped.size() >= DROPS:
			break
		if dropped.any(func(q: Vector2) -> bool: return q.distance_to(a.pos) < 4.0):
			continue
		if _break_away(a, rng.randf_range(0.6, 1.0)):
			dropped.append(a.pos)
	# Silt pours from the ceilings all round.
	ceilings.shuffle()
	for a in ceilings.slice(0, 6):
		Fx.silt(level, a.pos, 2.5, level.biome.sediment_tint)


## A new spike of rock breaking off the ceiling at [param a]; it trembles,
## then falls. Null if the rock there is too thin or nothing is below.
func _break_away(a: LevelLayout.Anchor, size: float) -> Stalactite:
	var half := Stalactite.LENGTH * 0.5 * size
	var center := a.pos - Vector2(0.0, half - 0.5)
	if level.field.sample(center) < 0.4 or not level.field.line_of_sight(center, center - Vector2(0.0, half + 4.0)):
		return null
	if level.layout.has_exit and center.distance_to(level.layout.exit) < 12.0:
		return null
	var rock := Stalactite.new()
	rock.size = size
	rock.pos = center
	level.add_entity(rock)
	rock.shake_loose(level.rng.randf_range(0.8, 1.5))
	return rock
