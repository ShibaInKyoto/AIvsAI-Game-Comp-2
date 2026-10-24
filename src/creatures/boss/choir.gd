class_name ChoirBoss
extends Entity
## The Choir: a colossal singer at the bottom of the trench.
##
## It sings in expanding waves. A wave that reaches the submarine hurts,
## unless the pilot answers it with a sonar ping as it arrives. Each answer
## leaves the four voice organs open for a moment; destroy all four to end
## the song. Every organ lost makes the song faster and denser.

signal defeated

const ANSWER_EARLY := 0.5
const ANSWER_LATE := 0.32
const OPEN_TIME := 4.5
const WAVE_DAMAGE := 14.0
const RING_SHADER := preload("res://src/fx/shaders/song_ring.gdshader")
## Per phase (organs destroyed): seconds between waves, wave speed, chance of a double wave.
const INTERVAL: Array[float] = [3.6, 3.2, 2.8, 2.5]
const SPEED: Array[float] = [13.0, 14.5, 16.0, 17.5]
const DOUBLE: Array[float] = [0.0, 0.25, 0.4, 0.55]

var center := Vector2.ZERO
var arena_radius := 30.0
var organs: Array[ChoirOrgan] = []
var phase := 0
var active := false
## Seconds the organs stay open after an answered wave.
var vulnerable := 0.0

## Each wave: {radius, speed, resolved, arrived, deadline, mesh, mat}
var _waves: Array[Dictionary] = []
var _pulse_timer := 2.5
var _queued_double := -1.0
var _last_ping := -100.0
var _done := false
var _t := 0.0
var _answer_streak := 0
var _heart: MeshInstance3D
var _heart_mat: ShaderMaterial
var _light: OmniLight3D
var _tentacles: Array[ArrayMesh] = []
var _tentacle_dirs: Array[Vector2] = []
var _hinted := false
var _beat := 0.0


func setup() -> void:
	radius = 0.0
	active_radius = 1000.0
	targetable = false
	pos = center + Vector2(0, 4.0)
	_build_heart()
	_spawn_organs()
	Events.sonar_pinged.connect(_on_ping)


func _build_heart() -> void:
	_heart_mat = ShaderMaterial.new()
	_heart_mat.shader = Creature.SHADER
	_heart_mat.set_shader_parameter(&"back_color", Color(0.18, 0.06, 0.22))
	_heart_mat.set_shader_parameter(&"belly_color", Color(0.3, 0.12, 0.35))
	_heart_mat.set_shader_parameter(&"glow_color", Color(1.0, 0.3, 0.85))
	_heart_mat.set_shader_parameter(&"glow_strength", 4.5)
	_heart_mat.set_shader_parameter(&"glow_pulse", 0.6)
	_heart_mat.set_shader_parameter(&"rim_strength", 0.8)
	_heart_mat.set_shader_parameter(&"swim_amp", 0.0)
	var heart_mesh := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.5), Vector2(0.2, 4.0), Vector2(0.5, 5.5), Vector2(0.8, 4.5), Vector2(1.0, 1.0)]),
		13.0, 28, 22, 1.15, 1.15, func(t: float, a: float) -> float:
			var veins := 1.0 - smoothstep(0.0, 0.12, absf(sin(a * 5.0 + t * 9.0)))
			return clampf(veins * 0.9 + (0.6 if t > 0.92 else 0.0), 0.0, 1.0))
	_heart = MeshInstance3D.new()
	_heart.mesh = heart_mesh
	_heart.material_override = _heart_mat
	_heart.rotation.z = PI * 0.5
	_heart.position = Vector3(0, 0, -9.0)
	_heart.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_heart)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.35, 0.85)
	_light.omni_range = 55.0
	_light.light_energy = 1.2
	_light.light_volumetric_fog_energy = 2.0
	_light.omni_attenuation = 0.8
	_light.position = Vector3(0, 0, -2.0)
	add_child(_light)
	var tentacle_mat := ShaderMaterial.new()
	tentacle_mat.shader = Creature.SHADER
	tentacle_mat.set_shader_parameter(&"back_color", Color(0.1, 0.04, 0.13))
	tentacle_mat.set_shader_parameter(&"belly_color", Color(0.2, 0.08, 0.24))
	tentacle_mat.set_shader_parameter(&"glow_color", Color(1.0, 0.35, 0.9))
	tentacle_mat.set_shader_parameter(&"glow_strength", 1.6)
	tentacle_mat.set_shader_parameter(&"glow_pulse", 0.8)
	tentacle_mat.set_shader_parameter(&"rim_strength", 0.5)
	tentacle_mat.set_shader_parameter(&"swim_amp", 0.0)
	for i in 7:
		var mesh := ArrayMesh.new()
		_tentacles.append(mesh)
		var a := PI + PI * (i + 0.5) / 7.0
		_tentacle_dirs.append(Vector2(cos(a), sin(a)))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = tentacle_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)


