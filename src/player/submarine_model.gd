class_name SubmarineModel
extends Node3D
## Procedurally assembled submarine. Each hangar frame has its own silhouette:
## the Lantern research sub, the Mako racer, the armored Bathysphere and the
## Whisper stealth drone. The nose points along local +X.

static var _plating: ImageTexture
var propeller: Node3D
var strobe: MeshInstance3D
var cockpit_material: StandardMaterial3D
var hull_material: StandardMaterial3D

var _dark: StandardMaterial3D
var _steel: StandardMaterial3D
var _prop_speed := 0.0
var _strobe_t := 0.0



func build(frame_id: StringName, hull_color: Color) -> void:
	_make_materials(hull_color)
	propeller = Node3D.new()
	add_child(propeller)
	match frame_id:
		&"mako":
			_build_mako()
		&"bathysphere":
			_build_bathysphere()
		&"whisper":
			_build_whisper()
		_:
			_build_lantern()


func animate(delta: float, thrust: float) -> void:
	_prop_speed = lerpf(_prop_speed, 4.0 + thrust * 30.0, 1.0 - exp(-4.0 * delta))
	propeller.rotate_x(_prop_speed * delta)
	_strobe_t += delta
	if strobe:
		strobe.visible = fmod(_strobe_t, 1.6) < 0.08


func set_cockpit_glow(energy: float) -> void:
	cockpit_material.emission_energy_multiplier = energy


func set_hull_color(c: Color) -> void:
	hull_material.albedo_color = c


# --- Materials ---------------------------------------------------------------------

func _make_materials(hull_color: Color) -> void:
	hull_material = StandardMaterial3D.new()
	hull_material.albedo_color = hull_color
	hull_material.albedo_texture = _plating_texture()
	hull_material.uv1_triplanar = true
	hull_material.uv1_scale = Vector3(0.9, 0.9, 0.9)
	hull_material.metallic = 0.4
	hull_material.roughness = 0.4
	hull_material.rim_enabled = true
	hull_material.rim = 0.25

	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.12, 0.13, 0.15)
	_dark.metallic = 0.7
	_dark.roughness = 0.35

	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.55, 0.58, 0.6)
	_steel.metallic = 0.85
	_steel.roughness = 0.28

	cockpit_material = StandardMaterial3D.new()
	cockpit_material.albedo_color = Color(0.05, 0.2, 0.28)
	cockpit_material.metallic = 0.2
	cockpit_material.roughness = 0.05
	cockpit_material.emission_enabled = true
	cockpit_material.emission = Color(0.2, 0.85, 1.0)
	cockpit_material.emission_energy_multiplier = 0.9
	cockpit_material.rim_enabled = true
	cockpit_material.rim = 0.6


## Riveted hull plating, generated once: light panels with dark seams.
static func _plating_texture() -> ImageTexture:
	if _plating == null:
		var size := 256
		var img := Image.create(size, size, true, Image.FORMAT_RGB8)
		img.fill(Color(1, 1, 1))
		for y in size:
			for x in size:
				var row := int(y / 64.0)
				var seam_y := y % 64 < 2
				var seam_x := (x + row * 37) % 96 < 2
				var c := 1.0
				if seam_y or seam_x:
					c = 0.55
				else:
					var rx := (x + row * 37) % 96
					var ry := y % 64
					if (rx == 8 or rx == 88) and ry % 12 == 6:
						c = 0.7
					c *= 0.94 + 0.06 * sin(float(x) * 0.05 + float(y) * 0.11)
				img.set_pixel(x, y, Color(c, c, c))
		img.generate_mipmaps()
		_plating = ImageTexture.create_from_image(img)
	return _plating


# --- Frames ------------------------------------------------------------------------

