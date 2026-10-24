class_name Siphonophore
extends Creature
## A drifting colony: a chain of glowing bells strung behind a swimming head,
## tens of meters long. Beautiful, slow and stinging along its whole length.

const SEGMENTS := 18
const SPACING := 1.3

var segments := PackedVector2Array()
var _goal := Vector2.ZERO
var _home := Vector2.ZERO
var _multimesh: MultiMesh
var _t := 0.0


func setup() -> void:
	species = &"siphon"
	max_hp = 40.0
	radius = 0.9
	mass = 3.0
	contact_damage = 9.0
	salvage_drop = 7
	hostile = false
	glow_color = level.biome.glow_color.lerp(Color(0.6, 0.8, 1.0), 0.5)
	super.setup()
	_home = pos
	_goal = wander_point(_home, 25.0)
	for i in SEGMENTS:
		segments.append(pos + Vector2(-i * SPACING, 0))
	_multimesh.instance_count = SEGMENTS
	for i in SEGMENTS:
		_multimesh.set_instance_custom_data(i, Color(float(i) / SEGMENTS, 0, 0, 0))


func build_model() -> void:
	var glow := glow_color
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.3, 0.35, 0.5))
		m.set_shader_parameter(&"belly_color", Color(0.5, 0.55, 0.7))
		m.set_shader_parameter(&"glow_color", glow)
		m.set_shader_parameter(&"glow_strength", 2.4)
		m.set_shader_parameter(&"glow_pulse", 0.6)
		m.set_shader_parameter(&"rim_strength", 0.9)
		m.set_shader_parameter(&"roughness", 0.1)
		m.set_shader_parameter(&"body_length", 1.0)
		m.set_shader_parameter(&"swim_amp", 0.05))
	var bell := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.1), Vector2(0.4, 0.45), Vector2(0.8, 0.4), Vector2(1, 0.0)]),
		1.0, 10, 6, 0.8, 1.0, func(t: float, _a: float) -> float: return 0.3 + 0.7 * (1.0 - smoothstep(0.0, 0.5, t)))
	var frond := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.01), Vector2(1, 0.04)]), 1.2, 4, 3, 1.0, 1.0,
		func(_t: float, _a: float) -> float: return 0.6)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.mesh = MeshKit.merge([[bell], [frond, Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(0, -0.9, 0.2))]])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _multimesh
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.top_level = true
	add_child(mmi)
	visuals.append(mmi)


func think() -> void:
	if pos.distance_to(_goal) < 3.0:
		_goal = wander_point(_home, 28.0)


func behave(delta: float) -> void:
	_t += delta
	var dir := (_goal - pos).normalized()
	steer(dir * 1.6 + Vector2(0, sin(_t * 0.5) * 0.4), 0.6, delta)


func tick(delta: float) -> void:
	super.tick(delta)
	# The chain follows the head like a rope.
	segments[0] = pos
	for i in range(1, SEGMENTS):
		var to := segments[i] - segments[i - 1]
		var d := to.length()
		if d > SPACING:
			segments[i] = segments[i - 1] + to / d * SPACING
		segments[i] += Vector2(0, -0.15 * delta) + level.current_at(segments[i]) * delta * 0.5
	for i in SEGMENTS:
		var a := segments[i]
		var b := segments[i - 1] if i > 0 else a + (a - segments[1])
		var heading := (b - a).normalized()
		var s := lerpf(1.0, 0.55, float(i) / SEGMENTS) * (1.0 + 0.08 * sin(_t * 3.0 - i * 0.6))
		var basis := Basis(Vector3.BACK, heading.angle() - PI * 0.5).scaled(Vector3.ONE * s)
		_multimesh.set_instance_transform(i, Transform3D(basis, Vector3(a.x, a.y, sin(i * 0.9 + _t) * 0.4)))
	_sting_along_body()


func _sting_along_body() -> void:
	var sub := level.player
	if sub == null or not sub.alive or _touch_cooldown > 0.0:
		return
	for i in range(1, SEGMENTS):
		if segments[i].distance_squared_to(sub.pos) < pow(Submarine.RADIUS + 0.6, 2.0):
			_touch_cooldown = 1.0
			on_touch_player(sub)
			return


func _update_visuals(_delta: float) -> void:
	for v in visuals:
		v.set_instance_shader_parameter(&"marked", _marked / _mark_total if _marked > 0.0 else 0.0)
		v.set_instance_shader_parameter(&"hit_flash", _flash)


func on_touch_player(sub: Submarine) -> void:
	sub.take_damage(contact_damage, pos, self)
	sub.run.battery = maxf(sub.run.battery - 6.0, 0.0)
	Audio.play_at(&"jelly_shock", sub.pos, -2.0)
