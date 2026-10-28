class_name Submarine
extends Node3D
## The player's submersible: inertial movement with terrain collision, aiming,
## the lamp, sonar, creature scanning, battery and hull.

signal died

const RADIUS := 1.15
const COLLISION_DAMAGE_SPEED := 7.5
const SCAN_TIME := 1.6
## Trickle charge (per second) with the lamp off, up to this share of capacity.
const EMERGENCY_CHARGE_RATE := 0.8
const EMERGENCY_CHARGE_CAP := 0.15

var level: Level
var run: RunState
var stats: SubStats

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var aim := Vector2.RIGHT
var facing := 1.0
var lamp_on := true
var boosting := false
var alive := true
var input_enabled := true
## When set (not INF), overrides player movement input (autopilot, cutscenes).
var external_move := Vector2.INF
## Current continuous noise radius in meters (shown on the HUD).
var noise_radius := 0.0
var sonar_cooldown := 0.0
## Creature currently being scanned by the lamp and its progress (0..1).
var scan_target: Creature
var scan_progress := 0.0

var model: SubmarineModel
var lamp: SpotLight3D
var fill_light: OmniLight3D
var harpoon: Harpoon
var tools: ToolBelt
var bubbles: GPUParticles3D
var engine_audio: AudioStreamPlayer
var leak: GPUParticles3D
var beam: MeshInstance3D
var _beam_mesh: CylinderMesh

var _yaw := 0.0
var _invulnerable := 0.0
var _since_damage := 99.0
var _noise_timer := 0.0
var _scan_timer := 0.0
var _scanned_this_run: Dictionary[StringName, bool] = {}
var _thrust_amount := 0.0
var _low_battery_warned := false
var _time := 0.0
var _camera: Camera3D
var _alarm_timer := 0.0
var _creak_timer := 12.0


func setup(p_level: Level, p_run: RunState, start: Vector2) -> void:
	level = p_level
	run = p_run
	stats = run.stats
	pos = start
	position = Vector3(pos.x, pos.y, 0)

	model = SubmarineModel.new()
	add_child(model)
	model.build(run.frame_id, Game.hull_color(run.frame_id))

	lamp = SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.95, 0.82)
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.05
	lamp.light_volumetric_fog_energy = 5.0
	lamp.spot_attenuation = 0.6
	lamp.spot_angle_attenuation = 1.6
	add_child(lamp)

	# Visible cone of scattered light. A child of the lamp so it follows its aim.
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.top_radius = 0.15
	_beam_mesh.radial_segments = 20
	_beam_mesh.rings = 1
	_beam_mesh.cap_top = false
	_beam_mesh.cap_bottom = false
	beam = MeshInstance3D.new()
	beam.mesh = _beam_mesh
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = preload("res://src/fx/shaders/lamp_beam.gdshader")
	beam_mat.set_shader_parameter(&"noise_tex", TerrainRenderer.detail_noise())
	beam.material_override = beam_mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(beam)
	var lens := MeshInstance3D.new()
	lens.mesh = MeshKit.sphere(0.13, 10, 6)
	lens.material_override = MeshKit.emissive_material(Color(1.0, 0.95, 0.8), 7.0)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(lens)

	fill_light = OmniLight3D.new()
	fill_light.light_color = Color(0.6, 0.85, 1.0)
	fill_light.omni_range = 11.0
	fill_light.light_energy = 0.55
	fill_light.omni_attenuation = 1.4
	fill_light.light_volumetric_fog_energy = 0.0
	fill_light.position = Vector3(0, 0, 3.0)
	add_child(fill_light)

	bubbles = Fx.bubble_emitter()
	bubbles.position = Vector3(-2.2, 0, 0)
	model.add_child(bubbles)
	# A damaged hull leaks a stream of bubbles from the tower.
	leak = Fx.bubble_emitter()
	leak.position = Vector3(-0.2, 0.9, 0.2)
	leak.emitting = false
	model.add_child(leak)

	engine_audio = AudioStreamPlayer.new()
	engine_audio.bus = &"SFX"
	var engine_stream := Audio.get_stream(&"engine_loop")
	if engine_stream is AudioStreamOggVorbis:
		(engine_stream as AudioStreamOggVorbis).loop = true
	engine_audio.stream = engine_stream
	engine_audio.volume_db = -30.0
	add_child(engine_audio)
	if engine_stream:
		engine_audio.play()

	harpoon = Harpoon.new()
	add_child(harpoon)
	harpoon.setup(self)
	tools = ToolBelt.new()
	add_child(tools)
	tools.setup(self)
	_apply_lamp_stats()


func refresh_stats() -> void:
	stats = run.stats
	_apply_lamp_stats()


