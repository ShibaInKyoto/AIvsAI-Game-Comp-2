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
## Glowing seams that breathe (a "pulse" finish), or false.
var _pulse := false



## Builds the frame's model in [param skin] (its factory paint if null).
func build(frame_id: StringName, skin: SubSkins.Livery = null) -> void:
	_make_materials(skin if skin else SubSkins.factory(frame_id))
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
	_merge_static()


func animate(delta: float, thrust: float) -> void:
	_prop_speed = lerpf(_prop_speed, 4.0 + thrust * 30.0, 1.0 - exp(-4.0 * delta))
	propeller.rotate_x(_prop_speed * delta)
	_strobe_t += delta
	if strobe:
		strobe.visible = fmod(_strobe_t, 1.6) < 0.08
	if _pulse:
		hull_material.emission_energy_multiplier = 0.4 + 1.8 * pow(0.5 + 0.5 * sin(_strobe_t * 1.8), 2.0)


func set_cockpit_glow(energy: float) -> void:
	cockpit_material.emission_energy_multiplier = energy


## Darkens the livery, glow and all (for a wreck).
func darken_hull(amount: float) -> void:
	hull_material.albedo_color = hull_material.albedo_color.darkened(amount)
	hull_material.emission_energy_multiplier *= 1.0 - amount
	_pulse = false


# --- Materials ---------------------------------------------------------------------

