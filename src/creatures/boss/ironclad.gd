class_name Ironclad
extends Guardian
## The Ironclad: a colossal armoured isopod that rules the hottest lair in the
## Abyssal Vents and seals the way down. It crawls the lair floor towards
## whatever it hears and rears up to crush anything that comes close. Its
## plates turn harpoons and torpedoes alike - but not the vents in its lair:
## caught in an eruption, the shell cracks open, glowing, for a few seconds.
## While it hunts a sound it pays the vents no mind; left to patrol, it waits
## for a rumbling vent to blow over before crossing it. Lure it across a vent
## as it erupts, then strike while it burns.

enum State { DORMANT, CRAWL, REAR, SLAM, SCALDED, DEAD }

## Model scale.
const SIZE := 1.7
## Height of the body centre above the floor.
const RIDE := 2.2
## Share of damage that gets through the shell unless the heat has cracked it.
const ARMOR := 0.08
## Share of a vent's own scald that gets through.
const VENT_ARMOR := 0.25
const REAR_TIME := 0.8
const SLAM_SPEED := 17.0
const SLAM_TIME := 0.55
const SLAM_DAMAGE := 28.0
const SLAM_RANGE := 9.0
const SCALD_TIME := 1.0
## Seconds it stands listening where a sound led it before patrolling on.
const LINGER := 3.5
## Per phase (thirds of its health): crawl speed, seconds the shell stays
## cracked, rest after a slam.
const CRAWL_SPEED: Array[float] = [3.5, 4.5, 5.5]
const OPEN_TIME: Array[float] = [4.5, 3.8, 3.2]
const REST: Array[float] = [1.4, 1.0, 0.7]

var state := State.DORMANT
var phase := 0
## Seconds left with the shell cracked open by heat.
var exposed := 0.0
## +1 when heading right.
var heading := 1.0
var _timer := 0.0
var _cooldown := 0.0
var _goal_x := 0.0
var _chasing := false
var _linger := 0.0
var _stride := 0.0
var _slam_dir := Vector2.UP
var _t := 0.0
var _clank_cooldown := 0.0
var _taught_armor := false
var _taught_heat := false
var _shrink := 1.0
var _legs: MeshInstance3D
var _shell: MeshInstance3D
## The lowest the body ever rides: just above the lair's lowest floor away
## from the fissure, so it bridges the drop instead of climbing down into it.
var _lowest := -INF


func setup() -> void:
	species = &"ironclad"
	title = "THE IRONCLAD"
	max_hp = 360.0
	radius = 2.0
	mass = 80.0
	contact_damage = 12.0
	salvage_drop = 75
	glow_color = Color(1.0, 0.45, 0.12)
	hearing = 2.0
	ambushable = false
	super.setup()
	active_radius = 1000.0
	lock_facing = true
	# On the lair floor, on whichever side of the fissure the floor is higher
	# (the flatter part of the bowl), facing the middle.
	var best := Vector2(lair_center.x, lair_center.y)
	for side: float in [-1.0, 1.0]:
		var x := lair_center.x + side * lair_radius.x * 0.5
		var fy := _floor_y(x, lair_center.y)
		if fy != -INF and (best.x == lair_center.x or fy + RIDE > best.y):
			best = Vector2(x, fy + RIDE)
	pos = level.field.resolve_circle(best, radius + 0.3)
	var lowest := INF
	for k in 13:
		var x := lair_center.x + (k / 6.0 - 1.0) * lair_radius.x * 0.85
		if absf(x - level.layout.exit.x) < 6.0:
			continue
		var fy := _floor_y(x, lair_center.y)
		if fy != -INF:
			lowest = minf(lowest, fy)
	_lowest = (lowest if lowest != INF else pos.y - RIDE) + RIDE - 0.5
	heading = -signf(pos.x - lair_center.x) if absf(pos.x - lair_center.x) > 0.5 else 1.0
	_goal_x = pos.x
	facing = Vector2(heading, 0.0)