func _apply_lamp_stats() -> void:
	lamp.spot_range = stats.lamp_range
	lamp.spot_angle = stats.lamp_angle
	lamp.light_energy = stats.lamp_energy
	# The cone points down the lamp's -Z axis; the cylinder's narrow top sits at the lamp.
	var length := stats.lamp_range * 0.75
	_beam_mesh.height = length
	_beam_mesh.bottom_radius = tan(deg_to_rad(stats.lamp_angle * 0.8)) * length
	beam.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -length * 0.5))


func set_camera(cam: Camera3D) -> void:
	_camera = cam


func tick(delta: float) -> void:
	_time += delta
	if not alive:
		vel = vel.lerp(Vector2(0, -1.5), 1.0 - exp(-1.0 * delta))
		_move(delta)
		position = Vector3(pos.x, pos.y, 0)
		return
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_since_damage += delta
	sonar_cooldown = maxf(sonar_cooldown - delta, 0.0)

	var move := Vector2.ZERO
	if input_enabled:
		move = Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
		_update_aim()
		_handle_actions()
	elif external_move != Vector2.INF:
		move = external_move
	_update_battery(delta, move)
	_update_movement(delta, move)
	_update_noise(delta)
	_update_scan(delta)
	_update_visuals(delta, move)
	harpoon.tick(delta)
	tools.tick(delta)

	_update_hull_feedback(delta)
	if stats.regen > 0.0 and _since_damage > 4.0 and run.hull < stats.max_hull:
		run.hull = minf(run.hull + stats.regen * delta, stats.max_hull)
	run.deepest_depth = maxi(run.deepest_depth, int(level.depth_at(pos.y)))


func _update_aim() -> void:
	if Settings.using_gamepad:
		var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_down", &"aim_up")
		if stick.length() > 0.3:
			aim = stick.normalized()
		else:
			var move := Input.get_vector(&"move_left", &"move_right", &"move_down", &"move_up")
			if move.length() > 0.3:
				aim = aim.slerp(move.normalized(), 0.15)
	elif _camera:
		var mouse := get_viewport().get_mouse_position()
		var origin := _camera.project_ray_origin(mouse)
		var dir := _camera.project_ray_normal(mouse)
		if absf(dir.z) > 0.0001:
			var t := -origin.z / dir.z
			var hit := origin + dir * t
			var to := Vector2(hit.x, hit.y) - pos
			if to.length() > 0.5:
				aim = to.normalized()
	if aim.x > 0.2:
		facing = 1.0
	elif aim.x < -0.2:
		facing = -1.0


func _handle_actions() -> void:
	if Input.is_action_just_pressed(&"lamp"):
		lamp_on = not lamp_on
		Audio.play(&"lamp_toggle", -6.0)
	if Input.is_action_just_pressed(&"ping"):
		try_ping()
	if Input.is_action_just_pressed(&"fire"):
		harpoon.fire(aim)
	if Input.is_action_just_released(&"fire"):
		harpoon.release()
	if Input.is_action_just_pressed(&"tool"):
		tools.use(aim)
	if Input.is_action_just_pressed(&"cycle_tool"):
		tools.cycle()


func try_ping() -> bool:
	if sonar_cooldown > 0.0:
		return false
	if run.battery < stats.sonar_cost:
		Audio.play(&"denied", -4.0)
		Events.toast.emit("Battery too low for sonar", Color(1.0, 0.5, 0.3))
		return false
	run.battery -= stats.sonar_cost
	sonar_cooldown = stats.sonar_cooldown
	level.ping(pos, stats.sonar_range, stats.sonar_mark_time)
	level.emit_noise(pos, stats.sonar_range * 0.5, self)
	Audio.play(&"sonar_ping", -2.0)
	if stats.sonar_stun:
		for e in level.targets_in_radius(pos, 14.0):
			if e is Creature:
				(e as Creature).stun(2.0)
	return true


func _update_battery(delta: float, move: Vector2) -> void:
	var drain_mult := Pressure.battery_drain(run.pressure)
	boosting = input_enabled and Input.is_action_pressed(&"boost") and move.length() > 0.1 and run.battery > 0.5
	var drain := 0.0
	if lamp_on:
		drain += stats.lamp_drain
	if boosting:
		drain += stats.boost_drain
	run.battery = maxf(run.battery - drain * drain_mult * delta, 0.0)
	# Emergency cells: running dark slowly restores enough charge for the odd
	# ping, so an empty battery is never a dead end.
	if drain == 0.0 and run.battery < stats.max_battery * EMERGENCY_CHARGE_CAP:
		run.battery = minf(run.battery + EMERGENCY_CHARGE_RATE * delta, stats.max_battery * EMERGENCY_CHARGE_CAP)
	if run.battery <= 0.0:
		if lamp_on:
			lamp_on = false
			Events.toast.emit("Battery depleted - lamp offline. Emergency cells recharge while running dark.",
					Color(1.0, 0.4, 0.3))
			Audio.play(&"power_down")
		boosting = false
	var low := run.battery < stats.max_battery * 0.2
	if low and not _low_battery_warned:
		_low_battery_warned = true
		Events.toast.emit("Battery low - find glow bulbs", Color(1.0, 0.8, 0.3))
		Audio.play(&"warning", -6.0)
	elif not low:
		_low_battery_warned = false


