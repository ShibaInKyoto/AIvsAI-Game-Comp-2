class_name PassingWhale
extends Entity
## In the second Sunlit Shelf zone a sperm whale passes through the open
## water behind the playfield, eleven metres of it, on slow beats of its
## flukes. It does not see the sub as anything worth a look. Its clicks reach
## the sub's sonar: every few seconds the cave around it shows up on the
## chart as if pinged, without a sound a hunter would follow. The reef below
## is where whales come to rest (see [WhaleFall]).

enum State { WAITING, PASSING, GONE }

const ZONE := 1
## How far behind the playfield it swims (in front of the cave's back wall).
const DEPTH := -3.5
const LENGTH := 11.0
const SPEED := 1.7
## Open water it needs along its way, and how far its way must run.
const CLEARANCE := 3.0
const MIN_RUN := 24.0
## How close the sub comes before it appears, and before it is witnessed.
const TRIGGER_RANGE := 50.0
const WITNESS_RANGE := 40.0
const CLICK_PING_RANGE := 34.0
const CLICK_PING_EVERY := 4.0
const FADE := 3.0
const RESEARCH := 5
const SKIN := Color(0.46, 0.5, 0.55)

var state := State.WAITING
## The stretch of open water it swims along (left to right).
var from := Vector2.ZERO
var to := Vector2.ZERO
var heading := 1.0
var witnessed := false
## Behind the title screen: it passes again and again, and is never witnessed.
var backdrop := false
var _x := 0.0
var _t := 0.0
var _click_in := 0.5
var _ping_in := 1.5
var _rest := 4.0
var _rng := RandomNumberGenerator.new()
var _rig: Node3D
var _flukes: Node3D
var _mat: StandardMaterial3D


## A level stretch of open water through [param p] (along the row
## [param rise] metres above it), as [from, to], or [] if it is too short.
static func stretch_through(field: TerrainField, p: Vector2, rise: float) -> Array[Vector2]:
	var y := p.y + rise
	if field.sample(Vector2(p.x, y)) <= CLEARANCE:
		return []
	var a := p.x
	while a > p.x - 40.0 and field.sample(Vector2(a - 1.0, y)) > CLEARANCE:
		a -= 1.0
	var b := p.x
	while b < p.x + 40.0 and field.sample(Vector2(b + 1.0, y)) > CLEARANCE:
		b += 1.0
	if b - a < MIN_RUN:
		return []
	return [Vector2(a, y), Vector2(b, y)]


## Finds the longest level stretch of open water in the zone, at least
## [constant MIN_RUN] long; returns the whale waiting there, or null.
static func place(level: Level) -> PassingWhale:
	var field := level.field
	var size := level.layout.size()
	var best_len := 0.0
	var best_a := Vector2.ZERO
	var best_b := Vector2.ZERO
	var y := -8.0
	while y > -(size.y - 8.0):
		var run_start := -1.0
		var x := 4.0
		while x < size.x - 4.0:
			var open := field.sample(Vector2(x, y)) > CLEARANCE
			if open and run_start < 0.0:
				run_start = x
			if (not open or x + 1.0 >= size.x - 4.0) and run_start >= 0.0:
				# The run ends at the last open sample.
				var end_x := x if open else x - 1.0
				if end_x - run_start > best_len:
					best_len = end_x - run_start
					best_a = Vector2(run_start, y)
					best_b = Vector2(end_x, y)
				run_start = -1.0
			x += 1.0
		y -= 2.0
	if best_len < MIN_RUN:
		return null
	var whale := PassingWhale.new()
	whale.from = best_a
	whale.to = best_b
	whale.pos = (best_a + best_b) * 0.5
	level.add_entity(whale)
	return whale


func setup() -> void:
	radius = 0.0
	active_radius = 1.0e6
	_rng.seed = hash(from)
	_rig = Node3D.new()
	_rig.top_level = true
	_rig.visible = false
	add_child(_rig)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = SKIN
	_mat.roughness = 0.85
	# Lit from the surface above: a pale rim keeps it from sinking into the
	# dark back of the cave.
	_mat.rim_enabled = true
	_mat.rim = 0.7
	_mat.rim_tint = 0.2
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	_build()


