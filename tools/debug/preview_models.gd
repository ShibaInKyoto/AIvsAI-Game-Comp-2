extends Node3D
## Debug helper: renders the four submarine frames side by side, or with
## "skins" every frame's challenge skins, a row per frame.
## Usage: xvfb-run godot --path . res://tools/debug/preview_models.tscn -- <out.png> [skins]

var _frames := 0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.55, 0.65)
	env.ambient_light_sky_contribution = 0.0
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var frames := Catalog.frames()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 13)
	if OS.get_cmdline_user_args().has("skins"):
		var skins := SubSkins.all().filter(func(s: SubSkins.Livery) -> bool: return not s.is_paint())
		for i in skins.size():
			var m := SubmarineModel.new()
			add_child(m)
			m.build(skins[i].frame, skins[i])
			m.position = Vector3((i % 3) * 5.5 - 5.5, 5.4 - (i / 3) * 3.6, 0)
			m.rotation_degrees = Vector3(10, -25, 0)
		cam.position = Vector3(0, 0, 19)
	else:
		for i in frames.size():
			var m := SubmarineModel.new()
			add_child(m)
			m.build(frames[i].id)
			m.position = Vector3((i % 2) * 6.0 - 3.0, 2.0 - (i / 2) * 4.0, 0)
			m.rotation_degrees = Vector3(10, -25, 0)
	cam.fov = 45
	add_child(cam)


func _process(_d: float) -> void:
	_frames += 1
	if _frames == 10:
		var args := OS.get_cmdline_user_args()
		get_viewport().get_texture().get_image().save_png(args[0] if args.size() > 0 else "user://models.png")
		get_tree().quit()