func _spawn_organs() -> void:
	var angles: Array[float] = [160.0, 20.0, 215.0, 325.0]
	for deg in angles:
		var dir := Vector2.from_angle(deg_to_rad(deg))
		var p := center + Vector2(dir.x * arena_radius, dir.y * arena_radius * 0.75) * 0.55
		# Walk outwards until close to the arena wall.
		for _i in 40:
			if level.field.sample(p + dir * 1.0) < 4.0:
				break
			p += dir * 1.0
		var organ := ChoirOrgan.new()
		organ.boss = self
		organ.pos = p
		level.add_entity(organ)
		organs.append(organ)


func tick(delta: float) -> void:
	_t += delta
	vulnerable = maxf(vulnerable - delta, 0.0)
	_animate(delta)
	if _done:
		_update_waves(delta)
		return
	var sub := level.player
	if not active:
		if sub and sub.alive and sub.pos.distance_to(center) < arena_radius * 0.95:
			_begin()
		return
	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		var p := mini(phase, INTERVAL.size() - 1)
		_pulse_timer = INTERVAL[p]
		_emit_wave(SPEED[p])
		if level.rng.randf() < DOUBLE[p]:
			_queued_double = 1.05
	if _queued_double > 0.0:
		_queued_double -= delta
		if _queued_double <= 0.0:
			_emit_wave(SPEED[mini(phase, SPEED.size() - 1)])
	_update_waves(delta)


func _begin() -> void:
	active = true
	Audio.play_music(&"boss", 1.5)
	Audio.play(&"choir_call", 2.0)
	Events.banner.emit("THE CHOIR", "Answer it.  Keep answering.")
	Events.shake_requested.emit(0.6)
	# The Choir's resonance supercharges the sonar for the duration.
	var stats := level.player.stats
	stats.sonar_cooldown = minf(stats.sonar_cooldown, 0.75)
	stats.sonar_cost = minf(stats.sonar_cost, 2.0)
	# Short-range answers keep the screen readable at this ping rate.
	stats.sonar_range = minf(stats.sonar_range, 38.0)
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		Events.toast.emit("Ping as each song wave reaches you to answer it.", UiTheme.ACCENT)
		Events.toast.emit("Answered waves open its voice organs - strike them.", UiTheme.ACCENT))


