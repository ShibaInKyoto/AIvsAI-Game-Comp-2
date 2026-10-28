class_name Puffer
extends Creature
## Spined puffer: a slow, curious reef fish that gulps water and swells into
## a ball of spines when anything rushes or roars past. Swollen, it hurts
## whatever touches it, lancers included; harpooned while swollen it bursts
## and sprays spines at everything nearby. Drifting past gently keeps it calm.

enum State { CALM, PUFFED }

const CALM_RADIUS := 0.65
const PUFFED_RADIUS := 1.15
const PUFF_TIME := 5.0
## Startled by the sub this close (plus part of its noise radius) ...
const STARTLE_RANGE := 3.0
## ... when the sub is at least this loud, or almost touching.
const STARTLE_NOISE := 7.0
const SPINE_DAMAGE := 12.0
const NOVA_RADIUS := 4.5
const NOVA_DAMAGE := 30.0

static var _spine_mesh: Mesh

var state := State.CALM
var _timer := 0.0
var _inflation := 0.0
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _spike_cooldown := 0.0
var _dying := false
var _short_spines: MeshInstance3D
var _long_spines: MeshInstance3D


func setup() -> void:
	species = &"puffer"
	max_hp = 18.0
	radius = CALM_RADIUS
	mass = 0.8
	contact_damage = SPINE_DAMAGE
	hearing = 0.45
	salvage_drop = 3
	hostile = false
	glow_color = Color(1.0, 0.85, 0.4)
	_turn_speed = 3.0
	super.setup()
	_home = pos
	_target = wander_point(_home, 9.0)


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.55, 0.45, 0.22))
		m.set_shader_parameter(&"belly_color", Color(0.9, 0.86, 0.72))
		m.set_shader_parameter(&"glow_color", Color(1.0, 0.85, 0.4))
		m.set_shader_parameter(&"glow_strength", 1.4)
		m.set_shader_parameter(&"roughness", 0.4)
		m.set_shader_parameter(&"body_length", 1.3)
		m.set_shader_parameter(&"swim_amp", 0.05)
		m.set_shader_parameter(&"swim_freq", 5.0))
	var body := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.12, 0.32), Vector2(0.45, 0.5),
			Vector2(0.75, 0.47), Vector2(0.93, 0.3), Vector2(1.0, 0.08)]), 1.3, 14, 12, 1.0, 0.9,
		func(t: float, a: float) -> float:
			# Glowing spots along the flanks.
			return 0.7 if sin(t * 22.0) * cos(a * 5.0) > 0.75 and t > 0.2 and t < 0.85 else 0.0)
	var tail := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-0.4, 0.32), Vector2(-0.3, 0.0),
			Vector2(-0.4, -0.32)]), 0.03, 0.2)
	var fin := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-0.22, 0.2), Vector2(-0.28, 0.02)]), 0.02)
	add_visual(MeshKit.merge([[body], [tail, Transform3D(Basis(), Vector3(-0.62, 0, 0))],
		[fin, Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.15, -0.05, 0.42))],
		[fin, Transform3D(Basis(Vector3.UP, -0.5), Vector3(0.15, -0.05, -0.42))]]), mat)
	if _spine_mesh == null:
		_spine_mesh = MeshKit.spike(0.045, 1.0, 0.0, 5)
	var spine_mat := StandardMaterial3D.new()
	spine_mat.albedo_color = Color(0.92, 0.88, 0.75)
	spine_mat.roughness = 0.5
	_short_spines = _spines(0.1, spine_mat)
	_long_spines = _spines(0.42, spine_mat)
	_long_spines.visible = false
	add_eyes(Vector3(0.42, 0.14, 0.32), 0.09, Color(0.95, 0.8, 0.3))


## Spines all over the body (an ellipsoid matching the calm shape).
func _spines(length: float, mat: Material) -> MeshInstance3D:
	var parts := []
	var n := 40
	for i in n:
		# Fibonacci sphere: evenly spread directions.
		var y := 1.0 - 2.0 * (i + 0.5) / n
		var r := sqrt(1.0 - y * y)
		var a := PI * (3.0 - sqrt(5.0)) * i
		var dir := Vector3(r * cos(a), y, r * sin(a))
		if dir.x < -0.75:
			continue
		var at := Vector3(dir.x * 0.6, dir.y * 0.47, dir.z * 0.42)
		var up := Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
		var side := dir.cross(up).normalized()
		var basis := Basis(dir, side.cross(dir).normalized(), side) * Basis.from_scale(Vector3(length, 1.0, 1.0))
		parts.append([_spine_mesh, Transform3D(basis, at)])
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.merge(parts)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(mi)
	return mi


