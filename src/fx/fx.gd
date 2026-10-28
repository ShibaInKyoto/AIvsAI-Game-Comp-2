class_name Fx
extends RefCounted
## Factory for particle effects. Meshes, textures and process materials are
## built once and shared; one-shot emitters free themselves when finished.

static var _soft_tex: GradientTexture2D
static var _ring_tex: GradientTexture2D
static var _cache: Dictionary[StringName, Resource] = {}


static func soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.4, Color(1, 1, 1, 0.55))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex


static func ring_texture() -> GradientTexture2D:
	if _ring_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.6, 0.85, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
		_ring_tex = GradientTexture2D.new()
		_ring_tex.gradient = g
		_ring_tex.fill = GradientTexture2D.FILL_RADIAL
		_ring_tex.fill_from = Vector2(0.5, 0.5)
		_ring_tex.fill_to = Vector2(1.0, 0.5)
		_ring_tex.width = 64
		_ring_tex.height = 64
	return _ring_tex


## Billboard quad material for particles. Additive for glowing effects.
static func particle_material(tex: Texture2D, additive: bool, emission := 1.0) -> StandardMaterial3D:
	var key := StringName("pm_%d_%s_%.2f" % [tex.get_instance_id(), additive, emission])
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.disable_receive_shadows = true
	if emission != 1.0:
		m.albedo_color = Color(emission, emission, emission, 1.0)
	_cache[key] = m
	return m


static func _quad(size: float, mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	return q


static func _emitter(amount: int, lifetime: float, process: ParticleProcessMaterial, mesh: Mesh,
		one_shot := true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.process_material = process
	p.draw_pass_1 = mesh
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-15, -15, -15), Vector3(30, 30, 30))
	if one_shot:
		p.finished.connect(p.queue_free)
	return p


static func _spawn(level: Node3D, node: GPUParticles3D, at: Vector2, z := 0.3) -> GPUParticles3D:
	if level == null:
		node.free()
		return null
	level.add_child(node)
	node.global_position = Vector3(at.x, at.y, z)
	node.emitting = true
	return node


static func _color_ramp(colors: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


# --- Continuous emitters -------------------------------------------------------

static func bubble_emitter() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(-1, 0.4, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, 2.2, 0)
	pm.damping_min = 0.8
	pm.damping_max = 1.6
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.color = Color(0.8, 0.95, 1.0, 0.55)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 2.0
	var p := _emitter(40, 2.4, pm, _quad(0.16, particle_material(ring_texture(), false)), false)
	return p


# --- One-shot effects ------------------------------------------------------------

static func sparks(level: Node3D, at: Vector2) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, -6, 0)
	pm.damping_min = 3.0
	pm.damping_max = 6.0
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.color_ramp = _color_ramp(PackedColorArray([Color(1, 0.9, 0.6, 1), Color(1, 0.5, 0.1, 1), Color(1, 0.2, 0.0, 0)]),
		PackedFloat32Array([0.0, 0.4, 1.0]))
	_spawn(level, _emitter(28, 0.6, pm, _quad(0.12, particle_material(soft_texture(), true, 4.0))), at)


