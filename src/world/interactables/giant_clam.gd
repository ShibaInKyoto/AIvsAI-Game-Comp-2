class_name GiantClam
extends Entity
## A giant clam on the Twilight Reef floor with a glowing pearl inside. Light
## reveals, sound betrays: it snaps shut the moment the lamp touches it or
## something loud goes off close by, and only gapes open again after a few
## seconds of dark and quiet. Kill the lamp, wait, and harpoon the pearl by
## its own glow. Swim into it while it gapes and it bites.

enum State { CLOSED, OPENING, OPEN, CLOSING }

## Dark and quiet it needs before it starts to open.
const CALM_TIME := 3.0
const OPEN_TIME := 1.4
const SNAP_TIME := 0.18
## How wide the top valve gapes, in radians.
const GAPE := 0.62
## Model scale: a little under four metres across.
const SIZE := 1.3
## Noise it reacts to: radii scaled by this (only loud sounds close by).
const HEARING := 0.5
const BITE := 10.0
const PEARL_RESEARCH := 6
const PEARL_SALVAGE := 8
const SHELL := Color(0.78, 0.72, 0.66)
const SHELL_DARK := Color(0.42, 0.36, 0.38)
const MANTLE := Color(0.2, 0.85, 0.8)
const PEARL := Color(1.0, 0.92, 0.98)

## Shown once per session, the first time the sub comes near one.
static var _explained := false

var state := State.CLOSED
## 0 = shut, 1 = gaping.
var openness := 0.0
var has_pearl := true
var _calm := 0.0
var _hinge: Node3D
var _pearl: MeshInstance3D
var _pearl_mat: StandardMaterial3D
var _mantle_mat: StandardMaterial3D
var _glow: OmniLight3D
var _t := 0.0


## Lays clams on flat stretches of the reef floor, clear of [param avoid], the
## entrance, the exit and the guardian's lair; returns how many it placed.
static func scatter(level: Level, rng: RandomNumberGenerator, avoid: PackedVector2Array, count: int) -> int:
	var layout := level.layout
	var anchors := layout.anchors.duplicate()
	for i in range(anchors.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: LevelLayout.Anchor = anchors[i]
		anchors[i] = anchors[j]
		anchors[j] = tmp
	var placed := 0
	for a: LevelLayout.Anchor in anchors:
		if placed >= count:
			break
		if a.normal.y < 0.85 or a.pos.distance_to(layout.start) < 20.0 or a.pos.distance_to(layout.exit) < 15.0:
			continue
		var above := a.pos + Vector2(0.0, 2.5)
		if not layout.is_reachable(above) or level.field.sample(above) < 2.0:
			continue
		if LevelPopulator.in_guarded_room(level, a.pos):
			continue
		# Flat enough to sit on: the floor either side within a hand's breadth.
		var y := MeridianStation.floor_below(level.field, above, 4.0)
		var yl := MeridianStation.floor_below(level.field, above + Vector2(-1.4, 0.0), 4.0)
		var yr := MeridianStation.floor_below(level.field, above + Vector2(1.4, 0.0), 4.0)
		if y == -INF or yl == -INF or yr == -INF or absf(yl - y) > 0.5 or absf(yr - y) > 0.5:
			continue
		var p := Vector2(a.pos.x, y + 0.55 * SIZE)
		var near := false
		for q in avoid:
			if q.distance_squared_to(p) < 100.0:
				near = true
				break
		# Not where a boulder sits on the same stretch of floor.
		for b in level.boulders:
			if b.distance_squared_to(p) < 9.0:
				near = true
				break
		if near:
			continue
		var clam := GiantClam.new()
		clam.pos = p
		level.add_entity(clam)
		avoid.append(p)
		placed += 1
	return placed


func setup() -> void:
	radius = 1.6
	active_radius = 60.0
	targetable = true
	var root := Node3D.new()
	root.scale = Vector3.ONE * SIZE
	add_child(root)
	var shell_mat := StandardMaterial3D.new()
	shell_mat.vertex_color_use_as_albedo = true
	shell_mat.roughness = 0.75
	# Open, the inside of the top valve faces the camera.
	shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var valve := _valve()
	# The bottom valve sits on the floor; the top one hinges at the back (-X).
	var bottom := MeshInstance3D.new()
	bottom.mesh = valve
	bottom.material_override = shell_mat
	bottom.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, 0.0, 0.0))
	root.add_child(bottom)
	_hinge = Node3D.new()
	_hinge.position = Vector3(-1.35, 0.05, 0.0)
	root.add_child(_hinge)
	var top := MeshInstance3D.new()
	top.mesh = valve
	top.material_override = shell_mat
	top.position = Vector3(1.35, -0.05, 0.0)
	_hinge.add_child(top)
	# The frilled mantle between the valves, and the pearl in it.
	_mantle_mat = StandardMaterial3D.new()
	_mantle_mat.albedo_color = MANTLE.darkened(0.4)
	_mantle_mat.emission_enabled = true
	_mantle_mat.emission = MANTLE
	_mantle_mat.emission_energy_multiplier = 0.0
	var mantle := MeshInstance3D.new()
	mantle.mesh = MeshKit.transformed(MeshKit.ball(1.0, 0.0, 16, 8),
		Transform3D(Basis().scaled(Vector3(1.15, 0.16, 0.85)), Vector3.ZERO))
	mantle.material_override = _mantle_mat
	root.add_child(mantle)
	_pearl = MeshInstance3D.new()
	_pearl.mesh = MeshKit.sphere(0.27, 12, 6)
	_pearl_mat = MeshKit.emissive_material(PEARL, 0.0)
	_pearl.material_override = _pearl_mat
	_pearl.position = Vector3(0.35, 0.16, 0.3)
	root.add_child(_pearl)
	_glow = OmniLight3D.new()
	_glow.light_color = PEARL.lerp(MANTLE, 0.3)
	_glow.omni_range = 5.0
	_glow.light_energy = 0.0
	_glow.position = Vector3(0.35, 0.7, 1.2)
	root.add_child(_glow)
	_calm = level.rng.randf_range(0.0, CALM_TIME)
	_apply()


