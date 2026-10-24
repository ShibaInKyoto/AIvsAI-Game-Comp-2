class_name Jelly
extends Creature
## Drifter jelly: pulses slowly along, drifts towards light and shocks
## anything it touches, draining batteries.

const SHOCK_DRAIN := 12.0

var _pulse_t := 0.0
var _drift := Vector2.ZERO
var _bell: MeshInstance3D


func setup() -> void:
	species = &"jelly"
	max_hp = 16.0
	radius = 0.9
	mass = 0.9
	contact_damage = 8.0
	salvage_drop = 2
	hostile = false
	upright = true
	glow_color = level.biome.glow_color.lerp(Color(1.0, 0.5, 0.9), 0.4)
	super.setup()
	_pulse_t = level.rng.randf() * 3.0
	_drift = Vector2(level.rng.randf_range(-1, 1), level.rng.randf_range(-0.3, 0.3)).normalized() * 0.6


func build_model() -> void:
	var glow := glow_color
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.35, 0.3, 0.5))
		m.set_shader_parameter(&"belly_color", Color(0.6, 0.5, 0.8))
		m.set_shader_parameter(&"glow_color", glow)
		m.set_shader_parameter(&"glow_strength", 2.6)
		m.set_shader_parameter(&"glow_pulse", 0.35)
		m.set_shader_parameter(&"rim_strength", 0.8)
		m.set_shader_parameter(&"roughness", 0.15)
		m.set_shader_parameter(&"body_length", 3.0)
		m.set_shader_parameter(&"swim_amp", 0.22)
		m.set_shader_parameter(&"swim_freq", 2.5)
		m.set_shader_parameter(&"swim_wave", 1.6)
		m.set_shader_parameter(&"swim_vertical", 0.5))
	# The model's +X axis points up (see Creature.upright); tentacles trail to -X.
	var bell := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.85), Vector2(0.15, 0.95), Vector2(0.55, 0.8), Vector2(0.85, 0.5), Vector2(1.0, 0.0)]),
		1.1, 16, 8, 1.0, 1.0, func(t: float, _a: float) -> float: return 0.35 + 0.65 * (1.0 - smoothstep(0.0, 0.3, t)))
	_bell = add_visual(bell, mat, Transform3D(Basis(), Vector3(0.4, 0, 0)))
	var parts := []
	for i in 7:
		var a := TAU * i / 7.0
		var length := level.rng.randf_range(1.6, 2.8)
		var tentacle := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.01), Vector2(1.0, 0.05)]), length, 4, 6, 1.0, 1.0,
			func(t: float, _a: float) -> float: return 0.5 * t)
		parts.append([tentacle, Transform3D(Basis(), Vector3(-length * 0.5 - 0.05, cos(a) * 0.55, sin(a) * 0.55))])
	add_visual(MeshKit.merge(parts), mat)


func behave(delta: float) -> void:
	_pulse_t += delta
	var pulse := maxf(sin(_pulse_t * 2.2), 0.0)
	var desired := _drift + Vector2(0, pulse * 1.2 - 0.2)
	var sub := level.player
	if sub and sub.illuminates(pos, 2.0) and pos.distance_to(sub.pos) < 16.0:
		desired += (sub.pos - pos).normalized() * 1.4
	var flare := nearest_flare()
	if flare:
		desired += (flare.pos - pos).normalized() * 1.8
	steer(desired, 0.8, delta)
	if level.field.sample(pos) < radius + 1.5:
		var n := level.field.normal(pos)
		if _drift.dot(n) < 0.0:
			_drift = _drift.reflect(n).normalized() * 0.6
	_bell.scale = Vector3(1.0 + pulse * 0.08, 1.0 - pulse * 0.12, 1.0 - pulse * 0.12)


func on_touch_player(sub: Submarine) -> void:
	sub.take_damage(contact_damage, pos, self)
	sub.run.battery = maxf(sub.run.battery - SHOCK_DRAIN, 0.0)
	Fx.flash(level, pos, glow_color, 8.0, 0.25)
	Audio.play_at(&"jelly_shock", pos, 0.0)