func _build_lantern() -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.72
	body.height = 3.4
	body.radial_segments = 24
	body.rings = 8
	_part(body, hull_material, Vector3(-0.1, 0, 0), Vector3(0, 0, -90))
	_part(_cylinder(0.735, 0.735, 0.22, 24), _dark, Vector3(-0.55, 0, 0), Vector3(0, 0, -90))
	_part(MeshKit.sphere(0.62, 24, 12), cockpit_material, Vector3(1.05, 0.08, 0), Vector3.ZERO)
	var tower := BoxMesh.new()
	tower.size = Vector3(0.9, 0.42, 0.42)
	_part(tower, hull_material, Vector3(-0.2, 0.78, 0), Vector3(0, 0, 4))
	_part(_cylinder(0.015, 0.03, 0.7, 6), _steel, Vector3(-0.45, 1.25, 0), Vector3(0, 0, 12))
	strobe = _part(MeshKit.sphere(0.06), MeshKit.emissive_material(Color.WHITE, 6.0), Vector3(-0.52, 1.6, 0), Vector3.ZERO)
	_part(_cylinder(0.5, 0.42, 0.5, 20), _dark, Vector3(-1.95, 0, 0), Vector3(0, 0, -90))
	_add_propeller(Vector3(-2.05, 0, 0), 3, 0.38)
	var fin := BoxMesh.new()
	fin.size = Vector3(0.55, 0.06, 0.5)
	_part(fin, hull_material, Vector3(-1.5, 0.0, 0.62), Vector3(0, 0, -6))
	_part(fin, hull_material, Vector3(-1.5, 0.0, -0.62), Vector3(0, 0, -6))
	var tail := BoxMesh.new()
	tail.size = Vector3(0.5, 0.55, 0.05)
	_part(tail, hull_material, Vector3(-1.55, 0.45, 0), Vector3(0, 0, -18))
	_part(tail, hull_material, Vector3(-1.55, -0.45, 0), Vector3(0, 0, 18))
	_part(_cylinder(0.04, 0.04, 2.2, 6), _steel, Vector3(0.0, -0.78, 0.35), Vector3(0, 0, -90))
	_part(_cylinder(0.04, 0.04, 2.2, 6), _steel, Vector3(0.0, -0.78, -0.35), Vector3(0, 0, -90))
	_running_lights(Vector3(-1.5, 0.05, 0.9), Vector3(-1.5, 0.05, -0.9))
	_part(_cylinder(0.14, 0.2, 0.3, 12), _dark, Vector3(1.0, -0.55, 0.0), Vector3(0, 0, -90))


func _build_mako() -> void:
	# Long needle hull with a teardrop canopy and swept fins.
	var hull := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.18), Vector2(0.1, 0.42), Vector2(0.5, 0.55), Vector2(0.82, 0.45), Vector2(1.0, 0.04)]),
		4.6, 20, 14, 0.85, 1.0)
	_part(hull, hull_material, Vector3(-0.1, 0, 0), Vector3.ZERO)
	_part(_cylinder(0.5, 0.5, 0.16, 20), _dark, Vector3(0.6, 0, 0), Vector3(0, 0, -90))
	var canopy := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.05), Vector2(0.4, 0.32), Vector2(1, 0.02)]), 1.5, 16,
			8, 1.0, 0.8)
	_part(canopy, cockpit_material, Vector3(0.85, 0.36, 0), Vector3.ZERO)
	var wing := MeshKit.fin(PackedVector2Array([Vector2(0.4, 0), Vector2(-0.6, 0), Vector2(-0.9, -0.75), Vector2(-0.3,
			-0.7)]), 0.05)
	_part(wing, hull_material, Vector3(-0.6, -0.05, 0.42), Vector3(-75, 0, 0))
	_part(wing, hull_material, Vector3(-0.6, -0.05, -0.42), Vector3(75, 0, 0))
	var dorsal := MeshKit.fin(PackedVector2Array([Vector2(0.2, 0), Vector2(-0.7, 0), Vector2(-0.95, 0.7)]), 0.05)
	_part(dorsal, hull_material, Vector3(-1.4, 0.35, 0), Vector3.ZERO)
	_part(dorsal, _dark, Vector3(-1.4, -0.35, 0), Vector3(180, 0, 0))
	_part(_cylinder(0.24, 0.2, 0.4, 14), _dark, Vector3(-2.35, 0, 0), Vector3(0, 0, -90))
	_add_propeller(Vector3(-2.5, 0, 0), 4, 0.28)
	strobe = _part(MeshKit.sphere(0.05), MeshKit.emissive_material(Color.WHITE, 6.0), Vector3(-1.95, 1.05, 0),
			Vector3.ZERO)
	_running_lights(Vector3(-1.1, -0.15, 1.12), Vector3(-1.1, -0.15, -1.12))
	_part(_cylinder(0.11, 0.16, 0.25, 10), _dark, Vector3(1.5, -0.32, 0.0), Vector3(0, 0, -90))
	# Torpedo tubes under the hull.
	_part(_cylinder(0.11, 0.11, 1.4, 10), _steel, Vector3(0.3, -0.5, 0.25), Vector3(0, 0, -90))
	_part(_cylinder(0.11, 0.11, 1.4, 10), _steel, Vector3(0.3, -0.5, -0.25), Vector3(0, 0, -90))