func _update_movement(delta: float, move: Vector2) -> void:
	var speed := stats.max_speed * (stats.boost_mult if boosting else 1.0)
	if run.battery <= 0.0:
		speed *= 0.7
	if move.length_squared() > 0.0001:
		var target := move.limit_length(1.0) * speed
		var k := stats.thrust / stats.max_speed
		vel = vel.lerp(target, 1.0 - exp(-k * delta))
	else:
		vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-stats.drag * delta))
	# Gentle neutral-buoyancy drift so the sub never feels frozen.
	vel.y += sin(_time * 0.9) * 0.15 * delta
	vel += level.current_at(pos) * delta * 1.1
	_thrust_amount = move.length()
	var impact := _move(delta)
	if impact > COLLISION_DAMAGE_SPEED:
		var dmg := (impact - COLLISION_DAMAGE_SPEED) * 3.0
		take_damage(dmg, pos - vel.normalized(), null, false)
		Audio.play_at(&"impact_rock", pos, 0.0)
		Fx.sparks(level, pos - level.field.normal(pos) * RADIUS)
	elif impact > 3.0:
		Audio.play_at(&"scrape", pos, -8.0)


## Moves with terrain collision. Returns the strongest impact speed.
func _move(delta: float) -> float:
	var field := level.field
	var motion := vel * delta
	var steps := maxi(1, ceili(motion.length() / 0.4))
	var impact := 0.0
	for _i in steps:
		pos += motion / steps
		var d := field.sample(pos)
		if d < RADIUS:
			var n := field.normal(pos)
			pos += n * (RADIUS - d)
			var vn := vel.dot(n)
			if vn < 0.0:
				impact = maxf(impact, -vn)
				vel -= n * vn * 1.25
				vel *= 0.92
	# Invisible ceiling above the entry shaft.
	if pos.y > -RADIUS:
		pos.y = -RADIUS
		vel.y = minf(vel.y, 0.0)
	return impact


func _update_noise(delta: float) -> void:
	var speed_frac := vel.length() / maxf(stats.max_speed, 0.1)
	noise_radius = (speed_frac * 13.0 + (14.0 if boosting else 0.0)) * stats.noise_mult
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = 0.2
		level.emit_noise(pos, noise_radius, self)


## True if the lamp is on and lights up point [param p].
func illuminates(p: Vector2, margin := 0.0) -> bool:
	if not lamp_on or not alive:
		return false
	var to := p - pos
	var dist := to.length()
	if dist > stats.lamp_range + margin:
		return false
	if dist > 1.5 and absf(rad_to_deg(aim.angle_to(to))) > stats.lamp_angle + 4.0:
		return false
	return level.field.line_of_sight(pos, p)