## One valve: a broad, shallow, ribbed half-dome with its lip at y = 0.
static func _valve() -> ArrayMesh:
	var half := SphereMesh.new()
	half.radius = 1.0
	half.height = 1.0
	half.is_hemisphere = true
	half.radial_segments = 24
	half.rings = 8
	# The hemisphere rises from y = 0 to its radius: squash it to half that.
	var dome := MeshKit.transformed(half, Transform3D(Basis().scaled(Vector3(1.4, 0.5, 1.05)), Vector3.ZERO))
	return MeshKit.painted(dome, func(v: Vector3) -> Color:
		# Ribs fanning out from the hinge, darker in the grooves and the lower half.
		var rib := 0.5 + 0.5 * cos(atan2(v.z, v.x + 1.4) * 22.0)
		var c := SHELL_DARK.lerp(SHELL, 0.55 + rib * 0.45)
		return c.darkened(clampf(-v.y * 0.6, 0.0, 0.4)))


func tick(delta: float) -> void:
	_t += delta
	var sub := level.player
	if not _explained and sub and sub.alive and sub.pos.distance_to(pos) < 14.0:
		_explained = true
		Events.toast.emit("A giant clam. It snaps shut in the light - kill the lamp, wait, " +
			"and harpoon the pearl by its glow.", UiTheme.ACCENT)
	var disturbed := _disturbed()
	match state:
		State.CLOSED:
			_calm = 0.0 if disturbed else _calm + delta
			if _calm >= CALM_TIME:
				state = State.OPENING
		State.OPENING:
			openness = minf(openness + delta / OPEN_TIME, 1.0)
			if disturbed:
				_snap()
			elif openness >= 1.0:
				state = State.OPEN
		State.OPEN:
			if disturbed:
				_snap()
		State.CLOSING:
			openness = maxf(openness - delta / SNAP_TIME, 0.0)
			if openness <= 0.0:
				state = State.CLOSED
				_calm = 0.0
	# Gaping, it bites whatever swims into it.
	if openness > 0.4 and sub and sub.alive and sub.pos.distance_to(pos) < radius + Submarine.RADIUS:
		sub.take_damage(BITE, pos, self)
		sub.vel += (sub.pos - pos).normalized() * 9.0
		_snap()
	_apply()


## Lit by the lamp, or something loud close by.
func _disturbed() -> bool:
	var sub := level.player
	if sub and sub.illuminates(pos + Vector2(0.0, 0.3), 1.0):
		return true
	return level.loudest_noise_at(pos, HEARING, self) != null


func _snap() -> void:
	if state == State.CLOSING or state == State.CLOSED:
		return
	state = State.CLOSING
	Audio.play_at(&"impact_rock", pos, -3.0, 0.1, 0.7)
	Fx.bubble_burst(level, pos + Vector2(0.4, 0.3), 10, 0.6)


func _apply() -> void:
	_hinge.rotation.z = GAPE * openness
	var glow := openness if has_pearl else 0.0
	var pulse := 0.85 + 0.15 * sin(_t * 2.2)
	_pearl.visible = has_pearl
	_pearl_mat.emission_energy_multiplier = 0.4 + 5.0 * glow * pulse
	_mantle_mat.emission_energy_multiplier = 1.2 * openness
	_glow.light_energy = 1.8 * glow * pulse


func on_harpoon_hit(harpoon: Node, _damage: float) -> HarpoonReaction:
	if has_pearl and openness > 0.55:
		take_pearl(level.player)
	else:
		# The harpoon turns off the shell; the clam clamps tight.
		var tip: Vector2 = harpoon.get(&"tip") if harpoon else pos
		Audio.play_at(&"harpoon_wall", tip, -2.0)
		Fx.sparks(level, tip)
		_snap()
	return HarpoonReaction.IGNORE


## The pearl is plucked out: research, and salvage spilled in the silt.
func take_pearl(sub: Submarine) -> void:
	if not has_pearl:
		return
	has_pearl = false
	if sub:
		sub.run.research += PEARL_RESEARCH
		sub.show_gain(PEARL_RESEARCH, " research", UiTheme.ACCENT)
	Pickup.scatter(level, pos + Vector2(0.0, 0.6), &"salvage",
		int(PEARL_SALVAGE * (1.0 + level.zone * 0.35)), 1.0)
	Audio.play_at(&"scan_complete", pos, 0.0)
	Fx.sparkle(level, pos + Vector2(0.3, 0.3), PEARL)
	Events.toast.emit("Pearl recovered: +%d research" % PEARL_RESEARCH, UiTheme.ACCENT)
	_snap()