func _make_materials(skin: SubSkins.Livery) -> void:
	hull_material = StandardMaterial3D.new()
	hull_material.uv1_triplanar = true
	hull_material.uv1_scale = Vector3(0.9, 0.9, 0.9)
	hull_material.metallic = 0.4
	hull_material.roughness = 0.4
	hull_material.rim_enabled = true
	hull_material.rim = 0.25
	if skin.pattern == &"plates" and skin.finish == &"":
		# Plain paint over the plating.
		hull_material.albedo_color = skin.color
		hull_material.albedo_texture = _plating_texture()
	else:
		var tex := SubSkins.textures(skin)
		hull_material.albedo_texture = tex[0]
		match skin.finish:
			&"chrome":
				# Mostly mirror, but with nothing down here to mirror it keeps
				# some of its color, and its edges catch the light.
				hull_material.metallic = 0.75
				hull_material.roughness = 0.16
				hull_material.rim = 0.7
			&"glow", &"pulse":
				hull_material.emission_enabled = true
				hull_material.emission = Color.WHITE
				hull_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				hull_material.emission_texture = tex[1]
				hull_material.emission_energy_multiplier = 1.6
				_pulse = skin.finish == &"pulse"
			&"sheen":
				hull_material.roughness = 0.25
				hull_material.next_pass = SubSkins.sheen()

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
	# A deep research submersible: a blunt pressure hull under a flat foam deck
	# and a short sail, viewports in heavy bezels at the bow, a lamp bar, a
	# folded manipulator, ducted thrusters and a skid frame.
	var hull := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.25), Vector2(0.06, 0.5), Vector2(0.2, 0.68),
		Vector2(0.55, 0.74), Vector2(0.8, 0.7), Vector2(0.92, 0.58), Vector2(0.98, 0.36), Vector2(1.0, 0.12)]),
		3.8, 24, 18, 0.88, 1.0)
	_part(hull, hull_material, Vector3(-0.1, 0, 0), Vector3.ZERO)
	var deck := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.12), Vector2(0.12, 0.42), Vector2(0.85, 0.46),
		Vector2(1, 0.2)]), 2.7, 16, 8, 0.32, 1.0)
	_part(deck, hull_material, Vector3(-0.25, 0.6, 0), Vector3.ZERO)
	var sail := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.16), Vector2(0.25, 0.3), Vector2(0.8, 0.3),
		Vector2(1, 0.14)]), 0.95, 14, 6, 1.25, 0.72)
	_part(sail, hull_material, Vector3(-0.35, 0.92, 0), Vector3.ZERO)
	_ring(0.2, 0.05, _dark, Vector3(-0.35, 1.28, 0), Vector3(0, 0, 0))
	_part(_cylinder(0.71, 0.71, 0.14, 24), _dark, Vector3(-1.15, 0, 0), Vector3(0, 0, -90))
	# Bow viewport in a heavy bezel, with two small side ports.
	_part(MeshKit.sphere(0.4, 20, 10), cockpit_material, Vector3(1.58, -0.08, 0), Vector3.ZERO)
	_ring(0.42, 0.07, _dark, Vector3(1.66, -0.08, 0), Vector3(0, 0, 90))
	for z: float in [0.56, -0.56]:
		_part(MeshKit.sphere(0.12, 10, 6), cockpit_material, Vector3(1.2, -0.28, z), Vector3.ZERO)
		_ring(0.13, 0.035, _dark, Vector3(1.2, -0.28, z * 1.04), Vector3(90, 0, 0))
	# Lamp bar over the viewport.
	_part(_box(Vector3(0.32, 0.13, 0.72)), _dark, Vector3(1.38, 0.5, 0), Vector3(0, 0, -12))
	_part(_box(Vector3(0.03, 0.07, 0.62)), MeshKit.emissive_material(Color(1.0, 0.95, 0.8), 4.0),
		Vector3(1.55, 0.47, 0), Vector3(0, 0, -12))
	# Manipulator arm folded under the bow, claw forward.
	var shoulder := Vector3(1.05, -0.6, 0.34)
	var elbow := Vector3(1.62, -0.74, 0.4)
	var wrist := Vector3(1.42, -0.92, 0.44)
	_part(MeshKit.sphere(0.09, 8, 4), _steel, shoulder, Vector3.ZERO)
	_seg(shoulder, elbow, 0.055, _steel)
	_part(MeshKit.sphere(0.07, 8, 4), _dark, elbow, Vector3.ZERO)
	_seg(elbow, wrist, 0.045, _steel)
	_seg(wrist, wrist + Vector3(0.18, 0.05, 0.03), 0.02, _dark)
	_seg(wrist, wrist + Vector3(0.18, -0.06, 0.03), 0.02, _dark)
	# Ducted lateral thrusters and a vertical one in the deck.
	for z: float in [0.86, -0.86]:
		_ring(0.2, 0.05, _dark, Vector3(-0.85, 0.05, z), Vector3(0, 0, 90))
		_part(_cylinder(0.05, 0.05, 0.2, 8), _steel, Vector3(-0.85, 0.05, z), Vector3(0, 0, -90))
		_seg(Vector3(-0.85, 0.05, z * 0.72), Vector3(-0.85, 0.05, z * 0.9), 0.045, _dark)
	_ring(0.22, 0.05, _dark, Vector3(-1.35, 0.72, 0), Vector3.ZERO)
	# Stern: shrouded main propeller and stabilisers.
	_part(_cylinder(0.3, 0.16, 0.4, 16), _dark, Vector3(-2.12, 0, 0), Vector3(0, 0, -90))
	_ring(0.42, 0.06, _dark, Vector3(-2.32, 0, 0), Vector3(0, 0, 90))
	_add_propeller(Vector3(-2.3, 0, 0), 3, 0.36)
	var stab := MeshKit.fin(PackedVector2Array([Vector2(0.3, 0), Vector2(-0.35, 0), Vector2(-0.45, 0.42),
		Vector2(-0.1, 0.4)]), 0.05)
	_part(stab, hull_material, Vector3(-1.75, 0.0, 0.5), Vector3(90, 0, 0))
	_part(stab, hull_material, Vector3(-1.75, 0.0, -0.5), Vector3(-90, 0, 0))
	_part(stab, hull_material, Vector3(-1.75, 0.45, 0), Vector3.ZERO)
	# Skid frame.
	for z: float in [0.42, -0.42]:
		_seg(Vector3(-1.3, -0.9, z), Vector3(1.05, -0.9, z), 0.04, _steel)
		_seg(Vector3(1.05, -0.9, z), Vector3(1.3, -0.72, z), 0.04, _steel)
		for x: float in [-0.9, 0.0, 0.85]:
			_seg(Vector3(x, -0.55, z * 0.8), Vector3(x, -0.9, z), 0.03, _steel)
	_part(_cylinder(0.015, 0.03, 0.6, 6), _steel, Vector3(-0.5, 1.55, 0), Vector3(0, 0, 10))
	strobe = _part(MeshKit.sphere(0.06), MeshKit.emissive_material(Color.WHITE, 6.0), Vector3(-0.56, 1.86, 0),
		Vector3.ZERO)
	_running_lights(Vector3(-1.95, 0.05, 0.95), Vector3(-1.95, 0.05, -0.95))


