extends "res://tools/debug/preview_stage.gd"
## Debug helper: stages a vent rumbling, a lancer winding up and a Stalker
## starting its hunt around the sub, with the sound-cue overlay on, and saves
## screenshots of the HUD.
## Usage: xvfb-run godot --path . res://tools/debug/preview_sound_cues.tscn -- <out_dir>

var _vent: ThermalVent
var _lancer: Lancer
var _heartbeat: Heartbeat


func _ready() -> void:
	Settings.sound_cues = true
	stage(6, 31337, &"lantern", true)
	LevelPopulator._spawn_vents(level, PackedVector2Array([level.layout.start]))
	_vent = find_entity(func(e: Entity) -> bool: return e is ThermalVent)
	place_sub(_vent.pos + _vent.normal * 4.0 + _vent.normal.orthogonal() * 7.0)
	add_hud()
	_heartbeat = Heartbeat.new()
	add_child(_heartbeat)
	(get_children().filter(func(n: Node) -> bool: return n is Hud)[0] as Hud).heartbeat = _heartbeat
	_lancer = Lancer.new()
	_lancer.pos = _open_spot(sub.pos, 8.0, PI)
	level.add_entity(_lancer)
	var stalker := Stalker.new()
	stalker.pos = _open_spot(sub.pos, 20.0, -PI * 0.5)
	level.add_entity(stalker)
	shot_prefix = "cues"
	shot_times = [0.9, 1.4, 2.0]
	_vent.erupt_soon()


func direct(dt: float) -> void:
	sub.aim = (_vent.pos - sub.pos).normalized()
	_heartbeat.tick(level, sub, dt)
	if t > 0.6 and _lancer.state == Lancer.State.WANDER:
		_lancer._begin_windup(sub.pos)


## Open water about [param dist] from [param from], trying directions round
## from [param angle].
func _open_spot(from: Vector2, dist: float, angle: float) -> Vector2:
	for i in 24:
		var p := from + Vector2.from_angle(angle + TAU * i / 24.0) * dist
		if level.field.sample(p) > 2.5 and level.field.line_of_sight(from, p):
			return p
	return from + Vector2(dist, 0.0)
