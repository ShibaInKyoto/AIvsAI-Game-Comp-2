class_name ThermalVent
extends Entity
## A fissure in the vent fields that erupts every so often. It rumbles and
## glows first, then blasts a column of scalding water that shoves and burns
## anything inside it - and is loud enough to bring every hunter in earshot.
## Creatures caught in the column cook, which a careful pilot can use.

enum State { DORMANT, WARNING, ERUPTING }

const HEIGHT := 15.0
const WIDTH := 2.4
const WARNING_TIME := 1.3
const ERUPT_TIME := 2.6
const PUSH := 34.0
## Damage per scald while inside the column (applied every [constant SCALD_INTERVAL]).
const SUB_SCALD := 6.0
const CREATURE_SCALD := 14.0
const SCALD_INTERVAL := 0.45
const NOISE := 26.0

## How far the vent sits out of the rock face (see [method LevelPopulator]).
const LIFT := 0.3
## The first eruption a pilot sees explains itself, once per session.
static var _explained := false

var normal := Vector2.UP
## One of the vents on the Ironclad's lair floor.
var in_lair := false
var state := State.DORMANT
var _timer := 0.0
var _scald_timer := 0.0
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _plume: GPUParticles3D
var _bubbles: GPUParticles3D


func setup() -> void:
	radius = 1.2
	active_radius = 80.0
	_timer = level.rng.randf_range(2.0, 9.0)
	var holder := Node3D.new()
	# Local +Y points out of the floor, along the eruption column.
	holder.rotation.z = normal.angle() - PI * 0.5
	add_child(holder)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.15, 0.06, 0.03)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.42, 0.12)
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var crack := MeshInstance3D.new()
	crack.mesh = _crack(level.rng)
	crack.material_override = _mat
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(crack)
	_plume = Fx.vent_plume(HEIGHT)
	holder.add_child(_plume)
	_bubbles = Fx.bubble_emitter()
	_bubbles.emitting = false
	holder.add_child(_bubbles)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.omni_range = 11.0
	_light.light_volumetric_fog_energy = 1.5
	_light.position = Vector3(0.0, 2.5, 1.0)
	_light.visible = false
	holder.add_child(_light)


## A jagged glowing seam split into the rock, following the relief from the
## back of the cave to its front edge so it lies flush (local +Y out of the
## rock, Z across the cave towards the camera).
static func _crack(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 14
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var wander := 0.0
	for k in steps + 1:
		var t := float(k) / steps
		var z := lerpf(-2.6, 1.1, t)
		# Widest in the middle, closing to a hairline at either end.
		var w := 0.6 * pow(sin(t * PI), 0.7) * rng.randf_range(0.6, 1.1) + 0.03
		wander = clampf(wander + rng.randf_range(-0.25, 0.25), -0.5, 0.5)
		var y := PropScatter.surface_offset(z) - LIFT + 0.04
		left.append(Vector3(wander - w, y, z))
		right.append(Vector3(wander + w, y, z))
	for k in steps:
		for v in [left[k], left[k + 1], right[k], right[k], left[k + 1], right[k + 1]]:
			st.set_normal(Vector3(0.0, 1.0, 0.0))
			st.add_vertex(v)
	return st.commit()


func tick(delta: float) -> void:
	_timer -= delta
	match state:
		State.DORMANT:
			_mat.emission_energy_multiplier = 0.8 + 0.3 * sin(level.time * 2.0 + pos.x)
			if _timer <= 0.0:
				_set_state(State.WARNING)
		State.WARNING:
			var k := 1.0 - _timer / WARNING_TIME
			_mat.emission_energy_multiplier = lerpf(1.0, 4.5, k) * (0.85 + 0.15 * sin(level.time * 30.0))
			_light.light_energy = 2.0 * k
			if _timer <= 0.0:
				_set_state(State.ERUPTING)
		State.ERUPTING:
			_mat.emission_energy_multiplier = 5.0
			_light.light_energy = 5.0 * (0.8 + 0.2 * sin(level.time * 20.0))
			_scald(delta)
			if _timer <= 0.0:
				_set_state(State.DORMANT)


## Starts the warning rumble now (tests and scripted moments).
func erupt_soon() -> void:
	_set_state(State.WARNING)


func _set_state(s: State) -> void:
	state = s
	match s:
		State.DORMANT:
			_timer = level.rng.randf_range(7.0, 13.0)
			_plume.emitting = false
			_bubbles.emitting = false
			_light.visible = false
		State.WARNING:
			_timer = WARNING_TIME
			_bubbles.emitting = true
			_light.visible = true
			Audio.play_at(&"vent_rumble", pos, -2.0)
		State.ERUPTING:
			_timer = ERUPT_TIME
			_scald_timer = 0.0
			_plume.emitting = true
			Audio.play_at(&"vent_erupt", pos, 0.0)
			level.emit_noise(pos + normal * 4.0, NOISE, self)
			_explain()


## How strongly the column grips something at [param p] (0 = outside it).
func column_strength(p: Vector2, r := 0.0) -> float:
	var rel := p - pos
	var along := rel.dot(normal)
	if along < -0.5 or along > HEIGHT:
		return 0.0
	var width := WIDTH * (1.0 + along / HEIGHT * 0.6) + r
	var lateral := absf(rel.dot(normal.orthogonal()))
	if lateral > width:
		return 0.0
	return (1.0 - along / HEIGHT * 0.7) * (1.0 - lateral / width * 0.5)


func _scald(delta: float) -> void:
	_scald_timer -= delta
	var burn := _scald_timer <= 0.0
	if burn:
		_scald_timer = SCALD_INTERVAL
	var sub := level.player
	if sub and sub.alive:
		var k := column_strength(sub.pos, Submarine.RADIUS)
		if k > 0.0:
			sub.vel += normal * PUSH * k * delta
			if burn:
				sub.take_damage(SUB_SCALD, sub.pos - normal, self, false)
	for e in level.targets_in_radius(pos + normal * HEIGHT * 0.5, HEIGHT * 0.6):
		var c := e as Creature
		if c == null:
			continue
		var ck := column_strength(c.pos, c.radius)
		if ck > 0.0:
			c.vel += normal * PUSH * 0.6 * ck * delta / maxf(c.mass, 1.0)
			if burn:
				c.take_damage(CREATURE_SCALD, pos, &"vent")


func _explain() -> void:
	var sub := level.player
	if _explained or sub == null or sub.pos.distance_to(pos) > 35.0:
		return
	_explained = true
	Events.toast.emit("Thermal vent! They rumble and glow before erupting - stay out of the column, " +
		"or lure hunters into it.", UiTheme.WARN)