func _build_mako() -> void:
	# A fast attack sub: a long torpedo hull, a low canopy faired into a hump,
	# bow planes, an X-tail round a pump-jet, and torpedo ports in the bow.
	var hull := MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.12), Vector2(0.05, 0.3), Vector2(0.15, 0.45),
		Vector2(0.6, 0.5), Vector2(0.85, 0.44), Vector2(0.96, 0.28), Vector2(1.0, 0.06)]), 4.5, 22, 16, 0.82, 1.0)
	_part(hull, hull_material, Vector3(-0.1, 0, 0), Vector3.ZERO)
	var hump := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.05), Vector2(0.3, 0.22), Vector2(1, 0.04)]), 1.8, 14,
		8, 0.55, 1.0)
	_part(hump, hull_material, Vector3(-0.25, 0.33, 0), Vector3.ZERO)
	var canopy := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.04), Vector2(0.35, 0.25), Vector2(1, 0.02)]), 1.3,
		16, 8, 0.72, 0.72)
	_part(canopy, cockpit_material, Vector3(0.75, 0.35, 0), Vector3.ZERO)
	_part(_cylinder(0.46, 0.46, 0.08, 20), _dark, Vector3(-0.95, 0, 0), Vector3(0, 0, -90))
	# Bow planes and an X-tail.
	var plane := MeshKit.fin(PackedVector2Array([Vector2(0.2, 0), Vector2(-0.25, 0), Vector2(-0.45, 0.55),
		Vector2(-0.1, 0.52)]), 0.04)
	_part(plane, hull_material, Vector3(1.05, -0.02, 0.3), Vector3(90, 0, 0))
	_part(plane, hull_material, Vector3(1.05, -0.02, -0.3), Vector3(-90, 0, 0))
	var tail := MeshKit.fin(PackedVector2Array([Vector2(0.3, 0), Vector2(-0.45, 0), Vector2(-0.7, 0.95),
		Vector2(-0.25, 0.9)]), 0.05)
	for deg: float in [45.0, 135.0, 225.0, 315.0]:
		_part(tail, hull_material if deg < 180.0 else _dark, Vector3(-1.75, 0, 0), Vector3(deg - 90.0, 0, 0))
	# Pump-jet: a shroud round a many-bladed rotor.
	_part(_cylinder(0.26, 0.14, 0.35, 16), _dark, Vector3(-2.35, 0, 0), Vector3(0, 0, -90))
	_ring(0.3, 0.06, _dark, Vector3(-2.5, 0, 0), Vector3(0, 0, 90))
	_add_propeller(Vector3(-2.5, 0, 0), 5, 0.24)
	# Torpedo ports either side of the bow and tube fairings along the belly.
	for z: float in [0.2, -0.2]:
		_ring(0.075, 0.025, _dark, Vector3(1.72, -0.12, z), Vector3(0, 0, 90))
		var fairing := _capsule(0.11, 1.6)
		_part(fairing, hull_material, Vector3(0.35, -0.38, z * 1.3), Vector3(0, 0, -90))
	# Intake slots on the flanks.
	_part(_box(Vector3(0.5, 0.07, 0.04)), _dark, Vector3(0.1, 0.05, 0.49), Vector3.ZERO)
	_part(_box(Vector3(0.5, 0.07, 0.04)), _dark, Vector3(0.1, 0.05, -0.49), Vector3.ZERO)
	strobe = _part(MeshKit.sphere(0.05), MeshKit.emissive_material(Color.WHITE, 6.0), Vector3(-2.2, 0.48, 0.0),
			Vector3.ZERO)
	_running_lights(Vector3(-2.2, -0.42, 0.42), Vector3(-2.2, -0.42, -0.42))
	_part(_cylinder(0.11, 0.16, 0.25, 10), _dark, Vector3(1.55, -0.32, 0.0), Vector3(0, 0, -90))