func is_hostile() -> bool:
	return state == State.PUFFED


func think() -> void:
	match state:
		State.CALM:
			if _startled():
				puff()
			elif pos.distance_to(_target) < 1.5:
				_target = wander_point(_home, 9.0)
		State.PUFFED:
			_timer -= THINK_INTERVAL
			if _timer <= 0.0:
				if _startled():
					_timer = 1.5
				else:
					state = State.CALM
					radius = CALM_RADIUS


func _startled() -> bool:
	var sub := level.player
	if sub and sub.alive:
		var d := pos.distance_to(sub.pos)
		if d < STARTLE_RANGE + sub.noise_radius * 0.4 and (sub.noise_radius > STARTLE_NOISE or d < radius + 2.6):
			return true
	if level.loudest_noise_at(pos, hearing, self) != null:
		return true
	for e in level.targets_in_radius(pos, 3.0):
		if e != self and e is Creature and e.vel.length() > 7.0:
			return true
	return false


## Swells up into a ball of spines.
func puff() -> void:
	if state == State.PUFFED:
		_timer = PUFF_TIME
		return
	state = State.PUFFED
	_timer = PUFF_TIME
	radius = PUFFED_RADIUS
	Audio.play_at(&"puffer_puff", pos, -2.0)
	Fx.bubble_burst(level, pos, 12, 0.6)


func behave(delta: float) -> void:
	_spike_cooldown = maxf(_spike_cooldown - delta, 0.0)
	var target_k := 1.0 if state == State.PUFFED else 0.0
	_inflation = move_toward(_inflation, target_k, delta * (5.0 if state == State.PUFFED else 0.6))
	match state:
		State.CALM:
			seek(_target, 1.5, 1.2, delta)
		State.PUFFED:
			# Swollen with water it can barely swim; it bobs where it is.
			vel = vel.lerp(Vector2(0.0, 0.3), 1.0 - exp(-2.0 * delta))
			if _spike_cooldown <= 0.0:
				_spike_creatures()
	_short_spines.visible = _inflation < 0.5
	_long_spines.visible = not _short_spines.visible


## Swollen spines hurt any creature pressed against them.
func _spike_creatures() -> void:
	for e in level.targets_in_radius(pos, radius + 0.3):
		var c := e as Creature
		if c and c != self and not c is Puffer:
			c.take_damage(SPINE_DAMAGE, pos, &"spines")
			_spike_cooldown = 0.5


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	var k := _inflation * _inflation * (3.0 - 2.0 * _inflation)
	model.basis = model.basis * Basis.from_scale(Vector3(lerpf(1.0, 1.45, k), lerpf(1.0, 2.0, k), lerpf(1.0, 2.0, k)))


func on_touch_player(sub: Submarine) -> void:
	if state == State.PUFFED:
		sub.take_damage(SPINE_DAMAGE, pos, self)
	else:
		puff()


func on_damaged(_amount: float, _from: Vector2) -> void:
	if alive:
		puff()


func on_harpoon_hit(harpoon: Node, damage: float) -> HarpoonReaction:
	if state == State.PUFFED:
		take_damage(max_hp * 3.0, level.player.pos if level.player else pos, &"harpoon")
		return HarpoonReaction.IGNORE
	return super.on_harpoon_hit(harpoon, damage)


func die() -> void:
	if not alive or _dying:
		return
	_dying = true
	if state == State.PUFFED:
		_spine_nova()
	super.die()


## Bursting while swollen sprays spines at everything close by.
func _spine_nova() -> void:
	Audio.play_at(&"puffer_burst", pos, 0.0)
	Fx.shockwave(level, pos, NOVA_RADIUS, Color(0.5, 0.45, 0.3), 0.35)
	Fx.rubble(level, pos, _spine_mesh, _long_spines.material_override, 10)
	level.emit_noise(pos, 12.0, self)
	for e in level.targets_in_radius(pos, NOVA_RADIUS):
		var c := e as Creature
		if c and c != self:
			c.take_damage(NOVA_DAMAGE, pos, &"spines")
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < NOVA_RADIUS * 0.7:
		sub.take_damage(SPINE_DAMAGE * 0.7, pos, self)
