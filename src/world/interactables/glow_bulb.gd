class_name GlowBulb
extends Entity
## A bioluminescent bulb growing on the cave wall. Touching it harvests its
## stored charge into the battery; it then goes dark.

const CHARGE := 28.0

static var _mesh: Mesh
static var _stalk_mesh: Mesh

var normal := Vector2.UP
var color := Color(0.4, 1.0, 0.8)
var _harvested := false
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _bulb: MeshInstance3D
var _t := 0.0


func setup() -> void:
	radius = 0.8
	active_radius = 60.0
	if _mesh == null:
		_mesh = MeshKit.ball(0.55, 1.0)
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.08
		stalk.bottom_radius = 0.16
		stalk.height = 1.0
		stalk.radial_segments = 6
		_stalk_mesh = stalk
	var holder := Node3D.new()
	holder.rotation.z = normal.angle() - PI * 0.5
	add_child(holder)
	var stalk_mi := MeshInstance3D.new()
	stalk_mi.mesh = _stalk_mesh
	var stalk_mat := StandardMaterial3D.new()
	stalk_mat.albedo_color = Color(0.25, 0.3, 0.25)
	stalk_mi.material_override = stalk_mat
	stalk_mi.position = Vector3(0, -0.3, 0)
	holder.add_child(stalk_mi)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color.darkened(0.3)
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 3.0
	_mat.rim_enabled = true
	_bulb = MeshInstance3D.new()
	_bulb.mesh = _mesh
	_bulb.material_override = _mat
	_bulb.position = Vector3(0, 0.35, 0)
	holder.add_child(_bulb)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = 6.0
	_light.light_energy = 1.2
	_light.light_volumetric_fog_energy = 0.5
	_light.position = Vector3(normal.x * 0.8, normal.y * 0.8, 1.0)
	add_child(_light)
	_t = level.rng.randf() * TAU


func tick(delta: float) -> void:
	_t += delta
	if _harvested:
		return
	var pulse := 0.8 + 0.2 * sin(_t * 1.7)
	_mat.emission_energy_multiplier = 3.0 * pulse
	_light.light_energy = 1.2 * pulse
	_bulb.scale = Vector3.ONE * (0.95 + 0.05 * sin(_t * 1.7))
	var sub := level.player
	if sub and sub.alive and sub.pos.distance_to(pos) < Submarine.RADIUS + radius + 0.4:
		_harvest(sub)


func is_ripe() -> bool:
	return not _harvested


func _harvest(sub: Submarine) -> void:
	_harvested = true
	Events.bulb_harvested.emit(pos)
	var gain := CHARGE * sub.stats.bulb_mult
	sub.add_battery(gain)
	Audio.play_at(&"bulb_harvest", pos, -2.0)
	Events.toast.emit("Battery +%d" % int(gain), UiTheme.ACCENT)
	Fx.sparkle(level, pos, color)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_mat, ^"emission_energy_multiplier", 0.15, 1.2)
	tween.tween_property(_light, ^"light_energy", 0.0, 1.2)
	tween.tween_property(_bulb, ^"scale", Vector3.ONE * 0.6, 1.2)
