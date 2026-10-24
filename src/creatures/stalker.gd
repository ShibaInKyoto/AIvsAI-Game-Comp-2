class_name Stalker
extends Creature
## Apex hunter. Patrols the zone, investigates noise, charges any lit sub it
## sees and is drawn off by flares. Retreats after taking heavy damage.

enum State { PATROL, INVESTIGATE, HUNT, DISTRACTED, FLEE }

const PATROL_SPEED := 3.5
const INVESTIGATE_SPEED := 7.0
const HUNT_SPEED := 11.0
const SIGHT := 24.0

var state := State.PATROL
var _target := Vector2.ZERO
var _timer := 0.0
var _bite_cooldown := 0.0
var _recent_damage := 0.0
var _flare: Flare
var _announced := false
var _jaw: MeshInstance3D
var _t := 0.0


func setup() -> void:
	species = &"stalker"
	max_hp = 230.0
	radius = 1.6
	mass = 20.0
	contact_damage = 30.0
	hearing = 1.6
	salvage_drop = 30
	glow_color = Color(1.0, 0.25, 0.2)
	_turn_speed = 3.0
	super.setup()
	_target = _patrol_point()


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.08, 0.09, 0.11))
		m.set_shader_parameter(&"belly_color", Color(0.22, 0.2, 0.22))
		m.set_shader_parameter(&"glow_color", Color(1.0, 0.25, 0.15))
		m.set_shader_parameter(&"glow_strength", 3.0)
		m.set_shader_parameter(&"glow_pulse", 0.25)
		m.set_shader_parameter(&"metallic", 0.25)
		m.set_shader_parameter(&"roughness", 0.4)
		m.set_shader_parameter(&"rim_strength", 0.35)
		m.set_shader_parameter(&"body_length", 7.0)
		m.set_shader_parameter(&"swim_amp", 0.35)
		m.set_shader_parameter(&"swim_freq", 3.2)
		m.set_shader_parameter(&"swim_wave", 0.9))
	var body := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.1), Vector2(0.15, 0.35), Vector2(0.45, 1.05), Vector2(0.7, 1.15),
			Vector2(0.88, 0.95), Vector2(1.0, 0.35)]), 7.0, 18, 24, 0.95, 0.75,
		func(t: float, a: float) -> float:
			var eye := 1.0 if (t > 0.9 and t < 0.94 and cos(a) > 0.15 and cos(a) < 0.6) else 0.0
			var flank := 0.7 if (absf(cos(a)) < 0.12 and t > 0.25 and t < 0.85 and fmod(t * 14.0, 1.0) < 0.55) else 0.0
			return maxf(eye * 2.0, flank))
	var tail := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-1.6, 1.5), Vector2(-1.1, 0), Vector2(-1.6, -1.5)]), 0.08, 0.2)
	var dorsal := MeshKit.fin(PackedVector2Array([Vector2(0.8, 0), Vector2(-0.6, 1.1), Vector2(-1.2, 0)]), 0.08)
	var pectoral := MeshKit.fin(PackedVector2Array([Vector2(0.3, 0), Vector2(-0.8, -0.2), Vector2(-0.4, -0.9)]), 0.06)
	add_visual(MeshKit.merge([
		[body], [tail, Transform3D(Basis(), Vector3(-3.4, 0, 0))],
		[dorsal, Transform3D(Basis(), Vector3(0.0, 1.0, 0))],
		[pectoral, Transform3D(Basis(), Vector3(1.2, -0.5, 0.6))],
		[pectoral, Transform3D(Basis(), Vector3(1.2, -0.5, -0.6))]]), mat)
	var jaw := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.7), Vector2(0.7, 0.6), Vector2(1, 0.15)]), 1.8, 12, 4, 0.35, 0.8)
	var teeth := []
	for i in 6:
		teeth.append([MeshKit.spike(0.07, 0.4, 0.2, 4), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.3 + i * 0.22, 0.12, 0.0))])
	_jaw = add_visual(MeshKit.merge([[jaw], [MeshKit.merge(teeth)]]), mat, Transform3D(Basis(), Vector3(2.6, -0.45, 0)))