func build_model() -> void:
	var mat := species_material(func(m: ShaderMaterial) -> void:
		m.set_shader_parameter(&"back_color", Color(0.2, 0.19, 0.2))
		m.set_shader_parameter(&"belly_color", Color(0.32, 0.26, 0.22))
		m.set_shader_parameter(&"glow_color", Color(1.0, 0.45, 0.12))
		m.set_shader_parameter(&"glow_strength", 1.2)
		m.set_shader_parameter(&"metallic", 0.55)
		m.set_shader_parameter(&"roughness", 0.4)
		m.set_shader_parameter(&"rim_strength", 0.45)
		m.set_shader_parameter(&"body_length", 4.2)
		m.set_shader_parameter(&"swim_amp", 0.0))
	# Eleven overlapping plates: ridges in the profile, molten seams between
	# them (the glow mask) that blaze when the heat cracks the shell.
	var profile := PackedVector2Array()
	for i in 45:
		var t := i / 44.0
		var plate := absf(sin(t * PI * 11.0))
		profile.append(Vector2(t, maxf(pow(sin(t * PI), 0.55) * 1.05 * (0.86 + 0.14 * plate), 0.08)))
	var shell := MeshKit.lathe(profile, 4.2, 18, 88, 0.62, 1.0, func(t: float, a: float) -> float:
		var seam := 1.0 - smoothstep(0.0, 0.3, absf(sin(t * PI * 11.0)))
		return seam if cos(a) > -0.3 and t > 0.06 and t < 0.94 else 0.0)
	# Tail fans and a pair of long, swept antennae.
	var uropod := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-0.9, 0.25), Vector2(-1.1, -0.05),
		Vector2(-0.4, -0.2)]), 0.06)
	var antenna := MeshKit.spike(0.05, 2.6, 0.0, 4)
	_shell = add_visual(MeshKit.merge([[shell],
		[uropod, Transform3D(Basis(Vector3.UP, 0.4), Vector3(-2.0, -0.1, 0.45))],
		[uropod, Transform3D(Basis(Vector3.UP, -0.4), Vector3(-2.0, -0.1, -0.45))],
		[antenna, Transform3D(Basis(Vector3.BACK, 0.35) * Basis(Vector3.UP, 0.35), Vector3(2.0, 0.1, 0.3))],
		[antenna, Transform3D(Basis(Vector3.BACK, 0.35) * Basis(Vector3.UP, -0.35), Vector3(2.0, 0.1, -0.3))]]), mat)
	var legs := []
	for i in 7:
		var x := -1.4 + i * 0.47
		for z: float in [-0.75, 0.75]:
			legs.append([MeshKit.spike(0.07, 0.9, 0.0, 4), Transform3D(Basis(Vector3.BACK, -PI * 0.5 - 0.35) *
				Basis(Vector3.UP, signf(z) * 0.5), Vector3(x, -0.35, z))])
	_legs = add_visual(MeshKit.merge(legs), mat)
	add_eyes(Vector3(1.85, 0.2, 0.42), 0.13, Color(0.05, 0.05, 0.06), 0.0)


func think() -> void:
	var sub := level.player
	match state:
		State.DORMANT:
			if sub and sub.alive and in_lair(sub.pos, 1.15):
				_awaken()
		State.CRAWL:
			if _cooldown <= 0.0 and sub and sub.alive and sub.pos.distance_to(pos) < SLAM_RANGE \
					and level.field.line_of_sight(pos, sub.pos):
				_rear(sub.pos)
				return
			var heard := _heard()
			if heard != Vector2.INF:
				_goal_x = clampf(heard.x, lair_center.x - lair_radius.x * 0.85, lair_center.x + lair_radius.x * 0.85)
				_chasing = true
			elif absf(_goal_x - pos.x) < 1.0:
				if _chasing:
					_chasing = false
					_linger = LINGER
				elif _linger <= 0.0:
					_goal_x = lair_center.x + level.rng.randf_range(-0.75, 0.75) * lair_radius.x


