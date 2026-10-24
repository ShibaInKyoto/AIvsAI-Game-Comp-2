class_name Gulper
extends Creature
## Gulper eel living in a wall burrow. It feels vibrations: subs that pass
## fast, loud or with a lamp in its face get struck by a lunge from the rock.
## The entity position is the head; the body is a tube back into the burrow.

enum State { LURK, STRIKE, RETRACT, HIDE }

const REACH := 9.5
const STRIKE_TIME := 0.32
const SENSE_RANGE := 10.0

var wall_normal := Vector2.UP
var state := State.LURK
var _burrow := Vector2.ZERO
var _rest := Vector2.ZERO
var _strike_from := Vector2.ZERO
var _strike_to := Vector2.ZERO
var _timer := 0.0
var _cooldown := 0.0
var _t := 0.0
var _body_mesh := ArrayMesh.new()
var _body: MeshInstance3D
var _head: MeshInstance3D


func setup() -> void:
	species = &"gulper"
	max_hp = 42.0
	radius = 0.75
	mass = 10.0
	contact_damage = 20.0
	salvage_drop = 6
	glow_color = Color(1.0, 0.35, 0.5)
	_burrow = pos - wall_normal * 1.2
	_rest = pos + wall_normal * 0.8
	pos = _rest
	super.setup()
	lock_facing = true
	facing = wall_normal


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.12, 0.08, 0.1))
		m.set_shader_parameter(&"belly_color", Color(0.3, 0.18, 0.2))
		m.set_shader_parameter(&"glow_color", Color(1.0, 0.3, 0.45))
		m.set_shader_parameter(&"glow_strength", 2.5)
		m.set_shader_parameter(&"glow_pulse", 0.5)
		m.set_shader_parameter(&"roughness", 0.35)
		m.set_shader_parameter(&"rim_strength", 0.4)
		m.set_shader_parameter(&"body_length", 1.6)
		m.set_shader_parameter(&"swim_amp", 0.0))
	var head := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.32), Vector2(0.4, 0.5), Vector2(0.8, 0.55), Vector2(1.0, 0.25)]), 1.6, 12, 8, 0.9, 1.0,
		func(t: float, a: float) -> float:
			return 1.0 if (t > 0.78 and t < 0.84 and cos(a) > 0.45) else 0.0)
	var fangs := []
	for i in 4:
		var z := -0.24 + i * 0.16
		fangs.append([MeshKit.spike(0.05, 0.3, 0.3, 4), Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0.7, 0.3, z))])
	_head = add_visual(MeshKit.merge([[head], [MeshKit.merge(fangs)]]), mat)
	add_eyes(Vector3(0.55, 0.32, 0.38), 0.08, Color(1.0, 0.4, 0.5), 3.0)
	# The body is rebuilt in world space every frame, so it lives outside `model`.
	_body = MeshInstance3D.new()
	_body.mesh = _body_mesh
	_body.material_override = mat
	_body.top_level = true
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	visuals.append(_body)


func think() -> void:
	if state != State.LURK or _cooldown > 0.0:
		return
	var sub := level.player
	if sub == null or not sub.alive:
		return
	var d := sub.pos.distance_to(_rest)
	if d > SENSE_RANGE:
		return
	var noticed := sub.noise_radius > 7.0 or sub.vel.length() > 5.5 or sub.illuminates(pos, radius) or d < 3.5
	if noticed and level.field.line_of_sight(_rest, sub.pos, 0.3):
		alert()
		state = State.STRIKE
		_timer = STRIKE_TIME
		_strike_from = pos
		_strike_to = _rest + (sub.pos - _rest).limit_length(REACH)
		Audio.play_at(&"gulper_strike", pos, 2.0)


func behave(delta: float) -> void:
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	match state:
		State.LURK:
			var sway := Vector2(-wall_normal.y, wall_normal.x) * sin(_t * 0.9) * 0.5
			pos = pos.lerp(_rest + sway, 1.0 - exp(-3.0 * delta))
		State.STRIKE:
			_timer -= delta
			var f := 1.0 - _timer / STRIKE_TIME
			pos = _strike_from.lerp(_strike_to, ease(f, 0.4))
			if _timer <= 0.0:
				state = State.RETRACT
				_timer = 1.2
		State.RETRACT, State.HIDE:
			_timer -= delta
			var target := _rest if state == State.RETRACT else _burrow
			pos = pos.lerp(target, 1.0 - exp(-3.0 * delta))
			if _timer <= 0.0:
				state = State.LURK
				_cooldown = 2.0
	vel = Vector2.ZERO
	var to_head := pos - _burrow
	facing = to_head.normalized() if to_head.length() > 0.1 else wall_normal


func tick(delta: float) -> void:
	super.tick(delta)
	_rebuild_body()


## The head never collides with rock: it is anchored to the burrow.
func move_and_collide_field(_delta: float, _bounce := 0.1) -> Vector2:
	return Vector2.ZERO


func _rebuild_body() -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var tail := _burrow - wall_normal * 2.0
	var head := pos - facing * 0.6
	var side := Vector2(-facing.y, facing.x)
	var n := 12
	for i in n:
		var t := float(i) / (n - 1)
		var p := tail.lerp(head, t)
		p += side * sin(t * PI * 2.0 + _t * 4.0) * 0.35 * sin(t * PI)
		pts.append(Vector3(p.x, p.y, 0.0))
		radii.append(lerpf(0.2, 0.42, t))
	MeshKit.tube(_body_mesh, pts, radii, 8, 1.0)


func on_touch_player(sub: Submarine) -> void:
	sub.take_damage(contact_damage if state == State.STRIKE else 6.0, pos, self)
	if state == State.STRIKE:
		state = State.RETRACT
		_timer = 1.2


func on_damaged(_amount: float, _from: Vector2) -> void:
	state = State.HIDE
	_timer = 4.0
