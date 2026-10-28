class_name Ghostfin
extends Creature
## Ghostfins: small, near-transparent pack hunters of the Hadal Trench, seen
## mostly as pairs of glowing eyes. Light draws them: a pack circles a lit
## lamp and takes turns darting in to bite, and loses interest a few seconds
## after the lamp goes dark. A burning flare pulls the whole pack off.

enum State { DRIFT, CIRCLE, DART, RETREAT }

## A lit lamp is noticed from this far away (with line of sight).
const SIGHT_RANGE := 24.0
const ORBIT_RADIUS := 6.0
const ORBIT_SPEED := 7.0
const DART_SPEED := 15.0
const DART_TIME := 0.5
## Seconds the pack keeps circling after the lamp goes dark.
const PATIENCE := 3.0

var state := State.DRIFT
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _orbit := 0.0
var _timer := 0.0
var _dark := 0.0
var _dart_dir := Vector2.RIGHT


func setup() -> void:
	species = &"ghostfin"
	max_hp = 14.0
	radius = 0.5
	mass = 0.5
	contact_damage = 7.0
	salvage_drop = 2
	glow_color = Color(0.6, 0.85, 1.0)
	_turn_speed = 9.0
	super.setup()
	_home = pos
	_target = wander_point(_home, 10.0)
	_orbit = level.rng.randf() * TAU
	_timer = level.rng.randf_range(1.5, 4.0)


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.05, 0.06, 0.08))
		m.set_shader_parameter(&"belly_color", Color(0.1, 0.12, 0.15))
		m.set_shader_parameter(&"glow_color", Color(0.55, 0.85, 1.0))
		m.set_shader_parameter(&"glow_strength", 1.8)
		m.set_shader_parameter(&"rim_strength", 0.9)
		m.set_shader_parameter(&"roughness", 0.1)
		m.set_shader_parameter(&"body_length", 1.4)
		m.set_shader_parameter(&"swim_amp", 0.14)
		m.set_shader_parameter(&"swim_freq", 10.0))
	var body := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.02), Vector2(0.3, 0.12), Vector2(0.7, 0.2),
			Vector2(0.9, 0.16), Vector2(1.0, 0.06)]), 1.4, 10, 10, 1.0, 0.55,
		func(t: float, a: float) -> float:
			# A faint glowing seam along the back.
			return 0.5 if cos(a) > 0.85 and t > 0.2 and t < 0.85 else 0.0)
	# Long, ragged fins that glow at the edges.
	var tail := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-0.55, 0.32), Vector2(-0.4, 0.0),
			Vector2(-0.6, -0.3)]), 0.02, 0.7)
	var dorsal := MeshKit.fin(PackedVector2Array([Vector2(0.15, 0), Vector2(-0.3, 0.28), Vector2(-0.45, 0.0)]),
		0.02, 0.6)
	add_visual(MeshKit.merge([[body], [tail, Transform3D(Basis(), Vector3(-0.68, 0, 0))],
		[dorsal, Transform3D(Basis(), Vector3(0.0, 0.16, 0))],
		[dorsal, Transform3D(Basis().scaled(Vector3(1, -0.8, 1)), Vector3(-0.1, -0.15, 0))]]), mat)
	add_eyes(Vector3(0.52, 0.06, 0.1), 0.06, Color(0.75, 0.95, 1.0), 4.0)


func think() -> void:
	var sub := level.player
	var flare := nearest_flare()
	var lit := sub != null and sub.alive and sub.lamp_on and pos.distance_to(sub.pos) < SIGHT_RANGE \
		and level.field.line_of_sight(pos, sub.pos)
	match state:
		State.DRIFT:
			if flare and flare.lure_strength(pos) > 0.05:
				state = State.CIRCLE
			elif lit:
				state = State.CIRCLE
				_timer = level.rng.randf_range(1.5, 3.5)
			elif pos.distance_to(_target) < 2.0:
				_target = wander_point(_home, 10.0)
		State.CIRCLE:
			_dark = 0.0 if lit or flare else _dark + THINK_INTERVAL
			if _dark > PATIENCE:
				state = State.DRIFT
				_home = pos
				_target = wander_point(_home, 10.0)


func behave(delta: float) -> void:
	match state:
		State.DRIFT:
			seek(_target, 2.5, 2.0, delta)
		State.CIRCLE:
			var center := _focus()
			_orbit += delta * ORBIT_SPEED / ORBIT_RADIUS
			seek(center + Vector2.from_angle(_orbit) * ORBIT_RADIUS, ORBIT_SPEED, 3.0, delta)
			_timer -= delta
			# Only a lamp is worth a bite; a flare is just circled.
			var sub := level.player
			if _timer <= 0.0 and sub and sub.alive and sub.lamp_on and nearest_flare() == null:
				state = State.DART
				_timer = DART_TIME
				_dart_dir = (sub.pos - pos).normalized()
				Audio.play_at(&"lancer_dash", pos, -10.0, 0.1, 1.8)
		State.DART:
			_timer -= delta
			vel = _dart_dir * DART_SPEED
			if _timer <= 0.0:
				_retreat()
		State.RETREAT:
			_timer -= delta
			seek(pos - _dart_dir * 4.0, 6.0, 3.0, delta)
			if _timer <= 0.0:
				state = State.CIRCLE
				_timer = level.rng.randf_range(2.0, 4.0)


## What the pack circles: a burning flare if there is one, else the sub.
func _focus() -> Vector2:
	var flare := nearest_flare()
	if flare:
		return flare.pos
	return level.player.pos if level.player else pos


func _retreat() -> void:
	state = State.RETREAT
	_timer = 0.8


func on_touch_player(sub: Submarine) -> void:
	if state == State.DART:
		sub.take_damage(contact_damage, pos, self)
		_retreat()


func on_damaged(_amount: float, _from: Vector2) -> void:
	if alive and state == State.DRIFT:
		state = State.CIRCLE
		_timer = 0.5
