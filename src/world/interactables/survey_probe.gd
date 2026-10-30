class_name SurveyProbe
extends Entity
## One of Meridian Deep's survey probes, dropped down the trench years ago to
## log temperature, pressure and song, and lost in its side passages. Most
## lie in the rooms off the main way down, still blinking. Hook one with the
## harpoon and reel it in (or bump into it) to download what it recorded:
## research, more the deeper it lay.

const RESEARCH_BASE := 6
const RESEARCH_PER_ZONE := 2
const BLINK := 1.8
const COLOR := Color(1.0, 0.72, 0.2)

static var _body_mesh: Mesh
static var _mast_mesh: Mesh
static var _shell: StandardMaterial3D
static var _dark: StandardMaterial3D

var _recovered := false
var _t := 0.0
var _light: OmniLight3D
var _lamp_mat: StandardMaterial3D


## Lays [param count] probes in the side rooms of [param level], away from
## the start and the way down. Returns how many found a place.
static func scatter(level: Level, rng: RandomNumberGenerator, used: PackedVector2Array, count: int) -> int:
	var layout := level.layout
	var rooms := layout.chambers.filter(func(c: LevelLayout.Chamber) -> bool:
		return c.kind == &"loot" and c.center.distance_to(layout.start) > 30.0 and c.center.distance_to(layout.exit) > 20.0)
	for i in range(rooms.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: LevelLayout.Chamber = rooms[i]
		rooms[i] = rooms[j]
		rooms[j] = swap
	var placed := 0
	for room: LevelLayout.Chamber in rooms:
		if placed >= count:
			break
		var p := layout.point_in_chamber(rng, room, 1.5)
		if p == Vector2.INF or not layout.is_reachable(p):
			continue
		# Settled on the floor of the room, where there is one.
		var floor_y := MeridianStation.floor_below(level.field, p, room.radius.y * 2.0)
		if floor_y != -INF and level.field.sample(Vector2(p.x, floor_y + 0.9)) > 0.7:
			p = Vector2(p.x, floor_y + 0.9)
		var clear := true
		for u in used:
			if u.distance_to(p) < 6.0:
				clear = false
				break
		if not clear:
			continue
		var probe := SurveyProbe.new()
		probe.pos = p
		level.add_entity(probe)
		used.append(p)
		placed += 1
	return placed


func setup() -> void:
	radius = 0.8
	active_radius = 90.0
	targetable = true
	if _body_mesh == null:
		_body_mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.2), Vector2(0.2, 0.45), Vector2(0.8, 0.45),
			Vector2(1.0, 0.15)]), 1.5, 14, 6, 1.0, 1.0)
		_mast_mesh = MeshKit.sphere(0.07, 6, 4)
		_shell = StandardMaterial3D.new()
		_shell.albedo_color = Color(0.95, 0.62, 0.12)
		_shell.metallic = 0.3
		_shell.roughness = 0.45
		_dark = StandardMaterial3D.new()
		_dark.albedo_color = Color(0.12, 0.13, 0.15)
		_dark.metallic = 0.6
	var body := MeshInstance3D.new()
	body.mesh = _body_mesh
	body.material_override = _shell
	body.position = Vector3(-0.75, 0.0, 0.0)
	body.rotation = Vector3(0.0, level.rng.randf_range(-0.5, 0.5), level.rng.randf_range(-0.25, 0.25))
	add_child(body)
	# A stub antenna with a lamp at its tip.
	var mast := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.03
	rod.bottom_radius = 0.04
	rod.height = 0.7
	mast.mesh = rod
	mast.material_override = _dark
	mast.position = Vector3(0.1, 0.6, 0.0)
	add_child(mast)
	var lamp := MeshInstance3D.new()
	lamp.mesh = _mast_mesh
	_lamp_mat = MeshKit.emissive_material(COLOR, 4.0)
	lamp.material_override = _lamp_mat
	lamp.position = Vector3(0.1, 0.98, 0.0)
	add_child(lamp)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = 5.0
	_light.position = Vector3(0.1, 1.0, 0.5)
	add_child(_light)
	_t = level.rng.randf() * BLINK


func tick(delta: float) -> void:
	_t += delta
	var on := fmod(_t, BLINK) < 0.18
	_light.light_energy = 1.6 if on else 0.05
	_lamp_mat.emission_energy_multiplier = 5.0 if on else 0.4
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < Submarine.RADIUS + radius + 0.3:
		recover(sub)


func on_harpoon_hit(_harpoon: Node, _damage: float) -> HarpoonReaction:
	return HarpoonReaction.DRAG


func on_reeled_in(sub: Submarine) -> void:
	recover(sub)


## The research it holds, by how deep it lay.
func research() -> int:
	return RESEARCH_BASE + RESEARCH_PER_ZONE * level.zone


func recover(sub: Submarine) -> void:
	if _recovered:
		return
	_recovered = true
	var gain := research()
	sub.run.research += gain
	sub.run.probes += 1
	sub.show_gain(gain, " research", UiTheme.ACCENT)
	Game.meta.probes_recovered += 1
	Audio.play_at(&"scan_complete", pos, 0.0, 0.05, 0.8)
	Fx.sparkle(level, pos, COLOR)
	Events.toast.emit("Survey probe recovered: its logs are worth %d research." % gain, UiTheme.ACCENT)
	despawn()