func _build_bathysphere() -> void:
	# A Beebe-style bathysphere: a thick cast sphere with quartz ports in heavy
	# bezels, a bolted hatch and lifting eye, a reinforcing belt, a frame on
	# skids, a ballast tank and a thruster on an aft outrigger.
	_part(MeshKit.sphere(1.15, 28, 16), hull_material, Vector3.ZERO, Vector3.ZERO)
	_ring(1.16, 0.07, _dark, Vector3.ZERO, Vector3.ZERO)
	# Quartz ports: one big one forward, two smaller above it.
	_part(_cylinder(0.3, 0.34, 0.22, 16), _dark, Vector3(1.05, 0.12, 0), Vector3(0, 0, -90))
	_part(MeshKit.sphere(0.24, 14, 8), cockpit_material, Vector3(1.12, 0.12, 0), Vector3.ZERO)
	for z: float in [0.58, -0.58]:
		var at := Vector3(0.82, 0.52, z)
		var out := at.normalized()
		_seg(at - out * 0.05, at + out * 0.14, 0.17, _dark)
		_part(MeshKit.sphere(0.13, 10, 6), cockpit_material, at + out * 0.12, Vector3.ZERO)
	# Bolted hatch and lifting eye on top.
	_part(_cylinder(0.42, 0.46, 0.14, 18), _dark, Vector3(0, 1.12, 0), Vector3.ZERO)
	for i in 10:
		var a := TAU * i / 10.0
		_part(MeshKit.sphere(0.035, 6, 3), _steel, Vector3(cos(a) * 0.4, 1.2, sin(a) * 0.4), Vector3.ZERO)
	_ring(0.16, 0.04, _steel, Vector3(0, 1.42, 0), Vector3(90, 0, 0))
	# Frame: four posts down to a pair of skids.
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var top := Vector3(cos(a) * 0.95, -0.55, sin(a) * 0.95)
		var foot := Vector3(cos(a) * 1.05, -1.45, sin(a) * 0.75)
		_seg(top, foot, 0.05, _steel)
	for z: float in [0.75, -0.75]:
		_seg(Vector3(-1.0, -1.45, z), Vector3(1.0, -1.45, z), 0.06, _steel)
		_seg(Vector3(1.0, -1.45, z), Vector3(1.2, -1.28, z), 0.06, _steel)
	_part(_capsule(0.3, 1.7), hull_material, Vector3(-0.1, -1.08, 0.0), Vector3(0, 0, -90))
	# Aft outrigger with the thruster.
	_seg(Vector3(-0.95, 0.0, 0), Vector3(-1.45, 0.0, 0), 0.07, _steel)
	_part(_cylinder(0.26, 0.2, 0.42, 14), _dark, Vector3(-1.55, 0.0, 0.0), Vector3(0, 0, -90))
	_ring(0.34, 0.05, _dark, Vector3(-1.72, 0.0, 0.0), Vector3(0, 0, 90))
	_add_propeller(Vector3(-1.72, 0.0, 0.0), 3, 0.28)
	_part(_cylinder(0.02, 0.03, 0.8, 6), _steel, Vector3(-0.35, 1.45, 0), Vector3(0, 0, 8))
	strobe = _part(MeshKit.sphere(0.07), MeshKit.emissive_material(Color.WHITE, 6.0), Vector3(-0.41, 1.85, 0),
		Vector3.ZERO)
	_running_lights(Vector3(-0.3, 0.0, 1.24), Vector3(-0.3, 0.0, -1.24))
	_part(_cylinder(0.15, 0.22, 0.3, 12), _dark, Vector3(1.05, -0.62, 0.0), Vector3(0, 0, -90))