func _update_scan(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.15
		var best: Creature = null
		var best_d := INF
		if lamp_on:
			for e in level.entities:
				var c := e as Creature
				if c == null or not c.alive or not c.scannable or _scanned_this_run.has(c.species):
					continue
				if c.pos.distance_squared_to(pos) > stats.lamp_range * stats.lamp_range:
					continue
				var d := pos.distance_to(c.pos)
				if d < best_d and illuminates(c.pos, c.radius):
					best = c
					best_d = d
		if best != scan_target:
			scan_target = best
			scan_progress = 0.0
	if scan_target and is_instance_valid(scan_target) and scan_target.alive:
		scan_progress += delta * stats.scan_speed / SCAN_TIME
		if scan_progress >= 1.0:
			_complete_scan(scan_target)
	else:
		scan_target = null
		scan_progress = 0.0


func _complete_scan(c: Creature) -> void:
	_scanned_this_run[c.species] = true
	var first := Game.meta.record_scan(c.species)
	run.scans += 1
	run.research += 10 if first else 3
	scan_target = null
	scan_progress = 0.0
	Audio.play(&"scan_complete", -3.0)
	Events.creature_scanned.emit(c.species, first)


func _update_visuals(delta: float, move: Vector2) -> void:
	var target_yaw := 0.0 if facing > 0.0 else -PI
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-7.0 * delta))
	# Euler order is YXZ, so the local Z pitch raises the nose for either facing.
	var pitch := clampf(vel.y * 0.05, -0.4, 0.4)
	model.rotation = Vector3(sin(_time * 0.7) * 0.03, _yaw, lerp_angle(model.rotation.z, pitch, 1.0 - exp(-4.0 * delta)))
	model.position.y = sin(_time * 1.3) * 0.06
	model.animate(delta, move.length() * (1.6 if boosting else 1.0))
	bubbles.emitting = move.length() > 0.2
	bubbles.amount_ratio = 1.0 if boosting else 0.5
	var speed_frac := clampf(vel.length() / (stats.max_speed * stats.boost_mult), 0.0, 1.0)
	engine_audio.volume_db = lerpf(engine_audio.volume_db,
			linear_to_db(0.08 + _thrust_amount * 0.35 + (0.2 if boosting else 0.0)), 1.0 - exp(-5.0 * delta))
	engine_audio.pitch_scale = 0.75 + speed_frac * 0.6

	lamp.visible = lamp_on
	# The lamp is a child of the (unrotated) submarine root, so local == world orientation.
	var lamp_offset := Vector3(aim.x * 1.1, aim.y * 1.1 - 0.3, 0.0)
	lamp.transform = Transform3D(Basis.looking_at(Vector3(aim.x, aim.y, 0.0), Vector3.BACK), lamp_offset)
	model.set_cockpit_glow(0.9 if run.battery > 0.0 else 0.15)
	position = Vector3(pos.x, pos.y, 0)


func take_damage(amount: float, from: Vector2, source: Node = null, knockback := true) -> void:
	if not alive or _invulnerable > 0.0:
		return
	if source is Creature:
		amount *= Pressure.creature_damage(run.pressure)
	amount *= Settings.damage_taken_mult()
	run.hull -= amount
	Settings.rumble_pulse(amount / 25.0, 0.25)
	_invulnerable = 0.35
	_since_damage = 0.0
	if knockback:
		vel += (pos - from).normalized() * clampf(amount * 0.5, 3.0, 12.0)
	Events.shake_requested.emit(clampf(amount / 30.0, 0.25, 1.0))
	Events.player_damaged.emit(amount)
	Audio.play(&"hull_hit", -2.0, randf_range(0.9, 1.1))
	if stats.ink_cloud and source != null:
		Fx.ink_cloud(level, pos)
		for e in level.targets_in_radius(pos, 10.0):
			if e is Creature:
				(e as Creature).blind(3.0)
	if run.hull <= 0.0:
		run.hull = 0.0
		_die()


## Leaks, alarms and the groan of the hull under pressure.
func _update_hull_feedback(delta: float) -> void:
	var frac := run.hull / maxf(stats.max_hull, 1.0)
	leak.emitting = frac < 0.4
	leak.amount_ratio = clampf(1.0 - frac * 2.0, 0.3, 1.0)
	Audio.set_muffle(clampf((0.3 - frac) / 0.3, 0.0, 0.6))
	_alarm_timer -= delta
	if frac < 0.25 and _alarm_timer <= 0.0:
		_alarm_timer = 2.5
		Audio.play(&"warning", -10.0)
	_creak_timer -= delta
	if _creak_timer <= 0.0:
		var depth_frac := clampf(level.depth_at(pos.y) / 11000.0, 0.0, 1.0)
		_creak_timer = randf_range(18.0, 32.0) * (1.0 - depth_frac * 0.5)
		Audio.play(&"creak", -14.0 + depth_frac * 6.0, randf_range(0.8, 1.1))


## Continuous damage without hit feedback (parasites, hazards).
func drain(hull_amount: float, battery_amount: float) -> void:
	if not alive:
		return
	run.battery = maxf(run.battery - battery_amount, 0.0)
	run.hull -= hull_amount * Settings.damage_taken_mult()
	_since_damage = 0.0
	if run.hull <= 0.0:
		run.hull = 0.0
		_die()


func heal(amount: float) -> void:
	run.hull = minf(run.hull + amount, stats.max_hull)


func add_battery(amount: float) -> void:
	run.battery = minf(run.battery + amount, stats.max_battery)


func _die() -> void:
	alive = false
	engine_audio.stop()
	lamp_on = false
	lamp.visible = false
	harpoon.release()
	bubbles.emitting = false
	Audio.play(&"implosion", 0.0)
	Events.shake_requested.emit(1.0)
	Fx.implosion(level, pos)
	var tween := create_tween()
	tween.tween_property(model, ^"scale", Vector3(0.85, 0.6, 0.8), 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(1.8)
	tween.tween_callback(func() -> void: died.emit())