func _build() -> void:
	# Body of revolution, tail (-X) to the great blunt head (+X).
	var profile := PackedVector2Array([Vector2(0.0, 0.16), Vector2(0.12, 0.3), Vector2(0.3, 0.68),
		Vector2(0.5, 1.0), Vector2(0.66, 1.15), Vector2(0.8, 1.2), Vector2(0.93, 1.15), Vector2(0.985, 0.95),
		Vector2(1.0, 0.5)])
	var parts: Array = [[MeshKit.lathe(profile, LENGTH, 16, 24, 1.0, 0.85)]]
	# The narrow lower jaw under the head, and the hump on the back.
	var jaw_profile := PackedVector2Array([Vector2(0.0, 0.26), Vector2(0.8, 0.2), Vector2(1.0, 0.1)])
	var jaw := MeshKit.lathe(jaw_profile, 3.6, 8, 3)
	parts.append([jaw, Transform3D(Basis().rotated(Vector3(0, 0, 1), 0.08), Vector3(LENGTH * 0.33, -0.95, 0.0))])
	parts.append([MeshKit.ball(0.7), Transform3D(Basis().scaled(Vector3(1.6, 0.55, 0.6)),
		Vector3(-LENGTH * 0.1, 0.85, 0.0))])
	# Paddle-shaped flippers behind the head, either side.
	var flipper := MeshKit.fin(PackedVector2Array([Vector2(0, 0), Vector2(-0.4, -0.9), Vector2(-1.1, -1.0),
		Vector2(-0.6, -0.2)]), 0.08)
	for side: float in [1.0, -1.0]:
		parts.append([flipper, Transform3D(Basis().rotated(Vector3(1, 0, 0), side * 0.5),
			Vector3(LENGTH * 0.2, -0.7, side * 0.8))])
	var body := MeshInstance3D.new()
	body.mesh = MeshKit.merge(parts)
	body.material_override = _mat
	_rig.add_child(body)
	# The flukes, flat to the water, beating up and down from the tail stock.
	_flukes = Node3D.new()
	_flukes.position = Vector3(-LENGTH * 0.5 + 0.2, 0.0, 0.0)
	_rig.add_child(_flukes)
	var fluke := MeshKit.fin(PackedVector2Array([Vector2(0.0, 0.0), Vector2(-1.0, 1.9), Vector2(-1.6, 1.75),
		Vector2(-1.15, 0.25), Vector2(-1.15, -0.25), Vector2(-1.6, -1.75), Vector2(-1.0, -1.9)]), 0.1)
	var flukes_mesh := MeshInstance3D.new()
	flukes_mesh.mesh = fluke
	flukes_mesh.material_override = _mat
	flukes_mesh.rotation.x = PI * 0.5
	_flukes.add_child(flukes_mesh)


func tick(delta: float) -> void:
	var sub := level.player
	match state:
		State.WAITING:
			if backdrop:
				_rest -= delta
				if _rest <= 0.0:
					_set_off(-heading)
			elif sub and sub.alive and sub.pos.distance_to(pos) < TRIGGER_RANGE:
				_begin(sub)
		State.PASSING:
			_swim(delta, sub)


## Sets off from the end of its stretch farther from the sub, so it passes it.
func _begin(sub: Submarine) -> void:
	_set_off(1.0 if sub.pos.distance_to(from) > sub.pos.distance_to(to) else -1.0)


func _set_off(dir: float) -> void:
	state = State.PASSING
	heading = dir
	_x = from.x if heading > 0.0 else to.x
	_t = 0.0
	_rig.visible = true
	_rig.rotation.y = 0.0 if heading > 0.0 else PI


func _swim(delta: float, sub: Submarine) -> void:
	_t += delta
	_x += heading * SPEED * delta
	var start_x := from.x if heading > 0.0 else to.x
	var end_x := to.x if heading > 0.0 else from.x
	var gone := absf(_x - start_x)
	var left := absf(end_x - _x)
	if left <= 0.0 or signf(end_x - _x) != heading:
		# Behind the title it comes round again after a while.
		state = State.WAITING if backdrop else State.GONE
		_rest = _rng.randf_range(10.0, 16.0)
		_rig.visible = false
		return
	# Out of the blue and back into it.
	_mat.albedo_color.a = clampf(minf(gone, left) / (SPEED * FADE), 0.0, 1.0)
	var bob := 0.25 * sin(_t * 0.5)
	var at := Vector2(_x, from.y + bob)
	_rig.position = Vector3(at.x, at.y, DEPTH)
	var beat := sin(_t * TAU / 4.2)
	_flukes.rotation.z = 0.35 * beat
	_rig.rotation.z = heading * 0.03 * cos(_t * TAU / 4.2)
	var head := at + Vector2(heading * LENGTH * 0.45, 0.0)
	_click_in -= delta
	if _click_in <= 0.0:
		_click_in = _rng.randf_range(0.55, 0.9)
		if _rng.randf() < 0.12:
			Audio.play_at(&"whale_creak", head, -6.0, 0.05)
		else:
			Audio.play_at(&"whale_click", head, -8.0, 0.1)
	# Its clicks chart the cave on the sub's sonar.
	_ping_in -= delta
	if _ping_in <= 0.0 and _mat.albedo_color.a > 0.5 and not backdrop:
		_ping_in = CLICK_PING_EVERY
		level.ping(head, CLICK_PING_RANGE, 2.0)
	var seen := _mat.albedo_color.a > 0.5 and sub and sub.alive and sub.pos.distance_to(at) < WITNESS_RANGE
	if seen and not witnessed and not backdrop:
		witnessed = true
		Wonders.witness("whale")
		sub.run.research += RESEARCH
		sub.show_gain(RESEARCH, " research", UiTheme.ACCENT)
		Events.toast.emit("A sperm whale passes, clicking. Its clicks show the cave on your sonar.", UiTheme.ACCENT)


## Where it is now, for tests and previews (INF when it is not passing).
func whale_pos() -> Vector2:
	return Vector2(_x, from.y) if state == State.PASSING else Vector2.INF
