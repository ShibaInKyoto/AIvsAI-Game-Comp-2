class_name ChoirOrgan
extends Creature
## One of the Choir's voice organs. Shielded by its own resonance unless the
## pilot has just answered the song, which leaves every organ open briefly.

var boss: ChoirBoss
var _bulb: MeshInstance3D
var _light: OmniLight3D
var _shield_hint := 0.0
var _t := 0.0


func setup() -> void:
	species = &"choir"
	max_hp = 150.0
	radius = 1.9
	mass = 99.0
	contact_damage = 10.0
	salvage_drop = 20
	glow_color = Color(1.0, 0.35, 0.9)
	super.setup()
	active_radius = 400.0
	lock_facing = true
	facing = (boss.center - pos).normalized()


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.25, 0.08, 0.25))
		m.set_shader_parameter(&"belly_color", Color(0.45, 0.2, 0.45))
		m.set_shader_parameter(&"glow_color", Color(1.0, 0.35, 0.9))
		m.set_shader_parameter(&"glow_strength", 3.0)
		m.set_shader_parameter(&"glow_pulse", 0.5)
		m.set_shader_parameter(&"rim_strength", 0.7)
		m.set_shader_parameter(&"body_length", 4.0)
		m.set_shader_parameter(&"swim_amp", 0.0))
	var bulb := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.3), Vector2(0.3, 1.5), Vector2(0.7, 1.7), Vector2(1.0, 0.2)]), 4.0, 16, 12, 1.0, 1.0,
		func(t: float, a: float) -> float:
			return 0.4 + 0.6 * (1.0 if fmod(t * 6.0 + a * 0.5, 1.0) < 0.35 else 0.0))
	_bulb = add_visual(bulb, mat)
	_light = OmniLight3D.new()
	_light.light_color = glow_color
	_light.omni_range = 12.0
	_light.light_energy = 1.5
	_light.light_volumetric_fog_energy = 1.0
	_light.position = Vector3(0, 0, 2.0)
	add_child(_light)


func behave(delta: float) -> void:
	_t += delta
	_shield_hint = maxf(_shield_hint - delta, 0.0)
	vel = Vector2.ZERO
	var open := boss != null and boss.vulnerable > 0.0
	var s := 1.0 + sin(_t * (5.0 if open else 2.0)) * (0.08 if open else 0.04)
	_bulb.scale = Vector3(s, s, s)
	var col := Color(1.0, 0.95, 0.6) if open else glow_color
	_light.light_color = col
	_light.light_energy = 3.0 if open else 1.5
	for v in visuals:
		v.set_instance_shader_parameter(&"glow_boost", 2.2 if open else 1.0)


func move_and_collide_field(_delta: float, _bounce := 0.1) -> Vector2:
	return Vector2.ZERO


func take_damage(amount: float, from: Vector2, kind: StringName = &"") -> void:
	if boss == null or boss.vulnerable <= 0.0:
		amount *= 0.08
		if _shield_hint <= 0.0:
			_shield_hint = 4.0
			Events.toast.emit("Its resonance shields it. Answer the song first.", UiTheme.WARN)
	super.take_damage(amount, from, kind)


func on_harpoon_hit(_harpoon: Node, damage: float) -> HarpoonReaction:
	take_damage(damage, level.player.pos if level.player else pos, &"harpoon")
	return HarpoonReaction.STICK if alive else HarpoonReaction.IGNORE


func die() -> void:
	if not alive:
		return
	Fx.explosion(level, pos, 5.0)
	Audio.play_at(&"organ_burst", pos, 3.0)
	Events.shake_requested.emit(0.7)
	if boss:
		boss.on_organ_destroyed(self)
	super.die()