func _build_whisper() -> void:
	# A flattened, faceted stealth drone: smoked glass and a glowing sensor
	# strip instead of a canopy, seams of light, a faceted dorsal blade and a
	# hexagonal pump-jet.
	var hull := MeshKit.lathe(PackedVector2Array([
			Vector2(0.0, 0.25), Vector2(0.2, 0.55), Vector2(0.6, 0.6), Vector2(0.9, 0.35), Vector2(1.0, 0.05)]),
		3.8, 6, 10, 0.45, 1.25)
	_part(hull, hull_material, Vector3(0, 0, 0), Vector3.ZERO)
	var seam := MeshKit.emissive_material(Color(0.6, 0.4, 1.0), 3.0)
	_part(_box(Vector3(3.0, 0.03, 1.35)), seam, Vector3(-0.1, 0.0, 0.0), Vector3.ZERO)
	var glass := MeshKit.lathe(PackedVector2Array([Vector2(0, 0.02), Vector2(0.45, 0.22), Vector2(1, 0.02)]), 1.2, 6,
			6, 0.5, 1.0)
	_part(glass, _dark, Vector3(0.95, 0.2, 0), Vector3.ZERO)
	_part(_box(Vector3(0.5, 0.03, 0.08)), cockpit_material, Vector3(1.2, 0.27, 0), Vector3(0, 0, -8))
	var blade := MeshKit.fin(PackedVector2Array([Vector2(0.35, 0), Vector2(-0.55, 0), Vector2(-0.75, 0.5),
		Vector2(-0.45, 0.42)]), 0.05)
	_part(blade, hull_material, Vector3(-0.85, 0.24, 0), Vector3.ZERO)
	var vane := MeshKit.fin(PackedVector2Array([Vector2(0.2, 0), Vector2(-0.5, 0), Vector2(-0.7, 0.55), Vector2(-0.3,
			0.5)]), 0.04)
	_part(vane, hull_material, Vector3(-1.2, 0.05, 0.6), Vector3(80, 0, 0))
	_part(vane, hull_material, Vector3(-1.2, 0.05, -0.6), Vector3(-80, 0, 0))
	_part(_cylinder(0.32, 0.36, 0.5, 6), _dark, Vector3(-1.95, 0, 0), Vector3(0, 0, -90))
	var shroud := _ring(0.36, 0.05, _dark, Vector3(-2.2, 0, 0), Vector3(0, 0, 90))
	(shroud.mesh as TorusMesh).rings = 6
	_add_propeller(Vector3(-2.1, 0, 0), 6, 0.26)
	strobe = _part(MeshKit.sphere(0.04), MeshKit.emissive_material(Color(0.6, 0.4, 1.0), 4.0), Vector3(-1.45, 0.72, 0),
			Vector3.ZERO)
	_part(_cylinder(0.1, 0.14, 0.25, 8), _dark, Vector3(1.4, -0.22, 0.0), Vector3(0, 0, -90))


# --- Helpers ---------------------------------------------------------------------

## Bakes the static parts sharing a material into one mesh each (a frame is
## built from dozens of primitives); the propeller and strobe stay separate
## because they animate.
func _merge_static() -> void:
	var groups: Dictionary[Material, Array] = {}
	for child in get_children():
		var mi := child as MeshInstance3D
		if mi == null or mi == strobe:
			continue
		if not groups.has(mi.material_override):
			groups[mi.material_override] = []
		groups[mi.material_override].append(mi)
	for mat: Material in groups:
		var parts: Array = groups[mat]
		if parts.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi: MeshInstance3D in parts:
			for surface in mi.mesh.get_surface_count():
				st.append_from(mi.mesh, surface, mi.transform)
			remove_child(mi)
			mi.queue_free()
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = mat
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(merged)


## A cylinder strut from [param a] to [param b].
func _seg(a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.BACK)
	if x.length_squared() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var mi := _part(_cylinder(r, r, a.distance_to(b), 8), mat, (a + b) * 0.5, Vector3.ZERO)
	mi.basis = Basis(x, y, x.cross(y).normalized())
	return mi


## A ring (bezel, duct, collar) of [param radius] around its local Y axis.
func _ring(radius: float, thickness: float, mat: Material, pos: Vector3, rot_deg: Vector3) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius - thickness
	t.outer_radius = radius + thickness
	t.rings = 24
	t.ring_segments = 8
	return _part(t, mat, pos, rot_deg)


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
