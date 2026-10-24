class_name Shoal
extends Creature
## A school of small glowing fish simulated as boids and drawn with one
## MultiMesh. The shoal is scannable but not targetable; it scatters from
## fast-moving submarines and flashes when startled.

const FISH_SPEED := 4.0
const PANIC_SPEED := 9.0

var fish_pos := PackedVector2Array()
var fish_vel := PackedVector2Array()
var _multimesh: MultiMesh
var _goal := Vector2.ZERO
var _panic := 0.0
var _home := Vector2.ZERO


func setup() -> void:
	species = &"shoal"
	max_hp = 1.0
	radius = 3.0
	contact_damage = 0.0
	hostile = false
	salvage_drop = 0
	glow_color = level.biome.glow_color
	super.setup()
	targetable = false
	_home = pos
	_goal = wander_point(_home, 15.0)
	var count := level.rng.randi_range(14, 24)
	for i in count:
		fish_pos.append(pos + Vector2(level.rng.randf_range(-2.5, 2.5), level.rng.randf_range(-1.5, 1.5)))
		fish_vel.append(Vector2(level.rng.randf_range(-1, 1), level.rng.randf_range(-0.3, 0.3)))
	_multimesh.instance_count = count
	for i in count:
		_multimesh.set_instance_custom_data(i, Color(level.rng.randf(), 0, 0, 0))


func build_model() -> void:
	var glow := glow_color
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.35, 0.45, 0.55))
		m.set_shader_parameter(&"belly_color", Color(0.85, 0.9, 0.95))
		m.set_shader_parameter(&"glow_color", glow)
		m.set_shader_parameter(&"glow_strength", 2.0)
		m.set_shader_parameter(&"metallic", 0.6)
		m.set_shader_parameter(&"roughness", 0.25)
		m.set_shader_parameter(&"body_length", 0.45)
		m.set_shader_parameter(&"swim_amp", 0.05)
		m.set_shader_parameter(&"swim_freq", 14.0)
		m.set_shader_parameter(&"swim_wave", 8.0))
	var body := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.01), Vector2(0.25, 0.05), Vector2(0.6, 0.08),
			Vector2(1, 0)]),
		0.45, 8, 6, 1.0, 0.5, func(t: float, a: float) -> float:
			return 1.0 - smoothstep(0.1, 0.3, absf(cos(a))) if t > 0.2 else 0.0)
	var tail := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-0.12, 0.08), Vector2(-0.12, -0.08)]), 0.01, 0.3)
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_custom_data = true
	_multimesh.mesh = MeshKit.merge([[body], [tail, Transform3D(Basis(), Vector3(-0.2, 0, 0))]])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _multimesh
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The MultiMesh is in world space; keep it out of the model transform.
	mmi.top_level = true
	add_child(mmi)
	visuals.append(mmi)


func think() -> void:
	if pos.distance_to(_goal) < 3.0:
		_goal = wander_point(_home, 18.0)
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < 9.0 and sub.vel.length() > 3.5:
		if _panic <= 0.0:
			Audio.play_at(&"shoal_scatter", pos, -8.0)
		_panic = 1.5


func behave(delta: float) -> void:
	_panic = maxf(_panic - delta, 0.0)
	var n := fish_pos.size()
	var center := Vector2.ZERO
	for p in fish_pos:
		center += p
	center /= maxf(n, 1)
	pos = center
	var sub := level.player
	var threat := sub.pos if sub and sub.alive else Vector2.INF
	var field := level.field
	var max_speed := PANIC_SPEED if _panic > 0.0 else FISH_SPEED
	for i in n:
		var p := fish_pos[i]
		var v := fish_vel[i]
		var sep := Vector2.ZERO
		var align := Vector2.ZERO
		for j in n:
			if i == j:
				continue
			var d := p - fish_pos[j]
			var dl := d.length_squared()
			if dl < 0.8:
				sep += d / maxf(dl, 0.05)
			if dl < 6.0:
				align += fish_vel[j]
		var steer_v := (center - p) * 0.6 + sep * 1.2 + align.normalized() * 0.8 + (_goal - center).normalized() * 1.2
		if threat != Vector2.INF:
			var away := p - threat
			var dist := away.length()
			if dist < 8.0:
				steer_v += away / maxf(dist, 0.1) * (8.0 - dist) * 2.5
		var wall := field.sample(p)
		if wall < 1.5:
			steer_v += field.normal(p) * (1.5 - wall) * 8.0
		v += steer_v * delta * 3.0
		v = v.limit_length(max_speed)
		p += v * delta
		if field.sample(p) < 0.3:
			p = field.resolve_circle(p, 0.3)
		fish_pos[i] = p
		fish_vel[i] = v
		var dir := v.normalized() if v.length_squared() > 0.01 else Vector2.RIGHT
		var basis := Basis(Vector3.BACK, dir.angle())
		if dir.x < 0.0:
			basis = basis * Basis(Vector3.RIGHT, PI)
		_multimesh.set_instance_transform(i, Transform3D(basis, Vector3(p.x, p.y, sin(i * 1.7) * 0.8)))
	vel = Vector2.ZERO
	for v in visuals:
		v.set_instance_shader_parameter(&"glow_boost", 1.0 + _panic * 2.0)


func _update_visuals(_delta: float) -> void:
	for v in visuals:
		v.set_instance_shader_parameter(&"marked", _marked / _mark_total if _marked > 0.0 else 0.0)