static func bubble_burst(level: Node3D, at: Vector2, amount := 30, size := 1.0) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6 * size
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0 * size
	pm.initial_velocity_max = 5.0 * size
	pm.gravity = Vector3(0, 3.0, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 2.0
	pm.color = Color(0.85, 0.95, 1.0, 0.6)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.0
	_spawn(level, _emitter(amount, 2.5, pm, _quad(0.22, particle_material(ring_texture(), false))), at)


## Creature hit / death puff in the creature's glow color.
static func ichor(level: Node3D, at: Vector2, color: Color, amount := 18) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 4.0
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.8
	var c0 := color
	c0.a = 0.9
	var c1 := color
	c1.a = 0.0
	pm.color_ramp = _color_ramp(PackedColorArray([c0, c1]), PackedFloat32Array([0.0, 1.0]))
	_spawn(level, _emitter(amount, 1.2, pm, _quad(0.35, particle_material(soft_texture(), true, 2.5))), at)


static func ink_cloud(level: Node3D, at: Vector2) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.damping_min = 1.5
	pm.damping_max = 2.5
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	pm.color_ramp = _color_ramp(PackedColorArray([Color(0.05, 0.02, 0.08, 0.85), Color(0.02, 0.0, 0.04, 0.0)]),
		PackedFloat32Array([0.0, 1.0]))
	_spawn(level, _emitter(40, 3.5, pm, _quad(1.2, particle_material(soft_texture(), false))), at, 1.0)


static func explosion(level: Node3D, at: Vector2, radius: float) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = radius * 1.5
	pm.initial_velocity_max = radius * 3.0
	pm.damping_min = radius
	pm.damping_max = radius * 2.0
	pm.scale_min = 1.0
	pm.scale_max = 3.0
	pm.color_ramp = _color_ramp(PackedColorArray([Color(1, 0.95, 0.8, 1), Color(1, 0.55, 0.15, 0.9), Color(0.3, 0.1,
			0.05, 0.0)]),
		PackedFloat32Array([0.0, 0.25, 1.0]))
	_spawn(level, _emitter(40, 0.9, pm, _quad(0.6, particle_material(soft_texture(), true, 5.0))), at)
	bubble_burst(level, at, 50, radius / 3.0)
	flash(level, at, Color(1.0, 0.7, 0.4), radius * 3.0, 0.5)
	shockwave(level, at, radius, Color(1.0, 0.8, 0.5))


static func implosion(level: Node3D, at: Vector2) -> void:
	bubble_burst(level, at, 90, 2.0)
	sparks(level, at)
	flash(level, at, Color(0.6, 0.9, 1.0), 25.0, 0.8)
	shockwave(level, at, 10.0, Color(0.6, 0.9, 1.0))


## Brief point light flash.
static func flash(level: Node3D, at: Vector2, color: Color, light_range: float, duration: float) -> void:
	if level == null:
		return
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = light_range
	light.light_energy = 6.0
	light.light_volumetric_fog_energy = 1.5
	level.add_child(light)
	light.global_position = Vector3(at.x, at.y, 1.5)
	var tween := light.create_tween()
	tween.tween_property(light, ^"light_energy", 0.0, duration).set_ease(Tween.EASE_OUT)
	tween.tween_callback(light.queue_free)


## Expanding additive ring on the gameplay plane.
static func shockwave(level: Node3D, at: Vector2, radius: float, color: Color) -> void:
	if level == null:
		return
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = ring_texture()
	m.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.add_child(mi)
	mi.global_position = Vector3(at.x, at.y, 0.5)
	mi.scale = Vector3.ONE * 0.2
	var tween := mi.create_tween().set_parallel(true)
	tween.tween_property(mi, ^"scale", Vector3.ONE * radius, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(m, ^"albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(mi.queue_free)


## Little burst when collecting a pickup.
## A billboard label for floating "+N" gains; always drawn on top.
static func float_label(color: Color) -> Label3D:
	var l := Label3D.new()
	l.font = UiTheme.BOLD_FONT
	l.font_size = 56
	l.outline_size = 14
	l.pixel_size = 0.015
	l.modulate = color
	l.outline_modulate = Color(0.0, 0.03, 0.06, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.shaded = false
	return l


static func sparkle(level: Node3D, at: Vector2, color: Color) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.damping_min = 4.0
	pm.damping_max = 6.0
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	var c1 := color
	c1.a = 0.0
	pm.color_ramp = _color_ramp(PackedColorArray([color, c1]), PackedFloat32Array([0.0, 1.0]))
	_spawn(level, _emitter(14, 0.6, pm, _quad(0.18, particle_material(soft_texture(), true, 4.0))), at)