func _build_bathysphere() -> void:
	# A thick pressure sphere with portholes inside a protective cage.
	_part(MeshKit.sphere(1.2, 28, 16), hull_material, Vector3(0, 0, 0), Vector3.ZERO)
	var port_mat := cockpit_material
	_part(MeshKit.sphere(0.36, 16, 8), port_mat, Vector3(1.02, 0.2, 0.0), Vector3.ZERO)
	_part(MeshKit.sphere(0.2, 12, 6), port_mat, Vector3(0.75, 0.3, 0.75), Vector3.ZERO)
	_part(MeshKit.sphere(0.2, 12, 6), port_mat, Vector3(0.75, 0.3, -0.75), Vector3.ZERO)
	var rim := TorusMesh.new()
	rim.inner_radius = 1.17
	rim.outer_radius = 1.3
	rim.rings = 32
	rim.ring_segments = 8
	_part(rim, _dark, Vector3.ZERO, Vector3(0, 0, 90))
	_part(rim, _dark, Vector3.ZERO, Vector3(90, 0, 0))
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		_part(_cylinder(0.05, 0.05, 2.3, 6), _steel, Vector3(0, -0.4, 0) + Vector3(cos(a), 0, sin(a)) * 1.05, Vector3.ZERO)
	_part(_cylinder(0.06, 0.06, 2.2, 6), _steel, Vector3(0, -1.5, 0.74), Vector3(0, 0, -90))
	_part(_cylinder(0.06, 0.06, 2.2, 6), _steel, Vector3(0, -1.5, -0.74), Vector3(0, 0, -90))
	# Ballast tanks and twin thrusters.
	_part(_capsule(0.32, 1.8), hull_material, Vector3(-0.2, -1.05, 0.0), Vector3(0, 0, -90))
	_part(_cylinder(0.3, 0.26, 0.45, 14), _dark, Vector3(-1.45, 0.0, 0.0), Vector3(0, 0, -90))
	_add_propeller(Vector3(-1.62, 0.0, 0.0), 3, 0.26)
	_part(_cylinder(0.02, 0.03, 0.9, 6), _steel, Vector3(-0.2, 1.55, 0), Vector3(0, 0, 8))
	strobe = _part(MeshKit.sphere(0.07), MeshKit.emissive_material(Color.WHITE, 6.0), Vector3(-0.27, 2.0, 0), Vector3.ZERO)
	_running_lights(Vector3(-0.2, 0.0, 1.32), Vector3(-0.2, 0.0, -1.32))
	_part(_cylinder(0.15, 0.22, 0.3, 12), _dark, Vector3(1.2, -0.55, 0.0), Vector3(0, 0, -90))


func _build_whisper() -> void:
	# Flattened, faceted stealth hull with glowing seams and a pump-jet.
	var hull := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.25), Vector2(0.2, 0.55), Vector2(0.6, 0.6), Vector2(0.9, 0.35), Vector2(1.0, 0.05)]),
		3.8, 6, 10, 0.45, 1.25)
	_part(hull, hull_material, Vector3(0, 0, 0), Vector3.ZERO)
	var seam := MeshKit.emissive_material(Color(0.6, 0.4, 1.0), 3.0)
	_part(_box(Vector3(3.0, 0.03, 1.35)), seam, Vector3(-0.1, 0.0, 0.0), Vector3.ZERO)
	var sensor := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.02), Vector2(0.5, 0.2), Vector2(1, 0.02)]), 0.9, 12,
			6, 0.5, 1.0)
	_part(sensor, cockpit_material, Vector3(1.25, 0.18, 0), Vector3.ZERO)
	var vane := MeshKit.fin(PackedVector2Array([Vector2(0.2, 0), Vector2(-0.5, 0), Vector2(-0.7, 0.55), Vector2(-0.3,
			0.5)]), 0.04)
	_part(vane, hull_material, Vector3(-1.2, 0.2, 0.35), Vector3(-20, 0, 0))
	_part(vane, hull_material, Vector3(-1.2, 0.2, -0.35), Vector3(20, 0, 0))
	_part(_cylinder(0.32, 0.36, 0.5, 6), _dark, Vector3(-1.95, 0, 0), Vector3(0, 0, -90))
	_add_propeller(Vector3(-2.05, 0, 0), 6, 0.26)
	strobe = _part(MeshKit.sphere(0.04), MeshKit.emissive_material(Color(0.6, 0.4, 1.0), 4.0), Vector3(-0.6, 0.3, 0),
			Vector3.ZERO)
	_part(_cylinder(0.1, 0.14, 0.25, 8), _dark, Vector3(1.4, -0.22, 0.0), Vector3(0, 0, -90))


# --- Helpers ---------------------------------------------------------------------

func _add_propeller(at: Vector3, blades: int, length: float) -> void:
	propeller.position = at
	for i in blades:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, length, 0.12)
		blade.mesh = bm
		blade.material_override = _steel
		blade.rotation = Vector3(TAU * i / blades, 0, 0)
		blade.position = Vector3(0, length * 0.47, 0).rotated(Vector3.RIGHT, TAU * i / blades)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		propeller.add_child(blade)


## Red port and green starboard navigation lights.
func _running_lights(port: Vector3, starboard: Vector3) -> void:
	_part(MeshKit.sphere(0.05), MeshKit.emissive_material(Color(1.0, 0.1, 0.1), 5.0), port, Vector3.ZERO)
	_part(MeshKit.sphere(0.05), MeshKit.emissive_material(Color(0.1, 1.0, 0.3), 5.0), starboard, Vector3.ZERO)


func _part(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	# The lamp sits inside the hull silhouette; hull shadows would black it out.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 4
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
