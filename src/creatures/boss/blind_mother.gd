class_name BlindMother
extends Creature
## The Blind Mother: a colossal eyeless eel coiled in a lair at the bottom of
## the Midnight Caverns, sealing the way down. She hunts by sound alone and
## lunges at whatever she hears. A lunge that ends in rock wedges her head in
## the wall and lays her glowing gills open; anywhere else her hide shrugs off
## almost everything. Ping beside a wall, slip away quietly - or fire a
## torpedo across the lair and let her chase the blast.

signal defeated

enum State { DORMANT, PROWL, AIM, LUNGE, STUCK, RECOVER, DEAD }

const SEGMENTS := 30
const SPACING := 0.85
const AIM_TIME := 0.75
const LUNGE_MAX := 2.2
const LUNGE_DAMAGE := 32.0
## Share of damage that gets through her hide unless she is stuck.
const ARMOR := 0.08
const PROWL_SPEED := 5.0
## Per phase (thirds of her health): lunge speed, seconds stuck, rest between lunges.
const LUNGE_SPEED: Array[float] = [24.0, 27.0, 30.0]
const STUCK_TIME: Array[float] = [3.6, 3.0, 2.5]
const REST: Array[float] = [1.6, 1.1, 0.7]

var lair_center := Vector2.ZERO
var lair_radius := Vector2(24.0, 14.0)
var state := State.DORMANT
var phase := 0
## True from the moment she wakes until she dies.
var active := false
var segments := PackedVector2Array()

var _timer := 0.0
var _cooldown := 0.0
var _target := Vector2.ZERO
var _lunge_dir := Vector2.RIGHT
var _wall_normal := Vector2.UP
var _orbit := 0.0
var _t := 0.0
var _clank_cooldown := 0.0
var _taught_armor := false
var _taught_stuck := false
var _body_mesh := ArrayMesh.new()
var _body: MeshInstance3D
var _gills: MeshInstance3D


func setup() -> void:
	species = &"mother"
	max_hp = 320.0
	radius = 1.6
	mass = 60.0
	contact_damage = 14.0
	salvage_drop = 70
	glow_color = Color(1.0, 0.5, 0.3)
	hearing = 2.4
	pos = lair_center + Vector2(0.0, -lair_radius.y * 0.45)
	super.setup()
	active_radius = 1000.0
	_orbit = level.rng.randf() * TAU
	# Coiled on the lair floor until something wakes her.
	for i in SEGMENTS:
		var a := i * 0.42
		var r := 2.0 + i * 0.22
		segments.append(pos + Vector2(cos(a) * r, sin(a) * r * 0.4))


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.07, 0.06, 0.07))
		m.set_shader_parameter(&"belly_color", Color(0.28, 0.24, 0.22))
		m.set_shader_parameter(&"glow_color", Color(1.0, 0.45, 0.25))
		m.set_shader_parameter(&"glow_strength", 1.6)
		m.set_shader_parameter(&"rim_strength", 0.35)
		m.set_shader_parameter(&"roughness", 0.55)
		m.set_shader_parameter(&"body_length", 3.4)
		m.set_shader_parameter(&"swim_amp", 0.0))
	var head := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 1.35), Vector2(0.45, 1.55), Vector2(0.8, 1.25),
		Vector2(1.0, 0.55)]), 3.4, 18, 10, 0.85, 1.0)
	var jaw := MeshKit.lathe(PackedVector2Array([Vector2(0, 1.1), Vector2(0.7, 0.9), Vector2(1, 0.3)]), 2.4, 14, 5,
			0.4, 0.9)
	var teeth := []
	for i in 9:
		var x := -0.9 + i * 0.24
		teeth.append([MeshKit.spike(0.08, 0.55, 0.0, 4), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.15, 0.6))])
		teeth.append([MeshKit.spike(0.08, 0.55, 0.0, 4), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(x, 0.15, -0.6))])
	add_visual(MeshKit.merge([[head], [jaw, Transform3D(Basis(), Vector3(0.7, -0.75, 0.0))],
		[MeshKit.merge(teeth), Transform3D(Basis(), Vector3(0.9, -0.65, 0.0))]]), mat)
	# Milky, sightless eyes.
	add_eyes(Vector3(1.15, 0.55, 1.05), 0.3, Color(0.82, 0.86, 0.9), 0.35)
	# Gill sacs along both sides of the head: dim until she is stuck.
	var sacs := []
	for i in 3:
		for side: float in [-1.0, 1.0]:
			sacs.append([MeshKit.ball(0.34, 1.0), Transform3D(Basis(), Vector3(-0.9 + i * 0.55, -0.1, side * 1.25))])
	var gill_mat := ShaderMaterial.new()
	gill_mat.shader = Creature.SHADER
	gill_mat.set_shader_parameter(&"back_color", Color(0.4, 0.1, 0.05))
	gill_mat.set_shader_parameter(&"belly_color", Color(0.5, 0.15, 0.08))
	gill_mat.set_shader_parameter(&"glow_color", Color(1.0, 0.35, 0.12))
	gill_mat.set_shader_parameter(&"glow_strength", 3.0)
	gill_mat.set_shader_parameter(&"swim_amp", 0.0)
	_gills = add_visual(MeshKit.merge(sacs), gill_mat)
	# The body is a tube rebuilt in world space every frame.
	_body = MeshInstance3D.new()
	_body.mesh = _body_mesh
	_body.material_override = mat
	_body.top_level = true
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_body)
	visuals.append(_body)


