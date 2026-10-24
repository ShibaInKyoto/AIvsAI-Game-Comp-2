class_name Mimic
extends Creature
## Looks exactly like a salvage cache until something gets close. Sonar marks
## it as hostile, which is the only tell. Worth a lot of salvage if killed.

enum State { DORMANT, LUNGE, CHASE, SETTLE }

var state := State.DORMANT
var _timer := 0.0
var _lid: MeshInstance3D
var _hinge: Node3D
var _t := 0.0


func setup() -> void:
	species = &"mimic"
	max_hp = 55.0
	radius = 1.0
	mass = 3.0
	contact_damage = 18.0
	salvage_drop = 26
	glow_color = Color(1.0, 0.75, 0.2)
	super.setup()
	scannable = false
	lock_facing = true


func build_model() -> void:
	var crate := StandardMaterial3D.new()
	crate.albedo_color = Color(0.85, 0.6, 0.15)
	crate.metallic = 0.6
	crate.roughness = 0.45
	var base := BoxMesh.new()
	base.size = Vector3(1.6, 0.6, 1.1)
	var body := MeshInstance3D.new()
	body.mesh = base
	body.material_override = crate
	body.position = Vector3(0, -0.25, 0)
	model.add_child(body)
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.6, 0.5, 1.1)
	_lid = MeshInstance3D.new()
	_lid.mesh = lid_mesh
	_lid.material_override = crate
	_hinge = Node3D.new()
	_hinge.position = Vector3(-0.8, 0.05, 0)
	model.add_child(_hinge)
	_hinge.add_child(_lid)
	_lid.position = Vector3(0.8, 0.25, 0)
	var tooth_mat := StandardMaterial3D.new()
	tooth_mat.albedo_color = Color(0.95, 0.92, 0.85)
	var teeth := []
	for i in 6:
		teeth.append([MeshKit.spike(0.06, 0.3, 0.0, 4), Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3(-0.6 + i * 0.24, 0.05, 0.4))])
		teeth.append([MeshKit.spike(0.06, 0.3, 0.0, 4), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(-0.6 + i * 0.24, -0.25, 0.4))])
	var t_mesh := MeshInstance3D.new()
	t_mesh.mesh = MeshKit.merge(teeth)
	t_mesh.material_override = tooth_mat
	model.add_child(t_mesh)
	var eye := MeshInstance3D.new()
	eye.mesh = SubmarineModel._sphere(0.1)
	eye.material_override = SubmarineModel._emissive(Color(1.0, 0.3, 0.1), 6.0)
	eye.position = Vector3(0.55, 0.2, 0.5)
	_lid.add_child(eye)


func think() -> void:
	if state == State.DORMANT:
		var sub := level.player
		if sub and sub.alive and sub.pos.distance_to(pos) < 4.8:
			_wake()


func _wake() -> void:
	alert()
	state = State.LUNGE
	_timer = 0.8
	scannable = true
	Audio.play_at(&"lurelight_snap", pos, 3.0)
	if level.player:
		vel = (level.player.pos - pos).normalized() * 14.0


func behave(delta: float) -> void:
	_t += delta
	var open := 0.0
	match state:
		State.DORMANT:
			vel = vel.lerp(Vector2(0, -0.6), 1.0 - exp(-1.2 * delta))
		State.LUNGE:
			_timer -= delta
			open = 0.9
			if _timer <= 0.0:
				state = State.CHASE
				_timer = 7.0
		State.CHASE:
			_timer -= delta
			open = 0.3 + 0.3 * sin(_t * 9.0)
			var sub := level.player
			if sub and sub.alive:
				seek(sub.pos, 6.5, 2.0, delta)
				facing = (sub.pos - pos).normalized()
			if _timer <= 0.0:
				state = State.SETTLE
		State.SETTLE:
			vel = vel.lerp(Vector2(0, -1.0), 1.0 - exp(-1.0 * delta))
			if level.player and level.player.pos.distance_to(pos) < 4.0:
				_wake()
	_hinge.rotation.z = lerpf(_hinge.rotation.z, open, 1.0 - exp(-10.0 * delta))
	model.rotation.z = 0.0 if state == State.DORMANT else clampf(vel.x * 0.04, -0.3, 0.3)


func _update_visuals(_delta: float) -> void:
	pass


func on_harpoon_hit(harpoon: Node, damage: float) -> HarpoonReaction:
	if state == State.DORMANT:
		_wake()
	return super.on_harpoon_hit(harpoon, damage)


func on_touch_player(sub: Submarine) -> void:
	if state == State.DORMANT:
		_wake()
	sub.take_damage(contact_damage, pos, self)
	Audio.play_at(&"stalker_bite", pos, -2.0)


func die() -> void:
	Pickup.scatter(level, pos, &"power", 20, 1.0)
	super.die()