func behave(delta: float) -> void:
	_t += delta
	_timer -= delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_clank_cooldown = maxf(_clank_cooldown - delta, 0.0)
	exposed = maxf(exposed - delta, 0.0)
	_linger = maxf(_linger - delta, 0.0)
	match state:
		State.DORMANT:
			vel = Vector2.ZERO
		State.CRAWL:
			_crawl(delta)
		State.REAR:
			vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
			var sub := level.player
			if sub and sub.alive:
				_slam_dir = (sub.pos - pos).normalized()
			facing = facing.slerp(Vector2(heading, 0.0).lerp(_slam_dir, 0.6).normalized(), 1.0 - exp(-6.0 * delta))
			if _timer <= 0.0:
				_slam()
		State.SLAM:
			vel = _slam_dir * SLAM_SPEED
			if _timer <= 0.0:
				state = State.CRAWL
				_cooldown = REST[phase]
		State.SCALDED:
			vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
			if _timer <= 0.0:
				state = State.CRAWL
		State.DEAD:
			vel = vel.lerp(Vector2(0.0, -1.0), 1.0 - exp(-1.0 * delta))
			_shrink = maxf(_timer / 3.0, 0.01)
			if _timer <= 0.0:
				despawn()


## Walks along the floor towards the goal, holding its height above the rock
## (and bridging the fissure in the middle of the lair). Left to patrol, it
## waits for a rumbling vent ahead to blow over.
func _crawl(delta: float) -> void:
	var dx := _goal_x - pos.x
	if absf(dx) > 0.5:
		heading = signf(dx)
	var speed := CRAWL_SPEED[phase] * clampf(absf(dx) / 2.0, 0.0, 1.0)
	if not _chasing and _vent_ahead():
		speed = 0.0
	if level.field.sample(pos + Vector2(heading * 3.4, 0.0)) < 1.0:
		speed = 0.0
		_goal_x = pos.x
	var fy := _floor_y(pos.x + heading * 1.5, pos.y)
	var want_y := maxf(fy + RIDE if fy != -INF and fy > pos.y - RIDE - 3.0 else pos.y, _lowest)
	vel.x = lerpf(vel.x, heading * speed, 1.0 - exp(-4.0 * delta))
	vel.y = lerpf(vel.y, clampf((want_y - pos.y) * 4.0, -8.0, 8.0), 1.0 - exp(-6.0 * delta))
	# Every stride shakes the floor; heard (and felt) across the lair.
	_stride += absf(vel.x) * delta
	if _stride > 2.2:
		_stride = 0.0
		Audio.play_at(&"plate_step", pos + Vector2(0.0, -RIDE), -4.0, 0.08)
	var slope := clampf((want_y - pos.y) * 0.25, -0.35, 0.35)
	facing = facing.slerp(Vector2(heading, slope * heading).normalized(), 1.0 - exp(-5.0 * delta)).normalized()


## The loudest recent noise it can hear, or INF. The vents' roar is the
## sound of its own lair: it never goes looking for an eruption.
func _heard() -> Vector2:
	var best := Vector2.INF
	var best_margin := 0.0
	for n in level.noises:
		# A noise can outlive whatever made it.
		if n.source == self or is_instance_valid(n.source) and n.source is ThermalVent:
			continue
		var margin: float = n.radius * hearing - pos.distance_to(n.pos)
		if margin > best_margin:
			best_margin = margin
			best = n.pos
	return best


func _vent_ahead() -> bool:
	for e in level.entities:
		var v := e as ThermalVent
		if v and v.state != ThermalVent.State.DORMANT:
			var dx := v.pos.x - pos.x
			if signf(dx) == heading and absf(dx) < 5.0 and absf(v.pos.y - pos.y) < 6.0:
				return true
	return false