func think() -> void:
	var sub := level.player
	match state:
		State.DORMANT:
			if sub and sub.alive and _in_lair(sub.pos, 1.15):
				_awaken()
		State.PROWL:
			if _cooldown <= 0.0:
				var heard := heard_noise()
				if heard != Vector2.INF:
					_begin_aim(heard)


func behave(delta: float) -> void:
	_t += delta
	_timer -= delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_clank_cooldown = maxf(_clank_cooldown - delta, 0.0)
	match state:
		State.DORMANT:
			vel = Vector2.ZERO
		State.PROWL:
			_orbit += delta * (0.22 + phase * 0.06)
			var target := lair_center + Vector2(cos(_orbit) * lair_radius.x * 0.6, sin(_orbit) * lair_radius.y * 0.5)
			seek(target, PROWL_SPEED * (1.0 + phase * 0.2), 1.5, delta)
		State.AIM:
			vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
			facing = facing.slerp((_target - pos).normalized(), 1.0 - exp(-8.0 * delta)).normalized()
			if _timer <= 0.0:
				_lunge()
		State.LUNGE:
			vel = _lunge_dir * LUNGE_SPEED[phase]
			if _timer <= 0.0:
				# Missed everything: curl back round.
				_recover(-_lunge_dir)
		State.STUCK:
			vel = Vector2.ZERO
			if _timer <= 0.0:
				_recover(_wall_normal)
		State.RECOVER:
			vel = vel.lerp(_wall_normal * 6.0, 1.0 - exp(-3.0 * delta))
			if _timer <= 0.0:
				state = State.PROWL
				_cooldown = REST[phase]
		State.DEAD:
			vel = vel.lerp(Vector2(0.0, -1.5), 1.0 - exp(-1.0 * delta))
			model.scale = Vector3.ONE * maxf(_timer / 3.0, 0.01)
			if _timer <= 0.0:
				despawn()


func tick(delta: float) -> void:
	super.tick(delta)
	_follow_body()
	_rebuild_body()


## While stuck she does not move at all; during a lunge, rock stops her dead.
func move_and_collide_field(delta: float, bounce := 0.1) -> Vector2:
	if state == State.STUCK or state == State.DORMANT:
		return Vector2.ZERO
	var hit := super.move_and_collide_field(delta, bounce)
	if state == State.LUNGE and hit != Vector2.ZERO:
		_on_impact(hit)
	return hit


func on_touch_player(sub: Submarine) -> void:
	if state == State.DEAD or state == State.DORMANT:
		return
	if state == State.LUNGE:
		sub.take_damage(LUNGE_DAMAGE, pos, self)
		sub.vel += _lunge_dir * 9.0
	else:
		sub.take_damage(contact_damage, pos, self)


func take_damage(amount: float, from: Vector2, kind: StringName = &"") -> void:
	if state == State.DEAD:
		return
	if state == State.DORMANT:
		_awaken()
	if state != State.STUCK:
		amount *= ARMOR
		if _clank_cooldown <= 0.0:
			_clank_cooldown = 0.5
			Audio.play_at(&"harpoon_wall", pos, -2.0, 0.05, 0.6)
		if not _taught_armor and kind != &"vent":
			_taught_armor = true
			Events.toast.emit("Her hide turns the blow. Make her strike the rock, then hit her gills.", UiTheme.WARN)
	super.take_damage(amount, from, kind)
	var frac := hp / max_hp
	var want := 0 if frac > 0.66 else (1 if frac > 0.33 else 2)
	if alive and state != State.DEAD and want > phase:
		phase = want
		_enrage()


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	active = false
	targetable = false
	hostile = false
	_timer = 3.0
	Events.hitstop.emit(0.25)
	Events.shake_requested.emit(1.0)
	Fx.flash(level, pos, glow_color, 30.0, 0.8)
	Fx.ichor(level, pos, glow_color, 60)
	Fx.bubble_burst(level, pos, 60, 3.0)
	Audio.play_at(&"choir_death", pos, 0.0, 0.0, 0.7)
	Events.creature_killed.emit(species, pos)
	var sub := level.player
	if sub:
		sub.run.kills += 1
		sub.run.research += 15
		sub.show_gain(15, " research", UiTheme.ACCENT)
	Pickup.scatter(level, pos, &"salvage", salvage_drop, 3.0)
	Pickup.scatter(level, pos, &"repair", 2, 2.0)
	level.unseal_exit()
	Audio.play_music(level.biome.music, 3.0)
	Events.banner.emit("THE WAY DOWN IS OPEN", "The Blind Mother is silent.")
	defeated.emit()


