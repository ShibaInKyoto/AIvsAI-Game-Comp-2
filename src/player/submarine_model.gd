class_name SubmarineModel
extends Node3D
## Procedurally assembled submarine mesh. The nose points along local +X.
## Purely visual: exposes the propeller and lamp mount for animation.

var propeller: Node3D
var lamp_mount: Node3D
var strobe: MeshInstance3D
var cockpit_material: StandardMaterial3D
var hull_material: StandardMaterial3D

var _prop_speed := 0.0
var _strobe_t := 0.0


func build(hull_color: Color) -> void:
	hull_material = StandardMaterial3D.new()
	hull_material.albedo_color = hull_color
	hull_material.metallic = 0.35
	hull_material.roughness = 0.42
	hull_material.rim_enabled = true
	hull_material.rim = 0.25

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.15)
	dark.metallic = 0.7
	dark.roughness = 0.35

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.58, 0.6)
	steel.metallic = 0.85
	steel.roughness = 0.28

	cockpit_material = StandardMaterial3D.new()
	cockpit_material.albedo_color = Color(0.05, 0.2, 0.28)
	cockpit_material.metallic = 0.2
	cockpit_material.roughness = 0.05
	cockpit_material.emission_enabled = true
	cockpit_material.emission = Color(0.2, 0.85, 1.0)
	cockpit_material.emission_energy_multiplier = 0.9
	cockpit_material.rim_enabled = true
	cockpit_material.rim = 0.6

	# Main pressure hull.
	var body := CapsuleMesh.new()
	body.radius = 0.72
	body.height = 3.4
	body.radial_segments = 24
	body.rings = 8
	_part(body, hull_material, Vector3(-0.1, 0, 0), Vector3(0, 0, -90))

	# Belly stripe band.
	var band := CylinderMesh.new()
	band.top_radius = 0.735
	band.bottom_radius = 0.735
	band.height = 0.22
	band.radial_segments = 24
	_part(band, dark, Vector3(-0.55, 0, 0), Vector3(0, 0, -90))

	# Glass cockpit dome.
	var dome := SphereMesh.new()
	dome.radius = 0.62
	dome.height = 1.24
	dome.radial_segments = 24
	dome.rings = 12
	_part(dome, cockpit_material, Vector3(1.05, 0.08, 0), Vector3.ZERO)

	# Conning tower with antenna.
	var tower := BoxMesh.new()
	tower.size = Vector3(0.9, 0.42, 0.42)
	_part(tower, hull_material, Vector3(-0.2, 0.78, 0), Vector3(0, 0, 4))
	var antenna := CylinderMesh.new()
	antenna.top_radius = 0.015
	antenna.bottom_radius = 0.03
	antenna.height = 0.7
	_part(antenna, steel, Vector3(-0.45, 1.25, 0), Vector3(0, 0, 12))
	strobe = _part(_sphere(0.06), _emissive(Color(1.0, 1.0, 1.0), 6.0), Vector3(-0.52, 1.6, 0), Vector3.ZERO)

	# Stern shroud and propeller.
	var shroud := CylinderMesh.new()
	shroud.top_radius = 0.5
	shroud.bottom_radius = 0.42
	shroud.height = 0.5
	shroud.radial_segments = 20
	_part(shroud, dark, Vector3(-1.95, 0, 0), Vector3(0, 0, -90))
	propeller = Node3D.new()
	propeller.position = Vector3(-2.05, 0, 0)
	add_child(propeller)
	for i in 3:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.38, 0.12)
		blade.mesh = bm
		blade.material_override = steel
		blade.rotation = Vector3(TAU * i / 3.0, 0, 0)
		blade.position = Vector3(0, 0.18, 0).rotated(Vector3.RIGHT, TAU * i / 3.0)
		propeller.add_child(blade)

	# Fins.
	var fin := BoxMesh.new()
	fin.size = Vector3(0.55, 0.06, 0.5)
	_part(fin, hull_material, Vector3(-1.5, 0.0, 0.62), Vector3(0, 0, -6))
	_part(fin, hull_material, Vector3(-1.5, 0.0, -0.62), Vector3(0, 0, -6))
	var tail := BoxMesh.new()
	tail.size = Vector3(0.5, 0.55, 0.05)
	_part(tail, hull_material, Vector3(-1.55, 0.45, 0), Vector3(0, 0, -18))
	_part(tail, hull_material, Vector3(-1.55, -0.45, 0), Vector3(0, 0, 18))

	# Skids.
	var skid := CylinderMesh.new()
	skid.top_radius = 0.04
	skid.bottom_radius = 0.04
	skid.height = 2.2
	_part(skid, steel, Vector3(0.0, -0.78, 0.35), Vector3(0, 0, -90))
	_part(skid, steel, Vector3(0.0, -0.78, -0.35), Vector3(0, 0, -90))

	# Running lights: red port, green starboard.
	_part(_sphere(0.05), _emissive(Color(1.0, 0.1, 0.1), 5.0), Vector3(-1.5, 0.05, 0.9), Vector3.ZERO)
	_part(_sphere(0.05), _emissive(Color(0.1, 1.0, 0.3), 5.0), Vector3(-1.5, 0.05, -0.9), Vector3.ZERO)

	# Lamp housing under the nose.
	lamp_mount = Node3D.new()
	lamp_mount.position = Vector3(1.0, -0.55, 0.0)
	add_child(lamp_mount)
	var housing := CylinderMesh.new()
	housing.top_radius = 0.14
	housing.bottom_radius = 0.2
	housing.height = 0.3
	_part(housing, dark, Vector3(1.0, -0.55, 0.0), Vector3(0, 0, -90))


func animate(delta: float, thrust: float) -> void:
	_prop_speed = lerpf(_prop_speed, 4.0 + thrust * 30.0, 1.0 - exp(-4.0 * delta))
	propeller.rotate_x(_prop_speed * delta)
	_strobe_t += delta
	strobe.visible = fmod(_strobe_t, 1.6) < 0.08


func set_cockpit_glow(energy: float) -> void:
	cockpit_material.emission_energy_multiplier = energy


func _part(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s


static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
