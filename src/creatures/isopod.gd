class_name Isopod
extends Creature
## Armored scavenger that crawls along the cave walls, leaps at passing subs
## and latches on, chewing through power lines until shaken off by boosting
## or a shock pulse.

enum State { CRAWL, LEAP, LATCHED, FALL }

const LEAP_RANGE := 7.5
const LEAP_SPEED := 14.0
const SHAKE_OFF_TIME := 1.1

var wall_normal := Vector2.UP
var state := State.CRAWL
var _dir := 1.0
var _timer := 0.0
var _latch_offset := Vector2.ZERO
var _shake := 0.0
var _cooldown := 0.0
var _legs: MeshInstance3D
var _t := 0.0


func setup() -> void:
	species = &"isopod"
	max_hp = 16.0
	radius = 0.6
	mass = 0.8
	contact_damage = 4.0
	salvage_drop = 3
	glow_color = Color(1.0, 0.6, 0.2)
	super.setup()
	_dir = 1.0 if level.rng.randf() < 0.5 else -1.0


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.42, 0.36, 0.32))
		m.set_shader_parameter(&"belly_color", Color(0.25, 0.2, 0.18))
		m.set_shader_parameter(&"glow_color", Color(1.0, 0.55, 0.15))
		m.set_shader_parameter(&"glow_strength", 1.6)
		m.set_shader_parameter(&"metallic", 0.3)
		m.set_shader_parameter(&"roughness", 0.5)
		m.set_shader_parameter(&"body_length", 1.3)
		m.set_shader_parameter(&"swim_amp", 0.0))
	# Segmented carapace: ridges in the profile read as armor plates.
	var profile := PackedVector2Array()
	for i in 15:
		var t := i / 14.0
		var r := sin(t * PI) * 0.55 * (0.88 + 0.12 * absf(sin(t * PI * 7.0)))
		profile.append(Vector2(t, maxf(r, 0.05)))
	var shell := MeshKit.lathe(profile, 1.3, 12, 28, 0.65, 1.0, func(t: float, a: float) -> float:
		return 1.0 if (t > 0.86 and t < 0.92 and cos(a) > 0.2) else 0.0)
	add_visual(shell, mat)
	var legs := []
	for i in 6:
		var x := -0.45 + i * 0.18
		for z: float in [-0.35, 0.35]:
			legs.append([MeshKit.spike(0.04, 0.35, 0.0, 4), Transform3D(Basis(Vector3.BACK, -PI * 0.5 - 0.3), Vector3(x, -0.2, z))])
	_legs = add_visual(MeshKit.merge(legs), mat)


func think() -> void:
	if state != State.CRAWL or _cooldown > 0.0:
		return
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < LEAP_RANGE and level.field.line_of_sight(pos, sub.pos):
		alert()
		state = State.LEAP
		_timer = 0.9
		vel = (sub.pos + sub.vel * 0.3 - pos).normalized() * LEAP_SPEED
		Audio.play_at(&"isopod_leap", pos, -2.0)


func behave(delta: float) -> void:
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	match state:
		State.CRAWL:
			_crawl(delta)
		State.LEAP:
			_timer -= delta
			vel *= exp(-0.8 * delta)
			if _timer <= 0.0:
				state = State.FALL
				_timer = 2.0
		State.FALL:
			_timer -= delta
			vel = vel.lerp(Vector2(0, -3.0), 1.0 - exp(-1.5 * delta))
			if level.field.sample(pos) < radius + 0.4 or _timer <= 0.0:
				state = State.CRAWL
				_cooldown = 1.5
		State.LATCHED:
			_ride(delta)
	_legs.rotation.x = sin(_t * 14.0) * 0.15 if state == State.CRAWL else 0.0


func _crawl(delta: float) -> void:
	var field := level.field
	var d := field.sample(pos)
	var n := field.normal(pos)
	wall_normal = n
	var tangent := Vector2(-n.y, n.x) * _dir
	# Hold ~0.3 m off the surface while walking along it.
	var hold := n * (radius + 0.3 - d) * 6.0
	vel = vel.lerp(tangent * 1.6 + hold, 1.0 - exp(-6.0 * delta))
	if d > radius + 3.0:
		state = State.FALL
		_timer = 2.0
	if level.rng.randf() < delta * 0.15:
		_dir = -_dir
	facing = tangent
	lock_facing = true


func _ride(delta: float) -> void:
	var sub := level.player
	if sub == null or not sub.alive:
		_detach()
		return
	pos = sub.pos + _latch_offset
	vel = sub.vel
	facing = -_latch_offset.normalized()
	sub.drain(1.2 * delta, 3.5 * delta)
	if sub.boosting:
		_shake += delta
		if _shake > SHAKE_OFF_TIME:
			_detach()
			vel = _latch_offset.normalized() * 8.0
	else:
		_shake = maxf(_shake - delta * 0.5, 0.0)


func move_and_collide_field(delta: float, bounce := 0.1) -> Vector2:
	if state == State.LATCHED:
		return Vector2.ZERO
	return super.move_and_collide_field(delta, bounce)


func on_touch_player(sub: Submarine) -> void:
	if state == State.LEAP or state == State.FALL:
		state = State.LATCHED
		_latch_offset = (pos - sub.pos).normalized() * (Submarine.RADIUS + 0.35)
		_shake = 0.0
		lock_facing = true
		Audio.play_at(&"isopod_latch", pos, 0.0)
		Events.toast.emit("Isopod latched on! Boost or shock to shake it off", UiTheme.WARN)
	elif state == State.CRAWL:
		sub.take_damage(contact_damage, pos, self)


func _detach() -> void:
	state = State.FALL
	_timer = 2.0
	_cooldown = 3.0


func stun(duration: float) -> void:
	super.stun(duration)
	if state == State.LATCHED:
		_detach()
		vel = _latch_offset.normalized() * 6.0


func is_latched() -> bool:
	return state == State.LATCHED
