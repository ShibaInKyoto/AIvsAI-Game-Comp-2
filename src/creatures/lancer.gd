class_name Lancer
extends Creature
## Needle-nosed hunter that strikes at sound. Investigates noise, winds up
## (its stripe flares as a tell) and dashes in a straight line.

enum State { WANDER, INVESTIGATE, WINDUP, DASH, RECOVER }

const DASH_SPEED := 23.0
const WINDUP_TIME := 0.55
const DASH_TIME := 0.55

var state := State.WANDER
var _timer := 0.0
var _target := Vector2.ZERO
var _dash_dir := Vector2.RIGHT
var _home := Vector2.ZERO


func setup() -> void:
	species = &"lancer"
	max_hp = 30.0
	radius = 0.7
	mass = 1.6
	contact_damage = 14.0
	hearing = 1.2
	salvage_drop = 4
	glow_color = Color(0.5, 0.9, 1.0)
	_turn_speed = 8.0
	super.setup()
	_home = pos
	_target = wander_point(_home, 12.0)


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.16, 0.22, 0.3))
		m.set_shader_parameter(&"belly_color", Color(0.72, 0.78, 0.82))
		m.set_shader_parameter(&"glow_color", Color(0.45, 0.9, 1.0))
		m.set_shader_parameter(&"glow_strength", 2.2)
		m.set_shader_parameter(&"metallic", 0.55)
		m.set_shader_parameter(&"roughness", 0.3)
		m.set_shader_parameter(&"body_length", 2.6)
		m.set_shader_parameter(&"swim_amp", 0.16)
		m.set_shader_parameter(&"swim_freq", 9.0))
	var body := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.04), Vector2(0.12, 0.12), Vector2(0.45, 0.3), Vector2(0.75, 0.27),
			Vector2(0.92, 0.12), Vector2(1.0, 0.0)]), 2.6, 12, 16, 1.0, 0.62,
		func(t: float, a: float) -> float:
			var stripe := 1.0 - smoothstep(0.08, 0.2, absf(cos(a)))
			var eye := 1.0 if (t > 0.86 and t < 0.9 and cos(a) > 0.3) else 0.0
			return maxf(stripe * smoothstep(0.1, 0.3, t) * 0.8, eye))
	var tail := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-0.55, 0.42), Vector2(-0.35, 0.0),
			Vector2(-0.55, -0.42)]), 0.03, 0.4)
	var dorsal := MeshKit.fin(PackedVector2Array([Vector2(0.3, 0), Vector2(-0.25, 0.32), Vector2(-0.35, 0.0)]), 0.03, 0.0)
	var mesh := MeshKit.merge([
		[body], [tail, Transform3D(Basis(), Vector3(-1.25, 0, 0))],
		[dorsal, Transform3D(Basis(), Vector3(-0.2, 0.26, 0))],
		[dorsal, Transform3D(Basis().scaled(Vector3(0.7, -0.7, 1)), Vector3(-0.5, -0.22, 0))]])
	add_visual(mesh, mat)
	add_eyes(Vector3(0.95, 0.07, 0.13), 0.07, Color(0.95, 0.9, 0.6))


func think() -> void:
	match state:
		State.WANDER, State.INVESTIGATE:
			if player_in_range(13.0) and (can_see_player(13.0) or level.player.noise_radius > 4.0):
				_begin_windup(level.player.pos)
				return
			var heard := heard_noise()
			if heard != Vector2.INF:
				state = State.INVESTIGATE
				_target = heard
			elif state == State.WANDER and pos.distance_to(_target) < 2.0:
				_target = wander_point(_home, 14.0)


func _begin_windup(at: Vector2) -> void:
	alert()
	state = State.WINDUP
	lock_facing = true
	_timer = WINDUP_TIME
	_target = at
	Audio.play_at(&"lancer_windup", pos, -2.0)


func behave(delta: float) -> void:
	match state:
		State.WANDER:
			seek(_target, 2.5, 2.0, delta)
		State.INVESTIGATE:
			seek(_target, 6.0, 3.0, delta)
			if pos.distance_to(_target) < 2.5:
				state = State.WANDER
				_target = wander_point(pos, 10.0)
		State.WINDUP:
			_timer -= delta
			# Track the target while winding up, drifting backwards slightly.
			if level.player and level.player.alive:
				_target = level.player.pos
			var to := (_target - pos).normalized()
			facing = facing.slerp(to, 1.0 - exp(-10.0 * delta)).normalized()
			vel = vel.lerp(-to * 1.5, 1.0 - exp(-4.0 * delta))
			_set_glow(1.0 + (1.0 - _timer / WINDUP_TIME) * 3.0)
			if _timer <= 0.0:
				state = State.DASH
				lock_facing = false
				_timer = DASH_TIME
				_dash_dir = to
				Audio.play_at(&"lancer_dash", pos, 0.0)
				level.emit_noise(pos, 10.0, self)
		State.DASH:
			_timer -= delta
			vel = _dash_dir * DASH_SPEED
			if _timer <= 0.0 or level.field.sample(pos + _dash_dir * (radius + 0.6)) < 0.3:
				state = State.RECOVER
				_timer = 1.3
				_set_glow(1.0)
		State.RECOVER:
			_timer -= delta
			vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-3.0 * delta))
			if _timer <= 0.0:
				state = State.WANDER
				_target = wander_point(pos, 10.0)


func on_touch_player(sub: Submarine) -> void:
	# Only a dash really hurts; brushing past a lancer just nips.
	sub.take_damage(contact_damage if state == State.DASH else 4.0, pos, self)
	if state == State.DASH:
		state = State.RECOVER
		_timer = 1.3
		vel = -_dash_dir * 6.0
		_set_glow(1.0)


func on_damaged(_amount: float, from: Vector2) -> void:
	if state == State.WANDER or state == State.INVESTIGATE:
		_begin_windup(from)


func _set_glow(boost: float) -> void:
	for v in visuals:
		v.set_instance_shader_parameter(&"glow_boost", boost)
