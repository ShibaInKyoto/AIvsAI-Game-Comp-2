class_name Lurelight
extends Creature
## Ambush angler. Hangs near a wall with a glowing lure dangling in front of
## a near-invisible body; anything that comes close to the light is engulfed.

enum State { LURE, SNAP, RETURN, HIDE }

const SNAP_RANGE := 6.5
const SNAP_SPEED := 17.0

var wall_normal := Vector2.UP
var state := State.LURE
var _home := Vector2.ZERO
var _timer := 0.0
var _lit_time := 0.0
var _jaw: MeshInstance3D
var _lure: Node3D
var _lure_light: OmniLight3D
var _t := 0.0


func setup() -> void:
	species = &"lurelight"
	max_hp = 60.0
	radius = 1.3
	mass = 4.0
	contact_damage = 26.0
	salvage_drop = 8
	glow_color = Color(0.5, 1.0, 0.85)
	_turn_speed = 3.0
	pos += wall_normal * 2.2
	super.setup()
	pos = level.field.resolve_circle(pos, radius)
	_home = pos
	facing = Vector2(-wall_normal.y, wall_normal.x) if level.rng.randf() < 0.5 else Vector2(wall_normal.y, -wall_normal.x)
	facing = (facing + wall_normal * 0.6).normalized()


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.06, 0.06, 0.08))
		m.set_shader_parameter(&"belly_color", Color(0.12, 0.1, 0.12))
		m.set_shader_parameter(&"glow_color", Color(0.4, 1.0, 0.8))
		m.set_shader_parameter(&"glow_strength", 1.2)
		m.set_shader_parameter(&"rim_strength", 0.15)
		m.set_shader_parameter(&"roughness", 0.7)
		m.set_shader_parameter(&"body_length", 2.8)
		m.set_shader_parameter(&"swim_amp", 0.08)
		m.set_shader_parameter(&"swim_freq", 3.0))
	var body := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.1), Vector2(0.2, 0.45), Vector2(0.55, 1.1), Vector2(0.85, 1.0), Vector2(1.0, 0.45)]),
		2.8, 16, 14, 1.0, 0.8, func(t: float, a: float) -> float:
			# Faint photophore spots along the flank.
			return 0.6 if (fmod(t * 9.0, 1.0) < 0.12 and absf(cos(a)) < 0.25 and t > 0.25 and t < 0.75) else 0.0)
	var tail := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-0.7, 0.6), Vector2(-0.5, 0), Vector2(-0.7, -0.6)]), 0.04)
	add_visual(MeshKit.merge([[body], [tail, Transform3D(Basis(), Vector3(-1.4, 0, 0))]]), mat)

	# Lower jaw with teeth; opens wide during a snap.
	var jaw_mesh := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.55), Vector2(0.6, 0.6), Vector2(1, 0.3)]), 1.2, 12, 4, 0.45, 0.85)
	var teeth := []
	for i in 7:
		var x := -0.3 + i * 0.14
		teeth.append([MeshKit.spike(0.05, 0.32, 0.0, 4), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.15, 0.35 - absf(x) * 0.2))])
		teeth.append([MeshKit.spike(0.05, 0.32, 0.0, 4), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.15, -0.35 + absf(x) * 0.2))])
	var tooth_mat := StandardMaterial3D.new()
	tooth_mat.albedo_color = Color(0.9, 0.88, 0.8)
	tooth_mat.emission_enabled = true
	tooth_mat.emission = Color(0.6, 0.9, 0.8)
	tooth_mat.emission_energy_multiplier = 0.4
	_jaw = add_visual(jaw_mesh, mat, Transform3D(Basis(), Vector3(0.75, -0.45, 0)))
	var teeth_mi := MeshInstance3D.new()
	teeth_mi.mesh = MeshKit.merge(teeth)
	teeth_mi.material_override = tooth_mat
	_jaw.add_child(teeth_mi)

	# The lure: a stalk arcing forward with a glowing bulb.
	_lure = Node3D.new()
	_lure.position = Vector3(1.0, 0.95, 0)
	model.add_child(_lure)
	var stalk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.05
	cyl.height = 1.6
	stalk.mesh = cyl
	stalk.material_override = mat
	stalk.rotation_degrees = Vector3(0, 0, -40)
	stalk.position = Vector3(0.5, 0.55, 0)
	_lure.add_child(stalk)
	var bulb := MeshInstance3D.new()
	bulb.mesh = SubmarineModel._sphere(0.2)
	bulb.material_override = SubmarineModel._emissive(Color(0.55, 1.0, 0.85), 9.0)
	bulb.position = Vector3(1.05, 1.15, 0)
	_lure.add_child(bulb)
	_lure_light = OmniLight3D.new()
	_lure_light.light_color = Color(0.5, 1.0, 0.85)
	_lure_light.omni_range = 7.0
	_lure_light.light_energy = 1.6
	_lure_light.light_volumetric_fog_energy = 1.0
	_lure_light.position = Vector3(1.05, 1.15, 0.6)
	_lure.add_child(_lure_light)


func lure_position() -> Vector2:
	return pos + facing * 2.2 + Vector2(0, 0.8)


func think() -> void:
	if state != State.LURE:
		return
	var sub := level.player
	if sub == null or not sub.alive:
		return
	var lure_d := sub.pos.distance_to(lure_position())
	var body_d := sub.pos.distance_to(pos)
	if sub.illuminates(pos, radius) and body_d < 12.0:
		_lit_time += THINK_INTERVAL
	else:
		_lit_time = maxf(_lit_time - THINK_INTERVAL, 0.0)
	if (lure_d < SNAP_RANGE or body_d < SNAP_RANGE * 0.8 or _lit_time > 1.0) and level.field.line_of_sight(pos, sub.pos):
		alert()
		state = State.SNAP
		_timer = 0.4
		_lit_time = 0.0
		lock_facing = true
		facing = (sub.pos - pos).normalized()
		Audio.play_at(&"lurelight_snap", pos, 2.0)


func behave(delta: float) -> void:
	_t += delta
	_lure.rotation.z = sin(_t * 1.3) * 0.12
	_lure_light.light_energy = 1.4 + sin(_t * 2.1) * 0.3
	var jaw_open := 0.0
	match state:
		State.LURE:
			seek(_home, 1.0, 1.5, delta)
			jaw_open = 0.05 + sin(_t * 0.7) * 0.03
		State.SNAP:
			_timer -= delta
			vel = facing * SNAP_SPEED
			jaw_open = 0.7
			if _timer <= 0.0:
				state = State.RETURN
				_timer = 2.5
				lock_facing = false
		State.RETURN:
			_timer -= delta
			seek(_home, 3.0, 2.0, delta)
			jaw_open = 0.2
			if _timer <= 0.0 or pos.distance_to(_home) < 1.0:
				state = State.LURE
		State.HIDE:
			_timer -= delta
			seek(_home, 4.0, 3.0, delta)
			_lure_light.light_energy = 0.2
			if _timer <= 0.0:
				state = State.LURE
	_jaw.rotation.z = lerpf(_jaw.rotation.z, -jaw_open, 1.0 - exp(-12.0 * delta))


func on_touch_player(sub: Submarine) -> void:
	sub.take_damage(contact_damage if state == State.SNAP else 8.0, pos, self)
	if state == State.SNAP:
		state = State.RETURN
		_timer = 2.5
		lock_facing = false


func on_damaged(_amount: float, _from: Vector2) -> void:
	if hp < max_hp * 0.5 and state != State.SNAP:
		state = State.HIDE
		_timer = 5.0