## The floor's height at [param x] below [param above] (plus a little), or
## -INF over the fissure.
func _floor_y(x: float, above: float) -> float:
	return MeridianStation.floor_below(level.field, Vector2(x, above + 2.0), lair_radius.y * 1.6)


func on_touch_player(sub: Submarine) -> void:
	if state == State.DEAD or state == State.DORMANT:
		return
	if state == State.SLAM:
		sub.take_damage(SLAM_DAMAGE, pos, self)
		sub.vel += _slam_dir * 10.0
		state = State.CRAWL
		_cooldown = REST[phase]
	else:
		sub.take_damage(contact_damage, pos, self)


func take_damage(amount: float, from: Vector2, kind: StringName = &"") -> void:
	if state == State.DEAD:
		return
	if state == State.DORMANT:
		_awaken()
	if kind == &"vent":
		amount *= VENT_ARMOR
		_crack()
	elif exposed <= 0.0:
		amount *= ARMOR
		if _clank_cooldown <= 0.0:
			_clank_cooldown = 0.5
			Audio.play_at(&"harpoon_wall", pos, -2.0, 0.05, 0.5)
		if not _taught_armor:
			_taught_armor = true
			Events.toast.emit("Its plates turn the blow. Lure it into a vent's eruption to crack the shell.",
				UiTheme.WARN)
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
	_timer = 3.0
	reward_defeat("The Ironclad's shell has gone cold.")


func is_hostile() -> bool:
	return state != State.DORMANT and state != State.DEAD


## A vent's heat splits the plates open.
func _crack() -> void:
	var fresh := exposed <= 0.0
	exposed = OPEN_TIME[phase]
	if fresh:
		state = State.SCALDED
		_timer = SCALD_TIME
		Audio.play_at(&"rock_shatter", pos, 2.0, 0.05, 0.7)
		Fx.sparks(level, pos + Vector2(0.0, 1.5))
		Events.shake_requested.emit(0.4)
		if not _taught_heat:
			_taught_heat = true
			Events.toast.emit("The heat cracked its shell - strike now!", UiTheme.GOOD)


func _update_visuals(delta: float) -> void:
	super._update_visuals(delta)
	model.basis = model.basis.scaled(Vector3.ONE * SIZE * _shrink)
	var glow := 0.4 + 0.15 * sin(_t * 1.5)
	if exposed > 0.0:
		glow = 3.2 + 0.9 * sin(_t * 11.0)
	elif state == State.REAR:
		glow = 1.4
	_shell.set_instance_shader_parameter(&"glow_boost", glow)
	# Legs paddle while it walks.
	var stride := clampf(absf(vel.x) / 3.0, 0.0, 1.0)
	_legs.rotation.z = sin(_t * 9.0) * 0.18 * stride


func _awaken() -> void:
	if active:
		return
	state = State.CRAWL
	_cooldown = 1.5
	wake("Its plates turn everything. The vents do not.", 0.45, &"furnace")


func _rear(at: Vector2) -> void:
	state = State.REAR
	_timer = REAR_TIME * (1.0 - phase * 0.15)
	_slam_dir = (at - pos).normalized()
	alert()
	Audio.play_at(&"lancer_windup", pos, 3.0, 0.03, 0.45)


func _slam() -> void:
	state = State.SLAM
	_timer = SLAM_TIME
	Audio.play_at(&"lancer_dash", pos, 4.0, 0.03, 0.5)
	level.emit_noise(pos, 14.0, self)


func _enrage() -> void:
	Audio.play_at(&"stalker_roar", pos, 4.0, 0.03, 0.45)
	Events.shake_requested.emit(0.6)
	# Its brood spills out from under the plates.
	for side: float in [-1.0, 1.0]:
		var p := level.field.resolve_circle(pos + Vector2(side * 2.5, -0.8), 0.6)
		var brood: Creature = LevelPopulator.SPECIES[&"isopod"].new()
		brood.pos = p
		brood.set(&"wall_normal", Vector2.UP)
		level.add_entity(brood)