func _emit_wave(speed: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mi.mesh = quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	add_child(mi)
	mi.global_position = Vector3(pos.x, pos.y, 0.4)
	mi.scale = Vector3.ONE * 0.5
	_waves.append({"radius": 0.5, "speed": speed, "resolved": false, "arrived": 0.0, "deadline": -1.0, "mesh": mi, "mat": mat})
	_beat = 1.0
	Audio.play(&"choir_wave", -1.0, randf_range(0.9, 1.1))
	level.emit_noise(pos, 20.0, self)


func _update_waves(delta: float) -> void:
	var sub := level.player
	var now := level.time
	for w in _waves.duplicate():
		w.radius += w.speed * delta
		var mi: MeshInstance3D = w.mesh
		mi.scale = Vector3.ONE * w.radius
		var fade := clampf(1.0 - (w.radius - arena_radius) / 25.0, 0.0, 1.0)
		(w.mat as ShaderMaterial).set_shader_parameter(&"intensity", 2.2 * fade)
		if not w.resolved and sub and sub.alive and not _done:
			if w.deadline < 0.0 and w.radius >= sub.pos.distance_to(pos):
				# The wave arrives: a ping just before it counts as an answer...
				if now - _last_ping <= ANSWER_EARLY:
					_answer(w)
				else:
					w.arrived = now
					w.deadline = now + ANSWER_LATE
			elif w.deadline >= 0.0:
				# ...and so does one shortly after.
				if _last_ping >= w.arrived:
					_answer(w)
				elif now > w.deadline:
					_miss(w)
		if fade <= 0.0:
			mi.queue_free()
			_waves.erase(w)


func _on_ping(origin: Vector2, _range: float) -> void:
	if level.player and origin.distance_to(level.player.pos) < 1.0:
		_last_ping = level.time


func _answer(w: Dictionary) -> void:
	w.resolved = true
	(w.mat as ShaderMaterial).set_shader_parameter(&"ring_color", Color(0.5, 1.0, 1.0))
	vulnerable = OPEN_TIME
	_answer_streak += 1
	Audio.play(&"choir_answer", 0.0, 1.0 + minf(_answer_streak, 6) * 0.04)
	Fx.shockwave(level, level.player.pos, 4.0, Color(0.3, 0.7, 0.7))
	if not _hinted:
		_hinted = true
		Events.toast.emit("Answered! Its organs are open - harpoon them!", UiTheme.GOOD)


func _miss(w: Dictionary) -> void:
	w.resolved = true
	_answer_streak = 0
	var sub := level.player
	sub.take_damage(WAVE_DAMAGE, pos, null)
	sub.run.battery = maxf(sub.run.battery - 6.0, 0.0)
	sub.vel += (sub.pos - pos).normalized() * 7.0


## Predicted seconds until the next unresolved wave reaches [param p]
## (negative inside the late-answer window), or INF if none is coming.
func next_arrival(p: Vector2) -> float:
	var d := p.distance_to(pos)
	var best := INF
	for w in _waves:
		if w.resolved:
			continue
		if w.deadline >= 0.0:
			best = minf(best, w.arrived - level.time)
		elif w.radius < d:
			best = minf(best, (d - w.radius) / w.speed)
	return best


func on_organ_destroyed(organ: ChoirOrgan) -> void:
	organs.erase(organ)
	phase += 1
	Audio.play(&"choir_call", 3.0, 0.9 + phase * 0.05)
	if organs.is_empty():
		_defeat()
		return
	var remaining := organs.size()
	Events.toast.emit("The song falters... %d voice%s remain." % [remaining, "" if remaining == 1 else "s"], UiTheme.ACCENT)
	_summon(phase)


func _summon(p: int) -> void:
	var count := 1 + p
	for i in count:
		var c: Creature = Lancer.new() if i % 2 == 0 else Jelly.new()
		var a := level.rng.randf() * TAU
		c.pos = level.field.resolve_circle(center + Vector2(cos(a), sin(a) * 0.6) * arena_radius * 0.6, 1.0)
		level.add_entity(c)


func _defeat() -> void:
	_done = true
	active = false
	vulnerable = 0.0
	Audio.stop_music(2.0)
	Audio.play(&"choir_death", 4.0)
	Events.shake_requested.emit(1.0)
	Fx.flash(level, pos, Color(1.0, 0.8, 1.0), 80.0, 3.0)
	Fx.shockwave(level, pos, 60.0, Color(1.0, 0.6, 1.0))
	var tween := create_tween()
	tween.tween_property(_light, ^"light_energy", 6.0, 1.0)
	tween.tween_property(_light, ^"light_energy", 0.0, 4.0)
	tween.parallel().tween_method(func(v: float) -> void:
		_heart_mat.set_shader_parameter(&"glow_strength", v), 3.5, 0.2, 4.0)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		Events.log_found.emit(&"log_final"))
	get_tree().create_timer(12.0).timeout.connect(func() -> void: defeated.emit())


func _animate(delta: float) -> void:
	_beat = maxf(_beat - delta * 2.5, 0.0)
	var s := 1.0 + 0.04 * sin(_t * 1.3) + (0.0 if _done else 0.06 * _beat)
	_heart.scale = Vector3(s, s, s)
	if not _done:
		_light.light_energy = 1.2 + (1.5 if vulnerable > 0.0 else 0.0) + sin(_t * 2.0) * 0.3
		_light.light_color = Color(1.0, 0.95, 0.7) if vulnerable > 0.0 else Color(1.0, 0.35, 0.85)
	# Tentacles trail from the heart into the dark, swaying slowly.
	for i in _tentacles.size():
		var dir := _tentacle_dirs[i]
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 14:
			var t := k / 13.0
			var side := Vector2(-dir.y, dir.x) * sin(_t * 0.7 + i * 1.3 + t * 4.0) * 4.0 * t
			var p := pos + dir * (5.0 + t * arena_radius * 1.1) + side
			pts.append(Vector3(p.x, p.y, lerpf(-9.0, -7.0 + sin(i + _t * 0.4) * 1.2, t)))
			radii.append(lerpf(0.95, 0.08, t))
		MeshKit.tube(_tentacles[i], pts, radii, 8, 0.6)