func _patrol_point() -> Vector2:
	var p := level.layout.random_open_point(level.rng, 4.0)
	return p if p != Vector2.INF else pos


func think() -> void:
	_recent_damage = maxf(_recent_damage - 10.0 * THINK_INTERVAL, 0.0)
	if state == State.FLEE:
		return
	var sub := level.player
	if sub and sub.alive and (can_see_player(SIGHT) or player_in_range(6.0)):
		if state != State.HUNT:
			state = State.HUNT
			_timer = 6.0
			Audio.play_at(&"stalker_roar", pos, 4.0)
			Events.shake_requested.emit(0.35)
			if not _announced:
				_announced = true
				Events.toast.emit("Something huge is hunting you. Kill the lamp, or throw a flare.", UiTheme.DANGER)
		else:
			_timer = 6.0
		_target = sub.pos
		return
	var flare := nearest_flare()
	if flare and flare.lure_strength(pos) > 0.15:
		state = State.DISTRACTED
		_flare = flare
		return
	var heard := heard_noise()
	if heard != Vector2.INF and state != State.HUNT:
		state = State.INVESTIGATE
		_target = heard
		_timer = 8.0


func behave(delta: float) -> void:
	_t += delta
	_bite_cooldown = maxf(_bite_cooldown - delta, 0.0)
	var jaw_open := 0.05
	match state:
		State.PATROL:
			seek(_target, PATROL_SPEED, 1.2, delta)
			if pos.distance_to(_target) < 4.0:
				_target = _patrol_point()
		State.INVESTIGATE:
			seek(_target, INVESTIGATE_SPEED, 1.8, delta)
			_timer -= delta
			if pos.distance_to(_target) < 4.0 or _timer <= 0.0:
				state = State.PATROL
				_target = _patrol_point()
		State.HUNT:
			_timer -= delta
			var sub := level.player
			if sub and sub.alive:
				var lead := sub.pos + sub.vel * 0.4
				seek(lead, HUNT_SPEED, 2.2, delta)
				jaw_open = 0.45 if pos.distance_to(sub.pos) < 8.0 else 0.15
			if _timer <= 0.0:
				state = State.INVESTIGATE
				_target = sub.pos if sub else pos
				_timer = 6.0
		State.DISTRACTED:
			if _flare == null or not is_instance_valid(_flare) or not _flare.alive:
				state = State.PATROL
				_target = _patrol_point()
			else:
				var orbit := _flare.pos + Vector2(cos(_t * 0.8), sin(_t * 0.8)) * 6.0
				seek(orbit, INVESTIGATE_SPEED, 1.6, delta)
		State.FLEE:
			_timer -= delta
			var sub := level.player
			var away := (pos - sub.pos).normalized() if sub else Vector2.UP
			steer(away * HUNT_SPEED, 2.0, delta)
			if _timer <= 0.0:
				state = State.PATROL
				_target = _patrol_point()
	_jaw.rotation.z = lerpf(_jaw.rotation.z, -jaw_open, 1.0 - exp(-8.0 * delta))


func on_touch_player(sub: Submarine) -> void:
	if _bite_cooldown > 0.0:
		return
	_bite_cooldown = 1.6
	sub.take_damage(contact_damage, pos, self)
	Audio.play_at(&"stalker_bite", pos, 2.0)
	# Peel away after a bite so the player has a window to react.
	vel = (pos - sub.pos).normalized() * 6.0


func on_damaged(amount: float, from: Vector2) -> void:
	_recent_damage += amount
	if _recent_damage > 70.0:
		state = State.FLEE
		_timer = 5.0
		_recent_damage = 0.0
		Audio.play_at(&"stalker_roar", pos, 0.0)
	elif state != State.HUNT and state != State.FLEE:
		state = State.INVESTIGATE
		_target = from
		_timer = 6.0


func on_pinged(origin: Vector2) -> void:
	if state == State.PATROL:
		state = State.INVESTIGATE
		_target = origin
		_timer = 8.0