func is_hostile() -> bool:
	return state != State.DORMANT and state != State.DEAD


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	var glow := 0.25
	match state:
		State.AIM:
			glow = 1.0
		State.STUCK:
			glow = 2.6 + 0.8 * sin(_t * 9.0)
	_gills.set_instance_shader_parameter(&"glow_boost", glow)


func _in_lair(p: Vector2, scale: float) -> bool:
	return ((p - lair_center) / (lair_radius * scale)).length_squared() < 1.0


func _awaken() -> void:
	if active:
		return
	active = true
	state = State.PROWL
	_cooldown = 1.5
	alert()
	Audio.play_at(&"stalker_roar", pos, 4.0, 0.03, 0.55)
	Audio.play_music(&"lair", 1.0)
	Events.shake_requested.emit(0.7)
	Events.banner.emit("THE BLIND MOTHER", "She hunts by sound alone. Make her strike the rock.")


func _begin_aim(target: Vector2) -> void:
	state = State.AIM
	_timer = AIM_TIME * (1.0 - phase * 0.15)
	_target = target
	Audio.play_at(&"lancer_windup", pos, 2.0, 0.03, 0.5)


func _lunge() -> void:
	state = State.LUNGE
	_timer = LUNGE_MAX
	_lunge_dir = (_target - pos).normalized() if _target.distance_to(pos) > 0.5 else facing
	facing = _lunge_dir
	Audio.play_at(&"lancer_dash", pos, 4.0, 0.03, 0.55)


func _on_impact(normal: Vector2) -> void:
	state = State.STUCK
	_timer = STUCK_TIME[phase]
	_wall_normal = normal
	vel = Vector2.ZERO
	Events.shake_requested.emit(0.8)
	Audio.play_at(&"impact_rock", pos, 6.0, 0.03, 0.5)
	Fx.sparks(level, pos - normal * radius)
	Fx.bubble_burst(level, pos, 30, 2.0)
	level.emit_noise(pos, 18.0, self)
	if not _taught_stuck:
		_taught_stuck = true
		Events.toast.emit("She's stuck in the rock - her gills are open!", UiTheme.GOOD)


func _recover(away: Vector2) -> void:
	state = State.RECOVER
	_timer = 0.9
	_wall_normal = away.normalized() if away.length_squared() > 0.01 else Vector2.UP


func _enrage() -> void:
	Audio.play_at(&"stalker_roar", pos, 4.0, 0.03, 0.5)
	Events.shake_requested.emit(0.6)
	# One lancer answers each of her roars.
	var p := level.layout.point_in_chamber(level.rng, LevelLayout.Chamber.new(lair_center, lair_radius, &"exit"), 2.0)
	var lancer: Creature = LevelPopulator.SPECIES[&"lancer"].new()
	lancer.pos = p
	level.add_entity(lancer)


## Each segment follows the one ahead like a rope, with a slow travelling wave.
func _follow_body() -> void:
	if state == State.DORMANT:
		return
	segments[0] = pos - facing * 1.6
	for i in range(1, SEGMENTS):
		var to := segments[i] - segments[i - 1]
		var d := to.length()
		if d > SPACING:
			segments[i] = segments[i - 1] + to / d * SPACING
		var p := segments[i]
		var push := level.field.sample(p)
		if push < 0.6:
			segments[i] = p + level.field.normal(p) * (0.6 - push)


func _rebuild_body() -> void:
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in SEGMENTS:
		var t := float(i) / (SEGMENTS - 1)
		var p := segments[i]
		if i > 0 and i < SEGMENTS - 1:
			var dir := (segments[i - 1] - segments[i + 1]).normalized()
			p += Vector2(-dir.y, dir.x) * sin(_t * 2.2 - i * 0.45) * 0.35 * t
		pts.append(Vector3(p.x, p.y, -0.2))
		radii.append(lerpf(1.35, 0.25, pow(t, 0.8)))
	MeshKit.tube(_body_mesh, pts, radii, 10, 0.6)
